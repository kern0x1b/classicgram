#import "TGAccountUsernamesRowBridge.h"
#import "TGAccountUsernamesPresenter.h"
#import "TGAccountUsernameRowCell.h"

static NSSet<NSNumber *> *TGAccountUsernamesMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet setWithObject:@(TGAccountUsernamesRowKindUsername)];
	});
	return migrated;
}

BOOL TGAccountUsernamesRowKindIsMigrated(TGAccountUsernamesRowKind kind) {
	return [TGAccountUsernamesMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGAccountUsernamesRowBridge

- (instancetype)initWithPresenter:(TGAccountUsernamesPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (TGAccountUsernamesItem *)itemAtRow:(NSInteger)row inSection:(TGAccountUsernamesRowSection)section {
	return section == TGAccountUsernamesRowSectionActive
		? [self.presenter activeItemAtRow:row]
		: [self.presenter disabledItemAtRow:row];
}

- (BOOL)ownsRowAtIndex:(NSInteger)row inSection:(TGAccountUsernamesRowSection)section {
	TGAccountUsernamesItem *item = [self itemAtRow:row inSection:section];
	if (!item)
		return NO;
	return TGAccountUsernamesRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row
					  inSection:(TGAccountUsernamesRowSection)section
						inTable:(UITableView *)table {
	TGAccountUsernamesItem *item = [self itemAtRow:row inSection:section];
	if (!item)
		return nil;

	TGAccountUsernameRowCell *cell = (TGAccountUsernameRowCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
