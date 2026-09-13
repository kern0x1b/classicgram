#import "TGStoryViewersRowBridge.h"
#import "TGStoryViewersPresenter.h"
#import "TGStoryViewerRowCell.h"

static NSSet<NSNumber *> *TGStoryViewersMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet set];
	});
	return migrated;
}

BOOL TGStoryViewersRowKindIsMigrated(TGStoryViewersRowKind kind) {
	return [TGStoryViewersMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGStoryViewersRowBridge

- (instancetype)initWithPresenter:(TGStoryViewersPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGStoryViewersItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGStoryViewersRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGStoryViewersItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGStoryViewerRowCell *cell = (TGStoryViewerRowCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleSubtitle
									 reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
