#import "TGResultIsError.h"
#import "TGFloodWaitMessage.h"
#import "TGRedactedRequestForLogging.h"
#import "TGClient+Private.h"
#import "TGClientSessionRestart.h"
#import "TGClient+UpdateHandling.h"
#import "TGClient+ChatState.h"
#import "TGFlattenChatState.h"
#import "TGLocalization.h"
#import "TGClient+Network.h"
#import "TGClient+ChatList.h"
#import "TGClient+Notifications.h"
#import "TGClient+Stories.h"
#import "TGClient+Reactions.h"
#import "TGClient+Bots.h"
#import "TGClient+Contacts.h"
#import "TGClient+AppSettings.h"
#import "TGClient+UserStatus.h"
#import "TGClient+Account.h"
#import "TGClient+Premium.h"
#import "TGClient+Messages.h"
#import "TGClient+DirectMessages.h"
#import "TGClient+SavedMessages.h"
#import "TGClient+WebLinks.h"
#import "TGClient+AiWriting.h"
#import "TGClient+SecretChats.h"
#import "TGClient+Payments.h"
#import "TGClient+Gifs.h"
#import "TGClient+Storage.h"
#import "TGFlattenMessage.h"
#import "TGCall.h"
#import "TGBackgroundSession.h"
#import "TGDiskCache.h"
#import "TGAccountManager.h"
#import "TGRemoteImageView.h"
#import "TGDayCalendarView.h"
#import "TGStarsViewController.h"
#import "TGSettingsViewController.h"
#import "TGStickerPanelView.h"
#import "TGStickerThumbnailCache.h"
#import "TGGifPickerViewController.h"
#import "TGMusicPlayer.h"
#import "TGTheme.h"
#import "TGAudioMetadata.h"
#import "AppDelegate.h"
#import <UIKit/UIKit.h>

extern void TGResetActiveChatThemeCachesForAccountSwitch(void);
#include <dlfcn.h>
#include "api_id.h"

NSDictionary *TGUserStatusInfo(NSDictionary *status);

NSString *TGSavedMessagesChatIdKey(void) {
	return [TGAccountManager defaultsKey:@"TGSavedMessagesChatId"];
}
NSString *TGSavedMessagesTitle(void) {
	return TGL(@"Settings.SavedMessages", @"Saved Messages");
}

NSString *TGActiveUsername(NSDictionary *user) {
	NSArray *active = user[@"usernames"][@"active_usernames"];
	if (![active isKindOfClass:NSArray.class] || !active.count)
		return nil;
	NSString *name = [active objectAtIndex:0];
	return [name isKindOfClass:NSString.class] ? name : nil;
}

static const NSTimeInterval kRequestDeadline = 300.0;

NSDictionary *TGChatActionBarInfo(id actionBar) {
	if (![actionBar isKindOfClass:NSDictionary.class])
		return (NSDictionary *)[NSNull null];
	NSString *kind = actionBar[@"@type"];
	if (![kind isKindOfClass:NSString.class])
		return (NSDictionary *)[NSNull null];
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:actionBar];
	info[@"kind"] = kind;
	return info;
}

NSString *TGTDLibTypeOf(id object) {
	if (![object isKindOfClass:NSDictionary.class])
		return @"";
	NSString *type = ((NSDictionary *)object)[@"@type"];
	return [type isKindOfClass:NSString.class] ? type : @"";
}

NSString *TGTDLibContentKindOfMessage(NSDictionary *message) {
	if (![message isKindOfClass:NSDictionary.class])
		return @"";
	NSDictionary *content = message[@"content"];
	if (![content isKindOfClass:NSDictionary.class])
		return @"";
	NSString *kind = content[@"@type"];
	return [kind isKindOfClass:NSString.class] ? kind : @"";
}

NSInteger TGResultErrorCode(NSDictionary *result) {
	if (!TGResultIsError(result))
		return 0;
	id code = [result isKindOfClass:NSDictionary.class] ? result[@"code"] : nil;
	return [code isKindOfClass:NSNumber.class] ? [code integerValue] : 0;
}

NSString *TGResultErrorMessage(NSDictionary *result) {
	if (!TGResultIsError(result))
		return nil;
	id message = [result isKindOfClass:NSDictionary.class] ? result[@"message"] : nil;
	return [message isKindOfClass:NSString.class] ? message : TGL(@"TDLib.RequestFailed", @"request failed");
}

NSInteger TGResultFloodWaitSeconds(NSDictionary *result) {
	if (TGResultErrorCode(result) != 429)
		return -1;
	return TGFloodWaitSecondsFromMessage(TGResultErrorMessage(result));
}

static TGClient *gSharedInstanceOverride = nil;

@implementation TGClient

+ (void)setSharedInstanceForTesting:(TGClient *_Nullable)override {
	gSharedInstanceOverride = override;
}

