#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGResendCountdown : NSObject

@property (nonatomic, copy, nullable) void (^onTick)(NSInteger secondsRemaining);
@property (nonatomic, copy, nullable) void (^onFinished)(void);

- (void)startWithSeconds:(NSInteger)seconds;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
