#import "TGClient+ChatManagement.h"
#import "TGNotificationManager.h"
#import "TGLocalization.h"
#import "TGClient+Notifications.h"
#import "TGClient+Network.h"
#import "TGClient+Private.h"
#import "TGClient+ChatState.h"
#import "TGClient+Forums.h"
#import "TGFlattenForums.h"
#import "TGPasscodeLock.h"
#import "TGInAppNotificationPreferences.h"
#import "TGSettingsService.h"
#import "TGAccountManager.h"
#import "TGTheme.h"
#import <AudioToolbox/AudioToolbox.h>

NSString *const TGNotificationManagerDidRequestOpenChatNotification =
	@"TGNotificationManagerDidRequestOpenChatNotification";
NSString *const TGNotificationManagerChatIdKey = @"chatId";

@interface TGInAppBannerView : UIView
@property (nonatomic, assign) int64_t chatId;
@end

@implementation TGInAppBannerView
@end

static const NSInteger kNotificationGroupCountMax = 5;
static const NSInteger kNotificationGroupSizeMax = 10;
static const NSTimeInterval kNotificationMinimumInterval = 1.0;
static const NSTimeInterval kNotificationMinimumSoundInterval = 3.0;
static const NSTimeInterval kNotificationBudgetWindow = 10.0;
static const NSUInteger kNotificationBudgetPerWindow = 5;
static const NSUInteger kNotificationAggregateThreshold = 5;
static const NSTimeInterval kNotificationAggregateBlock = 10.0;
static const NSUInteger kNotificationMaxBodyLength = 160;
static const NSUInteger kNotificationRecentKeyLimit = 256;

static NSString *TGNotificationSafeText(NSString *text) {
	if (![text isKindOfClass:[NSString class]] || !text.length)
		return nil;

	NSMutableString *out = [NSMutableString stringWithCapacity:
			MIN(text.length, kNotificationMaxBodyLength)];
	BOOL previousWasSpace = NO;
	BOOL truncated = NO;

	for (NSInteger i = 0; i < text.length; i++) {
		unichar ch = [text characterAtIndex:i];

		if (ch >= 0xd800 && ch <= 0xdbff) {
			if (i + 1 >= text.length)
				continue;
			unichar low = [text characterAtIndex:i + 1];
			if (low < 0xdc00 || low > 0xdfff)
				continue;
			if (out.length + 2 > kNotificationMaxBodyLength - 1) {
				truncated = YES;
				break;
			}
			[out appendFormat:@"%C%C", ch, low];
			i++;
			previousWasSpace = NO;
			continue;
		}
		if (ch >= 0xdc00 && ch <= 0xdfff)
			continue;

		BOOL isWhitespace = ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
		BOOL isControl = ch < 0x20 || (ch >= 0x7f && ch <= 0x9f);
		BOOL isDirectional = (ch >= 0x200b && ch <= 0x200f) ||
			(ch >= 0x202a && ch <= 0x202e) || (ch >= 0x2060 && ch <= 0x206f);
		BOOL isInvalid = ch == 0xfffc || ch == 0xfffe || ch == 0xffff || ch == 0xfeff;

		if (isWhitespace) {
			if (!previousWasSpace && out.length)
				[out appendString:@" "];
			previousWasSpace = YES;
			continue;
		}
		if (isControl || isDirectional || isInvalid)
			continue;
		if (out.length + 1 > kNotificationMaxBodyLength - 1) {
			truncated = YES;
			break;
		}
		[out appendFormat:@"%C", ch];
		previousWasSpace = NO;
	}

	NSString *clean = [out stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!clean.length)
		return nil;
	if (truncated || text.length > kNotificationMaxBodyLength)
		clean = [clean stringByAppendingString:@"…"];
	return clean;
}

static NSString *TGNotificationAggregateText(NSUInteger count) {
	return TGLPlural(@"Notification.AggregateNewMessages", (NSInteger)count,
			@"%lu new message", @"%lu new messages");
}

static NSString *TGNotificationLockedText(void) {
	return [NSString stringWithFormat:TGL(@"PUSH_LOCKED_MESSAGE", @"You have a new message%1$@"), @""];
}

