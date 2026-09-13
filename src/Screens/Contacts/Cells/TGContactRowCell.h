#import <UIKit/UIKit.h>
#import "TGEmoji.h"

@interface TGContactRowCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) TGEmojiLabel *titleLabel;
@property (nonatomic, strong) TGEmojiLabel *secondTitleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *premiumView;
@property (nonatomic, strong) UIImageView *verifiedLabel;
@property (nonatomic, strong) UILabel *closeFriendLabel;
- (void)resetForConfiguration;
@end
