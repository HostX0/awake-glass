#import "AGSession.h"
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <mach/mach_time.h>
#import <math.h>

NSErrorDomain const AGSessionErrorDomain = @"AGSessionErrorDomain";

static NSTimeInterval AGContinuousTime(void) {
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&timebase); });
    return (double)mach_continuous_time() * (double)timebase.numer /
           (double)timebase.denom / 1e9;
}

static NSError *AGPowerError(IOReturn result, NSString *description) {
    return [NSError errorWithDomain:AGSessionErrorDomain code:result
                          userInfo:@{NSLocalizedDescriptionKey: description,
                                     @"IOKitReturn": @(result)}];
}

@interface AGSession () {
    IOPMAssertionID _systemAssertion;
    IOPMAssertionID _displayAssertion;
    IOPMAssertionID _activityAssertion;
    NSTimeInterval _continuousStart;
    NSTimeInterval _lastActivityRefresh;
    NSTimeInterval _finalElapsed;
}
@property (nonatomic, readwrite, getter=isActive) BOOL active;
@property (nonatomic, readwrite) BOOL keepDisplayAwake;
@property (nonatomic, readwrite) BOOL keepUnlocked;
@property (nonatomic, readwrite) NSTimeInterval duration;
@property (nonatomic, readwrite, nullable) NSDate *endDate;
@property (nonatomic, readwrite, copy) NSString *status;
@property (nonatomic, readwrite, copy) NSString *stopReason;
@property (nonatomic, readwrite, nullable) NSError *lastError;
@property (nonatomic, strong, nullable) NSTimer *timer;
@end

@implementation AGSession

- (instancetype)init {
    self = [super init];
    if (self) {
        _systemAssertion = kIOPMNullAssertionID;
        _displayAssertion = kIOPMNullAssertionID;
        _activityAssertion = kIOPMNullAssertionID;
        _status = @"Ready";
        _stopReason = @"";
        NSNotificationCenter *workspace = NSWorkspace.sharedWorkspace.notificationCenter;
        [workspace addObserver:self selector:@selector(sessionBecameInactive:)
                          name:NSWorkspaceSessionDidResignActiveNotification object:nil];
        [workspace addObserver:self selector:@selector(screensWillSleep:)
                          name:NSWorkspaceScreensDidSleepNotification object:nil];
        [workspace addObserver:self selector:@selector(systemWillSleep:)
                          name:NSWorkspaceWillSleepNotification object:nil];
        [workspace addObserver:self selector:@selector(systemDidWake:)
                          name:NSWorkspaceDidWakeNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                 selector:@selector(applicationWillTerminate:)
                     name:NSApplicationWillTerminateNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                 selector:@selector(clockChanged:)
                     name:NSSystemClockDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [self.timer invalidate];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self releaseAssertions];
    // macOS also drops every assertion owned by a process when that process exits.
}

- (NSTimeInterval)elapsed {
    return self.active ? MAX(0, AGContinuousTime() - _continuousStart) : _finalElapsed;
}

- (NSTimeInterval)remaining {
    if (!self.active) return 0;
    if (self.duration == 0) return INFINITY;
    NSTimeInterval monotonicRemaining = MAX(0, self.duration - self.elapsed);
    // A forward clock change must not extend a finite session. A backward change
    // also cannot extend it because the continuous-clock deadline still applies.
    return MIN(monotonicRemaining, MAX(0, [self.endDate timeIntervalSinceNow]));
}

- (BOOL)startWithDuration:(NSTimeInterval)duration
        keepDisplayAwake:(BOOL)keepDisplayAwake
            keepUnlocked:(BOOL)keepUnlocked
                   error:(NSError **)error {
    if (error) *error = nil;
    if (!NSThread.isMainThread || !isfinite(duration) || duration < 0) {
        NSError *validation = AGPowerError(kIOReturnBadArgument,
            !NSThread.isMainThread ? @"Start a session on the main thread." :
            @"Choose a valid duration, or zero for an indefinite session.");
        if (error) *error = validation;
        return NO;
    }

    // A visible, logged-in console session is required for activity refresh.
    // Public session keys are used; no private screen-lock keys are inspected.
    CFDictionaryRef currentSession = CGSessionCopyCurrentDictionary();
    BOOL consoleActive = currentSession &&
        CFDictionaryGetValue(currentSession, kCGSessionOnConsoleKey) == kCFBooleanTrue &&
        CFDictionaryGetValue(currentSession, kCGSessionLoginDoneKey) == kCFBooleanTrue;
    if (currentSession) CFRelease(currentSession);
    if (keepUnlocked && !consoleActive) {
        NSError *inactive = AGPowerError(kIOReturnNotPermitted,
                                        @"Activity refresh requires an active desktop session.");
        if (error) *error = inactive;
        return NO;
    }

    [self finishWithReason:@"replaced" status:@"Ready" notify:NO];
    self.duration = duration;
    self.keepDisplayAwake = keepDisplayAwake;
    self.keepUnlocked = keepUnlocked;
    self.endDate = duration > 0 ? [NSDate dateWithTimeIntervalSinceNow:duration] : nil;
    self.lastError = nil;
    self.stopReason = @"";
    _continuousStart = AGContinuousTime();
    _lastActivityRefresh = 0;
    _finalElapsed = 0;

    IOReturn result = [self createAssertion:kIOPMAssertPreventUserIdleSystemSleep
                                     name:CFSTR("Awake Glass: keep Mac awake")
                                assertion:&_systemAssertion];
    if (result == kIOReturnSuccess && keepDisplayAwake) {
        result = [self createAssertion:kIOPMAssertPreventUserIdleDisplaySleep
                                  name:CFSTR("Awake Glass: keep display awake")
                             assertion:&_displayAssertion];
    }
    if (result == kIOReturnSuccess && keepUnlocked) {
        result = [self refreshUserActivity];
    }
    if (result != kIOReturnSuccess) {
        self.lastError = AGPowerError(result, @"macOS could not start the requested awake session.");
        [self finishWithReason:@"error" status:@"Could not start" notify:YES];
        if (error) *error = self.lastError;
        return NO;
    }

    self.active = YES;
    self.status = @"Active";
    __weak AGSession *weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        [weakSelf tick];
    }];
    self.timer.tolerance = 0.1;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self notifyChange];
    return YES;
}

