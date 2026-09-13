#import <UIKit/UIKit.h>

NSArray *TGVisibleAlertsInViewTree(UIView *root);
NSArray *TGVisibleAlertsInWindows(NSArray *windows);
void TGDismissVisibleAlertsInWindows(NSArray *windows);
