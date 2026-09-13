#import "TGGroupMembersRowBridge.h"
#import "TGGroupMembersPresenter.h"
#import "TGGroupMemberCell.h"

static NSSet<NSNumber *> *TGGroupMembersMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet setWithObject:@(TGGroupMembersRowKindMember)];
	});
	return migrated;
}

BOOL TGGroupMembersRowKindIsMigrated(TGGroupMembersRowKind kind) {
	return [TGGroupMembersMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGGroupMembersRowBridge

- (instancetype)initWithPresenter:(TGGroupMembersPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGGroupMembersItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGGroupMembersRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGGroupMembersItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGGroupMemberCell *cell = (TGGroupMemberCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	UIImage *avatar = nil;
	if ([self.delegate respondsToSelector:@selector(groupMembersRowBridge:avatarForUserId:)])
		avatar = [self.delegate groupMembersRowBridge:self avatarForUserId:item.userId];

	[cell applyItem:item avatar:avatar];

	return cell;
}

@end
