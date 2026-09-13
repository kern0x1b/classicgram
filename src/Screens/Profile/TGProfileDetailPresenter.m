#import "TGProfileDetailPresenter.h"
#import "TGProfileDetailItem.h"
#import "TGProfileDetailItemBuilder.h"

@implementation TGProfileDetailPresenter {
	NSArray<TGProfileDetailItem *> *_items;
}

- (instancetype)init {
	self = [super init];
	if (!self)
		return nil;

	_items = @[];
	return self;
}

- (NSInteger)numberOfItems {
	return (NSInteger)_items.count;
}

- (TGProfileDetailItem *)itemAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)_items.count)
		return nil;
	return _items[row];
}

- (void)updateDetails:(NSArray *)details isSongPlaying:(BOOL)isSongPlaying {
	NSMutableArray<TGProfileDetailItem *> *items = [NSMutableArray arrayWithCapacity:details.count];
	for (NSArray *pair in details) {
		TGProfileDetailItem *item = [TGProfileDetailItemBuilder itemFromPair:pair isSongPlaying:isSongPlaying];
		if (item)
			[items addObject:item];
	}
	_items = items;
}

@end