static NSString *const TGNotificationToneKey = @"TGNotificationToneId";
static const long long TGNotificationToneSystem = -1;

static NSString *TGNotificationToneFileName(long long toneId, NSString *extension) {
	if (toneId < 0)
		return nil;
	NSString *stem = [NSString stringWithFormat:@"%lld", toneId];
	if (![[NSBundle mainBundle] pathForResource:stem ofType:extension])
		return nil;
	return [stem stringByAppendingFormat:@".%@", extension];
}

static __weak TGInAppBannerView *sInAppBanner = nil;
static const NSTimeInterval kInAppBannerSeconds = 3.0;

static NSString *TGNotificationSoundName(long long soundId) {
	if (soundId == 0)
		return nil;

	NSString *fromServer = TGNotificationToneFileName(soundId, @"caf");
	if (fromServer)
		return fromServer;

	NSString *chosen = TGNotificationToneFileName([TGNotificationManager selectedToneId], @"caf");
	if (chosen)
		return chosen;

	return UILocalNotificationDefaultSoundName;
}

@interface TGNotificationManager ()

@property (nonatomic, strong) NSMutableDictionary *chatIdByGroup;
@property (nonatomic, strong) NSMutableDictionary *unreadByList;
@property (nonatomic, strong) NSMutableArray *recentKeys;
@property (nonatomic, strong) NSMutableSet *recentKeySet;
@property (nonatomic, assign) NSTimeInterval lastPresented;
@property (nonatomic, assign) NSTimeInterval aggregateBlockUntil;
@property (nonatomic, assign) NSTimeInterval lastSound;
@property (nonatomic, assign) NSTimeInterval budgetWindowStart;
@property (nonatomic, assign) NSUInteger budgetUsed;
@property (nonatomic, assign) NSInteger unmutedUnread;
@property (nonatomic, assign) BOOL haveUnreadCount;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, strong) id clientUpdateObserverToken;
@property (nonatomic, strong) id scopeUpdateObserverToken;

@end

@implementation TGNotificationManager

+ (instancetype)shared {
	static TGNotificationManager *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ shared = [[TGNotificationManager alloc] init]; });
	return shared;
}

- (id)init {
	self = [super init];
	if (!self)
		return nil;
	_chatIdByGroup = [NSMutableDictionary dictionary];
	_unreadByList = [NSMutableDictionary dictionary];
	_recentKeys = [NSMutableArray array];
	_recentKeySet = [NSMutableSet set];
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.clientUpdateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.clientUpdateObserverToken];
	if (self.scopeUpdateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.scopeUpdateObserverToken];
}

#pragma mark - lifecycle

- (void)start {
	if (!self.started) {
		self.started = YES;
		[self requestAlertPermission];
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		__weak typeof(self) weakSelf = self;
		self.clientUpdateObserverToken = [center
			addObserverForName:TGNotificationUpdateNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf handleClientUpdate:note];
					}];
		self.scopeUpdateObserverToken = [center
			addObserverForName:TGScopeNotificationSettingsDidChangeNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf handleScopeNotificationSettingsChange:note];
					}];
	}

	TGClient *tg = [TGClient shared];
	[tg setOptionNamed:@"notification_group_count_max"
				 value:@(kNotificationGroupCountMax)
			 isBoolean:NO];
	[tg setOptionNamed:@"notification_group_size_max"
				 value:@(kNotificationGroupSizeMax)
			 isBoolean:NO];
}

