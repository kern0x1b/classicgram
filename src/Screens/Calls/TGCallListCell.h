#import <UIKit/UIKit.h>

extern const CGFloat kCallAvatarSide;

@class TGCallsItem;

@interface TGCallListCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *arrowView;
- (void)applyItem:(TGCallsItem *)item avatar:(UIImage *)avatar;
@end
