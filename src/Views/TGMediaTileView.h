#import "TGRemoteImageView.h"

extern const CGFloat kMediaTileSide;
extern const CGFloat kMediaTileSpacing;
extern NSString *const TGMediaTileIdentifier;

UIColor *TGMediaPlaceholderColour(void);
NSString *TGMediaFormatDuration(NSInteger seconds);
UIImage *TGMediaTilePlaceholder(void);

@interface TGMediaTileView : TGRemoteImageView

@property (nonatomic, strong) UIView *badgeBar;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIImageView *playView;
@property (nonatomic, strong) UIImageView *shadowView;

- (void)showVideoBadge:(NSString *)text;
- (void)hideVideoBadge;

@end
