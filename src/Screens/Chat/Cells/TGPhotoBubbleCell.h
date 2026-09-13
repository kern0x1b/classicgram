#import "TGBubbleCellBase.h"
#import "TGFileStatusView.h"

@interface TGPhotoBubbleCell : TGBubbleCellBase

@property (nonatomic, strong, readonly) UIImageView *picture;
@property (nonatomic, strong, readonly) UIImageView *disc;
@property (nonatomic, strong, readonly) TGFileStatusView *fileStatus;
@property (nonatomic, strong, readonly) UILabel *mediaBadge;
@property (nonatomic, strong, readonly) TGEmojiLabel *body;

@end