- (void)requestAlertPermission {
	UIApplication *app = [UIApplication sharedApplication];
	SEL registerSelector = NSSelectorFromString(@"registerUserNotificationSettings:");
	if (![app respondsToSelector:registerSelector])
		return;

	Class settingsClass = NSClassFromString(@"UIUserNotificationSettings");
	SEL buildSelector = NSSelectorFromString(@"settingsForTypes:categories:");
	if (!settingsClass || ![settingsClass respondsToSelector:buildSelector])
		return;

	NSMethodSignature *signature = [settingsClass methodSignatureForSelector:buildSelector];
	if (!signature)
		return;
	NSInvocation *build = [NSInvocation invocationWithMethodSignature:signature];
	build.selector = buildSelector;
	build.target = settingsClass;
	NSUInteger types = (1 << 0) | (1 << 1) | (1 << 2);
	id categories = nil;
	[build setArgument:&types atIndex:2];
	[build setArgument:&categories atIndex:3];
	[build invoke];

	void *raw = NULL;
	[build getReturnValue:&raw];
	id settings = (__bridge id)raw;
	if (!settings)
		return;

	NSMethodSignature *registerSignature = [app methodSignatureForSelector:registerSelector];
	if (!registerSignature)
		return;
	NSInvocation *registration = [NSInvocation invocationWithMethodSignature:registerSignature];
	registration.selector = registerSelector;
	registration.target = app;
	[registration setArgument:&settings atIndex:2];
	[registration invoke];
}

- (void)applicationDidBecomeActive {
	[self flushDeliveredNotifications];
	if (self.haveUnreadCount)
		[self setBadge:[TGSettingsService totalUnreadBadgeCount]];
}

- (void)applicationDidEnterBackground {
	if (self.haveUnreadCount)
		[self setBadge:[TGSettingsService totalUnreadBadgeCount]];
}

#pragma mark - updates

- (void)handleClientUpdate:(NSNotification *)note {
	NSDictionary *update = note.object;
	if (![update isKindOfClass:[NSDictionary class]])
		return;
	NSString *type = TGTDLibTypeOf(update);
	if (!type.length)
		return;

	if ([type isEqualToString:@"updateNotificationGroup"])
		[self applyNotificationGroup:update];
	else if ([type isEqualToString:@"updateActiveNotifications"])
		[self applyActiveNotifications:update[@"groups"]];
	else if ([type isEqualToString:@"updateChatReadInbox"])
		[self applyReadInbox:update];
	else if ([type isEqualToString:@"updateChatNotificationSettings"])
		[self applyChatNotificationSettings:update];
	else if ([type isEqualToString:@"updateUnreadMessageCount"])
		[self applyUnreadMessageCount:update];
}

- (void)applyActiveNotifications:(NSArray *)groups {
	if (![groups isKindOfClass:[NSArray class]])
		return;
	for (NSDictionary *group in groups) {
		if (![group isKindOfClass:[NSDictionary class]])
			continue;
		int64_t chatId = [group[@"chat_id"] longLongValue];
		if (!chatId)
			continue;
		self.chatIdByGroup[@([group[@"id"] integerValue])] = @(chatId);
	}
}

- (void)applyNotificationGroup:(NSDictionary *)update {
	NSInteger groupId = [update[@"notification_group_id"] integerValue];
	int64_t chatId = [update[@"chat_id"] longLongValue];
	int64_t settingsChatId = [update[@"notification_settings_chat_id"] longLongValue];
	if (!settingsChatId)
		settingsChatId = chatId;
	long long soundId = [update[@"notification_sound_id"] longLongValue];

	if (chatId)
		self.chatIdByGroup[@(groupId)] = @(chatId);

	NSArray *removed = update[@"removed_notification_ids"];
	if ([removed isKindOfClass:[NSArray class]] && removed.count)
		[self cancelPendingLocalNotificationsForChat:chatId matchingIds:[NSSet setWithArray:removed]];

	NSArray *added = update[@"added_notifications"];
	if (![added isKindOfClass:[NSArray class]] || !added.count)
		return;

	if ([[TGClient shared] isChatMuted:settingsChatId]) {
		[[TGClient shared] removeNotificationGroup:groupId
								upToNotificationId:NSIntegerMax];
		return;
	}

	for (NSDictionary *notification in added) {
		int32_t topicId = TGForumsTopicIdForNotification(notification);
		if (topicId && [[TGClient shared] isForumTopicMuted:topicId inChat:chatId])
			continue;
		[self presentNotification:notification
							group:groupId
							 chat:chatId
						  soundId:soundId
							batch:added.count];
	}
}

- (void)applyReadInbox:(NSDictionary *)update {
	if ([update[@"unread_count"] integerValue] != 0)
		return;
	[self clearNotificationsForChat:[update[@"chat_id"] longLongValue]];
}

