#import <UIKit/UIKit.h>

@interface TGChatEventsViewController : UIViewController

@property (nonatomic, assign) int64_t chatId;

@property (nonatomic, copy) NSString *chatTitle;

- (instancetype)initWithChatId:(int64_t)chatId;

@end
