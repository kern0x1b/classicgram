#import "TGSupergroupUsernamesPresenter.h"
#import "TGSupergroupUsernamesItem.h"
#import "TGSupergroupUsernamesItemBuilder.h"
#import "TGLocalization.h"

@implementation TGSupergroupUsernamesPresenter {
	NSArray<TGSupergroupUsernamesItem *> *_activeItems;
	NSArray<TGSupergroupUsernamesItem *> *_disabledItems;
}

- (void)updateWithActive:(NSArray<NSString *> *)active
				disabled:(NSArray<NSString *> *)disabled
		editableUsername:(NSString *)editableUsername {
	NSMutableArray<TGSupergroupUsernamesItem *> *activeItems = [NSMutableArray arrayWithCapacity:active.count];
	for (NSString *username in active) {
		BOOL isEditable = editableUsername.length && [username isEqualToString:editableUsername];
		NSString *badgeText = isEditable ? TGL(@"GroupInfo.PublicLink", @"Public Link") : nil;
		[activeItems addObject:[TGSupergroupUsernamesItemBuilder itemFromUsername:username badgeText:badgeText]];
	}
	_activeItems = activeItems;

	NSMutableArray<TGSupergroupUsernamesItem *> *disabledItems = [NSMutableArray arrayWithCapacity:disabled.count];
	for (NSString *username in disabled)
		[disabledItems addObject:[TGSupergroupUsernamesItemBuilder itemFromUsername:username badgeText:nil]];
	_disabledItems = disabledItems;
}

- (NSInteger)numberOfActiveItems {
	return (NSInteger)_activeItems.count;
}

- (NSInteger)numberOfDisabledItems {
	return (NSInteger)_disabledItems.count;
}

- (TGSupergroupUsernamesItem *)activeItemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_activeItems.count)
		return nil;
	return _activeItems[row];
}

- (TGSupergroupUsernamesItem *)disabledItemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_disabledItems.count)
		return nil;
	return _disabledItems[row];
}

@end
