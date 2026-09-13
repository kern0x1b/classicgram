#import <Foundation/Foundation.h>
#import "TGAuthState.h"
#import "TGClientAuthenticating.h"
#import "TGResultIsError.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGUserStatusDidChangeNotification;
extern NSString *const TGUserProfileDidChangeNotification;
extern NSString *const TGChatReadOutboxDidChangeNotification;
extern NSString *const TGChatIsTranslatableDidChangeNotification;
extern NSString *const TGChatPinnedMessagesDidChangeNotification;
extern NSString *const TGChatAppearanceCatalogDidChangeNotification;
extern NSString *const TGChatActionBarDidChangeNotification;
extern NSString *const TGChatPermissionsDidChangeNotification;
extern NSString *const TGUserBlockedStateDidChangeNotification;
extern NSString *const TGChatVideoChatDidChangeNotification;
extern NSString *const TGGroupCallDidChangeNotification;
extern NSString *const TGChatMessageAutoDeleteTimeDidChangeNotification;
extern NSString *const TGWebBrowserSettingsDidChangeNotification;
extern NSString *const TGChatBackgroundDidChangeNotification;
extern NSString *const TGDefaultBackgroundRowKey;
extern NSString *const TGChatHasScheduledMessagesDidChangeNotification;
extern NSString *const TGChatMemberDidChangeNotification;
extern NSString *const TGChatMemberUserIdKey;
extern NSString *const TGChatNotificationSettingsDidChangeNotification;
extern NSString *const TGChatDraftDidChangeNotification;
extern NSString *const TGChatThemeDidChangeNotification;
extern NSString *const TGChatEmojiStatusDidChangeNotification;
extern NSString *const TGChatMessageSenderDidChangeNotification;
extern NSString *const TGChatMessageSenderIdKey;
extern NSString *const TGChatMessageSenderIsChatKey;
extern NSString *const TGInstalledStickerSetsDidChangeNotification;
extern NSString *const TGInstalledStickerSetsTypeKey;
extern NSString *const TGTrendingStickerSetsDidChangeNotification;
extern NSString *const TGTrendingStickerSetsTypeKey;
extern NSString *const TGRecentStickersDidChangeNotification;
extern NSString *const TGFavoriteStickersDidChangeNotification;
extern NSString *const TGSavedAnimationsDidChangeNotification;
extern NSString *const TGForumTopicDidChangeNotification;
extern NSString *const TGForumTopicChatIdKey;
extern NSString *const TGForumTopicTopicIdKey;

extern NSString *const TGMessageInteractionInfoDidChangeNotification;

extern NSString *const TGChatUnreadMentionsDidChangeNotification;
extern NSString *const TGChatUnreadReactionsDidChangeNotification;
extern NSString *const TGChatOnlineMemberCountDidChangeNotification;
extern NSString *const TGChatOnlineMemberCountKey;

extern NSString *const TGChatSlowModeDelayDidChangeNotification;
extern NSString *const TGChatSlowModeDelayKey;

extern NSString *const TGChatPendingJoinRequestsDidChangeNotification;
extern NSString *const TGChatPendingJoinRequestsCountKey;

extern NSString *const TGFileStateDidChangeNotification;
extern NSString *const TGFileStateFileIdKey;

extern NSString *const TGAuthStateDidChangeNotification;
extern NSString *const TGAuthStateKey;

extern NSString *const TGClientErrorNotification;
extern NSString *const TGClientErrorMessageKey;

extern NSString *const TGChatsDidChangeNotification;
extern NSString *const TGArchivedChatsDidChangeNotification;

extern NSString *const TGFileProgressDidChangeNotification;
extern NSString *const TGFileProgressFileIdKey;
extern NSString *const TGFileProgressValueKey;

extern NSString *const TGChatActionDidChangeNotification;
extern NSString *const TGChatActionChatIdKey;
extern NSString *const TGChatActionTextKey;
extern NSString *const TGChatActionTopicIdKey;

