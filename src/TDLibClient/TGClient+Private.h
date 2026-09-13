#import "TGClient.h"
#import "TGChatPositions.h"

NS_ASSUME_NONNULL_BEGIN

typedef void *_Nullable (*td_create_fn)(void);
typedef void (*td_send_fn)(void *_Nonnull client, const char *_Nonnull request);
typedef const char *_Nullable (*td_recv_fn)(void *_Nonnull client, double timeout);
typedef const char *_Nullable (*td_exec_fn)(void *_Nullable client, const char *_Nonnull request);
typedef void (*td_destroy_fn)(void *_Nonnull client);

@interface TGClient ()
@property (nonatomic, assign) void *handle;
@property (nonatomic, assign, nullable) void *client;
@property (nonatomic, assign) td_create_fn td_create;
@property (nonatomic, assign) td_send_fn td_send;
@property (nonatomic, assign) td_recv_fn td_recv;
@property (nonatomic, assign) td_destroy_fn td_destroy;
@property (nonatomic, assign) BOOL suspended;
@property (nonatomic, assign) BOOL suspending;
@property (nonatomic, assign) BOOL resumeWhenClosed;
@property (nonatomic, assign) BOOL applicationStateWatched;
@property (nonatomic, assign) BOOL chatsChangedWhileBackgrounded;
@property (nonatomic, copy, nullable) void (^suspendCompletion)(void);
@property (nonatomic, assign) TGAuthState authState;
@property (nonatomic, assign) BOOL available;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL diskCachesDisabledForBackgroundLaunch;
@property (nonatomic, assign) BOOL parametersUsedDiskCaches;
@property (nonatomic, copy, nullable) NSString *pendingPhoneNumber;
@property (nonatomic, strong) NSMutableDictionary *chatsById;
@property (nonatomic, strong) NSMutableDictionary *chatActionTimers;
@property (nonatomic, strong) NSMutableDictionary *usersById;
@property (nonatomic, strong) NSMutableDictionary *userPhotosById;
@property (nonatomic, strong) NSMutableDictionary *userPhotoKeysById;

@property (nonatomic, strong) NSMutableDictionary *userRecordsById;
@property (nonatomic, strong) NSMutableArray *contactWaiters;
@property (nonatomic, assign) BOOL contactsFetchInFlight;
@property (nonatomic, assign) NSTimeInterval contactsFetchIssuedAt;
@property (nonatomic, assign) NSTimeInterval contactsFetchStartedAt;

@property (nonatomic, strong) NSMutableDictionary *forumSupergroups;
@property (nonatomic, strong) NSMutableDictionary *directMessagesSupergroups;
@property (nonatomic, strong) NSMutableDictionary *scopeMuteForByScope;
@property (nonatomic, strong) NSMutableDictionary *topicNotificationSettingsByKey;
@property (nonatomic, assign) int64_t openChatId;
@property (nonatomic, strong) NSMutableDictionary *autosaveSettingsByScope;
@property (nonatomic, strong) NSMutableDictionary *autosaveExceptionsByChatId;
@property (nonatomic, strong) NSArray *archivedChats;
@property (nonatomic, strong) NSArray *folders;
@property (nonatomic, assign) BOOL folderTagsEnabled;
@property (nonatomic, assign) NSInteger mainChatListPosition;
@property (nonatomic, strong) NSMutableDictionary *folderDefinitionsById;
@property (nonatomic, strong) NSArray *chats;
@property (nonatomic, strong) NSArray *closeBirthdayUsers;
@property (nonatomic, strong) NSMutableArray *outbox;
@property (nonatomic, assign) BOOL parametersSent;
@property (nonatomic, strong, nullable) NSMutableArray *preInitRequests;
@property (nonatomic, strong) NSLock *outboxLock;
@property (nonatomic, strong) NSMutableArray *inbox;
@property (nonatomic, strong) NSLock *inboxLock;
@property (nonatomic, assign) BOOL inboxScheduled;
@property (nonatomic, assign) NSTimeInterval lastBridgeActivity;
@property (nonatomic, assign) NSUInteger chatsAtLastLoad;
@property (nonatomic, assign) BOOL chatListComplete;
@property (nonatomic, assign) BOOL chatsNotifyScheduled;
@property (nonatomic, assign) BOOL idlePolling;
@property (nonatomic, assign) BOOL cachedChatsLoaded;
@property (nonatomic, assign) NSTimeInterval lastChatSnapshotSave;
@property (nonatomic, strong) NSMutableSet *chatsConfirmedByServer;
@property (nonatomic, assign) NSUInteger loadChatsAttempts;
@property (nonatomic, strong, nullable) NSDictionary *me;
@property (nonatomic, assign) TGConnectionState connectionState;
@property (nonatomic, strong) NSMutableDictionary *pendingRequests;
@property (nonatomic, assign) NSUInteger requestSeq;
@property (nonatomic, strong) NSMutableDictionary *fileWaiters;
@property (nonatomic, strong) NSMutableDictionary *fileStates;
@property (nonatomic, strong) NSMutableArray *fileStatesOrder;
@property (nonatomic, strong) NSMutableDictionary *downloadPriorityHints;
@property (nonatomic, strong) NSArray *availableEffectReactionIds;
@property (nonatomic, strong) NSArray *availableEffectStickerIds;
@property (nonatomic, strong) NSMutableDictionary *effectCache;
@property (nonatomic, strong, nullable) NSArray *textCompositionStyles;
@property (nonatomic, assign) NSTimeInterval lastPendingSweep;
@property (nonatomic, strong, nullable) NSTimer *pendingSweepTimer;
@property (nonatomic, strong) NSMutableDictionary *bridgeSendCounts;
@property (nonatomic, strong) NSMutableDictionary *bridgeRecvCounts;
@property (nonatomic, strong) NSLock *bridgeCountsLock;

- (void)request:(NSDictionary *)request completion:(void (^ _Nullable)(NSDictionary *))completion;
- (void)request:(NSDictionary *)request
	   deadline:(NSTimeInterval)deadline
	 completion:(void (^ _Nullable)(NSDictionary *))completion;
- (void)sendUnguarded:(NSDictionary *)request;
- (void)flushPendingPhoneNumber;
- (void)saveCachedFolders;

- (void)resetForAccountSwitch;
- (void)capUserRegistriesIfNeeded;
- (void)capSupergroupFlagRegistriesIfNeeded;

- (void)saveCachedChatsThrottled;
- (void)dropChatsMissingFromServerList;
- (void)postChatsAndArchiveChanged;

@end

NSString *TGSavedMessagesChatIdKey(void);
NSString *TGDraftText(id draftMessage);
@class TGFlattenContext;
TGFlattenContext *TGCurrentFlattenContext(void);
NSDictionary *TGUserStatusInfo(NSDictionary *status);
NSString *TGActiveUsername(NSDictionary *user);
NSString *TGSessionPlatformString(NSString *platform, NSString *systemVersion);

NS_ASSUME_NONNULL_END
