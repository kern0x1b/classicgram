#import <UIKit/UIKit.h>
#import "TGCoordinator.h"
#import "TGLoginViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGLoginCoordinator : TGCoordinator

@property (nonatomic, strong, readonly, nullable) TGLoginViewController *loginViewController;
@property (nonatomic, assign) BOOL cancellable;

@property (nonatomic, copy, nullable) void (^onCancelled)(void);
@property (nonatomic, copy, nullable) void (^onPhoneSubmitted)(NSString *phoneNumber);
@property (nonatomic, copy, nullable) void (^onCodeSubmitted)(NSString *code);
@property (nonatomic, copy, nullable) void (^onPasswordSubmitted)(NSString *password);

- (instancetype)initWithWindow:(UIWindow *)window;
- (void)start;
- (void)finish;

@end

NS_ASSUME_NONNULL_END
