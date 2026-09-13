#import <UIKit/UIKit.h>

@interface TGQuickReplyListViewController : UIViewController

- (instancetype)initWithChatId:(int64_t)chatId;
- (void)beginCreatingShortcutWithText:(NSString *)text;

@property (nonatomic, copy) void (^onSent)(void);
@property (nonatomic, copy) void (^onPicked)(NSInteger shortcutId, NSString *name);

@end
