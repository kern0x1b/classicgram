#import <UIKit/UIKit.h>

@class TGGroupMembersItem;

@interface TGGroupMemberCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *titleSecondLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *roleLabel;
@property (nonatomic, assign) BOOL subtitleIsOnline;

- (void)setName:(NSString *)name;
- (void)applyItem:(TGGroupMembersItem *)item avatar:(UIImage *)avatar;
@end
