#import "TGQuoteEntitySelection.h"

NSArray *TGQuoteEntitiesForSelectedRange(NSArray *entities, NSRange range) {
	if (![entities isKindOfClass:NSArray.class] || range.length == 0)
		return @[];

	NSInteger selectionStart = (NSInteger)range.location;
	NSInteger selectionEnd = (NSInteger)NSMaxRange(range);
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *entity in entities) {
		if (![entity isKindOfClass:NSDictionary.class])
			continue;

		NSInteger entityStart = [entity[@"offset"] integerValue];
		NSInteger entityEnd = entityStart + [entity[@"length"] integerValue];
		NSInteger overlapStart = MAX(entityStart, selectionStart);
		NSInteger overlapEnd = MIN(entityEnd, selectionEnd);
		if (overlapEnd <= overlapStart)
			continue;

		NSMutableDictionary *shifted = [entity mutableCopy];
		shifted[@"offset"] = @(overlapStart - selectionStart);
		shifted[@"length"] = @(overlapEnd - overlapStart);
		[out addObject:shifted];
	}
	return out;
}
