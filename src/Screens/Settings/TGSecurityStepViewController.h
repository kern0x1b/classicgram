#import <UIKit/UIKit.h>

@class TGSecurityStepViewController;

typedef void (^TGSecurityStepBlock)(TGSecurityStepViewController *step, NSString *text);

@interface TGSecurityStepViewController : UITableViewController <UITextFieldDelegate>
@property (nonatomic, strong) NSString *stepTitle;
@property (nonatomic, strong) NSString *stepCaption;
@property (nonatomic, strong) NSString *footerText;
@property (nonatomic, strong) NSString *placeholder;
@property (nonatomic, strong) NSString *actionTitle;
@property (nonatomic, strong) NSString *skipTitle;
@property (nonatomic, assign) BOOL secure;
@property (nonatomic, assign) BOOL numeric;
@property (nonatomic, assign) BOOL email;
@property (nonatomic, copy) TGSecurityStepBlock onSubmit;
@property (nonatomic, copy) dispatch_block_t onSkip;
- (NSString *)text;
- (void)setBusy:(BOOL)busy;
- (void)refuseWithMessage:(NSString *)message;
@end
