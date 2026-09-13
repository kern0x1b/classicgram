#import "TGBubbleCellBase.h"

@interface TGAlbumBubbleCell : TGBubbleCellBase

@property (nonatomic, strong, readonly) UIView *album;
@property (nonatomic, strong, readonly) TGEmojiLabel *body;

@property (nonatomic, readonly) NSUInteger tileCount;
- (UIImageView *)tileAtIndex:(NSUInteger)index;

@end
