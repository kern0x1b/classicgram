#import <UIKit/UIKit.h>

@interface TGPlaceholderView : UIView

@property (nonatomic, strong, readonly) UIImageView *iconView;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *bodyLabel;
@property (nonatomic, strong, readonly) UIButton *actionButton;

- (CGFloat)layoutContentWidth:(CGFloat)width;

@end
