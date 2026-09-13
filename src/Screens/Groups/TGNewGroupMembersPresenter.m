#import "TGNewGroupMembersPresenter.h"
#import "TGNewGroupMembersItem.h"
#import "TGNewGroupMembersItemBuilder.h"

@implementation TGNewGroupMembersPresenter {
	NSArray<TGNewGroupMembersItem *> *_items;
}

- (void)updateWithContacts:(NSArray *)contacts
					titles:(NSArray<NSString *> *)titles
				  selected:(NSArray *)selected {
	NSMutableArray<TGNewGroupMembersItem *> *items = [NSMutableArray arrayWithCapacity:contacts.count];
	[contacts enumerateObjectsUsingBlock:^(NSDictionary *user, NSUInteger idx, BOOL *stop) {
		NSString *titleText = idx < titles.count ? titles[idx] : @"";
		TGNewGroupMembersItem *item =
			[TGNewGroupMembersItemBuilder itemFromUser:user titleText:titleText selected:selected];
		[items addObject:item];
	}];
	_items = items;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGNewGroupMembersItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

@end
