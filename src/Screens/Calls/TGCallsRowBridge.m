#import "TGCallsRowBridge.h"
#import "TGCallsPresenter.h"
#import "TGCallListCell.h"

static NSSet<NSNumber *> *TGCallsMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet setWithObject:@(TGCallsRowKindGroup)];
	});
	return migrated;
}

BOOL TGCallsRowKindIsMigrated(TGCallsRowKind kind) {
	return [TGCallsMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGCallsRowBridge

- (instancetype)initWithPresenter:(TGCallsPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGCallsItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGCallsRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGCallsItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGCallListCell *cell = (TGCallListCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	UIImage *avatar = nil;
	if (item.avatarKey && [self.delegate respondsToSelector:@selector(callsRowBridge:avatarForKey:)])
		avatar = [self.delegate callsRowBridge:self avatarForKey:item.avatarKey];

	[cell applyItem:item avatar:avatar];

	return cell;
}

@end
