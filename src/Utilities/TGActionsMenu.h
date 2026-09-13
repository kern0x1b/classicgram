#import <UIKit/UIKit.h>

extern NSString *const TGActionsMenuSelectList;
extern NSString *const TGActionsMenuAddStory;
extern NSString *const TGActionsMenuMarkAllRead;
extern NSString *const TGActionsMenuEditFolders;

@interface TGActionsMenu : NSObject

+ (void)showFromRect:(CGRect)rect
			  inView:(UIView *)host
	 currentFolderId:(NSInteger)currentFolderId
		titleForList:(NSString * (^)(NSInteger listId, NSString *title))titleForList
			onAction:(void (^)(NSString *action, NSInteger folderId))onAction;

+ (void)dismiss;

+ (BOOL)isVisible;

@end
