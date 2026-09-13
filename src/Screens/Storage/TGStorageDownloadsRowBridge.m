#import "TGStorageDownloadsRowBridge.h"
#import "TGStorageDownloadsPresenter.h"
#import "TGStorageDownloadsCellBase.h"
#import "TGStorageDownloadsCellCatalogue.h"

static NSSet<NSNumber *> *TGStorageDownloadsMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet set];
	});
	return migrated;
}

BOOL TGStorageDownloadsRowKindIsMigrated(TGStorageDownloadsRowKind kind) {
	return [TGStorageDownloadsMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGStorageDownloadsRowBridge

- (instancetype)initWithPresenter:(TGStorageDownloadsPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (UITableViewCell *)cellForItem:(TGStorageDownloadsItem *)item inTable:(UITableView *)table {
	if (!item)
		return nil;

	TGStorageDownloadsCellBase *cell = (TGStorageDownloadsCellBase *)
		[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc]
			  initWithStyle:[TGStorageDownloadsCellCatalogue cellStyleForKind:item.kind]
			reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

- (BOOL)ownsEntryRowAtIndex:(NSInteger)row {
	if (row < 0 || row >= self.presenter.numberOfEntryRows)
		return NO;
	return TGStorageDownloadsRowKindIsMigrated([self.presenter itemAtEntryRow:row].kind);
}

- (BOOL)ownsClearRow {
	if (!self.presenter.showsClearRow)
		return NO;
	return TGStorageDownloadsRowKindIsMigrated(TGStorageDownloadsRowKindClear);
}

- (UITableViewCell *)cellForEntryRow:(NSInteger)row inTable:(UITableView *)table {
	return [self cellForItem:[self.presenter itemAtEntryRow:row] inTable:table];
}

- (UITableViewCell *)cellForClearRowInTable:(UITableView *)table {
	return [self cellForItem:[self.presenter clearRowItem] inTable:table];
}

@end
