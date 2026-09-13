#import "TGBoosterPageMerge.h"

static NSString *TGBoosterKey(id booster) {
	if (![booster isKindOfClass:[NSDictionary class]])
		return nil;
	id identifier = ((NSDictionary *)booster)[@"id"];
	if ([identifier isKindOfClass:[NSString class]] && ((NSString *)identifier).length)
		return identifier;
	if ([identifier isKindOfClass:[NSNumber class]])
		return [identifier stringValue];
	return nil;
}

NSArray *TGBoostersWithPageAppended(NSArray *existing, NSArray *page) {
	if (![page isKindOfClass:[NSArray class]] || !page.count)
		return nil;
	NSArray *kept = [existing isKindOfClass:[NSArray class]] ? existing : @[];

	NSMutableSet *known = [NSMutableSet set];
	for (id booster in kept) {
		NSString *key = TGBoosterKey(booster);
		if (key)
			[known addObject:key];
	}

	NSMutableArray *fresh = [NSMutableArray array];
	for (id booster in page) {
		if (![booster isKindOfClass:[NSDictionary class]])
			continue;
		NSString *key = TGBoosterKey(booster);
		if (key) {
			if ([known containsObject:key])
				continue;
			[known addObject:key];
		}
		[fresh addObject:booster];
	}
	if (!fresh.count)
		return nil;
	return [kept arrayByAddingObjectsFromArray:fresh];
}
