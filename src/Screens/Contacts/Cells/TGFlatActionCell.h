#import <UIKit/UIKit.h>

@interface TGFlatActionCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UIImageView *disclosureIndicator;
- (void)setIconNamed:(NSString *)name at:(CGPoint)origin;
@end
