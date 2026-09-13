#import <UIKit/UIKit.h>

@protocol TGBackspaceTextFieldDelegate <NSObject>
- (void)textFieldDidHitLastBackspace;
@end

@interface TGBackspaceTextField : UITextField
@property (nonatomic, weak) id<TGBackspaceTextFieldDelegate> backspaceDelegate;
@end
