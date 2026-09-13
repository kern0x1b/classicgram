#import "TGMessageLayoutCache.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessageLayoutBuilder.h"
#import "TGMessageLayout.h"
#import "TGCacheTrim.h"

@interface TGMessageLayoutCacheEntry : NSObject

@property (nonatomic, strong) TGMessageItem *item;
@property (nonatomic, assign) TGMessageFingerprint fingerprint;
@property (nonatomic, strong) TGMessageLayout *layout;
@property (nonatomic, assign) uint64_t lastAccessTick;

@end

@implementation TGMessageLayoutCacheEntry
@end

@implementation TGMessageLayoutCache {
	NSUInteger _capacity;
	NSMutableDictionary<NSNumber *, TGMessageLayoutCacheEntry *> *_entriesByMessageId;
	uint64_t _tick;
	NSUInteger _hitCount;
	NSUInteger _missCount;
	NSUInteger _evictionCount;
}

- (instancetype)initWithCapacity:(NSUInteger)capacity {
	self = [super init];
	if (!self)
		return nil;

	_capacity = capacity;
	_entriesByMessageId = [NSMutableDictionary dictionary];
	_tick = 0;
	return self;
}

- (void)tg_evictIfNeeded {
	if (_entriesByMessageId.count <= _capacity)
		return;

	NSUInteger keep = _capacity - _capacity / 4;
	NSArray *oldestFirst = [_entriesByMessageId keysSortedByValueUsingComparator:
		^NSComparisonResult(TGMessageLayoutCacheEntry *left, TGMessageLayoutCacheEntry *right) {
			if (left.lastAccessTick < right.lastAccessTick)
				return NSOrderedAscending;
			if (left.lastAccessTick > right.lastAccessTick)
				return NSOrderedDescending;
			return NSOrderedSame;
		}];
	NSArray *stale = TGCacheTrimKeys(oldestFirst, keep, keep);
	_evictionCount += stale.count;
	[_entriesByMessageId removeObjectsForKeys:stale];
}

- (TGMessageLayout *)layoutForItem:(TGMessageItem *)item
						   context:(TGChatLayoutContext *)context {
	NSNumber *key = @(item.messageId);
	TGMessageFingerprint fingerprint =
		TGMessageFingerprintWithContextGeneration(item.fingerprint, context.generation);

	TGMessageLayoutCacheEntry *entry = _entriesByMessageId[key];
	if (entry && TGMessageFingerprintEqual(entry.fingerprint, fingerprint)) {
		entry.lastAccessTick = ++_tick;
		_hitCount += 1;
		return entry.layout;
	}
	_missCount += 1;

	TGMessageLayout *layout = [TGMessageLayoutBuilder layoutForItem:item context:context];

	TGMessageLayoutCacheEntry *fresh = [[TGMessageLayoutCacheEntry alloc] init];
	fresh.item = item;
	fresh.fingerprint = fingerprint;
	fresh.layout = layout;
	fresh.lastAccessTick = ++_tick;
	_entriesByMessageId[key] = fresh;

	[self tg_evictIfNeeded];
	return layout;
}

- (NSUInteger)hitCount {
	return _hitCount;
}

- (NSUInteger)missCount {
	return _missCount;
}

- (NSUInteger)evictionCount {
	return _evictionCount;
}

- (void)resetCounts {
	_hitCount = 0;
	_missCount = 0;
	_evictionCount = 0;
}

- (void)invalidateMessageId:(int64_t)messageId {
	[_entriesByMessageId removeObjectForKey:@(messageId)];
}

@end
