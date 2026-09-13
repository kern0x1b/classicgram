#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Groups)

#pragma mark - creating groups

- (void)createBasicGroupWithTitle:(NSString *)title
						  userIds:(NSArray *)userIds
					   completion:(void (^ _Nullable)(int64_t chatId, NSArray *failedUserIds))completion;

- (void)createSupergroupWithTitle:(NSString *)title
					  description:(NSString *)description
						isChannel:(BOOL)isChannel
						  isForum:(BOOL)isForum
					   completion:(void (^ _Nullable)(int64_t chatId))completion;

- (void)upgradeBasicGroupToSupergroup:(int64_t)chatId
						   completion:(void (^ _Nullable)(int64_t newChatId))completion;

#pragma mark - group info

- (void)groupInfoForChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)setGroupChat:(int64_t)chatId title:(NSString *)title
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroupChat:(int64_t)chatId description:(NSString *)description
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroupChat:(int64_t)chatId photoAtPath:(NSString *)path
		  completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - members

- (void)membersInGroup:(int64_t)chatId
				filter:(NSString * _Nullable)filter
				offset:(NSInteger)offset
				 limit:(NSInteger)limit
			completion:(void (^ _Nullable)(NSArray *members, NSInteger totalCount))completion;

- (void)searchMembersInGroup:(int64_t)chatId
					   query:(NSString *)query
					  filter:(NSString * _Nullable)filter
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *members, BOOL failed))completion;

- (void)mentionCandidatesInGroup:(int64_t)chatId
						   query:(NSString *)query
						   limit:(NSInteger)limit
					  completion:(void (^ _Nullable)(NSArray *candidates))completion;

- (void)memberStatusOfUser:(int64_t)userId
				   inGroup:(int64_t)chatId
				completion:(void (^ _Nullable)(NSDictionary *member))completion;

- (void)administratorRightsOfUser:(int64_t)userId
						  inGroup:(int64_t)chatId
					   completion:(void (^ _Nullable)(NSDictionary *rights, NSString *status,
									  BOOL canBeEdited, NSString *customTitle))completion;

- (void)permissionsOfUser:(int64_t)userId
				  inGroup:(int64_t)chatId
			   completion:(void (^ _Nullable)(NSDictionary *permissions, BOOL isRestricted, NSInteger untilDate))completion;

- (void)myAdministratorRightsInGroup:(int64_t)chatId
						  completion:(void (^ _Nullable)(NSDictionary *rights, NSString *status))completion;

- (NSArray *)administratorRightKeys;

- (NSArray *)memberPermissionKeys;

- (void)groupMemberCount:(int64_t)chatId
			  completion:(void (^ _Nullable)(NSInteger count))completion;

- (void)addMembers:(NSArray *)userIds
		   toGroup:(int64_t)chatId
		completion:(void (^ _Nullable)(NSArray *failedUserIds, NSString *errorMessage))completion;

- (void)removeMember:(int64_t)userId
		   fromGroup:(int64_t)chatId
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)banMember:(int64_t)userId
		   inGroup:(int64_t)chatId
		 untilDate:(NSInteger)untilDate
	revokeMessages:(BOOL)revokeMessages
		completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)unbanMember:(int64_t)userId
			inGroup:(int64_t)chatId
		 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)deleteAllMessagesFromUser:(int64_t)userId
						   inGroup:(int64_t)chatId
						completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)restrictMember:(int64_t)userId
			   inGroup:(int64_t)chatId
		   permissions:(NSDictionary *)permissions
			 untilDate:(NSInteger)untilDate
			completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - administrators

- (void)administratorsInGroup:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSArray *admins))completion;

- (void)promoteMember:(int64_t)userId
			  inGroup:(int64_t)chatId
			   rights:(NSDictionary *)rights
		  customTitle:(NSString *)customTitle
		   completion:(void (^ _Nullable)(BOOL statusOk, BOOL tagOk))completion;

