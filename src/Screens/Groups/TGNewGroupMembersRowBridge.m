#import "TGNewGroupMembersRowBridge.h"
#import "TGNewGroupMembersPresenter.h"
#import "TGNewGroupMemberRowCell.h"

static NSSet<NSNumber *> *TGNewGroupMembersMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet setWithObject:@(TGNewGroupMembersRowKindContact)];
	});
	return migrated;
}

BOOL TGNewGroupMembersRowKindIsMigrated(TGNewGroupMembersRowKind kind) {
	return [TGNewGroupMembersMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGNewGroupMembersRowBridge

- (instancetype)initWithPresenter:(TGNewGroupMembersPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGNewGroupMembersItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGNewGroupMembersRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGNewGroupMembersItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGNewGroupMemberRowCell *cell = (TGNewGroupMemberRowCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
