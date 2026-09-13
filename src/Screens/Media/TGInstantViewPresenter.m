#import "TGInstantViewPresenter.h"
#import "TGInstantViewController.h"
#import "TGInstantViewItem.h"
#import "TGInstantViewItemBuilder.h"

@implementation TGInstantViewPresenter {
	NSArray<TGInstantViewItem *> *_items;
}

- (void)updateWithBlocks:(NSArray *)blocks width:(CGFloat)width {
	NSMutableArray<TGInstantViewItem *> *items = [NSMutableArray arrayWithCapacity:blocks.count];
	for (NSDictionary *block in blocks) {
		CGFloat height = [TGInstantViewController heightForBlock:block width:width];
		[items addObject:[TGInstantViewItemBuilder itemFromBlock:block height:height width:width]];
	}
	_items = items;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGInstantViewItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

@end
