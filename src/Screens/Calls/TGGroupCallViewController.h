#import <UIKit/UIKit.h>

@interface TGGroupCallViewController : UITableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int32_t groupCallId;
@property (nonatomic, copy) NSString *fallbackTitle;

- (instancetype)initWithChatId:(int64_t)chatId
				   groupCallId:(int32_t)groupCallId
						 title:(NSString *)title;

@end