- (void)applyChatNotificationSettings:(NSDictionary *)update {
	NSDictionary *settings = update[@"notification_settings"];
	if (![settings isKindOfClass:[NSDictionary class]])
		return;
	int64_t chatId = [update[@"chat_id"] longLongValue];
	TGClient *tg = [TGClient shared];
	NSMutableDictionary *info = [[tg chatInfoForId:chatId] mutableCopy] ?: [NSMutableDictionary dictionary];
	info[@"chatUseDefaultMuteFor"] = @([settings[@"use_default_mute_for"] boolValue]);
	info[@"chatMuteFor"] = settings[@"mute_for"] ?: @(0);
	if (![tg effectiveMutedForChatInfo:info])
		return;
	[self clearNotificationsForChat:chatId];
}

- (void)handleScopeNotificationSettingsChange:(NSNotification *)note {
	NSString *scope = note.userInfo[@"scope"];
	if (![scope isKindOfClass:[NSString class]])
		return;
	TGClient *tg = [TGClient shared];
	for (NSDictionary *info in [tg.chatsById.allValues copy]) {
		if (![info[@"chatUseDefaultMuteFor"] boolValue])
			continue;
		if (![[tg notificationScopeForChatInfo:info] isEqualToString:scope])
			continue;
		if (![tg effectiveMutedForChatInfo:info])
			continue;
		[self clearNotificationsForChat:[info[@"id"] longLongValue]];
	}
}

- (void)applyUnreadMessageCount:(NSDictionary *)update {
	NSDictionary *list = update[@"chat_list"];
	NSString *listType = TGTDLibTypeOf(list);
	if (![listType isEqualToString:@"chatListMain"] &&
		![listType isEqualToString:@"chatListArchive"])
		return;

	self.unreadByList[listType] = @([update[@"unread_unmuted_count"] integerValue]);

	NSInteger total = 0;
	for (NSNumber *count in [self.unreadByList allValues])
		total += [count integerValue];
	self.unmutedUnread = total < 0 ? 0 : total;
	self.haveUnreadCount = YES;

	if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
		[self setBadge:[TGSettingsService totalUnreadBadgeCount]];
}

#pragma mark - presentation

