#import "TGClient+Contacts.h"
#import "TGClient+Messages.h"
#import "TGClient+ChatState.h"
#import "TGProfileService.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Groups.h"
#import "TGClient+Channels.h"
#import "TGClient+Forums.h"
#import "TGClient+DirectMessages.h"
#import "TGClient+Stories.h"
#import "TGClient+Privacy.h"
#import "TGClient+Account.h"
#import "TGClient+Translation.h"

@implementation TGProfileService

+ (void)ownerAfterLeavingGroup:(int64_t)chatId
					completion:(void (^)(NSString *name))completion {
	[[TGClient shared] ownerAfterLeavingGroup:chatId completion:completion];
}

+ (void)sendContactFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
						phone:(NSString *)phone
					   userId:(int64_t)userId
					   toChat:(int64_t)chatId {
	[[TGClient shared] sendContactFirstName:firstName
									lastName:lastName
									   phone:phone
									   vcard:@""
									  userId:userId
									  toChat:chatId
									 options:nil];
}

+ (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds {
	[[TGClient shared] setChat:chatId autoDeleteSeconds:seconds];
}

+ (void)setChat:(int64_t)chatId
	autoDeleteSeconds:(NSInteger)seconds
		   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChat:chatId autoDeleteSeconds:seconds completion:completion];
}

+ (NSInteger)autoDeleteSecondsForChat:(int64_t)chatId {
	return [[TGClient shared] autoDeleteSecondsForChat:chatId];
}

+ (void)setSlowModeDelay:(NSInteger)seconds
				 forChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setSlowModeDelay:seconds forChat:chatId completion:completion];
}

+ (void)clearHistoryInChat:(int64_t)chatId {
	[[TGClient shared] clearHistoryInChat:chatId];
}

+ (void)clearHistoryInChat:(int64_t)chatId revoke:(BOOL)revoke completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] clearHistoryInChat:chatId revoke:revoke completion:completion];
}

+ (void)setChat:(int64_t)chatId joined:(BOOL)joined completion:(void (^)(BOOL))completion {
	[[TGClient shared] setChat:chatId joined:joined completion:completion];
}

+ (void)setTitle:(NSString *)title
		 forChat:(int64_t)chatId
	  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setTitle:title forChat:chatId completion:completion];
}

+ (void)setChat:(int64_t)chatId
	directMessagesGroupEnabled:(BOOL)enabled
					 starCount:(NSInteger)starCount
					completion:(void (^)(BOOL success))completion {
	[[TGClient shared] setChat:chatId directMessagesGroupEnabled:enabled starCount:starCount
						completion:completion];
}

+ (void)setGroup:(int64_t)chatId
	unrestrictBoostCount:(NSInteger)count
			  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setGroup:chatId unrestrictBoostCount:count completion:completion];
}

+ (void)setGroup:(int64_t)chatId
	mainProfileTab:(NSString *)tab
		completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setGroup:chatId mainProfileTab:tab completion:completion];
}

+ (void)removePhotoForChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] removePhotoForChat:chatId completion:completion];
}

+ (void)upgradeBasicGroupToSupergroup:(int64_t)chatId
						   completion:(void (^)(int64_t newChatId))completion {
	[[TGClient shared] upgradeBasicGroupToSupergroup:chatId completion:completion];
}

+ (void)convertGroupToBroadcastGroup:(int64_t)chatId
						  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] convertGroupToBroadcastGroup:chatId completion:completion];
}

+ (void)setDescription:(NSString *)description
			   forChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setDescription:description forChat:chatId completion:completion];
}

+ (void)reportGroup:(int64_t)chatId
		   optionId:(NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^)(NSString *status, NSString *title, NSArray *options,
						NSString *newOptionId, BOOL optional))completion {
	[[TGClient shared] reportGroup:chatId optionId:optionId text:text completion:completion];
}

+ (void)setPhotoAtPath:(NSString *)path
			   forChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setPhotoAtPath:path forChat:chatId completion:completion];
}

+ (void)setSupergroup:(int64_t)supergroupId
			  isForum:(BOOL)isForum
			  hasTabs:(BOOL)hasTabs
		   completion:(void (^)(BOOL success))completion {
	[[TGClient shared] setSupergroup:supergroupId isForum:isForum hasTabs:hasTabs
						  completion:completion];
}

+ (void)groupInfoForChat:(int64_t)chatId
			  completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] groupInfoForChat:chatId completion:completion];
}

