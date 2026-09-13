#import "TGHiddenStoriesPresenter.h"
#import "TGHiddenStoriesItem.h"
#import "TGHiddenStoriesItemBuilder.h"

@implementation TGHiddenStoriesPresenter {
	NSArray<TGHiddenStoriesItem *> *_items;
}

- (void)updateWithPosters:(NSArray *)posters {
	NSMutableArray<TGHiddenStoriesItem *> *items = [NSMutableArray arrayWithCapacity:posters.count];
	for (NSDictionary *poster in posters)
		[items addObject:[TGHiddenStoriesItemBuilder itemFromPoster:poster]];
	_items = items;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGHiddenStoriesItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

@end
