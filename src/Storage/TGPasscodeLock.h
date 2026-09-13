#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGPasscodeLockDidUnlockNotification;

@interface TGPasscodeLock : NSObject

+ (instancetype)shared;

- (BOOL)isSet;
- (BOOL)isSimple;
- (BOOL)matches:(NSString *)passcode;
- (BOOL)attemptUnlock:(NSString *)passcode;
- (NSTimeInterval)lockoutRemainingSeconds;

- (BOOL)setPasscode:(NSString *)passcode simple:(BOOL)simple;
- (BOOL)removePasscode;

- (NSInteger)autoLockSeconds;
- (void)setAutoLockSeconds:(NSInteger)seconds;

- (BOOL)isLocked;
- (BOOL)isLockedOrWillLockOnReturn;

- (void)applicationDidFinishLaunching;
- (void)applicationWillResignActive;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationDidBecomeActive;

@end

NS_ASSUME_NONNULL_END
