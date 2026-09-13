#import "TGBubbleCellBase.h"

@interface TGMapBubbleCell : TGBubbleCellBase

@property (nonatomic, strong, readonly) UIImageView *picture;
@property (nonatomic, strong, readonly) TGEmojiLabel *body;

@end