- (void)presentNotification:(NSDictionary *)notification
					  group:(NSInteger)groupId
					   chat:(int64_t)chatId
					soundId:(long long)soundId
					  batch:(NSUInteger)batchCount {
	if (![notification isKindOfClass:[NSDictionary class]])
		return;

	UIApplication *app = [UIApplication sharedApplication];
	BOOL foreground = app.applicationState == UIApplicationStateActive;
	if (foreground && chatId != 0 && chatId == [TGClient shared].openChatId)
		return;

	NSInteger notificationId = [notification[@"id"] integerValue];
	NSString *key = [NSString stringWithFormat:@"%d:%d", (int)groupId, (int)notificationId];
	if ([self.recentKeySet containsObject:key])
		return;
	[self rememberKey:key];

	if (![self consumeBudget])
		return;

	TGClient *tg = [TGClient shared];
	NSString *chatName = [tg titleForChatId:chatId];
	NSDictionary *alert = [tg alertForNotification:notification chatName:chatName];
	if (!alert)
		return;

	NSDictionary *type = notification[@"type"];
	BOOL locked = foreground ? [[TGPasscodeLock shared] isLocked]
							  : [[TGPasscodeLock shared] isLockedOrWillLockOnReturn];
	BOOL previewHidden = locked ||
		([TGTDLibTypeOf(type) isEqualToString:@"notificationTypeNewMessage"] &&
			![type[@"show_preview"] boolValue]);

	NSString *title = locked ? nil : alert[@"title"];
	NSString *body = alert[@"body"];
	BOOL isAggregate = batchCount >= kNotificationAggregateThreshold;
	if (isAggregate)
		body = TGNotificationAggregateText(batchCount);
	else if (locked)
		body = TGNotificationLockedText();

	NSString *safe = TGNotificationSafeText(body);
	if (!safe.length)
		return;

	NSTimeInterval now = CFAbsoluteTimeGetCurrent();
	if (now < self.aggregateBlockUntil)
		return;
	if (self.lastPresented != 0.0 && now - self.lastPresented < kNotificationMinimumInterval)
		return;
	self.lastPresented = now;
	if (isAggregate)
		self.aggregateBlockUntil = now + kNotificationAggregateBlock;

	if (foreground) {
		BOOL silent = [notification[@"is_silent"] boolValue];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self presentInAppFeedbackChatId:chatId title:title body:safe silent:silent];
		});
		return;
	}

	UILocalNotification *local = [[UILocalNotification alloc] init];
	if (!local)
		return;

	BOOL canShowAlertTitle = [local respondsToSelector:NSSelectorFromString(@"setAlertTitle:")];
	NSString *alertBody = safe;
	if (!isAggregate && !locked && !previewHidden && !canShowAlertTitle &&
			title.length && ![safe hasPrefix:title])
		alertBody = [NSString stringWithFormat:@"%@: %@", title, safe];
	local.alertBody = alertBody;
	local.alertAction = TGL(@"Notification.ViewAction", @"View");
	local.userInfo = @{
		@"chatId" : @(chatId),
		@"groupId" : @(groupId),
		@"notificationId" : @(notificationId),
		@"topicId" : @(TGForumsTopicIdForNotification(notification)),
	};

	NSInteger approximateBadge = [TGSettingsService totalUnreadBadgeCount];
	local.applicationIconBadgeNumber = approximateBadge < 0 ? 0 : approximateBadge;

	NSString *sound = [notification[@"is_silent"] boolValue]
		? nil
		: TGNotificationSoundName(soundId);
	if (sound) {
		if (self.lastSound != 0.0 && now - self.lastSound < kNotificationMinimumSoundInterval)
			sound = nil;
		else
			self.lastSound = now;
	}
	local.soundName = sound;

	if (title.length && canShowAlertTitle)
		[local setValue:title forKey:@"alertTitle"];

	dispatch_async(dispatch_get_main_queue(), ^{
		if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
			[[UIApplication sharedApplication] presentLocalNotificationNow:local];
	});
}

#pragma mark - in-app feedback

- (void)presentInAppFeedbackChatId:(int64_t)chatId
							 title:(NSString *)title
							  body:(NSString *)body
							silent:(BOOL)silent {
	if (!silent) {
		if ([TGInAppNotificationPreferences inAppSoundsEnabled])
			[TGNotificationManager previewToneId:[TGNotificationManager selectedToneId]];
		if ([TGInAppNotificationPreferences inAppVibrateEnabled])
			AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
	}
	if (![TGInAppNotificationPreferences inAppPreviewEnabled])
		return;
	[self showInAppBannerChatId:chatId title:title body:body];
}

- (void)showInAppBannerChatId:(int64_t)chatId title:(NSString *)title body:(NSString *)body {
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	if (!window)
		return;
	[self dismissInAppBanner];

	CGFloat width = window.bounds.size.width;
	CGFloat height = 56.0f;
	TGInAppBannerView *banner = [[TGInAppBannerView alloc] initWithFrame:
			CGRectMake(0, -height, width, height)];
	banner.chatId = chatId;
	banner.backgroundColor = [[TGTheme shared] listBackgroundColour];
	banner.layer.shadowColor = [UIColor blackColor].CGColor;
	banner.layer.shadowOpacity = 0.3f;
	banner.layer.shadowOffset = CGSizeMake(0, 1);
	banner.layer.shadowRadius = 3;

	UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, width - 24, 18)];
	titleLabel.font = [UIFont boldSystemFontOfSize:14];
	titleLabel.textColor = [[TGTheme shared] primaryTextColour];
	titleLabel.backgroundColor = [UIColor clearColor];
	titleLabel.text = title.length ? title : TGL(@"Tour.Title1", @"Telegram");
	[banner addSubview:titleLabel];

	UILabel *bodyLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 26, width - 24, 24)];
	bodyLabel.font = [UIFont systemFontOfSize:13];
	bodyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	bodyLabel.backgroundColor = [UIColor clearColor];
	bodyLabel.numberOfLines = 1;
	bodyLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	bodyLabel.text = body;
	[banner addSubview:bodyLabel];

	[banner addGestureRecognizer:[[UITapGestureRecognizer alloc]
									 initWithTarget:self
											 action:@selector(inAppBannerTapped:)]];
	[window addSubview:banner];
	sInAppBanner = banner;

	CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
	CGFloat statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
	if (statusBarHeight < 1.0f)
		statusBarHeight = 20.0f;

	CGRect resting = banner.frame;
	resting.origin.y = statusBarHeight;
	[UIView animateWithDuration:0.25 animations:^{
		banner.frame = resting;
	}];

	[self performSelector:@selector(dismissInAppBannerIfCurrent:)
			   withObject:banner
			   afterDelay:kInAppBannerSeconds];
}

