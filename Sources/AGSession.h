#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const AGSessionErrorDomain;

/// A temporary power assertion. All state and callbacks are used on the main thread.
/// The system's saved power and security settings are never modified.
@interface AGSession : NSObject

@property (nonatomic, readonly, getter=isActive) BOOL active;
@property (nonatomic, readonly) BOOL keepDisplayAwake;
/// Best-effort idle activity declaration. Does not unlock the Mac or change password policy.
@property (nonatomic, readonly) BOOL keepUnlocked;
/// Zero denotes an indefinite session.
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval elapsed;
/// INFINITY for an indefinite active session; zero while inactive.
@property (nonatomic, readonly) NSTimeInterval remaining;
@property (nonatomic, readonly, nullable) NSDate *endDate;
@property (nonatomic, readonly, copy) NSString *status;
@property (nonatomic, readonly, copy) NSString *stopReason;
@property (nonatomic, readonly, nullable) NSError *lastError;
@property (nonatomic, copy, nullable) void (^onChange)(AGSession *session);

/// A duration of zero means until stopped. Invalid durations leave an existing session intact.
- (BOOL)startWithDuration:(NSTimeInterval)duration
        keepDisplayAwake:(BOOL)keepDisplayAwake
            keepUnlocked:(BOOL)keepUnlocked
                   error:(NSError * _Nullable * _Nullable)error;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
