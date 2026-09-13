#import "TGConnectedWebsitesPresenter.h"
#import "TGConnectedWebsitesItem.h"
#import "TGConnectedWebsitesItemBuilder.h"

@implementation TGConnectedWebsitesPresenter {
	NSArray<TGConnectedWebsitesItem *> *_items;
}

- (void)updateWithSites:(NSArray *)sites {
	NSMutableArray<TGConnectedWebsitesItem *> *items = [NSMutableArray arrayWithCapacity:sites.count];
	for (NSDictionary *site in sites)
		[items addObject:[TGConnectedWebsitesItemBuilder itemFromSite:site]];
	_items = items;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGConnectedWebsitesItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

@end
