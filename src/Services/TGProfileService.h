#import <Foundation/Foundation.h>

@interface TGProfileService : NSObject

+ (void)ownerAfterLeavingGroup:(int64_t)chatId
					completion:(void (^)(NSString *name))completion;

+ (void)sendContactFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
						phone:(NSString *)phone
					   userId:(int64_t)userId
					   toChat:(int64_t)chatId;

+ (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds;

+ (void)setChat:(int64_t)chatId
	autoDeleteSeconds:(NSInteger)seconds
		   completion:(void (^)(BOOL ok))completion;

+ (NSInteger)autoDeleteSecondsForChat:(int64_t)chatId;

+ (void)setSlowModeDelay:(NSInteger)seconds
				 forChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion;

+ (void)clearHistoryInChat:(int64_t)chatId;

+ (void)clearHistoryInChat:(int64_t)chatId revoke:(BOOL)revoke completion:(void (^)(BOOL ok))completion;

+ (void)setChat:(int64_t)chatId joined:(BOOL)joined completion:(void (^)(BOOL ok))completion;

+ (void)setTitle:(NSString *)title
		 forChat:(int64_t)chatId
	  completion:(void (^)(BOOL ok))completion;

+ (void)setChat:(int64_t)chatId
	directMessagesGroupEnabled:(BOOL)enabled
					 starCount:(NSInteger)starCount
					completion:(void (^)(BOOL success))completion;

+ (void)setGroup:(int64_t)chatId
	unrestrictBoostCount:(NSInteger)count
			  completion:(void (^)(BOOL ok))completion;

+ (void)setGroup:(int64_t)chatId
	mainProfileTab:(NSString *)tab
		completion:(void (^)(BOOL ok))completion;

+ (void)removePhotoForChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;

+ (void)upgradeBasicGroupToSupergroup:(int64_t)chatId
						   completion:(void (^)(int64_t newChatId))completion;

+ (void)convertGroupToBroadcastGroup:(int64_t)chatId
						  completion:(void (^)(BOOL ok))completion;

+ (void)setDescription:(NSString *)description
			   forChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion;

+ (void)reportGroup:(int64_t)chatId
		   optionId:(NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^)(NSString *status, NSString *title, NSArray *options,
						NSString *newOptionId, BOOL optional))completion;

+ (void)setPhotoAtPath:(NSString *)path
			   forChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion;

+ (void)setSupergroup:(int64_t)supergroupId
			  isForum:(BOOL)isForum
			  hasTabs:(BOOL)hasTabs
		   completion:(void (^)(BOOL success))completion;

+ (void)groupInfoForChat:(int64_t)chatId
			  completion:(void (^)(NSDictionary *info))completion;

+ (void)groupMemberCount:(int64_t)chatId
			  completion:(void (^)(NSInteger count))completion;

+ (void)canGetStatisticsForChat:(int64_t)chatId
					 completion:(void (^)(BOOL canGet))completion;

+ (void)managementInfoForChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *info))completion;

+ (void)boostStatusForChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *status))completion;

+ (void)channelSignaturesForChat:(int64_t)chatId
					  completion:(void (^)(NSDictionary *info))completion;

+ (void)discussionGroupForChannel:(int64_t)chatId
					   completion:(void (^)(NSNumber *linkedChatId))completion;

+ (void)administratorsInGroup:(int64_t)chatId
				   completion:(void (^)(NSArray *admins))completion;

+ (void)myAdministratorRightsForChat:(int64_t)chatId
						  completion:(void (^)(NSDictionary *rights))completion;

+ (void)inviteLinkCountsInGroup:(int64_t)chatId
					 completion:(void (^)(NSArray *counts))completion;

+ (void)pendingJoinRequestCountForChat:(int64_t)chatId
							completion:(void (^)(NSInteger count, BOOL failed))completion;

+ (void)membersJoinedViaPrimaryInviteLinkInChat:(int64_t)chatId
										  limit:(NSInteger)limit
									 completion:(void (^)(NSArray *members,
													NSInteger total))completion;

+ (void)primaryInviteLinkForGroup:(int64_t)chatId
					   completion:(void (^)(NSDictionary *link))completion;

