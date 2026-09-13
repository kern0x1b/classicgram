#import "TGJoinedMemberPageMerge.h"

NSArray *TGJoinedMembersWithPageAppended(NSArray *existing, NSArray *page) {
	if (![page isKindOfClass:[NSArray class]] || !page.count)
		return nil;
	NSArray *kept = [existing isKindOfClass:[NSArray class]] ? existing : @[];

	NSMutableSet *known = [NSMutableSet set];
	for (id member in kept) {
		id userId = [member isKindOfClass:[NSDictionary class]] ? ((NSDictionary *)member)[@"userId"] : nil;
		if ([userId isKindOfClass:[NSNumber class]])
			[known addObject:userId];
	}

	NSMutableArray *fresh = [NSMutableArray array];
	for (id member in page) {
		if (![member isKindOfClass:[NSDictionary class]])
			continue;
		id userId = ((NSDictionary *)member)[@"userId"];
		if ([userId isKindOfClass:[NSNumber class]]) {
			if ([known containsObject:userId])
				continue;
			[known addObject:userId];
		}
		[fresh addObject:member];
	}
	if (!fresh.count)
		return nil;
	return [kept arrayByAddingObjectsFromArray:fresh];
}
