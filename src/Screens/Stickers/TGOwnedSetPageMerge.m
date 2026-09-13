#import "TGOwnedSetPageMerge.h"

static NSString *TGOwnedSetKey(id set) {
	if (![set isKindOfClass:[NSDictionary class]])
		return nil;
	id identifier = ((NSDictionary *)set)[@"id"];
	if ([identifier isKindOfClass:[NSString class]] && ((NSString *)identifier).length)
		return identifier;
	if ([identifier isKindOfClass:[NSNumber class]])
		return [identifier stringValue];
	return nil;
}

NSArray *TGOwnedSetsWithPageAppended(NSArray *existing, NSArray *page) {
	if (![page isKindOfClass:[NSArray class]] || !page.count)
		return nil;
	NSArray *kept = [existing isKindOfClass:[NSArray class]] ? existing : @[];

	NSMutableSet *known = [NSMutableSet set];
	for (id set in kept) {
		NSString *key = TGOwnedSetKey(set);
		if (key)
			[known addObject:key];
	}

	NSMutableArray *fresh = [NSMutableArray array];
	for (id set in page) {
		if (![set isKindOfClass:[NSDictionary class]])
			continue;
		NSString *key = TGOwnedSetKey(set);
		if (key) {
			if ([known containsObject:key])
				continue;
			[known addObject:key];
		}
		[fresh addObject:set];
	}
	if (!fresh.count)
		return nil;
	return [kept arrayByAddingObjectsFromArray:fresh];
}