- (void)dismissInAppBannerIfCurrent:(TGInAppBannerView *)banner {
	if (sInAppBanner == banner)
		[self dismissInAppBanner];
}

- (void)dismissInAppBanner {
	TGInAppBannerView *banner = sInAppBanner;
	if (!banner)
		return;
	sInAppBanner = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(dismissInAppBannerIfCurrent:)
											   object:banner];
	CGRect resting = banner.frame;
	resting.origin.y = -resting.size.height;
	[UIView animateWithDuration:0.2 animations:^{
		banner.frame = resting;
	} completion:^(BOOL done) {
		[banner removeFromSuperview];
	}];
}

- (void)inAppBannerTapped:(UITapGestureRecognizer *)recognizer {
	TGInAppBannerView *banner = (TGInAppBannerView *)recognizer.view;
	int64_t chatId = banner.chatId;
	[self dismissInAppBanner];
	if (!chatId)
		return;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGNotificationManagerDidRequestOpenChatNotification
					  object:self
					userInfo:@{TGNotificationManagerChatIdKey : @(chatId)}];
}

- (BOOL)consumeBudget {
	NSTimeInterval now = CFAbsoluteTimeGetCurrent();
	if (self.budgetWindowStart == 0.0 || now - self.budgetWindowStart >= kNotificationBudgetWindow) {
		self.budgetWindowStart = now;
		self.budgetUsed = 0;
	}
	if (self.budgetUsed >= kNotificationBudgetPerWindow)
		return NO;
	self.budgetUsed++;
	return YES;
}

- (void)rememberKey:(NSString *)key {
	[self.recentKeySet addObject:key];
	[self.recentKeys addObject:key];
	while (self.recentKeys.count > kNotificationRecentKeyLimit) {
		NSString *oldest = [self.recentKeys objectAtIndex:0];
		[self.recentKeySet removeObject:oldest];
		[self.recentKeys removeObjectAtIndex:0];
	}
}

#pragma mark - clearing

- (void)clearNotificationsForChat:(int64_t)chatId {
	if (!chatId)
		return;

	NSMutableArray *groups = [NSMutableArray array];
	for (NSNumber *group in [self.chatIdByGroup allKeys])
		if ([self.chatIdByGroup[group] longLongValue] == chatId)
			[groups addObject:group];

	for (NSNumber *group in groups) {
		[[TGClient shared] removeNotificationGroup:[group integerValue]
								upToNotificationId:NSIntegerMax];
		[self.chatIdByGroup removeObjectForKey:group];
	}

	[self cancelPendingLocalNotificationsForChat:chatId matchingIds:nil];

	if (![TGSettingsService totalUnreadBadgeCount])
		[self flushDeliveredNotifications];
}

- (void)discardEverythingForAccountSwitch {
	UIApplication *app = [UIApplication sharedApplication];
	[app cancelAllLocalNotifications];
	[self.chatIdByGroup removeAllObjects];
	[self.unreadByList removeAllObjects];
	[self setBadge:0];
	NSLog(@"TGNotificationManager: notifications discarded for the account switch");
}

