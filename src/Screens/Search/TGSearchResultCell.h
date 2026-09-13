#import <UIKit/UIKit.h>

@class TGSearchResultItem;

@interface TGSearchResultCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *titleLabelSecond;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *dateLabel;
- (void)setTitleFirst:(NSString *)first second:(NSString *)second;
- (void)applyItem:(TGSearchResultItem *)item avatar:(UIImage *)avatar;
@end