extern NSString *const TGMessageDidChangeNotification;
extern NSString *const TGMessageChatIdKey;
extern NSString *const TGMessageDataKey;
extern NSString *const TGMessageDeletedIdKey;

extern NSString *const TGDownloadsDidChangeNotification;
extern NSString *const TGDownloadsSummaryKey;
extern NSString *const TGPollDidChangeNotification;
extern NSString *const TGPollDataKey;

NSString *TGSavedMessagesTitle(void);

#ifdef __cplusplus
extern "C" {
#endif

NSString *TGTDLibContentKindOfMessage(NSDictionary *message);
NSString *TGTDLibTypeOf(id _Nullable object);
NSDictionary *TGChatActionBarInfo(id actionBar);
NSInteger TGResultErrorCode(NSDictionary *result);
NSString *TGResultErrorMessage(NSDictionary *result);
NSInteger TGResultFloodWaitSeconds(NSDictionary *result);

#ifdef __cplusplus
}
#endif

@interface TGClient : NSObject

+ (instancetype)shared;

+ (void)setSharedInstanceForTesting:(nullable TGClient *)override;

@property (nonatomic, readonly) BOOL available;
@property (nonatomic, readonly) BOOL suspended;
@property (nonatomic, readonly) TGAuthState authState;
@property (nonatomic, assign) BOOL ignoresSensitiveContentRestrictions;
@property (nonatomic, assign) BOOL canIgnoreSensitiveContentRestrictions;
@property (nonatomic, assign) NSInteger pinnedForumTopicCountMax;
@property (nonatomic, assign) NSInteger pinnedChatCountMax;
@property (nonatomic, assign) NSInteger pinnedArchivedChatCountMax;
@property (nonatomic, assign) BOOL hasActiveLiveLocationShare;

@property (nonatomic, assign) BOOL frozen;
@property (nonatomic, assign) long long freezingDate;
@property (nonatomic, assign) long long freezeDeletionDate;
@property (nonatomic, copy, nullable) NSString *freezeAppealLink;

@property (nonatomic, assign) BOOL ageVerificationRequired;
@property (nonatomic, assign) NSInteger ageVerificationMinAge;
@property (nonatomic, copy, nullable) NSString *ageVerificationBotUsername;
@property (nonatomic, copy, nullable) NSString *ageVerificationCountry;

@property (nonatomic, copy, nullable) NSString *pendingTermsOfServiceId;
@property (nonatomic, copy, nullable) NSString *pendingTermsOfServiceText;
@property (nonatomic, copy, nullable) NSArray *pendingTermsOfServiceEntities;
@property (nonatomic, assign) NSInteger pendingTermsOfServiceMinAge;

@property (nonatomic, assign) BOOL speechRecognitionTrialKnown;
@property (nonatomic, assign) NSInteger speechRecognitionTrialMaxMediaDuration;
@property (nonatomic, assign) NSInteger speechRecognitionTrialWeeklyCount;
@property (nonatomic, assign) NSInteger speechRecognitionTrialLeftCount;
@property (nonatomic, assign) long long speechRecognitionTrialNextResetDate;

- (void)suspendForBackgroundWithCompletion:(nullable void (^)(void))completion;
- (void)resumeFromBackground;
- (void)reopenForDiskCachesIfNeededWhileCallInProgress:(BOOL)callInProgress;

@property (nonatomic, copy) NSString *pendingEmailAddressPattern;
@property (nonatomic, copy) NSString *pendingPasswordHint;
@property (nonatomic, assign) BOOL pendingHasRecoveryEmail;
@property (nonatomic, copy) NSString *pendingRecoveryEmailPattern;

typedef NS_ENUM(NSInteger, TGConnectionState) {
	TGConnectionStateUnknown = 0,
	TGConnectionStateWaitingForNetwork,
	TGConnectionStateConnecting,
	TGConnectionStateConnectingToProxy,
	TGConnectionStateUpdating,
	TGConnectionStateReady
};