- (IOReturn)createAssertion:(CFStringRef)type name:(CFStringRef)name
                 assertion:(IOPMAssertionID *)assertion {
    return IOPMAssertionCreateWithDescription(type, name,
        CFSTR("Temporary session requested from Awake Glass"), NULL, NULL,
        self.duration, self.duration > 0 ? kIOPMAssertionTimeoutActionRelease : NULL,
        assertion);
}

- (IOReturn)refreshUserActivity {
    IOReturn result = IOPMAssertionDeclareUserActivity(
        CFSTR("Awake Glass: delay idle screen lock"), kIOPMUserActiveLocal,
        &_activityAssertion);
    if (result == kIOReturnSuccess) {
        _lastActivityRefresh = AGContinuousTime();
        // The public activity declaration creates/reuses an assertion. Keep its
        // lifetime bounded by this session too, including when our timer stalls.
        // It does not unlock a locked session or change any password setting.
        if (self.duration > 0 && _activityAssertion != kIOPMNullAssertionID) {
            NSTimeInterval remaining = MIN(self.duration -
                (AGContinuousTime() - _continuousStart), [self.endDate timeIntervalSinceNow]);
            if (remaining <= 0) return kIOReturnTimeout;
            result = IOPMAssertionSetProperty(_activityAssertion,
                kIOPMAssertionTimeoutActionKey, kIOPMAssertionTimeoutActionRelease);
            if (result == kIOReturnSuccess) {
                result = IOPMAssertionSetProperty(_activityAssertion,
                    kIOPMAssertionTimeoutKey, (__bridge CFNumberRef)@(remaining));
            }
        }
    }
    return result;
}

- (void)tick {
    if (!self.active) return;
    if (self.duration > 0 && self.remaining <= 0) {
        [self finishWithReason:@"expired" status:@"Finished" notify:YES];
        return;
    }
    if (self.keepUnlocked && AGContinuousTime() - _lastActivityRefresh >= 15) {
        IOReturn result = [self refreshUserActivity];
        if (result != kIOReturnSuccess) {
            self.lastError = AGPowerError(result, @"macOS stopped the idle activity refresh.");
            [self finishWithReason:@"error" status:@"Stopped" notify:YES];
            return;
        }
    }
    [self notifyChange];
}

- (void)stop {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self stop]; });
        return;
    }
    [self finishWithReason:@"stopped" status:@"Stopped" notify:YES];
}

- (void)releaseAssertions {
    IOPMAssertionID *assertions[] = {&_activityAssertion, &_displayAssertion, &_systemAssertion};
    for (NSUInteger index = 0; index < sizeof(assertions) / sizeof(assertions[0]); index++) {
        IOPMAssertionID assertion = *assertions[index];
        *assertions[index] = kIOPMNullAssertionID;
        if (assertion != kIOPMNullAssertionID) {
            // Release may report not-found after powerd's finite timeout released it.
            IOPMAssertionRelease(assertion);
        }
    }
}

- (void)finishWithReason:(NSString *)reason status:(NSString *)status notify:(BOOL)notify {
    if (self.active) _finalElapsed = self.elapsed;
    self.active = NO;
    [self.timer invalidate];
    self.timer = nil;
    [self releaseAssertions];
    self.status = status;
    self.stopReason = reason;
    if (notify) [self notifyChange];
}

- (void)notifyChange {
    if (self.onChange) self.onChange(self);
}

- (void)stopForSystemReason:(NSString *)reason {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self stopForSystemReason:reason]; });
        return;
    }
    if (self.active) [self finishWithReason:reason status:@"Paused by macOS" notify:YES];
}

- (void)sessionBecameInactive:(NSNotification *)notification {
    [self stopForSystemReason:@"session-inactive"];
}
- (void)screensWillSleep:(NSNotification *)notification {
    // A dark display is expected in Mac-only mode: its system assertion must
    // remain active so background work can continue. In the display/activity
    // modes, respect an intentional display sleep and stop activity refresh.
    if (self.keepDisplayAwake || self.keepUnlocked) {
        [self stopForSystemReason:@"display-sleep"];
    }
}
- (void)systemWillSleep:(NSNotification *)notification {
    [self stopForSystemReason:@"system-sleep"];
}
- (void)systemDidWake:(NSNotification *)notification { [self tick]; }
- (void)clockChanged:(NSNotification *)notification { [self tick]; }
- (void)applicationWillTerminate:(NSNotification *)notification { [self stop]; }

@end
