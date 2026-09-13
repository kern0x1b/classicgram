#import <UIKit/UIKit.h>

@interface TGChatInputTextView : UITextView
@property (nonatomic, copy) void (^onTextAssigned)(void);
@end
