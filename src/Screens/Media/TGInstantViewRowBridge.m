#import "TGInstantViewRowBridge.h"
#import "TGInstantViewPresenter.h"
#import "TGInstantViewCellBase.h"

static NSSet<NSNumber *> *TGInstantViewMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet set];
	});
	return migrated;
}

BOOL TGInstantViewRowKindIsMigrated(TGInstantViewRowKind kind) {
	return [TGInstantViewMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGInstantViewRowBridge

- (instancetype)initWithPresenter:(TGInstantViewPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGInstantViewItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGInstantViewRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGInstantViewItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGInstantViewCellBase *cell = (TGInstantViewCellBase *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	UIImage *image = nil;
	if (item.kind == TGInstantViewRowKindMedia && item.photoFileId != 0 &&
		[self.delegate respondsToSelector:@selector(instantViewRowBridge:imageForFileId:)])
		image = [self.delegate instantViewRowBridge:self imageForFileId:item.photoFileId];

	[cell applyItem:item image:image];

	return cell;
}

@end
