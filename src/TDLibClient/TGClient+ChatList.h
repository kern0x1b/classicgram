#import "TGClient.h"
#import "TGChatListId.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGChatFoldersDidChangeNotification;
extern NSString *const TGUnreadMessageCountDidChangeNotification;
extern NSString *const TGUnreadChatCountDidChangeNotification;

@interface TGClient (ChatList)

- (BOOL)chatListsAreLoaded;

#pragma mark - lists

- (void)chatsInList:(TGChatListId)list
			  limit:(NSInteger)limit
		 completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)loadMoreChatsInList:(TGChatListId)list limit:(NSInteger)limit;

- (void)markListAsRead:(TGChatListId)list;

- (NSDictionary *)unreadSummaryForList:(TGChatListId)list;

- (void)setChat:(int64_t)chatId markedAsUnread:(BOOL)marked completion:(void (^ _Nullable)(BOOL success))completion;

- (void)markChatAsRead:(int64_t)chatId completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)markChatAsRead:(int64_t)chatId;

- (BOOL)isChatMarkedAsUnread:(int64_t)chatId;

- (void)chatMarkedAsUnread:(int64_t)chatId completion:(void (^ _Nullable)(BOOL marked))completion;

#pragma mark - pinning

- (void)setChat:(int64_t)chatId pinned:(BOOL)pinned inList:(TGChatListId)list completion:(void (^ _Nullable)(BOOL success))completion;

- (void)setPinnedChats:(NSArray *)chatIds inList:(TGChatListId)list completion:(void (^ _Nullable)(BOOL success))completion;

#pragma mark - membership of lists

- (void)addChat:(int64_t)chatId toList:(TGChatListId)list completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)listsToAddChat:(int64_t)chatId completion:(void (^ _Nullable)(NSArray *lists))completion;

#pragma mark - folders

- (void)folderWithId:(NSInteger)folderId completion:(void (^ _Nullable)(NSDictionary *folder))completion;

- (void)saveFolder:(NSDictionary *)folder completion:(void (^ _Nullable)(NSInteger folderId, NSString *errorMessage))completion;

- (void)deleteFolder:(NSInteger)folderId
		leavingChats:(NSArray *)chatIds
		  completion:(void (^ _Nullable)(BOOL success, NSString *errorMessage))completion;

- (void)chatsToLeaveWhenDeletingFolder:(NSInteger)folderId completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)chatCountForFolder:(NSDictionary *)folder completion:(void (^ _Nullable)(NSInteger count))completion;

- (void)defaultIconNameForFolder:(NSDictionary *)folder completion:(void (^ _Nullable)(NSString *iconName))completion;

- (NSArray *)folderIconNames;

- (NSString *)symbolForFolderIconName:(NSString *)iconName;

- (void)beginObservingFolderChanges;

- (void)reorderFolders:(NSArray *)folderIds
	   mainListPosition:(NSInteger)position
			 completion:(void (^ _Nullable)(BOOL success, NSString *errorMessage))completion;

- (void)recommendedFoldersWithCompletion:(void (^ _Nullable)(NSArray *folders, BOOL failed))completion;

- (void)clearAllDraftMessagesExcludingSecretChats:(BOOL)excludeSecretChats
									   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)toggleFolderTagsEnabled:(BOOL)enabled completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)refreshFolderTagDefinitions;

- (NSDictionary *)primaryFolderTagForChatId:(int64_t)chatId;

#pragma mark - shared folders

- (void)inviteLinksForFolder:(NSInteger)folderId completion:(void (^ _Nullable)(NSArray *links, BOOL failed))completion;

- (void)shareableChatsInFolder:(NSInteger)folderId completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)createInviteLinkForFolder:(NSInteger)folderId
							 name:(NSString *)name
						  chatIds:(NSArray *)chatIds
					   completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)editInviteLink:(NSString *)link
			 forFolder:(NSInteger)folderId
				  name:(NSString *)name
			   chatIds:(NSArray *)chatIds
			completion:(void (^ _Nullable)(NSDictionary *updated))completion;

- (void)deleteInviteLink:(NSString *)link
				forFolder:(NSInteger)folderId
			   completion:(void (^ _Nullable)(BOOL success, NSString *errorMessage))completion;

- (void)checkFolderInviteLink:(NSString *)link completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)joinFolderByInviteLink:(NSString *)link
					   chatIds:(nullable NSArray *)chatIds
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)chatFolderInviteLinkFromDeepLink:(NSString *)urlString
							   completion:(void (^ _Nullable)(NSString *_Nullable inviteLink))completion;

- (void)newChatsInFolder:(NSInteger)folderId completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)addNewChats:(NSArray * _Nullable)chatIds
		   toFolder:(NSInteger)folderId
		 completion:(void (^ _Nullable)(BOOL success, NSString *errorMessage))completion;

#pragma mark - archive settings

- (void)archiveSettingsWithCompletion:(void (^ _Nullable)(NSDictionary *settings))completion;

#pragma mark - search and recents

- (void)searchChatList:(NSString *)query
			completion:(void (^ _Nullable)(NSArray *local, NSArray *global))completion;

- (void)topChatsWithCompletion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)removeTopChat:(int64_t)chatId;

- (void)recentlyOpenedChatsWithCompletion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)addRecentlyFoundChat:(int64_t)chatId;
- (void)removeRecentlyFoundChat:(int64_t)chatId;
- (void)clearRecentlyFoundChats;

#pragma mark - row rendering

- (void)rowDetailForChat:(int64_t)chatId completion:(void (^ _Nullable)(NSDictionary *detail))completion;

#pragma mark - chat titles

- (NSString *)cachedTitleForChatId:(int64_t)chatId;

- (void)titleForChatId:(int64_t)chatId completion:(void (^ _Nullable)(NSString *title))completion;

- (void)titlesForChatIds:(NSArray *)chatIds completion:(void (^ _Nullable)(NSDictionary *titles))completion;

#pragma mark - account switch

- (void)resetChatListCachesForAccountSwitch;

@end

NS_ASSUME_NONNULL_END