- (void)cancelPendingLocalNotificationsForChat:(int64_t)chatId matchingIds:(NSSet *)notificationIds {
	if (!chatId)
		return;
	UIApplication *app = [UIApplication sharedApplication];
	for (UILocalNotification *scheduled in [app scheduledLocalNotifications]) {
		if ([scheduled.userInfo[@"chatId"] longLongValue] != chatId)
			continue;
		if (notificationIds && ![notificationIds containsObject:scheduled.userInfo[@"notificationId"]])
			continue;
		[app cancelLocalNotification:scheduled];
	}
}

- (void)flushDeliveredNotifications {
	UIApplication *app = [UIApplication sharedApplication];
	if (![UIApplication instancesRespondToSelector:@selector(setApplicationIconBadgeNumber:)])
		return;
	NSArray *scheduled = [app scheduledLocalNotifications];
	app.applicationIconBadgeNumber = 1;
	app.applicationIconBadgeNumber = 0;
	if (scheduled.count)
		[app setScheduledLocalNotifications:scheduled];
}

- (void)setBadge:(NSInteger)count {
	if (![UIApplication instancesRespondToSelector:@selector(setApplicationIconBadgeNumber:)])
		return;
	[UIApplication sharedApplication].applicationIconBadgeNumber = count < 0 ? 0 : count;
}

#pragma mark - taps

- (int64_t)chatIdForLocalNotification:(UILocalNotification *)notification {
	NSDictionary *info = notification.userInfo;
	if (![info isKindOfClass:[NSDictionary class]])
		return 0;
	return [info[@"chatId"] longLongValue];
}

- (int64_t)threadIdForLocalNotification:(UILocalNotification *)notification {
	NSDictionary *info = notification.userInfo;
	if (![info isKindOfClass:[NSDictionary class]])
		return 0;
	return [info[@"topicId"] longLongValue];
}

#pragma mark - tones

+ (NSArray *)builtInToneIds {
	return @[ @0, @3, @4, @5, @6, @7, @8, @9 ];
}

+ (NSArray *)builtInToneNames {
	return @[
		TGL(@"NotificationsSound.Tritone", @"Tri-tone"),
		TGL(@"NotificationsSound.Tremolo", @"Tremolo"),
		TGL(@"NotificationsSound.Alert", @"Alert"),
		TGL(@"NotificationsSound.Bell", @"Bell"),
		TGL(@"NotificationsSound.Calypso", @"Calypso"),
		TGL(@"NotificationsSound.Chime", @"Chime"),
		TGL(@"NotificationsSound.Glass", @"Glass"),
		TGL(@"NotificationsSound.Telegraph", @"Telegraph"),
	];
}

+ (NSString *)nameForToneId:(long long)toneId {
	NSInteger index = [[self builtInToneIds] indexOfObject:@(toneId)];
	if (index == NSNotFound)
		return TGL(@"UserInfo.NotificationsDefault", @"Default");
	return [self builtInToneNames][index];
}

+ (long long)selectedToneId {
	NSNumber *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:[TGAccountManager defaultsKey:TGNotificationToneKey]];
	if (![stored isKindOfClass:[NSNumber class]])
		return TGNotificationToneSystem;
	long long toneId = [stored longLongValue];
	if (![[self builtInToneIds] containsObject:@(toneId)])
		return TGNotificationToneSystem;
	return toneId;
}

+ (void)setSelectedToneId:(long long)toneId {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *key = [TGAccountManager defaultsKey:TGNotificationToneKey];
	if ([[self builtInToneIds] containsObject:@(toneId)])
		[defaults setObject:@(toneId) forKey:key];
	else
		[defaults removeObjectForKey:key];
	[defaults synchronize];
}

+ (void)previewToneId:(long long)toneId {
	NSString *stem = [NSString stringWithFormat:@"%lld", toneId];
	NSString *path = [[NSBundle mainBundle] pathForResource:stem ofType:@"caf"];
	if (!path.length)
		return;

	static SystemSoundID playing = 0;
	if (playing != 0) {
		AudioServicesDisposeSystemSoundID(playing);
		playing = 0;
	}
	NSURL *url = [NSURL fileURLWithPath:path];
	if (AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &playing) != kAudioServicesNoError) {
		playing = 0;
		return;
	}
	AudioServicesPlaySystemSound(playing);
}

@end
