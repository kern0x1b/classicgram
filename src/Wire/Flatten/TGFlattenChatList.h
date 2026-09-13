#import <Foundation/Foundation.h>
#import "TGChatListId.h"

NS_ASSUME_NONNULL_BEGIN

NSString *TGPlainText(id _Nullable formatted);
NSDictionary *TGChatFolderNamePayload(NSDictionary *_Nullable wireName, NSString *_Nullable title);
NSDictionary *TGChatListObject(TGChatListId list);
TGChatListId TGChatListIdFromObject(id _Nullable object);
NSInteger TGUnreadContributionForChatRow(NSDictionary *_Nullable chat);
NSInteger TGUnreadBadgeCountInChatRows(NSArray *_Nullable chats, BOOL countsChats, BOOL includesMuted);
NSInteger TGUnreadChatCountFromUpdate(NSDictionary *_Nullable update, BOOL includesMuted);
BOOL TGChatFolderExclusionAllowsChat(NSDictionary *_Nullable folder, NSDictionary *_Nullable chat);

NS_ASSUME_NONNULL_END