+ (instancetype)shared {
	if (gSharedInstanceOverride)
		return gSharedInstanceOverride;
	static TGClient *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		s = [[TGClient alloc] init];
		s.chatsById = [NSMutableDictionary dictionary];
		s.chatActionTimers = [NSMutableDictionary dictionary];
		s.usersById = [NSMutableDictionary dictionary];
		s.userPhotosById = [NSMutableDictionary dictionary];
		s.userPhotoKeysById = [NSMutableDictionary dictionary];
		s.userRecordsById = [NSMutableDictionary dictionary];
		s.contactWaiters = [NSMutableArray array];
		s.forumSupergroups = [NSMutableDictionary dictionary];
		s.directMessagesSupergroups = [NSMutableDictionary dictionary];
		s.scopeMuteForByScope = [NSMutableDictionary dictionary];
		s.topicNotificationSettingsByKey = [NSMutableDictionary dictionary];
		s.autosaveSettingsByScope = [NSMutableDictionary dictionary];
		s.autosaveExceptionsByChatId = [NSMutableDictionary dictionary];
		s.archivedChats = @[];
		s.folders = @[];
		s.folderDefinitionsById = [NSMutableDictionary dictionary];
		s.chats = @[];
		s.closeBirthdayUsers = @[];
		s.outbox = [NSMutableArray array];
		s.pendingRequests = [NSMutableDictionary dictionary];
		s.fileWaiters = [NSMutableDictionary dictionary];
		s.fileStates = [NSMutableDictionary dictionary];
		s.fileStatesOrder = [NSMutableArray array];
		s.downloadPriorityHints = [NSMutableDictionary dictionary];
		s.outboxLock = [[NSLock alloc] init];
		s.inbox = [NSMutableArray array];
		s.inboxLock = [[NSLock alloc] init];
		s.bridgeSendCounts = [NSMutableDictionary dictionary];
		s.bridgeRecvCounts = [NSMutableDictionary dictionary];
		s.bridgeCountsLock = [[NSLock alloc] init];
		s.pinnedForumTopicCountMax = 5;
		s.pinnedChatCountMax = 5;
		s.pinnedArchivedChatCountMax = 100;
	});
	return s;
}

#pragma mark - lifecycle

- (BOOL)start {
	if (self.running)
		return self.available;

	if (self.handle)
		return [self spawnClient];

	NSString *path = [[NSBundle mainBundle].bundlePath
		stringByAppendingPathComponent:@"libtdjson.dylib"];

	TGMemMark(@"before dlopen tdjson");
	self.handle = dlopen(path.UTF8String, RTLD_NOW | RTLD_LOCAL);
	TGMemMark(@"after dlopen tdjson");
	if (!self.handle) {
		NSLog(@"TGClient: dlopen failed: %s", dlerror());
		return NO;
	}

	td_exec_fn exec = dlsym(self.handle, "td_json_client_execute");
	self.td_create = dlsym(self.handle, "td_json_client_create");
	self.td_send = dlsym(self.handle, "td_json_client_send");
	self.td_recv = dlsym(self.handle, "td_json_client_receive");
	self.td_destroy = dlsym(self.handle, "td_json_client_destroy");
	if (!self.td_create || !self.td_send || !self.td_recv) {
		NSLog(@"TGClient: missing td_json_client_* symbols");
		return NO;
	}
	if (!self.td_destroy)
		NSLog(@"TGClient: no td_json_client_destroy - background close will leak the instance");

	if (exec)
		exec(NULL, "{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":1}");

	[[TGBackgroundSession shared] attachToTDLibHandle:self.handle];
	[self watchApplicationState];

	return [self spawnClient];
}

- (BOOL)spawnClient {
	if (!self.td_create) {
		NSLog(@"TGClient: spawn requested before the library was loaded");
		return NO;
	}
	self.client = self.td_create();
	TGMemMark(@"after td_json_client_create");
	if (!self.client) {
		NSLog(@"TGClient: td_json_client_create returned NULL");
		return NO;
	}

	self.parametersSent = NO;
	self.suspending = NO;
	self.suspended = NO;
	self.available = YES;
	self.running = YES;

	[self send:@{@"@type" : @"getAuthorizationState"}];

	[NSThread detachNewThreadSelector:@selector(receiveLoop) toTarget:self withObject:nil];

	NSLog(@"TGClient: started");
	return YES;
}

#pragma mark - background suspension

static BOOL TGIsClosedAuthUpdate(NSDictionary *obj) {
	if (![obj[@"@type"] isEqualToString:@"updateAuthorizationState"])
		return NO;
	return [obj[@"authorization_state"][@"@type"]
		isEqualToString:@"authorizationStateClosed"];
}

- (void)suspendForBackgroundWithCompletion:(void (^)(void))completion {
	if (self.suspended || (!self.running && !self.client)) {
		self.suspended = YES;
		if (completion)
			completion();
		return;
	}

	if (completion) {
		void (^earlier)(void) = self.suspendCompletion;
		self.suspendCompletion = earlier ? ^{ earlier(); completion(); } : completion;
	}
	if (self.suspending)
		return;

	self.suspending = YES;
	NSLog(@"TGClient: closing TDLib to release the database");
	[self sendUnguarded:@{@"@type" : @"close"}];

	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || !strongSelf.suspending)
				return;
			NSLog(@"TGClient: close did not complete in time - forcing the receive loop down");
			strongSelf.running = NO;
		});
}

- (void)resumeFromBackground {
	if (self.suspending) {
		self.resumeWhenClosed = YES;
		return;
	}
	if (!self.suspended)
		return;

	self.suspended = NO;
	self.chatListComplete = NO;
	self.loadChatsAttempts = 0;
	self.connectionState = TGConnectionStateUnknown;
	[self loadCachedChats];

	NSLog(@"TGClient: reopening TDLib for the foreground");
	if (![self start])
		NSLog(@"TGClient: could not reopen TDLib");
}

- (void)reopenForDiskCachesIfNeededWhileCallInProgress:(BOOL)callInProgress {
	if (!TGSessionNeedsRestartForDiskCaches(self.running, self.parametersSent,
			self.parametersUsedDiskCaches, !self.diskCachesDisabledForBackgroundLaunch,
			callInProgress))
		return;

	NSLog(@"TGClient: reopening TDLib so this foreground session gets its databases");
	__weak typeof(self) weakSelf = self;
	[self suspendForBackgroundWithCompletion:^{
		[weakSelf resumeFromBackground];
	}];
}

