#import "TGContactsProgressWindow.h"

@implementation TGContactsProgressWindow

- (void)show {
	if (self.window)
		return;
	CGRect bounds = [[UIScreen mainScreen] bounds];
	self.window = [[UIWindow alloc] initWithFrame:bounds];
	self.window.windowLevel = UIWindowLevelStatusBar + 1.0f;
	self.window.backgroundColor = [UIColor clearColor];
	self.window.userInteractionEnabled = YES;

	UIView *dim = [[UIView alloc] initWithFrame:bounds];
	dim.backgroundColor = [UIColor clearColor];
	[self.window addSubview:dim];

	CGFloat containerX = (CGFloat)(int)((bounds.size.width - 100) / 2);
	CGFloat containerY = (CGFloat)(int)((bounds.size.height - 100) / 2);
	self.containerView = [[UIView alloc] initWithFrame:CGRectMake(containerX, containerY, 100, 100)];
	self.containerView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.7f];
	self.containerView.layer.cornerRadius = 16.0f;
	self.containerView.alpha = 0.0f;
	[dim addSubview:self.containerView];

	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	spinner.center = CGPointMake(50, 50);
	spinner.frame = CGRectIntegral(spinner.frame);
	[spinner startAnimating];
	[self.containerView addSubview:spinner];

	self.window.hidden = NO;
	[UIView animateWithDuration:0.3f animations:^{
		self.containerView.alpha = 1.0f;
	}];
}

- (void)dismiss {
	if (!self.window)
		return;
	UIWindow *window = self.window;
	UIView *container = self.containerView;
	self.window = nil;
	self.containerView = nil;
	[UIView animateWithDuration:0.3f animations:^{
		container.alpha = 0.0f;
	} completion:^(BOOL finished) {
		window.hidden = YES;
	}];
}

@end
