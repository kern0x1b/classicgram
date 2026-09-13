#include <UIKit/UIKit.h>
#include "UIKit/UIKit.h"
@interface RootViewController : UITabBarController

- (void)updateUnreadBadge;

- (CGFloat)tabBarInsetForController:(UIViewController *)controller;

+ (RootViewController *)splitRootController;

+ (BOOL)isSplitLayoutActive;
- (BOOL)isSplitLayoutActive;

- (UISplitViewController *)splitLayoutController;

+ (void)forgetSplitLayout;

+ (BOOL)iconBadgeWasPushed;

+ (UINavigationController *)detailNavigationController;
- (UINavigationController *)detailNavigationController;

+ (BOOL)presentInDetail:(UIViewController *)controller;
- (BOOL)presentInDetail:(UIViewController *)controller;

+ (BOOL)pushInDetail:(UIViewController *)controller;
- (BOOL)pushInDetail:(UIViewController *)controller;

+ (void)showDetailEmptyState;
- (void)showDetailEmptyState;

@end
