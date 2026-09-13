#import "TGChatHistoryCache.h"
#import "TGChatHistoryCacheFileName.h"
#import <UIKit/UIKit.h>

static const NSUInteger kChatHistoryCacheChats = 3;

static __strong NSString *gTGChatHistoryCacheScope = nil;

static NSString *TGChatHistoryCachePath(void) {
	NSString *caches = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	return [caches stringByAppendingPathComponent:
			TGChatHistoryCacheFileName(gTGChatHistoryCacheScope)];
}

static NSArray *TGChatHistoryVolatileFileIdKeys(void) {
	return @[ @"photoId", @"docId", @"coverFileId", @"richCoverFileId" ];
}

static id TGChatHistoryMessageWithFileIdsStripped(id message) {
	if (![message isKindOfClass:NSDictionary.class])
		return message;
	NSMutableDictionary *mutable = nil;
	for (NSString *key in TGChatHistoryVolatileFileIdKeys()) {
		if (!((NSDictionary *)message)[key])
			continue;
		if (!mutable)
			mutable = [message mutableCopy];
		[mutable removeObjectForKey:key];
	}
	return mutable ?: message;
}

static id TGChatHistoryPlistSafe(id value) {
	if ([value isKindOfClass:NSDictionary.class]) {
		NSMutableDictionary *out = [NSMutableDictionary dictionary];
		for (id key in value) {
			if (![key isKindOfClass:NSString.class])
				continue;
			id safe = TGChatHistoryPlistSafe(value[key]);
			if (safe)
				out[key] = safe;
		}
		return out;
	}
	if ([value isKindOfClass:NSArray.class]) {
		NSMutableArray *out = [NSMutableArray array];
		for (id item in value) {
			id safe = TGChatHistoryPlistSafe(item);
			if (safe)
				[out addObject:safe];
		}
		return out;
	}
	if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class] ||
		[value isKindOfClass:NSData.class] || [value isKindOfClass:NSDate.class])
		return value;
	return nil;
}

@implementation TGChatHistoryCache {
	NSMutableDictionary *_messagesByKey;
	NSMutableArray *_keysByAge;
	BOOL _persistScheduled;
	id _memoryWarningObserverToken;
	id _didEnterBackgroundObserverToken;
}

+ (instancetype)shared {
	static TGChatHistoryCache *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ shared = [[TGChatHistoryCache alloc] init]; });
	return shared;
}

- (instancetype)init {
	self = [super init];
	if (!self)
		return nil;

	_messagesByKey = [NSMutableDictionary dictionary];
	_keysByAge = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	_memoryWarningObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf clear];
				}];
	_didEnterBackgroundObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf persist];
				}];
	[self load];
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_memoryWarningObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_memoryWarningObserverToken];
	if (_didEnterBackgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_didEnterBackgroundObserverToken];
}

- (NSString *)keyForChat:(int64_t)chatId thread:(int64_t)threadId {
	return [NSString stringWithFormat:@"%lld:%lld", chatId, threadId];
}

- (NSArray *)messagesForChat:(int64_t)chatId thread:(int64_t)threadId {
	return _messagesByKey[[self keyForChat:chatId thread:threadId]];
}

- (void)setMessages:(NSArray *)messages forChat:(int64_t)chatId thread:(int64_t)threadId {
	NSString *key = [self keyForChat:chatId thread:threadId];
	if (!messages.count) {
		[_messagesByKey removeObjectForKey:key];
		[_keysByAge removeObject:key];
		return;
	}

	_messagesByKey[key] = messages;
	[_keysByAge removeObject:key];
	[_keysByAge addObject:key];
	[self schedulePersist];

	while (_keysByAge.count > kChatHistoryCacheChats) {
		NSString *oldest = _keysByAge[0];
		[_keysByAge removeObjectAtIndex:0];
		[_messagesByKey removeObjectForKey:oldest];
	}
}

- (void)clear {
	[_messagesByKey removeAllObjects];
	[_keysByAge removeAllObjects];
}

- (void)setAccountScope:(NSString *)accountScope {
	NSString *next = accountScope.length ? [accountScope copy] : nil;
	if (next == gTGChatHistoryCacheScope || [next isEqualToString:gTGChatHistoryCacheScope])
		return;
	[self persist];
	[self clear];
	gTGChatHistoryCacheScope = next;
	[self load];
}

- (void)load {
	NSDictionary *stored = [NSDictionary dictionaryWithContentsOfFile:TGChatHistoryCachePath()];
	for (NSString *key in stored) {
		NSArray *messages = stored[key];
		if (![key isKindOfClass:NSString.class] || ![messages isKindOfClass:NSArray.class])
			continue;
		if (_keysByAge.count >= kChatHistoryCacheChats)
			break;
		NSMutableArray *sanitized = [NSMutableArray arrayWithCapacity:messages.count];
		for (id message in messages)
			[sanitized addObject:TGChatHistoryMessageWithFileIdsStripped(message)];
		_messagesByKey[key] = sanitized;
		[_keysByAge addObject:key];
	}
}

- (void)schedulePersist {
	if (_persistScheduled)
		return;
	_persistScheduled = YES;
	__weak TGChatHistoryCache *weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatHistoryCache *strongSelf = weakSelf;
			strongSelf->_persistScheduled = NO;
			[strongSelf persist];
		});
}

- (void)persist {
	NSString *path = TGChatHistoryCachePath();
	if (!_messagesByKey.count) {
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		return;
	}

	NSMutableDictionary *safe = [NSMutableDictionary dictionary];
	for (NSString *key in _messagesByKey) {
		id messages = TGChatHistoryPlistSafe(_messagesByKey[key]);
		if (messages)
			safe[key] = messages;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		if (![safe writeToFile:path atomically:YES])
			return;
		[[NSFileManager defaultManager] setAttributes:
				@{NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication}
										 ofItemAtPath:path
												error:nil];
	});
}

@end
