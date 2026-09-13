#import <UIKit/UIKit.h>

@interface TGStarsListBadgeSubtitleCell : UITableViewCell

- (void)applyTitle:(NSString *)title
		 badgeText:(NSString *)badgeText
		detailText:(NSString *)detailText
	   destructive:(BOOL)destructive
		  tappable:(BOOL)tappable;

@end
