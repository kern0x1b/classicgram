#import "TGPaidReactors.h"

static NSInteger TGPaidReactorStars(NSDictionary *reactor) {
	id stars = reactor[@"stars"];
	return [stars respondsToSelector:@selector(integerValue)] ? [stars integerValue] : 0;
}

static NSString *TGPaidReactorName(NSDictionary *reactor) {
	NSString *name = reactor[@"name"];
	return [name isKindOfClass:NSString.class] ? name : @"";
}

NSArray *TGPaidReactorsRanked(NSArray *reactors) {
	if (![reactors isKindOfClass:NSArray.class])
		return @[];

	NSMutableArray *usable = [NSMutableArray array];
	for (id raw in reactors) {
		if (![raw isKindOfClass:NSDictionary.class])
			continue;
		if (TGPaidReactorStars(raw) <= 0)
			continue;
		[usable addObject:raw];
	}

	[usable sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
		NSInteger leftStars = TGPaidReactorStars(left);
		NSInteger rightStars = TGPaidReactorStars(right);
		if (leftStars != rightStars)
			return leftStars > rightStars ? NSOrderedAscending : NSOrderedDescending;
		BOOL leftAnonymous = [left[@"isAnonymous"] boolValue];
		BOOL rightAnonymous = [right[@"isAnonymous"] boolValue];
		if (leftAnonymous != rightAnonymous)
			return leftAnonymous ? NSOrderedDescending : NSOrderedAscending;
		return [TGPaidReactorName(left) localizedCaseInsensitiveCompare:TGPaidReactorName(right)];
	}];
	return [usable copy];
}

NSInteger TGPaidReactorsTotalStars(NSArray *reactors) {
	if (![reactors isKindOfClass:NSArray.class])
		return 0;
	NSInteger total = 0;
	for (id raw in reactors) {
		if (![raw isKindOfClass:NSDictionary.class])
			continue;
		NSInteger stars = TGPaidReactorStars(raw);
		if (stars > 0)
			total += stars;
	}
	return total;
}

NSString *TGPaidReactorsStarText(NSInteger stars) {
	if (stars <= 0)
		return @"";
	return [NSString stringWithFormat:@"%d ⭐", (int)stars];
}
