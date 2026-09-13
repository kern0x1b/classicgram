#import "TGFlattenHistory.h"

NSArray *TGHistoryOldestFirst(NSArray *newestFirst, NSInteger limit) {
	NSArray *kept = newestFirst;
	if (limit > 0 && (NSInteger)kept.count > limit)
		kept = [kept subarrayWithRange:NSMakeRange(0, (NSUInteger)limit)];
	return [[kept reverseObjectEnumerator] allObjects];
}

NSArray *TGMergeRawMessages(NSArray *first, NSArray *second) {
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:first.count + second.count];
	NSMutableSet *seenIds = [NSMutableSet setWithCapacity:first.count + second.count];
	for (NSArray *batch in @[ first, second ]) {
		for (NSDictionary *m in batch) {
			NSNumber *mid = [m isKindOfClass:NSDictionary.class] ? m[@"id"] : nil;
			if (!mid || [seenIds containsObject:mid])
				continue;
			[seenIds addObject:mid];
			[out addObject:m];
		}
	}
	[out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		int64_t ia = [a[@"id"] longLongValue], ib = [b[@"id"] longLongValue];
		if (ia == ib)
			return NSOrderedSame;
		return ia > ib ? NSOrderedAscending : NSOrderedDescending;
	}];
	return out;
}
