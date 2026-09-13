#import "TGOwnedSetsPresenter.h"
#import "TGOwnedSetsItem.h"
#import "TGOwnedSetsItemBuilder.h"

@implementation TGOwnedSetsPresenter {
	NSArray *_sets;
}

- (void)updateWithSets:(NSArray *)sets {
	_sets = sets ?: @[];
}

- (NSInteger)numberOfSets {
	return (NSInteger)_sets.count;
}

- (TGOwnedSetsItem *)createRowItem {
	return [TGOwnedSetsItemBuilder itemForCreateRow];
}

- (TGOwnedSetsItem *)itemAtSetRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_sets.count)
		return nil;
	return [TGOwnedSetsItemBuilder itemFromSet:_sets[row]];
}

@end