+ (void)replacePrimaryInviteLinkForGroup:(int64_t)chatId
							  completion:(void (^)(NSDictionary *link))completion;

+ (void)setChannelSignaturesForChat:(int64_t)chatId
					   signMessages:(BOOL)sign
				 showAuthorProfiles:(BOOL)showAuthorProfiles
						 completion:(void (^)(BOOL ok))completion;

+ (void)setChat:(int64_t)chatId
	allHistoryAvailable:(BOOL)available
			 completion:(void (^)(BOOL ok))completion;

+ (void)isAllHistoryAvailableForChat:(int64_t)chatId
						  completion:(void (^)(BOOL available))completion;

+ (void)setChat:(int64_t)chatId
	hiddenMembers:(BOOL)hidden
	   completion:(void (^)(BOOL ok))completion;

+ (void)setChat:(int64_t)chatId
	antiSpamEnabled:(BOOL)enabled
		 completion:(void (^)(BOOL ok))completion;

+ (void)setChat:(int64_t)chatId
	protectedContent:(BOOL)protectedContent
		  completion:(void (^)(BOOL ok))completion;

+ (void)forumTopicRowsForChat:(int64_t)chatId
				   completion:(void (^)(NSArray *topics))completion;

+ (void)suitableDiscussionChatsWithCompletion:(void (^)(NSArray *chats))completion;

+ (void)setDiscussionGroup:(int64_t)discussionChatId
				forChannel:(int64_t)chatId
				completion:(void (^)(BOOL ok, NSString *errorMessage))completion;

+ (void)similarChatsForChat:(int64_t)chatId
				 completion:(void (^)(NSArray *chats, NSInteger totalCount))completion;

+ (void)openSimilarChat:(int64_t)openedChatId fromChat:(int64_t)chatId;

+ (void)setGroup:(int64_t)chatId
	hasAutomaticTranslation:(BOOL)enabled
				 completion:(void (^)(BOOL ok))completion;

+ (void)chatsToPostStoriesWithCompletion:(void (^)(NSArray *chats))completion;

+ (void)canPostStoryAsChat:(int64_t)chatId
				completion:(void (^)(BOOL canPost, NSString *reason))completion;

+ (void)postPhotoStoryAtPath:(NSString *)path
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				   toProfile:(BOOL)toProfile
				  completion:(void (^)(NSDictionary *story))completion;

+ (void)reportChatPhoto:(int64_t)chatId
				 fileId:(long long)fileId
				 reason:(NSString *)reason
				   text:(NSString *)text
			 completion:(void (^)(BOOL ok))completion;

+ (void)profileAudiosForUser:(int64_t)userId
					  offset:(NSInteger)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *audios, BOOL failed))completion;

+ (void)giftsForUser:(int64_t)userId completion:(void (^)(NSArray *gifts))completion;

+ (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion;

+ (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion;

+ (void)userProfile:(int64_t)userId completion:(void (^)(NSDictionary *info))completion;

+ (void)canSendMessageToUser:(int64_t)userId
				  completion:(void (^)(BOOL canSend, BOOL isPaid, NSInteger starCount,
								 NSString *blockReason))completion;

+ (void)messageCountInChat:(int64_t)chatId
					filter:(NSString *)filter
				completion:(void (^)(NSInteger count))completion;

+ (void)setChat:(int64_t)chatId muted:(BOOL)muted;

+ (BOOL)isChatMuted:(int64_t)chatId;

+ (BOOL)isChatPrivate:(int64_t)chatId;

+ (void)setChat:(int64_t)chatId
	translatable:(BOOL)translatable
	  completion:(void (^)(BOOL ok))completion;

+ (BOOL)isChatTranslatable:(int64_t)chatId;

+ (NSNumber *)photoFileIdForChat:(int64_t)chatId;

+ (void)setGroup:(int64_t)chatId
	stickerSetName:(NSString *)name
		completion:(void (^)(BOOL ok))completion;

+ (void)membersOfChat:(int64_t)chatId completion:(void (^)(NSArray *members))completion;

+ (void)memberCountForChat:(int64_t)chatId completion:(void (^)(NSInteger count))completion;

+ (NSArray *)slowModePresets;

@end