- (void)setMemberTag:(NSString *)tag
			 forUser:(int64_t)userId
			 inGroup:(int64_t)chatId
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)dismissAdmin:(int64_t)userId
			 inGroup:(int64_t)chatId
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)transferOwnershipOfGroup:(int64_t)chatId
						  toUser:(int64_t)userId
						password:(NSString *)password
					  completion:(void (^ _Nullable)(BOOL ok, NSString *errorMessage))completion;

- (void)canTransferOwnershipWithCompletion:(void (^ _Nullable)(NSString *status, NSInteger retryAfterSeconds))completion;

- (void)ownerAfterLeavingGroup:(int64_t)chatId
					completion:(void (^ _Nullable)(NSString *name))completion;

#pragma mark - default permissions

- (void)defaultPermissionsInGroup:(int64_t)chatId
					   completion:(void (^ _Nullable)(NSDictionary *permissions))completion;

- (void)setDefaultPermissions:(NSDictionary *)permissions
					  inGroup:(int64_t)chatId
				   completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - public groups

- (void)checkGroupUsername:(NSString *)username
				   forChat:(int64_t)chatId
				completion:(void (^ _Nullable)(NSString *status))completion;

- (void)setGroupChat:(int64_t)chatId username:(NSString *)username
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroupChat:(int64_t)chatId username:(NSString *)username
			  active:(BOOL)active
		  completion:(void (^ _Nullable)(BOOL ok, NSString *errorMessage))completion;

- (void)reorderUsernames:(NSArray *)usernames forGroup:(int64_t)chatId
			  completion:(void (^ _Nullable)(BOOL ok, NSString *errorMessage))completion;

- (void)setGroup:(int64_t)chatId unrestrictBoostCount:(NSInteger)count
			  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroup:(int64_t)chatId hasAutomaticTranslation:(BOOL)enabled
				 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroup:(int64_t)chatId mainProfileTab:(NSString *)tab
		completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)createdPublicChatsWithCompletion:(void (^ _Nullable)(NSArray *chats, BOOL failed))completion;

#pragma mark - invite links

- (void)primaryInviteLinkForGroup:(int64_t)chatId
					   completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)replacePrimaryInviteLinkForGroup:(int64_t)chatId
							  completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)editInviteLink:(NSString *)inviteLink
			   inGroup:(int64_t)chatId
				  name:(NSString *)name
		expirationDate:(NSInteger)expirationDate
		   memberLimit:(NSInteger)memberLimit
	createsJoinRequest:(BOOL)createsJoinRequest
			completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)revokeInviteLink:(NSString *)inviteLink
				 inGroup:(int64_t)chatId
			  completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)membersJoinedViaInviteLink:(NSString *)inviteLink
						   inGroup:(int64_t)chatId
							 limit:(NSInteger)limit
						completion:(void (^ _Nullable)(NSArray *members))completion;

- (void)inviteLinkCountsInGroup:(int64_t)chatId
					 completion:(void (^ _Nullable)(NSArray *counts))completion;

#pragma mark - joining

- (void)processJoinRequestFromUser:(int64_t)userId
						   inGroup:(int64_t)chatId
						   approve:(BOOL)approve
						completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - group settings

- (void)setGroup:(int64_t)chatId allHistoryAvailable:(BOOL)available
			 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroup:(int64_t)chatId hiddenMembers:(BOOL)hidden
	   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroup:(int64_t)chatId aggressiveAntiSpam:(BOOL)enabled
			completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)reportSpamMessages:(NSArray *)messageIds inGroup:(int64_t)chatId
				completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroup:(int64_t)chatId signMessages:(BOOL)sign
	  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroup:(int64_t)chatId joinToSend:(BOOL)joinToSend
	joinByRequest:(BOOL)joinByRequest
	   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroup:(int64_t)chatId isForum:(BOOL)isForum
	  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)convertGroupToBroadcastGroup:(int64_t)chatId
						  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setGroup:(int64_t)chatId stickerSetName:(NSString *)name
		completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - recent actions

#pragma mark - reporting

- (void)reportGroup:(int64_t)chatId
		   optionId:(NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^ _Nullable)(NSString *status, NSString *title, NSArray *options, NSString *newOptionId, BOOL optional))completion;

@end

NS_ASSUME_NONNULL_END
