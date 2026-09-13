#import <UIKit/UIKit.h>
#import "TGBubbleCellDelegate.h"

@class TGMessageItem;
@class TGMessageLayout;
@class TGEmojiLabel;

@interface TGMessageRowCell : UITableViewCell

@property (nonatomic, weak) id<TGBubbleCellDelegate> delegate;

@property (nonatomic, strong, readonly) UIView *dayPlate;
@property (nonatomic, strong, readonly) UILabel *dayLabel;
@property (nonatomic, strong, readonly) UIButton *dayHit;
@property (nonatomic, strong, readonly) UIView *unreadStrip;
@property (nonatomic, strong, readonly) UIView *unreadTopLine;
@property (nonatomic, strong, readonly) UIView *unreadBottomLine;
@property (nonatomic, strong, readonly) UILabel *unreadLabel;
@property (nonatomic, strong, readonly) UIImageView *unreadArrow;
@property (nonatomic, strong, readonly) UIImageView *selectionCheck;

@property (nonatomic, assign, readonly) int64_t appliedMessageId;
@property (nonatomic, assign) NSInteger appliedRow;
@property (nonatomic, assign) CGFloat headerHeight;
@property (nonatomic, assign) CGPoint lastTouchInCell;
@property (nonatomic, assign) BOOL lastTouchKnown;

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout;

- (void)setSelectionChecked:(BOOL)checked
					  image:(UIImage *)image
					 hidden:(BOOL)hidden
				   animated:(BOOL)animated;

- (TGEmojiLabel *)tg_richTextLabel;

@end
