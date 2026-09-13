#import <UIKit/UIKit.h>

@interface TGLoginViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, copy) void (^onPhoneSubmitted)(NSString *phoneNumber);
@property (nonatomic, copy) void (^onCodeSubmitted)(NSString *code);
@property (nonatomic, copy) void (^onPasswordSubmitted)(NSString *password);
@property (nonatomic, copy) void (^onCancelled)(void);

@property (nonatomic, assign) BOOL cancellable;
@end

@interface TGLoginViewController (Public)

- (void)showCodeStepWithPhoneNumber:(NSString *)phoneNumber;
- (void)showPasswordStepWithHint:(NSString *)hint recoveryEmailPattern:(NSString *)recoveryEmailPattern;
- (void)showEmailStep;
- (void)showEmailCodeStepWithPattern:(NSString *)pattern;
- (void)showRegistrationStep;

- (void)setBusy:(BOOL)busy;

@end
