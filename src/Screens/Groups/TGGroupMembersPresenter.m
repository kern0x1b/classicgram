#import "TGGroupMembersPresenter.h"
#import "TGGroupMembersItem.h"
#import "TGGroupMembersItemBuilder.h"

@implementation TGGroupMembersPresenter {
	NSArray<TGGroupMembersItem *> *_items;
}

- (void)updateWithMembers:(NSArray *)members {
	NSMutableArray<TGGroupMembersItem *> *items = [NSMutableArray arrayWithCapacity:members.count];
	for (NSDictionary *member in members) {
		if (![member isKindOfClass:NSDictionary.class])
			continue;
		[items addObject:[TGGroupMembersItemBuilder itemFromMember:member]];
	}
	_items = items;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGGroupMembersItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

@end