+ (void)groupMemberCount:(int64_t)chatId
			  completion:(void (^)(NSInteger count))completion {
	[[TGClient shared] groupMemberCount:chatId completion:completion];
}

+ (void)canGetStatisticsForChat:(int64_t)chatId
					 completion:(void (^)(BOOL canGet))completion {
	[[TGClient shared] canGetStatisticsForChat:chatId completion:completion];
}

+ (void)managementInfoForChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] managementInfoForChat:chatId completion:completion];
}

+ (void)boostStatusForChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *status))completion {
	[[TGClient shared] boostStatusForChat:chatId completion:completion];
}

+ (void)channelSignaturesForChat:(int64_t)chatId
					  completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] channelSignaturesForChat:chatId completion:completion];
}

+ (void)discussionGroupForChannel:(int64_t)chatId
					   completion:(void (^)(NSNumber *linkedChatId))completion {
	[[TGClient shared] discussionGroupForChannel:chatId completion:completion];
}

+ (void)administratorsInGroup:(int64_t)chatId
				   completion:(void (^)(NSArray *admins))completion {
	[[TGClient shared] administratorsInGroup:chatId completion:completion];
}

+ (void)myAdministratorRightsForChat:(int64_t)chatId
						  completion:(void (^)(NSDictionary *rights))completion {
	[[TGClient shared] myRightsInChat:chatId completion:completion];
}

+ (void)inviteLinkCountsInGroup:(int64_t)chatId
					 completion:(void (^)(NSArray *counts))completion {
	[[TGClient shared] inviteLinkCountsInGroup:chatId completion:completion];
}

+ (void)pendingJoinRequestCountForChat:(int64_t)chatId
							completion:(void (^)(NSInteger count, BOOL failed))completion {
	[[TGClient shared] pendingJoinRequestCountForChat:chatId completion:completion];
}

+ (void)membersJoinedViaPrimaryInviteLinkInChat:(int64_t)chatId
										  limit:(NSInteger)limit
									 completion:(void (^)(NSArray *members, NSInteger total))completion {
	TGClient *client = [TGClient shared];
	[client membersJoinedViaPrimaryInviteLinkInChat:chatId limit:limit completion:completion];
}

+ (void)primaryInviteLinkForGroup:(int64_t)chatId
					   completion:(void (^)(NSDictionary *link))completion {
	[[TGClient shared] primaryInviteLinkForGroup:chatId completion:completion];
}

+ (void)replacePrimaryInviteLinkForGroup:(int64_t)chatId
							  completion:(void (^)(NSDictionary *link))completion {
	[[TGClient shared] replacePrimaryInviteLinkForGroup:chatId completion:completion];
}

+ (void)setChannelSignaturesForChat:(int64_t)chatId
					   signMessages:(BOOL)sign
				 showAuthorProfiles:(BOOL)showAuthorProfiles
						 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChannelSignaturesForChat:chatId signMessages:sign
								showAuthorProfiles:showAuthorProfiles
										completion:completion];
}

+ (void)setChat:(int64_t)chatId
	allHistoryAvailable:(BOOL)available
			 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChat:chatId allHistoryAvailable:available completion:completion];
}

+ (void)isAllHistoryAvailableForChat:(int64_t)chatId
						  completion:(void (^)(BOOL available))completion {
	[[TGClient shared] isAllHistoryAvailableForChat:chatId completion:completion];
}

+ (void)setChat:(int64_t)chatId
	hiddenMembers:(BOOL)hidden
	   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChat:chatId hiddenMembers:hidden completion:completion];
}

+ (void)setChat:(int64_t)chatId
	antiSpamEnabled:(BOOL)enabled
		 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChat:chatId antiSpamEnabled:enabled completion:completion];
}

+ (void)setChat:(int64_t)chatId
	protectedContent:(BOOL)protectedContent
		  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChat:chatId protectedContent:protectedContent completion:completion];
}

+ (void)forumTopicRowsForChat:(int64_t)chatId
				   completion:(void (^)(NSArray *topics))completion {
	[[TGClient shared] forumTopicRowsForChat:chatId completion:completion];
}

+ (void)suitableDiscussionChatsWithCompletion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] suitableDiscussionChatsWithCompletion:completion];
}

