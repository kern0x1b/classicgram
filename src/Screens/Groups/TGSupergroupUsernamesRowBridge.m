#import "TGSupergroupUsernamesRowBridge.h"
#import "TGSupergroupUsernamesPresenter.h"
#import "TGSupergroupUsernameRowCell.h"

static NSSet<NSNumber *> *TGSupergroupUsernamesMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet set];
	});
	return migrated;
}

BOOL TGSupergroupUsernamesRowKindIsMigrated(TGSupergroupUsernamesRowKind kind) {
	return [TGSupergroupUsernamesMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGSupergroupUsernamesRowBridge

- (instancetype)initWithPresenter:(TGSupergroupUsernamesPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (TGSupergroupUsernamesItem *)itemAtRow:(NSInteger)row inSection:(TGSupergroupUsernamesRowSection)section {
	return section == TGSupergroupUsernamesRowSectionActive
		? [self.presenter activeItemAtRow:row]
		: [self.presenter disabledItemAtRow:row];
}

- (BOOL)ownsRowAtIndex:(NSInteger)row inSection:(TGSupergroupUsernamesRowSection)section {
	TGSupergroupUsernamesItem *item = [self itemAtRow:row inSection:section];
	if (!item)
		return NO;
	return TGSupergroupUsernamesRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row
					  inSection:(TGSupergroupUsernamesRowSection)section
						inTable:(UITableView *)table {
	TGSupergroupUsernamesItem *item = [self itemAtRow:row inSection:section];
	if (!item)
		return nil;

	TGSupergroupUsernameRowCell *cell = (TGSupergroupUsernameRowCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