- (void)resetForAccountSwitch {
	self.me = nil;
	self.authState = TGAuthStateUnknown;
	self.connectionState = TGConnectionStateUnknown;
	self.chatListComplete = NO;
	self.cachedChatsLoaded = NO;
	self.chatsChangedWhileBackgrounded = NO;
	self.loadChatsAttempts = 0;
	self.chatsAtLastLoad = 0;
	self.lastChatSnapshotSave = 0;
	self.pendingPhoneNumber = nil;
	self.parametersSent = NO;
	self.preInitRequests = nil;
	[self clearPendingTermsOfService];
	[self clearFreezeState];
	[self clearAgeVerificationParameters];
	[self clearSpeechRecognitionTrialForAccountSwitch];
	[self resetBotStartLinksForAccountSwitch];

	[self failPendingRequests:@"account switched"];

	[self.inboxLock lock];
	[self.inbox removeAllObjects];
	[self.inboxLock unlock];

	[self invalidateAllChatActionTimers];
	[self.chatsById removeAllObjects];
	[self.usersById removeAllObjects];
	[self.userPhotosById removeAllObjects];
	[self.userPhotoKeysById removeAllObjects];
	[self.userRecordsById removeAllObjects];
	[self.forumSupergroups removeAllObjects];
	[self.directMessagesSupergroups removeAllObjects];
	[self.folderDefinitionsById removeAllObjects];
	[self.scopeMuteForByScope removeAllObjects];
	[self.topicNotificationSettingsByKey removeAllObjects];
	self.openChatId = 0;
	[self.autosaveSettingsByScope removeAllObjects];
	[self.autosaveExceptionsByChatId removeAllObjects];
	[self.chatsConfirmedByServer removeAllObjects];
	[self.fileWaiters removeAllObjects];
	[self.fileStates removeAllObjects];
	[self.fileStatesOrder removeAllObjects];
	[self.downloadPriorityHints removeAllObjects];
	[self.contactWaiters removeAllObjects];
	[self resetQuickReplyCachesForAccountSwitch];
	[self resetChatListCachesForAccountSwitch];
	[self resetDirectMessagesCachesForAccountSwitch];
	[self resetHistoryPrefetchCachesForAccountSwitch];
	[self resetSavedMessagesCachesForAccountSwitch];
	[self resetSecretChatCachesForAccountSwitch];
	[self resetStoryPostCachesForAccountSwitch];
	[self resetUserStatusCachesForAccountSwitch];
	[self resetAppSettingsCachesForAccountSwitch];
	[self resetAiWritingCachesForAccountSwitch];
	[self resetStarBalanceCacheForAccountSwitch];
	[self resetPaidReactionDefaultCacheForAccountSwitch];
	[self resetGifSearchBotCacheForAccountSwitch];
	[self resetReactionCachesForAccountSwitch];

	self.chats = @[];
	self.archivedChats = @[];
	self.folders = @[];
	self.closeBirthdayUsers = @[];

	[TGRemoteImageView tgPurgeMemoryCache];
	[TGDayCalendarView resetForAccountSwitch];
	[TGStarsViewController resetPaidMediaUnlocksForAccountSwitch];
	[TGSettingsViewController resetAutoDownloadPresetCacheForAccountSwitch];
	[TGSettingsViewController resetDataSaverCacheForAccountSwitch];
	[self forgetAutoDownloadSettingsMirror];
	[TGStickerPanelView resetSectionSnapshotForAccountSwitch];
	[TGStickerThumbnailCache purgeMemory];
	[TGGifPickerViewController purgeVideoStillCacheForAccountSwitch];
	[TGMusicPlayer resetForAccountSwitch];
	[TGTheme resetDefaultBackgroundIdForAccountSwitch];
	[TGAudioMetadata flush];
	TGResetActiveChatThemeCachesForAccountSwitch();
	[self forgetChatSnapshotDigest];
	[self rebuildChats];
	NSLog(@"TGClient: in-memory state cleared for the account switch");
}

- (void)capUserRegistriesIfNeeded {
	if (self.usersById.count > 2000 || self.userRecordsById.count > 2000) {
		[self.usersById removeAllObjects];
		[self.userRecordsById removeAllObjects];
	}
}

- (void)capSupergroupFlagRegistriesIfNeeded {
	if (self.forumSupergroups.count > 2000 || self.directMessagesSupergroups.count > 2000) {
		[self.forumSupergroups removeAllObjects];
		[self.directMessagesSupergroups removeAllObjects];
	}
}

- (void)tearDownClient:(void *)client {
	self.available = NO;
	self.running = NO;
	self.client = NULL;

	[self.outboxLock lock];
	[self.outbox removeAllObjects];
	[self.outboxLock unlock];

	[self.inboxLock lock];
	[self.inbox removeAllObjects];
	self.inboxScheduled = NO;
	[self.inboxLock unlock];

	if (self.td_destroy)
		self.td_destroy(client);

	dispatch_async(dispatch_get_main_queue(), ^{ [self didFinishSuspending]; });
}

- (void)didFinishSuspending {
	if (!self.suspending)
		return;
	self.suspending = NO;
	self.suspended = YES;
	NSLog(@"TGClient: TDLib closed, database released");

	void (^done)(void) = self.suspendCompletion;
	self.suspendCompletion = nil;
	if (done)
		done();

	if (self.resumeWhenClosed) {
		self.resumeWhenClosed = NO;
		[self resumeFromBackground];
	}
}

- (void)watchApplicationState {
	if (self.applicationStateWatched)
		return;
	self.applicationStateWatched = YES;
	__weak typeof(self) weakSelf = self;
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	[centre addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *__unused note) {
						weakSelf.idlePolling = YES;
						[weakSelf setSelfOnline:NO];
					}];
	[centre addObserverForName:UIApplicationWillEnterForegroundNotification object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *__unused note) {
						weakSelf.idlePolling = NO;
						[weakSelf setSelfOnline:YES];
					}];
	[centre addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *__unused note) {
						[weakSelf replayDeferredChatListUpdate];
					}];
}

- (void)replayDeferredChatListUpdate {
	if (!self.chatsChangedWhileBackgrounded)
		return;
	self.chatsChangedWhileBackgrounded = NO;
	[self postChatsAndArchiveChanged];
}

