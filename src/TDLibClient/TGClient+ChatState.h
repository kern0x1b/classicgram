#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGChatProtectedContentDidChangeNotification;

@interface TGClient (ChatState)

- (void)setScope:(NSString *)scope muted:(BOOL)muted;
- (void)accountTtlWithCompletion:(void (^ _Nullable)(BOOL ok, NSInteger days))completion;
- (void)setLanguage:(NSString *)packId;
- (void)chatWithUsername:(NSString *)username
			  completion:(void (^ _Nullable)(int64_t, NSString *))completion;
- (void)setChat:(int64_t)chatId muted:(BOOL)muted;
- (NSNumber *)photoFileIdForChat:(int64_t)chatId;
- (void)photoFileIdForChat:(int64_t)chatId completion:(void (^ _Nullable)(NSNumber *))completion;
- (NSDictionary *)chatInfoForId:(int64_t)chatId;
- (BOOL)cachedPremiumForChatId:(int64_t)chatId;
- (NSDictionary *)cachedCredibilityForChatId:(int64_t)chatId;
- (void)userInfo:(int64_t)userId completion:(void (^ _Nullable)(NSDictionary *))completion;
- (void)messageCountInChat:(int64_t)chatId filter:(NSString *)filter
				completion:(void (^ _Nullable)(NSInteger))completion;
- (NSString *)nameForUserId:(int64_t)userId;
- (NSString *)usernameForUserId:(int64_t)userId;
- (void)memberCountForChat:(int64_t)chatId completion:(void (^ _Nullable)(NSInteger count))completion;
- (void)resolveMemberCountForChat:(int64_t)chatId
					   completion:(void (^ _Nullable)(NSInteger count))completion;
- (void)ensureUserName:(int64_t)userId completion:(void (^ _Nullable)(void))completion;
- (void)mergeForumFlagFromChat:(NSDictionary *)chat
						  into:(NSMutableDictionary *)info
						chatId:(NSNumber *)chatId;
- (void)applySavedMessagesIdentityTo:(NSMutableDictionary *)info;
- (void)mergeChat:(NSDictionary *)chat;
- (void)mergeOutgoingStateFromMessage:(NSDictionary *)last into:(NSMutableDictionary *)info;
- (long long)lastReadOutgoingMessageInChat:(int64_t)chatId;
- (long long)lastReadIncomingMessageInChat:(int64_t)chatId;
- (long long)lastMessageIdInChat:(int64_t)chatId;
- (NSInteger)unreadCountInChat:(int64_t)chatId;
- (int32_t)activeVideoChatGroupCallIdForChat:(int64_t)chatId;
- (BOOL)videoChatHasParticipantsForChat:(int64_t)chatId;
- (void)refreshOutgoingReadStateForChat:(int64_t)chatId
							 completion:(void (^ _Nullable)(long long lastReadId))completion;
- (void)refreshOutgoingReadStateIn:(NSMutableDictionary *)info;
- (NSString *)previewForLastMessage:(NSDictionary *)last inChat:(NSDictionary *)info;
- (void)applyChatUpdate:(NSDictionary *)update;
- (void)rebuildChats;
- (void)scheduleChatsChanged;
- (void)recomputeMutedForChatsInScope:(NSString *)scope;
- (void)storeScopeDefaultMuteFor:(NSNumber *)muteFor forScope:(NSString *)scope;
- (void)loadNotificationScopeDefaults;
- (void)applyScopeNotificationSettingsUpdate:(NSDictionary *)update;

- (NSString *)notificationScopeForChatInfo:(NSDictionary *)info;
- (BOOL)effectiveMutedForChatInfo:(NSDictionary *)info;

@end

NS_ASSUME_NONNULL_END
