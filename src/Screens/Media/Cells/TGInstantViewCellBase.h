#import "TGInstantViewRowCell.h"

@class TGInstantViewItem;
@class TGEmojiLabel;

@interface TGInstantViewCellBase : TGInstantViewRowCell

@property (nonatomic, strong, readonly) TGEmojiLabel *body;
@property (nonatomic, strong, readonly) UIView *bar;
@property (nonatomic, strong, readonly) UIImageView *picture;
@property (nonatomic, strong, readonly) UILabel *caption;
@property (nonatomic, assign) CGPoint lastTouchInCell;
@property (nonatomic, assign) BOOL lastTouchKnown;

- (void)applyItem:(TGInstantViewItem *)item image:(UIImage *)image;

@end