- (void)postChatsAndArchiveChanged {
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	[centre postNotificationName:TGChatsDidChangeNotification object:self];
	[centre postNotificationName:TGArchivedChatsDidChangeNotification object:self];
}

static const NSTimeInterval kRecvBusyWindow = 0.35;
static const NSTimeInterval kRecvQuietWindow = 5.0;
static const double kRecvBusyTimeout = 0.005;
static const double kRecvQuietTimeout = 0.01;
static const double kRecvIdleTimeout = 0.05;
static const double kRecvBackgroundTimeout = 1.0;
static const NSUInteger kInboxBatch = 48;
static const NSUInteger kInboxHighWater = 512;

- (double)receiveTimeout {
	if (self.idlePolling)
		return kRecvBackgroundTimeout;
	NSTimeInterval quiet = [NSDate timeIntervalSinceReferenceDate] - self.lastBridgeActivity;
	if (quiet < kRecvBusyWindow)
		return kRecvBusyTimeout;
	if (quiet < kRecvQuietWindow)
		return kRecvQuietTimeout;
	return kRecvIdleTimeout;
}

- (void)receiveLoop {
	void *client = self.client;
	BOOL closed = NO;

	while (self.running && !closed) {
		@autoreleasepool {
			if ([self drainOutbox])
				self.lastBridgeActivity = [NSDate timeIntervalSinceReferenceDate];

			const char *res = self.td_recv(client, [self receiveTimeout]);
			if (!res)
				continue;

			self.lastBridgeActivity = [NSDate timeIntervalSinceReferenceDate];
			[[TGBackgroundSession shared] noteDataReceived];

			NSData *data = [NSData dataWithBytes:res length:strlen(res)];
			NSError *err = nil;
			NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
			if (![obj isKindOfClass:NSDictionary.class]) {
				NSLog(@"TGClient: bad JSON: %@", err);
				continue;
			}

			closed = TGIsClosedAuthUpdate(obj);
			[self enqueueUpdate:obj];
		}
	}

	[self tearDownClient:client];
}

- (void)enqueueUpdate:(NSDictionary *)obj {
	BOOL schedule = NO;
	NSInteger depth = 0;
	[self.inboxLock lock];
	[self.inbox addObject:obj];
	depth = self.inbox.count;
	if (!self.inboxScheduled) {
		self.inboxScheduled = YES;
		schedule = YES;
	}
	[self.inboxLock unlock];

	if (schedule)
		dispatch_async(dispatch_get_main_queue(), ^{ [self drainInbox]; });

	if (depth >= kInboxHighWater)
		[NSThread sleepForTimeInterval:kRecvBusyTimeout];
}

- (void)drainInbox {
	NSArray *batch = nil;
	BOOL more = NO;
	[self.inboxLock lock];
	NSInteger take = MIN(self.inbox.count, kInboxBatch);
	if (take) {
		batch = [self.inbox subarrayWithRange:NSMakeRange(0, take)];
		[self.inbox removeObjectsInRange:NSMakeRange(0, take)];
	}
	more = self.inbox.count > 0;
	if (!more)
		self.inboxScheduled = NO;
	[self.inboxLock unlock];

	for (NSDictionary *obj in batch) {
		@autoreleasepool {
			[self handleUpdate:obj];
		}
	}

	if (more)
		dispatch_async(dispatch_get_main_queue(), ^{ [self drainInbox]; });
}

#pragma mark - sending

- (BOOL)requestSurvivesUninitialised:(NSDictionary *)request {
	NSString *type = request[@"@type"];
	return [type isEqualToString:@"setTdlibParameters"] ||
		[type isEqualToString:@"getAuthorizationState"] ||
		[type isEqualToString:@"setLogVerbosityLevel"] ||
		[type isEqualToString:@"setLogStream"];
}

- (void)countBridgeSend:(NSDictionary *)request {
	if (!TGPerfLogging())
		return;
	NSString *type = [request[@"@type"] isKindOfClass:NSString.class] ? request[@"@type"] : @"?";
	[self.bridgeCountsLock lock];
	NSNumber *n = self.bridgeSendCounts[type];
	self.bridgeSendCounts[type] = @(n.unsignedIntegerValue + 1);
	[self.bridgeCountsLock unlock];
}

- (void)sendUnguarded:(NSDictionary *)request {
	[self countBridgeSend:request];
	NSError *err = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:request options:0 error:&err];
	if (!data) {
		NSLog(@"TGClient: cannot encode %@: %@", TGRedactedRequestForLogging(request), err);
		return;
	}

	NSMutableData *z = [[NSMutableData alloc] initWithCapacity:data.length + 1];
	[z appendData:data];
	[z appendBytes:"\0" length:1];

	[self.outboxLock lock];
	[self.outbox addObject:z];
	[self.outboxLock unlock];
}

- (void)send:(NSDictionary *)request {
	if (!self.parametersSent && ![self requestSurvivesUninitialised:request]) {
		if (!self.preInitRequests)
			self.preInitRequests = [NSMutableArray array];
		[self.preInitRequests addObject:request];
		return;
	}

	[self countBridgeSend:request];
	NSError *err = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:request options:0 error:&err];
	if (!data) {
		NSLog(@"TGClient: cannot encode %@: %@", TGRedactedRequestForLogging(request), err);
		return;
	}

	NSMutableData *z = [[NSMutableData alloc] initWithCapacity:data.length + 1];
	[z appendData:data];
	[z appendBytes:"\0" length:1];

	[self.outboxLock lock];
	[self.outbox addObject:z];
	[self.outboxLock unlock];
}

- (BOOL)drainOutbox {
	if (!self.available)
		return NO;

	NSArray *pending = nil;
	[self.outboxLock lock];
	if (self.outbox.count) {
		pending = [self.outbox copy];
		[self.outbox removeAllObjects];
	}
	[self.outboxLock unlock];
	if (!pending)
		return NO;

	for (NSData *d in pending)
		self.td_send(self.client, d.bytes);
	return YES;
}

