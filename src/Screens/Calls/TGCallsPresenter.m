#import "TGCallsPresenter.h"
#import "TGCallsItem.h"
#import "TGCallsItemBuilder.h"

@implementation TGCallsPresenter {
	NSArray<TGCallsItem *> *_items;
}

- (void)updateWithGroups:(NSArray *)groups {
	NSMutableArray<TGCallsItem *> *items = [NSMutableArray arrayWithCapacity:groups.count];
	for (NSDictionary *group in groups) {
		if (![group isKindOfClass:NSDictionary.class])
			continue;
		[items addObject:[TGCallsItemBuilder itemFromGroup:group]];
	}
	_items = items;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGCallsItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

@end
