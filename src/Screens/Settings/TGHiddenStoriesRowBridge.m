#import "TGHiddenStoriesRowBridge.h"
#import "TGHiddenStoriesPresenter.h"
#import "TGHiddenStoriesPosterCell.h"

static NSSet<NSNumber *> *TGHiddenStoriesMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet set];
	});
	return migrated;
}

BOOL TGHiddenStoriesRowKindIsMigrated(TGHiddenStoriesRowKind kind) {
	return [TGHiddenStoriesMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGHiddenStoriesRowBridge

- (instancetype)initWithPresenter:(TGHiddenStoriesPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGHiddenStoriesItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGHiddenStoriesRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGHiddenStoriesItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGHiddenStoriesPosterCell *cell = (TGHiddenStoriesPosterCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