- (void)request:(NSDictionary *)request completion:(void (^)(NSDictionary *))completion {
	[self request:request deadline:kRequestDeadline completion:completion];
}

- (void)request:(NSDictionary *)request
	   deadline:(NSTimeInterval)deadline
	 completion:(void (^)(NSDictionary *))completion {
	if (!completion) {
		[self send:request];
		return;
	}
	NSString *extra = [NSString stringWithFormat:@"r%lu", (unsigned long)(++self.requestSeq)];
	self.pendingRequests[extra] = @{
		@"block" : [completion copy],
		@"deadline" : @([NSDate timeIntervalSinceReferenceDate] + deadline),
	};

	NSMutableDictionary *withExtra = [request mutableCopy];
	withExtra[@"@extra"] = extra;
	[self send:withExtra];
	[self startPendingSweepTimer];
}

#pragma mark - authorization steps

- (void)setTdlibLogVerbosity:(NSInteger)level {
	[self send:@{
		@"@type" : @"setLogVerbosityLevel",
		@"new_verbosity_level" : @(level),
	}];
}

- (void)sendPhoneNumber:(NSString *)phoneNumber {
	self.pendingPhoneNumber = phoneNumber;
	if (!self.available)
		return;
	if (self.authState == TGAuthStateWaitPhoneNumber ||
		self.authState == TGAuthStateWaitCode ||
		self.authState == TGAuthStateWaitRegistration)
		[self flushPendingPhoneNumber];
}

- (void)flushPendingPhoneNumber {
	if (!self.pendingPhoneNumber.length)
		return;
	NSString *number = self.pendingPhoneNumber;
	self.pendingPhoneNumber = nil;
	[self send:@{
		@"@type" : @"setAuthenticationPhoneNumber",
		@"phone_number" : number,
	}];
}

#pragma mark - shared notification names and flatten context

NSString *const TGUserStatusDidChangeNotification = @"TGUserStatusDidChangeNotification";
NSString *const TGUserProfileDidChangeNotification = @"TGUserProfileDidChangeNotification";
NSString *const TGChatReadOutboxDidChangeNotification = @"TGChatReadOutboxDidChangeNotification";
NSString *const TGChatIsTranslatableDidChangeNotification = @"TGChatIsTranslatableDidChangeNotification";
NSString *const TGChatPinnedMessagesDidChangeNotification = @"TGChatPinnedMessagesDidChangeNotification";
NSString *const TGChatAppearanceCatalogDidChangeNotification = @"TGChatAppearanceCatalogDidChangeNotification";
NSString *const TGWebBrowserSettingsDidChangeNotification = @"TGWebBrowserSettingsDidChangeNotification";
NSString *const TGChatActionBarDidChangeNotification = @"TGChatActionBarDidChangeNotification";
NSString *const TGChatPermissionsDidChangeNotification = @"TGChatPermissionsDidChangeNotification";
NSString *const TGUserBlockedStateDidChangeNotification = @"TGUserBlockedStateDidChangeNotification";
NSString *const TGChatVideoChatDidChangeNotification = @"TGChatVideoChatDidChangeNotification";
NSString *const TGGroupCallDidChangeNotification = @"TGGroupCallDidChangeNotification";
NSString *const TGChatMessageAutoDeleteTimeDidChangeNotification = @"TGChatMessageAutoDeleteTimeDidChangeNotification";
NSString *const TGChatBackgroundDidChangeNotification = @"TGChatBackgroundDidChangeNotification";
NSString *const TGDefaultBackgroundRowKey = @"defaultBackgroundRow";
NSString *const TGChatHasScheduledMessagesDidChangeNotification = @"TGChatHasScheduledMessagesDidChangeNotification";
NSString *const TGChatMemberDidChangeNotification = @"TGChatMemberDidChangeNotification";
NSString *const TGChatMemberUserIdKey = @"userId";
NSString *const TGChatNotificationSettingsDidChangeNotification = @"TGChatNotificationSettingsDidChangeNotification";
NSString *const TGChatDraftDidChangeNotification = @"TGChatDraftDidChangeNotification";
NSString *const TGChatThemeDidChangeNotification = @"TGChatThemeDidChangeNotification";
NSString *const TGChatEmojiStatusDidChangeNotification = @"TGChatEmojiStatusDidChangeNotification";
NSString *const TGChatMessageSenderDidChangeNotification = @"TGChatMessageSenderDidChangeNotification";
NSString *const TGChatMessageSenderIdKey = @"senderId";
NSString *const TGChatMessageSenderIsChatKey = @"isChat";
NSString *const TGInstalledStickerSetsDidChangeNotification = @"TGInstalledStickerSetsDidChangeNotification";
NSString *const TGInstalledStickerSetsTypeKey = @"stickerType";
NSString *const TGTrendingStickerSetsDidChangeNotification = @"TGTrendingStickerSetsDidChangeNotification";
NSString *const TGTrendingStickerSetsTypeKey = @"stickerType";
NSString *const TGRecentStickersDidChangeNotification = @"TGRecentStickersDidChangeNotification";
NSString *const TGFavoriteStickersDidChangeNotification = @"TGFavoriteStickersDidChangeNotification";
NSString *const TGSavedAnimationsDidChangeNotification = @"TGSavedAnimationsDidChangeNotification";
NSString *const TGForumTopicDidChangeNotification = @"TGForumTopicDidChangeNotification";
NSString *const TGForumTopicChatIdKey = @"chatId";
NSString *const TGForumTopicTopicIdKey = @"topicId";
NSString *const TGFileStateDidChangeNotification = @"TGFileStateDidChangeNotification";
NSString *const TGFileStateFileIdKey = @"fileId";
NSString *const TGMessageInteractionInfoDidChangeNotification = @"TGMessageInteractionInfoDidChangeNotification";
NSString *const TGChatUnreadMentionsDidChangeNotification = @"TGChatUnreadMentionsDidChangeNotification";
NSString *const TGChatUnreadReactionsDidChangeNotification = @"TGChatUnreadReactionsDidChangeNotification";
NSString *const TGChatOnlineMemberCountDidChangeNotification = @"TGChatOnlineMemberCountDidChangeNotification";
NSString *const TGChatOnlineMemberCountKey = @"onlineMemberCount";
NSString *const TGChatSlowModeDelayDidChangeNotification = @"TGChatSlowModeDelayDidChangeNotification";
NSString *const TGChatSlowModeDelayKey = @"slowModeDelay";
NSString *const TGChatPendingJoinRequestsDidChangeNotification = @"TGChatPendingJoinRequestsDidChangeNotification";
NSString *const TGChatPendingJoinRequestsCountKey = @"pendingJoinRequestsCount";
NSString *const TGAuthStateDidChangeNotification = @"TGAuthStateDidChangeNotification";
NSString *const TGAuthStateKey = @"authState";
NSString *const TGClientErrorNotification = @"TGClientErrorNotification";
NSString *const TGClientErrorMessageKey = @"message";
NSString *const TGChatsDidChangeNotification = @"TGChatsDidChangeNotification";
NSString *const TGArchivedChatsDidChangeNotification = @"TGArchivedChatsDidChangeNotification";
NSString *const TGFileProgressDidChangeNotification = @"TGFileProgressDidChangeNotification";
NSString *const TGFileProgressFileIdKey = @"fileId";
NSString *const TGFileProgressValueKey = @"progress";
NSString *const TGChatActionDidChangeNotification = @"TGChatActionDidChangeNotification";
NSString *const TGChatActionChatIdKey = @"chatId";
NSString *const TGChatActionTextKey = @"action";
NSString *const TGChatActionTopicIdKey = @"topicId";
NSString *const TGMessageDidChangeNotification = @"TGMessageDidChangeNotification";
NSString *const TGDownloadsDidChangeNotification = @"TGDownloadsDidChangeNotification";
NSString *const TGDownloadsSummaryKey = @"downloads";
NSString *const TGPollDidChangeNotification = @"TGPollDidChangeNotification";
NSString *const TGPollDataKey = @"poll";
NSString *const TGMessageChatIdKey = @"chatId";
NSString *const TGMessageDataKey = @"message";
NSString *const TGMessageDeletedIdKey = @"deletedId";

