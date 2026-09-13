#import "TGStarsListPresenter.h"
#import "TGStarsListItem.h"
#import "TGStarsListItemBuilder.h"

@implementation TGStarsListPresenter {
	NSArray *_rows;
	BOOL _loading;
	BOOL _moreAvailable;
	NSString *_emptyText;
}

- (void)updateWithRows:(NSArray *)rows
			   loading:(BOOL)loading
		 moreAvailable:(BOOL)moreAvailable
			 emptyText:(NSString *)emptyText {
	_rows = rows ?: @[];
	_loading = loading;
	_moreAvailable = moreAvailable;
	_emptyText = [emptyText copy];
}

- (NSInteger)numberOfItems {
	if (!_rows.count)
		return 1;
	return (NSInteger)_rows.count + (_moreAvailable ? 1 : 0);
}

- (TGStarsListItem *)itemAtRow:(NSInteger)row {
	if (row < 0)
		return nil;
	if (!_rows.count || row >= (NSInteger)_rows.count) {
		BOOL isMoreRow = _rows.count > 0;
		return [TGStarsListItemBuilder itemForStatusLoading:_loading isMoreRow:isMoreRow emptyText:_emptyText];
	}
	return [TGStarsListItemBuilder itemFromRow:_rows[row]];
}

@end
