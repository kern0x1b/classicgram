#import "TGStorageDownloadsPresenter.h"
#import "TGStorageDownloadsItem.h"
#import "TGStorageDownloadsItemBuilder.h"

@implementation TGStorageDownloadsPresenter {
	NSArray *_entries;
	BOOL _loaded;
	BOOL _loading;
	BOOL _showsMore;
	NSDictionary *_suggestedNames;
}

- (void)updateWithEntries:(NSArray *)entries
				   loaded:(BOOL)loaded
				  loading:(BOOL)loading
				showsMore:(BOOL)showsMore
		   suggestedNames:(NSDictionary *)suggestedNames {
	_entries = entries ?: @[];
	_loaded = loaded;
	_loading = loading;
	_showsMore = showsMore;
	_suggestedNames = suggestedNames ?: @{};
}

- (NSInteger)numberOfEntryRows {
	if (!_loaded)
		return 1;
	if (!_entries.count)
		return 1;
	return (NSInteger)_entries.count + (_showsMore ? 1 : 0);
}

- (BOOL)showsClearRow {
	return _entries.count > 0;
}

- (TGStorageDownloadsItem *)itemAtEntryRow:(NSInteger)row {
	if (!_loaded)
		return [TGStorageDownloadsItemBuilder itemForLoadingRow];
	if (!_entries.count)
		return [TGStorageDownloadsItemBuilder itemForEmptyRow];
	if (row < 0 || row >= (NSInteger)_entries.count)
		return [TGStorageDownloadsItemBuilder itemForMoreRowLoading:_loading];
	return [TGStorageDownloadsItemBuilder itemForEntry:_entries[row] suggestedNames:_suggestedNames];
}

- (TGStorageDownloadsItem *)clearRowItem {
	return [TGStorageDownloadsItemBuilder itemForClearRow];
}

@end
