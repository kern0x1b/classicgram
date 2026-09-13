#import "TGConnectedWebsitesRowBridge.h"
#import "TGConnectedWebsitesPresenter.h"
#import "TGConnectedWebsiteRowCell.h"

static NSSet<NSNumber *> *TGConnectedWebsitesMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet set];
	});
	return migrated;
}

BOOL TGConnectedWebsitesRowKindIsMigrated(TGConnectedWebsitesRowKind kind) {
	return [TGConnectedWebsitesMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGConnectedWebsitesRowBridge

- (instancetype)initWithPresenter:(TGConnectedWebsitesPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGConnectedWebsitesItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGConnectedWebsitesRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGConnectedWebsitesItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGConnectedWebsiteRowCell *cell = (TGConnectedWebsiteRowCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleSubtitle
									 reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
