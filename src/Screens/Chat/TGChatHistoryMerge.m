#import "TGChatHistoryMerge.h"

static NSNumber *TGHistoryMessageId(id message) {
	if (![message isKindOfClass:[NSDictionary class]])
		return nil;
	id identifier = ((NSDictionary *)message)[@"id"];
	return [identifier isKindOfClass:[NSNumber class]] ? identifier : nil;
}

NSArray *TGHistoryWithOlderPagePrepended(NSArray *existing,
	NSArray *incoming,
	long long anchorMessageId) {
	if (![incoming isKindOfClass:[NSArray class]] || !incoming.count)
		return nil;
	NSArray *kept = [existing isKindOfClass:[NSArray class]] ? existing : @[];

	NSMutableSet *known = [NSMutableSet set];
	for (id message in kept) {
		NSNumber *identifier = TGHistoryMessageId(message);
		if (identifier)
			[known addObject:identifier];
	}

	NSMutableArray *older = [NSMutableArray array];
	for (id message in incoming) {
		NSNumber *identifier = TGHistoryMessageId(message);
		if (!identifier || [known containsObject:identifier])
			continue;
		if (anchorMessageId != 0 && identifier.longLongValue >= anchorMessageId)
			continue;
		[known addObject:identifier];
		[older addObject:message];
	}
	if (!older.count)
		return nil;

	[older sortUsingComparator:^NSComparisonResult(id left, id right) {
		long long a = TGHistoryMessageId(left).longLongValue;
		long long b = TGHistoryMessageId(right).longLongValue;
		if (a == b)
			return NSOrderedSame;
		return a < b ? NSOrderedAscending : NSOrderedDescending;
	}];
	return [older arrayByAddingObjectsFromArray:kept];
}