+ (void)setDiscussionGroup:(int64_t)discussionChatId
				forChannel:(int64_t)chatId
				completion:(void (^)(BOOL ok, NSString *errorMessage))completion {
	[[TGClient shared] setDiscussionGroup:discussionChatId forChannel:chatId completion:completion];
}

+ (void)similarChatsForChat:(int64_t)chatId
				 completion:(void (^)(NSArray *chats, NSInteger totalCount))completion {
	[[TGClient shared] similarChatsForChat:chatId completion:completion];
}

+ (void)openSimilarChat:(int64_t)openedChatId fromChat:(int64_t)chatId {
	[[TGClient shared] openSimilarChat:openedChatId fromChat:chatId];
}

+ (void)setGroup:(int64_t)chatId
	hasAutomaticTranslation:(BOOL)enabled
				 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setGroup:chatId hasAutomaticTranslation:enabled completion:completion];
}

+ (void)chatsToPostStoriesWithCompletion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] chatsToPostStoriesWithCompletion:completion];
}

+ (void)canPostStoryAsChat:(int64_t)chatId
				completion:(void (^)(BOOL canPost, NSString *reason))completion {
	[[TGClient shared] canPostStoryAsChat:chatId completion:completion];
}

+ (void)postPhotoStoryAtPath:(NSString *)path
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				   toProfile:(BOOL)toProfile
				  completion:(void (^)(NSDictionary *story))completion {
	[[TGClient shared] postPhotoStoryAtPath:path asChat:chatId caption:caption privacy:privacy
									userIds:userIds
								  toProfile:toProfile
								 completion:completion];
}

+ (void)reportChatPhoto:(int64_t)chatId
				 fileId:(long long)fileId
				 reason:(NSString *)reason
				   text:(NSString *)text
			 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] reportChatPhoto:chatId fileId:fileId reason:reason text:text
							completion:completion];
}

+ (void)profileAudiosForUser:(int64_t)userId
					  offset:(NSInteger)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *audios, BOOL failed))completion {
	[[TGClient shared] profileAudiosForUser:userId offset:offset limit:limit completion:completion];
}

+ (void)giftsForUser:(int64_t)userId completion:(void (^)(NSArray *gifts))completion {
	[[TGClient shared] giftsForUser:userId completion:completion];
}

+ (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] chatProfile:chatId completion:completion];
}

+ (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion {
	[[TGClient shared] userInfo:userId completion:completion];
}

+ (void)userProfile:(int64_t)userId completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] userProfile:userId completion:completion];
}

+ (void)canSendMessageToUser:(int64_t)userId
				  completion:(void (^)(BOOL canSend, BOOL isPaid, NSInteger starCount,
								 NSString *blockReason))completion {
	[[TGClient shared] canSendMessageToUser:userId completion:completion];
}

+ (void)messageCountInChat:(int64_t)chatId
					filter:(NSString *)filter
				completion:(void (^)(NSInteger count))completion {
	[[TGClient shared] messageCountInChat:chatId filter:filter completion:completion];
}

+ (void)setChat:(int64_t)chatId muted:(BOOL)muted {
	[[TGClient shared] setChat:chatId muted:muted];
}

+ (BOOL)isChatMuted:(int64_t)chatId {
	return [[TGClient shared] isChatMuted:chatId];
}

+ (BOOL)isChatPrivate:(int64_t)chatId {
	return [[TGClient shared] isPrivateChat:chatId];
}

+ (void)setChat:(int64_t)chatId
	translatable:(BOOL)translatable
	  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChat:chatId translatable:translatable completion:completion];
}

+ (BOOL)isChatTranslatable:(int64_t)chatId {
	return [[TGClient shared] isChatTranslatable:chatId];
}

+ (NSNumber *)photoFileIdForChat:(int64_t)chatId {
	return [[TGClient shared] photoFileIdForChat:chatId];
}

+ (void)setGroup:(int64_t)chatId
	stickerSetName:(NSString *)name
		completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setGroup:chatId stickerSetName:name completion:completion];
}

+ (void)membersOfChat:(int64_t)chatId completion:(void (^)(NSArray *members))completion {
	[[TGClient shared] membersOfChat:chatId completion:completion];
}

+ (void)memberCountForChat:(int64_t)chatId completion:(void (^)(NSInteger count))completion {
	[[TGClient shared] memberCountForChat:chatId completion:completion];
}

+ (NSArray *)slowModePresets {
	return [TGClient slowModePresets];
}

@end
