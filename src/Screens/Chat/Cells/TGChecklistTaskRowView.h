#import <UIKit/UIKit.h>

@interface TGChecklistTaskRowView : UIControl

@property (nonatomic, strong, readonly) UIView *checkbox;
@property (nonatomic, strong, readonly) UILabel *titleLabel;

- (void)setChecked:(BOOL)checked title:(NSString *)title completedByName:(NSString *)completedByName;

@end
