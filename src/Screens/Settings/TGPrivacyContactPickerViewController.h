#import <UIKit/UIKit.h>

typedef void (^TGPrivacyPickerBlock)(NSArray *userIds);

@interface TGPrivacyContactPickerViewController : UITableViewController
- (instancetype)initWithTitle:(NSString *)title
					 selected:(NSArray *)selected
				   completion:(TGPrivacyPickerBlock)completion;
@end
