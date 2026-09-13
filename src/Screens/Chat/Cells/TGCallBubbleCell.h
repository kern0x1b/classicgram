#import "TGBubbleCellBase.h"

@interface TGCallBubbleCell : TGBubbleCellBase

@property (nonatomic, strong, readonly) UIImageView *glyph;
@property (nonatomic, strong, readonly) UILabel *title;
@property (nonatomic, strong, readonly) UILabel *detail;

@end
