#import "TGStarsListRowBridge.h"
#import "TGStarsListPresenter.h"
#import "TGStarsListCellBase.h"
#import "TGStarsListCellCatalogue.h"

static NSSet<NSNumber *> *TGStarsListMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet set];
	});
	return migrated;
}

BOOL TGStarsListRowKindIsMigrated(TGStarsListRowKind kind) {
	return [TGStarsListMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGStarsListRowBridge

- (instancetype)initWithPresenter:(TGStarsListPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGStarsListItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGStarsListRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGStarsListItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGStarsListCellBase *cell = (TGStarsListCellBase *)
		[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc]
			  initWithStyle:[TGStarsListCellCatalogue cellStyleForKind:item.kind]
			reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
