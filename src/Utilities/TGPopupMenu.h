#import <UIKit/UIKit.h>

@interface TGPopupMenu : UIView

+ (void)showItems:(NSArray *)items
		  atPoint:(CGPoint)point
		   inView:(UIView *)host
		 onChoice:(void (^)(NSInteger index, NSString *title))choice;

+ (void)dismiss;

@end
