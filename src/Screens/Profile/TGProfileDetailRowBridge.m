#import "TGProfileDetailRowBridge.h"
#import "TGProfileDetailPresenter.h"
#import "TGProfileDetailCell.h"
#import "TGProfileDetailItem.h"

static NSSet<NSNumber *> *TGProfileDetailMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet setWithObject:@(TGProfileDetailRowKindPlain)];
	});
	return migrated;
}

BOOL TGProfileDetailRowKindIsMigrated(TGProfileDetailRowKind kind) {
	return [TGProfileDetailMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGProfileDetailRowBridge

- (instancetype)initWithPresenter:(TGProfileDetailPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGProfileDetailItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGProfileDetailRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGProfileDetailItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGProfileDetailCell *cell = (TGProfileDetailCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
