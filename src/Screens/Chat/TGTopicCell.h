#import <UIKit/UIKit.h>
#import "TGDateLabel.h"

@interface TGTopicCell : UITableViewCell

@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *previewLabel;
@property (nonatomic, strong) TGDateLabel *dateLabel;
@property (nonatomic, strong) UIImageView *badgeBackground;
@property (nonatomic, strong) UILabel *badge;
@property (nonatomic, strong) UIImageView *arrow;
@property (nonatomic, strong) UIImageView *pinIcon;
@property (nonatomic, strong) UIImageView *muteIcon;
- (void)applyBadgeShadowForHighlight:(BOOL)highlighted;

@end