NSDictionary *TGUserStatusInfo(NSDictionary *status) {
	NSString *type = status[@"@type"];
	if ([type isEqualToString:@"userStatusOnline"])
		return @{@"isOnline" : @YES,
			@"text" : TGL(@"Presence.online", @"online"),
			@"rank" : @(4000000000LL),
			@"expires" : @([status[@"expires"] doubleValue])};
	if ([type isEqualToString:@"userStatusOffline"]) {
		int64_t wasOnline = [status[@"was_online"] longLongValue];
		NSDate *date = [NSDate dateWithTimeIntervalSince1970:wasOnline];
		NSDate *now = [NSDate date];

		static NSCalendar *cal = nil;
		static NSDateFormatter *timeFmt = nil;
		static NSDateFormatter *dayFmt = nil;
		static NSDateFormatter *dateFmt = nil;
		if (!cal) {
			cal = [NSCalendar currentCalendar];
			timeFmt = [NSDateFormatter new];
			timeFmt.dateFormat = @"HH:mm";
			dayFmt = [NSDateFormatter new];
			dayFmt.dateFormat = @"EEEE";
			dateFmt = [NSDateFormatter new];
			dateFmt.dateFormat = @"dd.MM.yyyy";
		}

		static NSMutableDictionary *phrases = nil;
		static NSDate *phrasesExpire = nil;
		if (!phrases)
			phrases = [NSMutableDictionary dictionary];
		if (!phrasesExpire || [now compare:phrasesExpire] != NSOrderedAscending) {
			NSUInteger midnightUnits = NSCalendarUnitYear | NSCalendarUnitMonth |
				NSCalendarUnitDay;
			NSDate *midnight = [cal dateFromComponents:
					[cal components:midnightUnits fromDate:now]];
			NSDateComponents *oneDay = [[NSDateComponents alloc] init];
			oneDay.day = 1;
			phrasesExpire = [cal dateByAddingComponents:oneDay toDate:midnight options:0];
			[phrases removeAllObjects];
		}
		NSDictionary *remembered = phrases[@(wasOnline)];
		if (remembered)
			return remembered;

		NSString *time = [timeFmt stringFromDate:date];

		NSUInteger dayUnits = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
		NSDate *dateOnly = [cal dateFromComponents:[cal components:dayUnits fromDate:date]];
		NSDate *nowOnly = [cal dateFromComponents:[cal components:dayUnits fromDate:now]];
		NSInteger dayDelta = [cal components:NSCalendarUnitDay
									fromDate:dateOnly
									  toDate:nowOnly
									 options:0]
								 .day;

		NSString *lastSeenText;
		if (dayDelta == 0) {
			lastSeenText = [NSString stringWithFormat:
				TGL(@"LastSeen.TodayAt", @"last seen today at %@"), time];
		} else if (dayDelta == 1) {
			lastSeenText = [NSString stringWithFormat:
				TGL(@"LastSeen.YesterdayAt", @"last seen yesterday at %@"), time];
		} else if (dayDelta > 1 && dayDelta < 7) {
			lastSeenText = [NSString stringWithFormat:
				TGL(@"Presence.LastSeenOnWeekdayAt", @"last seen on %@ at %@"),
				[dayFmt stringFromDate:date], time];
		} else {
			lastSeenText = [NSString stringWithFormat:
				TGL(@"Presence.LastSeenOnDateAt", @"last seen %@ at %@"),
				[dateFmt stringFromDate:date], time];
		}
		NSDictionary *info = @{@"isOnline" : @NO,
			@"text" : lastSeenText,
			@"rank" : @(wasOnline)};
		phrases[@(wasOnline)] = info;
		return info;
	}
	if ([type isEqualToString:@"userStatusRecently"])
		return @{@"isOnline" : @NO,
			@"text" : TGL(@"LastSeen.Lately", @"last seen recently"),
			@"rank" : @(3)};
	if ([type isEqualToString:@"userStatusLastWeek"])
		return @{@"isOnline" : @NO,
			@"text" : TGL(@"LastSeen.WithinAWeek", @"last seen within a week"),
			@"rank" : @(2)};
	if ([type isEqualToString:@"userStatusLastMonth"])
		return @{@"isOnline" : @NO,
			@"text" : TGL(@"LastSeen.WithinAMonth", @"last seen within a month"),
			@"rank" : @(1)};
	return @{@"isOnline" : @NO,
		@"text" : TGL(@"LastSeen.ALongTimeAgo", @"last seen a long time ago"),
		@"rank" : @(0)};
}

