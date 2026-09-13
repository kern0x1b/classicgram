#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (ChatManagement)

#pragma mark - title, description, photo

- (void)setTitle:(NSString *)title forChat:(int64_t)chatId
	  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setDescription:(NSString *)description forChat:(int64_t)chatId
			completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setPhotoAtPath:(NSString *)path forChat:(int64_t)chatId
			completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)removePhotoForChat:(int64_t)chatId completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - management snapshot

- (void)managementInfoForChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSDictionary *info))completion;

#pragma mark - administrators and own rights

- (void)administratorsForChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSArray *administrators))completion;

- (void)myRightsInChat:(int64_t)chatId
			completion:(void (^ _Nullable)(NSDictionary *rights))completion;

- (void)canManageInviteLinksInChat:(int64_t)chatId
						completion:(void (^ _Nullable)(BOOL canManage))completion;

#pragma mark - permissions

+ (NSArray *)permissionKeys;

- (void)permissionsForChat:(int64_t)chatId
				completion:(void (^ _Nullable)(NSDictionary *permissions, BOOL failed))completion;

- (void)setPermissions:(NSDictionary *)permissions forChat:(int64_t)chatId
			completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - slow mode

- (void)setSlowModeDelay:(NSInteger)seconds forChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(BOOL ok))completion;

+ (NSArray *)slowModePresets;

#pragma mark - supergroup switches

- (void)setChat:(int64_t)chatId allHistoryAvailable:(BOOL)available
			 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId joinByRequest:(BOOL)joinByRequest
	   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId joinToSendMessages:(BOOL)joinToSend
			completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId signMessages:(BOOL)sign showSender:(BOOL)showSender
	  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId protectedContent:(BOOL)protectedContent
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId hiddenMembers:(BOOL)hidden
	   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId antiSpamEnabled:(BOOL)enabled
		 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)reportNotSpamMessages:(NSArray *)messageIds inChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSArray *succeededMessageIds))completion;

- (void)reportAntiSpamFalsePositiveForMessage:(int64_t)messageId
									   inChat:(int64_t)chatId
								   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)convertChatToBroadcastGroup:(int64_t)chatId
						 completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - invite links

- (void)primaryInviteLinkForChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(NSString *link))completion;

- (void)replacePrimaryInviteLinkForChat:(int64_t)chatId
							 completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)inviteLinksForChat:(int64_t)chatId revoked:(BOOL)revoked
				completion:(void (^ _Nullable)(NSArray *links))completion;

- (void)createInviteLinkForChat:(int64_t)chatId
						   name:(NSString *)name
				 expirationDate:(NSInteger)expirationDate
					memberLimit:(NSInteger)memberLimit
			   requiresApproval:(BOOL)requiresApproval
					 completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)editInviteLink:(NSString *)link
				inChat:(int64_t)chatId
				  name:(NSString *)name
		expirationDate:(NSInteger)expirationDate
		   memberLimit:(NSInteger)memberLimit
	  requiresApproval:(BOOL)requiresApproval
			completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)createSubscriptionInviteLinkForChat:(int64_t)chatId
									   name:(NSString *)name
								  starCount:(int64_t)starCount
								 completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)editSubscriptionInviteLink:(NSString *)link
							inChat:(int64_t)chatId
							  name:(NSString *)name
						completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)inviteLink:(NSString *)link inChat:(int64_t)chatId
		completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)revokeInviteLink:(NSString *)link inChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)deleteRevokedInviteLink:(NSString *)link inChat:(int64_t)chatId
					 completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)deleteAllRevokedInviteLinksInChat:(int64_t)chatId
							   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)membersJoinedViaInviteLink:(NSString *)link
							inChat:(int64_t)chatId
							 limit:(NSInteger)limit
						completion:(void (^ _Nullable)(NSArray *members, NSInteger total))completion;
- (void)membersJoinedViaInviteLink:(NSString *)link
							inChat:(int64_t)chatId
					   afterUserId:(int64_t)afterUserId
					 afterJoinDate:(NSInteger)afterJoinDate
							 limit:(NSInteger)limit
						completion:(void (^ _Nullable)(NSArray *members, NSInteger total))completion;

- (void)membersJoinedViaPrimaryInviteLinkInChat:(int64_t)chatId
										  limit:(NSInteger)limit
									 completion:(void (^ _Nullable)(NSArray *members, NSInteger total))completion;

#pragma mark - joining by link

