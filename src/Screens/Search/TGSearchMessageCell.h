#import <UIKit/UIKit.h>

@class TGSearchResultItem;

@interface TGSearchMessageCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *textLabel_;
@property (nonatomic, strong) UILabel *dateLabel;
- (void)applyItem:(TGSearchResultItem *)item avatar:(UIImage *)avatar;
@end