TGFlattenContext *TGCurrentFlattenContext(void) {
	static TGFlattenContext *context = nil;
	if (!context) {
		context = [TGFlattenContext new];
		context.userName = ^NSString *(int64_t userId) {
			return [[TGClient shared] nameForUserId:userId];
		};
		context.botServiceText = ^NSString *(NSDictionary *message) {
			return [[TGClient shared] botServiceTextForMessage:message];
		};
		context.secretServiceText = ^NSString *(NSDictionary *message) {
			return [[TGClient shared] secretServiceTextForMessage:message];
		};
		context.localizedFallback = ^NSString *(NSString *key, NSString *fallback) {
			return TGL(key, fallback);
		};
		context.rememberFileState = ^(NSDictionary *file) {
			[[TGClient shared] rememberStateOfFileObject:file notify:NO];
		};
		context.fileState = ^NSDictionary *(NSDictionary *file) {
			return TGFlattenFileObjectState(file);
		};
		context.reactionChips = ^NSArray *(NSDictionary *interactionInfo, int64_t chatId) {
			return [TGClient reactionChipsFromInteractionInfo:interactionInfo chatId:chatId];
		};
		context.reactionSummary = ^NSString *(NSArray *chips) {
			return [TGClient reactionSummaryFromChips:chips];
		};
		context.flattenedPageBlocks = ^NSArray *(NSArray *rawBlocks) {
			return [TGClient flattenedPageBlocks:rawBlocks];
		};
	}
	context.myUserId = [[[TGClient shared].me objectForKey:@"id"] longLongValue];
	context.ignoresSensitiveContentRestrictions =
		[TGClient shared].ignoresSensitiveContentRestrictions;
	context.chatsById = [[TGClient shared] chatsById];
	return context;
}

#pragma mark - chat list snapshot

static NSString *const TGChatSnapshotName = @"chatlist";
static const NSUInteger kChatSnapshotLimit = 200;
static const NSTimeInterval kChatSnapshotInterval = 10.0;
static const NSTimeInterval kChatSnapshotQuiet = 2.0;

static unsigned long long TGChatSnapshotDigest = 0;
static NSTimeInterval TGChatSnapshotTracked = 0;

static dispatch_queue_t TGChatSnapshotQueue(void) {
	static dispatch_queue_t queue = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("TGChatSnapshot", NULL);
	});
	return queue;
}

static unsigned long long TGChatSnapshotDigestOf(NSData *data) {
	const unsigned char *bytes = (const unsigned char *)data.bytes;
	NSInteger length = data.length;
	unsigned long long hash = 14695981039346656037ULL;
	for (NSInteger i = 0; i < length; i++) {
		hash ^= bytes[i];
		hash *= 1099511628211ULL;
	}
	return hash ^ (unsigned long long)length;
}

static NSDictionary *TGPlistSafeChat(NSDictionary *chat) {
	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:chat.count];
	for (NSString *key in chat) {
		id value = chat[key];
		if (![key isKindOfClass:NSString.class])
			continue;
		if ([key isEqualToString:@"photoFileId"])
			continue;
		if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class])
			out[key] = value;
	}
	return [out[@"id"] isKindOfClass:NSNumber.class] ? out : nil;
}

static NSString *const TGFolderSnapshotName = @"folders";

- (void)saveCachedFolders {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *folder in self.folders ?: @[]) {
		id folderId = folder[@"id"];
		id title = folder[@"title"];
		if ([folderId isKindOfClass:NSNumber.class] && [title isKindOfClass:NSString.class])
			[rows addObject:@{@"id" : folderId, @"title" : title}];
	}
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:rows format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
	[[NSUserDefaults standardUserDefaults] setBool:self.folderTagsEnabled
											forKey:[TGAccountManager defaultsKey:@"tgFolderTagsEnabled"]];
	[[NSUserDefaults standardUserDefaults] setInteger:self.mainChatListPosition
												forKey:[TGAccountManager defaultsKey:@"tgMainChatListPosition"]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	if (!data.length)
		return;
	NSString *path = [TGDiskCache snapshotPathForName:TGFolderSnapshotName];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[TGDiskCache writeData:data toProtectedPath:path];
	});
}

- (void)loadCachedFolders {
	self.folderTagsEnabled = [[NSUserDefaults standardUserDefaults]
		boolForKey:[TGAccountManager defaultsKey:@"tgFolderTagsEnabled"]];
	self.mainChatListPosition = [[NSUserDefaults standardUserDefaults]
		integerForKey:[TGAccountManager defaultsKey:@"tgMainChatListPosition"]];
	if (self.folders.count)
		return;
	NSData *data = [NSData dataWithContentsOfFile:
			[TGDiskCache snapshotPathForName:TGFolderSnapshotName]];
	if (!data.length)
		return;
	id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
	if ([plist isKindOfClass:NSArray.class] && [(NSArray *)plist count]) {
		self.folders = plist;
		[self refreshFolderTagDefinitions];
	}
}

