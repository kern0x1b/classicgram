#import "TGLoginCoordinator.h"

@interface TGLoginCoordinator ()

@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, strong, readwrite, nullable) TGLoginViewController *loginViewController;

@end

@implementation TGLoginCoordinator

- (instancetype)initWithWindow:(UIWindow *)window {
	self = [super init];
	if (self)
		_window = window;
	return self;
}

- (void)start {
	if (self.loginViewController)
		return;

	TGLoginViewController *loginVC = [[TGLoginViewController alloc] init];
	loginVC.cancellable = self.cancellable;
	self.loginViewController = loginVC;

	__weak typeof(self) weakSelf = self;
	loginVC.onCancelled = ^{
		typeof(weakSelf) strongSelf = weakSelf;
		if (strongSelf.onCancelled)
			strongSelf.onCancelled();
	};
	loginVC.onPhoneSubmitted = ^(NSString *phoneNumber) {
		typeof(weakSelf) strongSelf = weakSelf;
		if (strongSelf.onPhoneSubmitted)
			strongSelf.onPhoneSubmitted(phoneNumber);
	};
	loginVC.onCodeSubmitted = ^(NSString *code) {
		typeof(weakSelf) strongSelf = weakSelf;
		if (strongSelf.onCodeSubmitted)
			strongSelf.onCodeSubmitted(code);
	};
	loginVC.onPasswordSubmitted = ^(NSString *password) {
		typeof(weakSelf) strongSelf = weakSelf;
		if (strongSelf.onPasswordSubmitted)
			strongSelf.onPasswordSubmitted(password);
	};

	UINavigationController *nav =
		[[UINavigationController alloc] initWithRootViewController:loginVC];
	[self.window setRootViewController:nav];
}

- (void)finish {
	self.loginViewController = nil;
}

@end
