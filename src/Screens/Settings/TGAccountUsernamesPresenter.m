#import "TGAccountUsernamesPresenter.h"
#import "TGAccountUsernamesItem.h"
#import "TGAccountUsernamesItemBuilder.h"

@implementation TGAccountUsernamesPresenter {
	NSArray<TGAccountUsernamesItem *> *_activeItems;
	NSArray<TGAccountUsernamesItem *> *_disabledItems;
}

- (void)updateWithActive:(NSArray<NSString *> *)active
				disabled:(NSArray<NSString *> *)disabled
		editableUsername:(NSString *)editableUsername {
	NSMutableArray<TGAccountUsernamesItem *> *activeItems = [NSMutableArray arrayWithCapacity:active.count];
	for (NSString *username in active) {
		BOOL isEditable = editableUsername.length && [username isEqualToString:editableUsername];
		TGAccountUsernamesItem *activeItem = [TGAccountUsernamesItemBuilder itemFromUsername:username showsEditableBadge:isEditable];
		[activeItems addObject:activeItem];
	}
	_activeItems = activeItems;

	NSMutableArray<TGAccountUsernamesItem *> *disabledItems = [NSMutableArray arrayWithCapacity:disabled.count];
	for (NSString *username in disabled) {
		TGAccountUsernamesItem *disabledItem = [TGAccountUsernamesItemBuilder itemFromUsername:username showsEditableBadge:NO];
		[disabledItems addObject:disabledItem];
	}
	_disabledItems = disabledItems;
}

- (NSInteger)numberOfActiveItems {
	return (NSInteger)_activeItems.count;
}

- (NSInteger)numberOfDisabledItems {
	return (NSInteger)_disabledItems.count;
}

- (TGAccountUsernamesItem *)activeItemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_activeItems.count)
		return nil;
	return _activeItems[row];
}

- (TGAccountUsernamesItem *)disabledItemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_disabledItems.count)
		return nil;
	return _disabledItems[row];
}

@end
