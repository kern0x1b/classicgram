#import "TGStoryViewersPresenter.h"
#import "TGStoryViewersItem.h"
#import "TGStoryViewersItemBuilder.h"

@implementation TGStoryViewersPresenter {
	NSArray<TGStoryViewersItem *> *_items;
}

- (void)updateWithRows:(NSArray *)rows {
	NSMutableArray<TGStoryViewersItem *> *items = [NSMutableArray arrayWithCapacity:rows.count];
	for (NSDictionary *row in rows)
		[items addObject:[TGStoryViewersItemBuilder itemFromRow:row]];
	_items = items;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGStoryViewersItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

@end
