#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGFoldersPage) {
	TGFoldersPageList = 0,

	TGFoldersPageEditor = 1,

	TGFoldersPageChatPicker = 2,

	TGFoldersPageIconPicker = 3
};

@interface TGFoldersViewController : UITableViewController

@property (nonatomic, assign) TGFoldersPage page;

@property (nonatomic, assign) NSInteger folderId;

@end
