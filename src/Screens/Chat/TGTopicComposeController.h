#import <UIKit/UIKit.h>

@interface TGTopicComposeController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) NSArray *colours;
@property (nonatomic, assign) NSInteger selectedColour;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UIButton *createButton;
@property (nonatomic, assign) BOOL created;
@property (nonatomic, strong) NSMutableArray *swatches;
@property (nonatomic, copy) void (^onCreate)(NSString *name, NSInteger colour);

@end
