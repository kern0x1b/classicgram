#import "TGChatLayoutBridge.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGMessageLayoutCache.h"
#import "TGChatLayoutContext.h"
#import "TGMessageRowCell.h"

@implementation TGChatLayoutBridge {
	NSMutableDictionary<NSNumber *, TGMessageItem *> *_itemsByRow;
	TGMessageLayoutCache *_cache;
}

- (instancetype)initWithContext:(TGChatLayoutContext *)context {
	self = [super init];
	if (!self)
		return nil;

	_context = context;
	_itemsByRow = [NSMutableDictionary dictionary];
	_cache = [[TGMessageLayoutCache alloc] initWithCapacity:240];
	return self;
}

- (void)setItem:(TGMessageItem *)item forRow:(NSInteger)row {
	_itemsByRow[@(row)] = item;
}

- (void)removeAllItems {
	[_itemsByRow removeAllObjects];
}

- (CGFloat)heightForRow:(NSInteger)row {
	TGMessageItem *item = _itemsByRow[@(row)];
	if (!item)
		return 0;
	return [_cache layoutForItem:item context:self.context].height;
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGMessageItem *item = _itemsByRow[@(row)];
	if (!item)
		return nil;

	TGMessageLayout *layout = [_cache layoutForItem:item context:self.context];
	TGMessageRowCell *cell = [table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell) {
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];
		if ([self.delegate respondsToSelector:@selector(attachInteractionsToRowCell:)])
			[self.delegate attachInteractionsToRowCell:cell];
	}
	if ([self.delegate respondsToSelector:@selector(resetRowCellSwipeIfNeeded:)])
		[self.delegate resetRowCellSwipeIfNeeded:cell];

	cell.delegate = self.delegate;
	cell.appliedRow = row;
	[cell applyItem:item layout:layout];
	if ([self.delegate respondsToSelector:@selector(configureBitmapsForCell:atRow:)])
		[self.delegate configureBitmapsForCell:cell atRow:row];
	[self.selectionDelegate configureSelectionForCell:cell atRow:row];

	return cell;
}

- (NSString *)cacheCountsDescription {
	NSUInteger hits = _cache.hitCount;
	NSUInteger misses = _cache.missCount;
	NSUInteger total = hits + misses;
	NSUInteger percent = total ? (hits * 100) / total : 0;
	return [NSString stringWithFormat:@"hits=%lu misses=%lu evicted=%lu hit=%lu%%",
		(unsigned long)hits, (unsigned long)misses, (unsigned long)_cache.evictionCount,
		(unsigned long)percent];
}

- (void)resetCacheCounts {
	[_cache resetCounts];
}

- (void)invalidateMessageId:(int64_t)messageId {
	[_cache invalidateMessageId:messageId];
}

@end