@property (nonatomic, readonly) TGConnectionState connectionState;

@property (nonatomic, readonly) NSArray *archivedChats;

@property (nonatomic, readonly) NSArray *folders;

@property (nonatomic, readonly) BOOL folderTagsEnabled;

@property (nonatomic, readonly) NSInteger mainChatListPosition;

@property (nonatomic, readonly) NSArray *chats;

@property (nonatomic, readonly, nullable) NSDictionary *me;

@property (nonatomic, readonly) NSArray *closeBirthdayUsers;

- (BOOL)start;

- (void)loadCachedChats;
- (void)saveCachedChats;
- (void)clearCachedChats;

- (void)request:(NSDictionary *)request completion:(void (^ _Nullable)(NSDictionary *result))completion;

#pragma mark - files

#pragma mark - messages

#pragma mark - account settings

#pragma mark - contacts

#pragma mark - maintenance

- (void)sendPhoneNumber:(NSString *)phoneNumber;
- (void)setTdlibLogVerbosity:(NSInteger)level;

- (void)send:(NSDictionary *)request;

- (void)resetBridgeCounts;
- (void)logBridgeCounts;
@end

@interface TGClient (History)

- (void)historyForChat:(int64_t)chatId
				 limit:(NSInteger)limit
			completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)historyForChat:(int64_t)chatId
				thread:(int64_t)threadId
				 limit:(NSInteger)limit
			completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)historyForSavedTopic:(int64_t)savedTopicId
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)historyForDirectMessagesTopic:(int64_t)topicId
							   inChat:(int64_t)chatId
								limit:(NSInteger)limit
						   completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)historyForChat:(int64_t)chatId
				thread:(int64_t)threadId
				 limit:(NSInteger)limit
			 onlyLocal:(BOOL)onlyLocal
			completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)historyForChat:(int64_t)chatId
				thread:(int64_t)threadId
				 limit:(NSInteger)limit
			 onlyLocal:(BOOL)onlyLocal
			  progress:(void (^ _Nullable)(NSArray *messages))progress
			completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)historyForChat:(int64_t)chatId
				thread:(int64_t)threadId
		 aroundMessage:(int64_t)anchorMessageId
				 newer:(NSInteger)newerWanted
				 limit:(NSInteger)limit
			 onlyLocal:(BOOL)onlyLocal
			  progress:(nullable void (^)(NSArray *messages))progress
			completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)prefetchLocalHistoryForChat:(int64_t)chatId
					  aroundMessage:(int64_t)anchorMessageId
							  newer:(NSInteger)newerWanted
							  limit:(NSInteger)limit;
- (BOOL)attachToPrefetchedHistoryForChat:(int64_t)chatId
						   aroundMessage:(int64_t)anchorMessageId
								   newer:(NSInteger)newerWanted
								   limit:(NSInteger)limit
							  completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)resetHistoryPrefetchCachesForAccountSwitch;
- (void)searchMessages:(NSString *)query completion:(void (^ _Nullable)(NSArray *messages))completion;
- (void)searchInChat:(int64_t)chatId
				query:(NSString *)query
			 threadId:(int64_t)threadId
 directMessagesTopic:(int64_t)directMessagesTopicId
		   savedTopic:(int64_t)savedTopicId
		fromMessageId:(int64_t)fromMessageId
				limit:(NSInteger)limit
		   completion:(void (^ _Nullable)(NSArray *messages, int64_t nextFromMessageId, NSInteger totalCount))completion;
- (void)searchInSecretChat:(int64_t)chatId
					  query:(NSString *)query
					 offset:(NSString *)offset
					  limit:(NSInteger)limit
				 completion:(void (^ _Nullable)(NSArray *messages, NSString *nextOffset, NSInteger totalCount))completion;

@end

NS_ASSUME_NONNULL_END