- (void)previewInviteLink:(NSString *)link
			   completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)joinChatByInviteLink:(NSString *)link
				  completion:(void (^ _Nullable)(int64_t chatId, BOOL requestSent, NSString *errorCode))completion;

- (void)inactiveSupergroupChatsWithCompletion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)leaveChatForJoinLimit:(int64_t)chatId completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - join requests

- (void)joinRequestsForChat:(int64_t)chatId
				 inviteLink:(NSString *)inviteLink
					  query:(NSString *)query
			  offsetRequest:(NSDictionary *)offsetRequest
					  limit:(NSInteger)limit
				 completion:(void (^ _Nullable)(NSArray *requests, NSInteger total, NSDictionary *nextOffset))completion;

- (void)processJoinRequestFromUser:(int64_t)userId
							inChat:(int64_t)chatId
						   approve:(BOOL)approve
						completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)processAllJoinRequestsInChat:(int64_t)chatId
						  inviteLink:(NSString *)inviteLink
							 approve:(BOOL)approve
						  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)pendingJoinRequestCountForChat:(int64_t)chatId
							completion:(void (^ _Nullable)(NSInteger count, BOOL failed))completion;

#pragma mark - send as

- (BOOL)parseMessageSender:(NSDictionary *)sender
				   senderId:(int64_t *)outSenderId
					 isChat:(BOOL *)outIsChat;

- (void)availableMessageSendersForChat:(int64_t)chatId
							completion:(void (^ _Nullable)(NSArray *senders))completion;

- (void)currentMessageSenderForChat:(int64_t)chatId
						 completion:(void (^ _Nullable)(int64_t senderId, BOOL isChat))completion;

- (void)setMessageSenderId:(int64_t)senderId
					isChat:(BOOL)isChat
				   forChat:(int64_t)chatId
				completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - event log

- (void)eventLogForChat:(int64_t)chatId
				  query:(NSString *)query
			fromEventId:(int64_t)fromEventId
				  limit:(NSInteger)limit
				filters:(NSArray *)filters
				userIds:(NSArray *)userIds
			 completion:(void (^ _Nullable)(NSArray *_Nullable events))completion;

- (void)resolvePhotoFileIdForUserId:(int64_t)userId
						 completion:(void (^ _Nullable)(NSNumber *_Nullable fileId))completion;

- (void)statusForUser:(int64_t)userId completion:(void (^ _Nullable)(NSString *status))completion;
- (int64_t)savedMessagesChatId;
- (NSNumber *)photoFileIdForUserId:(int64_t)userId;
- (NSString *)photoKeyForUserId:(int64_t)userId;
- (void)cacheProfilePhoto:(NSDictionary *)user;
- (void)canSendInChat:(int64_t)chatId
			completion:(void (^ _Nullable)(BOOL canSend, BOOL isChannel, NSDictionary *permissions))completion;
- (void)canSendInChat:(int64_t)chatId
				 topic:(int64_t)topicId
			completion:(void (^ _Nullable)(BOOL canSend, BOOL isChannel, NSDictionary *permissions))completion;
- (void)deleteChat:(int64_t)chatId;
- (void)deleteChat:(int64_t)chatId revoke:(BOOL)revoke completion:(void (^ _Nullable)(BOOL success))completion;
- (void)membersOfChat:(int64_t)chatId completion:(void (^ _Nullable)(NSArray *members))completion;
- (void)loadChats;
- (void)pinnedMessageForChat:(int64_t)chatId
				  completion:(void (^ _Nullable)(NSDictionary *message))completion;
- (void)pinnedMessagesForChat:(int64_t)chatId
					   thread:(int64_t)threadId
				   savedTopic:(int64_t)savedTopicId
				   completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)userProfile:(int64_t)userId completion:(void (^ _Nullable)(NSDictionary *info))completion;
- (void)chatProfile:(int64_t)chatId completion:(void (^ _Nullable)(NSDictionary *info))completion;
- (BOOL)isChatMuted:(int64_t)chatId;
- (BOOL)isPrivateChat:(int64_t)chatId;
- (void)clearHistoryInChat:(int64_t)chatId;
- (void)clearHistoryInChat:(int64_t)chatId revoke:(BOOL)revoke completion:(void (^ _Nullable)(BOOL ok))completion;
- (NSInteger)autoDeleteSecondsForChat:(int64_t)chatId;

- (void)setChat:(int64_t)chatId joined:(BOOL)joined completion:(void (^ _Nullable)(BOOL success))completion;
- (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds;
- (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds completion:(void (^ _Nullable)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END
