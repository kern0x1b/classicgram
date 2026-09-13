#import <UIKit/UIKit.h>

@interface TGChatFolderLinkPreviewViewController : UITableViewController

@property (nonatomic, copy) NSString *inviteLink;
@property (nonatomic, copy) NSString *folderTitle;
@property (nonatomic, copy) NSString *folderIconName;
@property (nonatomic, assign) NSInteger folderId;
@property (nonatomic, strong) NSArray *missingChatIds;
@property (nonatomic, strong) NSArray *addedChatIds;

+ (void)presentForInviteLink:(NSString *)link
	fromNavigationController:(UINavigationController *)navigationController;

@end
