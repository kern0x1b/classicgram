#import <UIKit/UIKit.h>

@interface TGChatListViewController : UITableViewController <UIActionSheetDelegate>
@end

@interface TGChatListViewController (Public)

- (void)actionsTapped;
- (void)addStory;
- (void)markCurrentListAsRead;
- (void)openFolderManagement;

- (void)prefetchOpenHistoryForChat:(int64_t)chatId;

@end
