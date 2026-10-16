#import <AppKit/AppKit.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <math.h>
#import <string.h>
#import <unistd.h>
#import "../Sources/AGSession.h"

static void Check(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message.UTF8String);
        exit(1);
    }
}

static NSArray<NSDictionary *> *OwnedAssertions(void) {
    CFDictionaryRef all = NULL;
    Check(IOPMCopyAssertionsByProcess(&all) == kIOReturnSuccess,
          @"Read power assertions");
    NSDictionary *byPID = CFBridgingRelease(all);
    NSMutableArray *owned = NSMutableArray.array;
    for (NSDictionary *assertion in byPID[@(getpid())]) {
        NSString *name = assertion[(__bridge NSString *)kIOPMAssertionNameKey];
        if ([name hasPrefix:@"Awake Glass:"]) [owned addObject:assertion];
    }
    return owned;
}

static void DrainRunLoop(NSTimeInterval seconds) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (deadline.timeIntervalSinceNow > 0) {
        [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode
                           beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        AGSession *session = AGSession.new;
        NSError *error = nil;
        __block NSUInteger callbacks = 0;
        session.onChange = ^(AGSession *changed) { callbacks++; };

        Check([session startWithDuration:0 keepDisplayAwake:YES keepUnlocked:NO error:&error],
              error.localizedDescription ?: @"Start indefinite session");
        Check(session.isActive && isinf(session.remaining) && session.endDate == nil,
              @"Indefinite session state");
        Check(OwnedAssertions().count == 2, @"Own system and display assertions");
        Check(![session startWithDuration:-1 keepDisplayAwake:NO keepUnlocked:NO error:&error],
              @"Reject invalid duration");
        Check(session.isActive && OwnedAssertions().count == 2,
              @"Invalid input preserves current session");
        [session stop];
        Check(!session.isActive && session.remaining == 0 && OwnedAssertions().count == 0,
              @"Explicit stop releases all assertions");

        Check([session startWithDuration:1 keepDisplayAwake:YES keepUnlocked:NO error:&error],
              @"Start finite session");
        Check(session.endDate != nil && session.remaining > 0 && session.remaining <= 1,
              @"Finite deadline state");
        for (NSDictionary *assertion in OwnedAssertions()) {
            Check([assertion[(__bridge NSString *)kIOPMAssertionTimeoutActionKey]
                    isEqual:(__bridge NSString *)kIOPMAssertionTimeoutActionRelease],
                  @"Kernel timeout uses release action");
        }
        // Deliberately stall this test's timer: powerd must still release the
        // assertions independently. No system setting or screen state is changed.
        usleep(1500000);
        Check(OwnedAssertions().count == 0, @"Kernel releases assertions while run loop stalls");
        DrainRunLoop(0.15);
        Check(!session.isActive && [session.stopReason isEqual:@"expired"],
              @"Timer records expiry after the run loop resumes");

        Check([session startWithDuration:0 keepDisplayAwake:NO keepUnlocked:NO error:&error],
              @"Start Mac-only session");
        Check(OwnedAssertions().count == 1, @"Mac-only session owns one assertion");
        [NSWorkspace.sharedWorkspace.notificationCenter
            postNotificationName:NSWorkspaceScreensDidSleepNotification object:nil];
        Check(session.isActive && OwnedAssertions().count == 1,
              @"Mac-only mode keeps its system assertion when the display sleeps");
        [NSWorkspace.sharedWorkspace.notificationCenter
            postNotificationName:NSWorkspaceSessionDidResignActiveNotification object:nil];
        Check(!session.isActive && OwnedAssertions().count == 0,
              @"Session resign releases all assertions and never resumes automatically");

        if (argc > 1 && strcmp(argv[1], "--activity") == 0) {
            Check([session startWithDuration:0 keepDisplayAwake:YES keepUnlocked:YES error:&error],
                  error.localizedDescription ?: @"Start indefinite public activity refresh");
            NSDictionary *firstActivity = nil;
            for (NSDictionary *assertion in OwnedAssertions()) {
                if ([assertion[(__bridge NSString *)kIOPMAssertionNameKey]
                        isEqual:@"Awake Glass: delay idle screen lock"]) firstActivity = assertion;
            }
            Check(firstActivity != nil, @"Activity declaration has an owned assertion");
            DrainRunLoop(16.2);
            NSUInteger activeActivityCount = 0;
            for (NSDictionary *assertion in OwnedAssertions()) {
                if ([assertion[(__bridge NSString *)kIOPMAssertionNameKey]
                        isEqual:@"Awake Glass: delay idle screen lock"] &&
                    [assertion[(__bridge NSString *)kIOPMAssertionLevelKey] intValue] != 0) {
                    activeActivityCount++;
                }
            }
            Check(session.isActive && activeActivityCount == 1,
                  @"Refresh remains active across 15 seconds without duplicate activity assertions");
            [session stop];
            Check(OwnedAssertions().count == 0,
                  @"Stop releases the current activity assertion after a refresh");

            Check([session startWithDuration:2 keepDisplayAwake:YES keepUnlocked:YES error:&error],
                  error.localizedDescription ?: @"Start public activity refresh");
            Check(session.isActive && OwnedAssertions().count >= 2,
                  @"Activity session is active");
            DrainRunLoop(2.3);
            Check(!session.isActive && OwnedAssertions().count == 0,
                  @"Activity assertion also releases at expiry");
        }
        Check(callbacks >= 6, @"Observers see state changes");
        printf("PASS: temporary assertions, expiry, kernel timeout, stop, validation and session safety\n");
    }
    return 0;
}