- (void)loadCachedChats {
	if (self.cachedChatsLoaded || self.chatsById.count)
		return;
	self.cachedChatsLoaded = YES;
	[self loadCachedFolders];

	NSData *data = [NSData dataWithContentsOfFile:
			[TGDiskCache snapshotPathForName:TGChatSnapshotName]];
	if (!data.length)
		return;

	id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
	if (![plist isKindOfClass:NSArray.class])
		return;

	for (id entry in (NSArray *)plist) {
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *chat = TGPlistSafeChat(entry);
		NSNumber *chatId = chat[@"id"];
		if (!chatId || self.chatsById[chatId])
			continue;
		NSMutableDictionary *restored = [chat mutableCopy];
		[restored removeObjectForKey:@"photoFileId"];
		restored[@"action"] = @"";
		if ([restored[@"isSaved"] boolValue])
			restored[@"title"] = TGSavedMessagesTitle();
		self.chatsById[chatId] = restored;
	}
	NSLog(@"TGClient: %lu chats restored from disk", (unsigned long)self.chatsById.count);
	[self rebuildChats];
}

- (void)saveCachedChatsThrottled {
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - self.lastChatSnapshotSave < kChatSnapshotInterval)
		return;
	if ([[[NSRunLoop mainRunLoop] currentMode] isEqualToString:UITrackingRunLoopMode]) {
		TGChatSnapshotTracked = now;
		return;
	}
	if (now - TGChatSnapshotTracked < kChatSnapshotQuiet)
		return;
	[self saveCachedChats];
}

- (void)saveCachedChats {
	if (self.authState != TGAuthStateReady)
		return;
	self.lastChatSnapshotSave = [NSDate timeIntervalSinceReferenceDate];

	NSMutableArray *pending = [NSMutableArray arrayWithCapacity:kChatSnapshotLimit];
	for (NSArray *list in @[ self.chats ?: @[], self.archivedChats ?: @[] ]) {
		for (NSDictionary *chat in list) {
			if (pending.count >= kChatSnapshotLimit)
				break;
			[pending addObject:[chat copy]];
		}
	}
	if (!pending.count)
		return;

	NSString *path = [TGDiskCache snapshotPathForName:TGChatSnapshotName];
	dispatch_async(TGChatSnapshotQueue(), ^{
		@autoreleasepool {
			NSMutableArray *rows = [NSMutableArray arrayWithCapacity:pending.count];
			for (NSDictionary *chat in pending) {
				NSDictionary *safe = TGPlistSafeChat(chat);
				if (safe)
					[rows addObject:safe];
			}
			if (!rows.count)
				return;
			NSData *data = [NSPropertyListSerialization dataWithPropertyList:rows format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
			if (!data.length)
				return;
			unsigned long long digest = TGChatSnapshotDigestOf(data);
			if (digest == TGChatSnapshotDigest &&
				[[NSFileManager defaultManager] fileExistsAtPath:path])
				return;
			if ([TGDiskCache writeData:data toProtectedPath:path])
				TGChatSnapshotDigest = digest;
		}
	});
}

- (void)forgetChatSnapshotDigest {
	dispatch_async(TGChatSnapshotQueue(), ^{ TGChatSnapshotDigest = 0; });
}

- (void)clearCachedChats {
	self.lastChatSnapshotSave = 0;
	NSString *path = [TGDiskCache snapshotPathForName:TGChatSnapshotName];
	NSString *folders = [TGDiskCache snapshotPathForName:TGFolderSnapshotName];
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	dispatch_async(TGChatSnapshotQueue(), ^{
		TGChatSnapshotDigest = 0;
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:folders error:NULL];
	});
}

- (void)dropChatsMissingFromServerList {
	if (!self.chatsConfirmedByServer.count)
		return;
	NSMutableArray *stale = [NSMutableArray array];
	for (NSNumber *chatId in self.chatsById)
		if (![self.chatsConfirmedByServer containsObject:chatId])
			[stale addObject:chatId];
	if (!stale.count)
		return;
	[self.chatsById removeObjectsForKeys:stale];
	NSLog(@"TGClient: dropped %lu chats the server no longer lists",
		(unsigned long)stale.count);
	[self rebuildChats];
}

- (void)resetBridgeCounts {
	[self.bridgeCountsLock lock];
	[self.bridgeSendCounts removeAllObjects];
	[self.bridgeRecvCounts removeAllObjects];
	[self.bridgeCountsLock unlock];
	NSLog(@"PERF bridgecounts reset");
}

- (void)logBridgeCounts {
	[self.bridgeCountsLock lock];
	NSDictionary *sent = [self.bridgeSendCounts copy];
	NSDictionary *recv = [self.bridgeRecvCounts copy];
	[self.bridgeCountsLock unlock];

	NSInteger totalSent = 0, totalRecv = 0;
	for (NSNumber *n in sent.allValues)
		totalSent += n.unsignedIntegerValue;
	for (NSNumber *n in recv.allValues)
		totalRecv += n.unsignedIntegerValue;

	for (NSString *type in [sent.allKeys sortedArrayUsingSelector:@selector(compare:)])
		NSLog(@"PERF bridge sent %@ x%@", type, sent[type]);
	for (NSString *type in [recv.allKeys sortedArrayUsingSelector:@selector(compare:)])
		NSLog(@"PERF bridge recv %@ x%@", type, recv[type]);
	NSLog(@"PERF bridge totals sent=%lu recv=%lu",
		(unsigned long)totalSent, (unsigned long)totalRecv);
}

@end
