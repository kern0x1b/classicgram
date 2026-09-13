#import "TGMessageRowCell.h"
#import "TGEmoji.h"

@interface TGServiceRowCell : TGMessageRowCell

@property (nonatomic, strong, readonly) UIView *plate;
@property (nonatomic, strong, readonly) TGEmojiLabel *body;
@property (nonatomic, strong, readonly) UIImageView *picture;

@end
