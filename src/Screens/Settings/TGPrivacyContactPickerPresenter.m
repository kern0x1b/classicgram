#import "TGPrivacyContactPickerPresenter.h"
#import "TGPrivacyContactPickerItem.h"
#import "TGPrivacyContactPickerItemBuilder.h"

@implementation TGPrivacyContactPickerPresenter {
	NSArray<TGPrivacyContactPickerItem *> *_items;
}

- (void)updateWithContacts:(NSArray *)contacts chosen:(NSArray *)chosen {
	NSMutableArray<TGPrivacyContactPickerItem *> *items = [NSMutableArray arrayWithCapacity:contacts.count];
	for (NSDictionary *user in contacts)
		[items addObject:[TGPrivacyContactPickerItemBuilder itemFromUser:user chosen:chosen]];
	_items = items;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGPrivacyContactPickerItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

@end
