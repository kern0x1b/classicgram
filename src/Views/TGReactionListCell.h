#import <UIKit/UIKit.h>
#import "TGEmoji.h"

@interface TGReactionListCell : UITableViewCell

@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) TGEmojiLabel *emojiLabel;

@end
