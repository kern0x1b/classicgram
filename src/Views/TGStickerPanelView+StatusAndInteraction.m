#import "TGStickerPanelView.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import "TGStickerCatalogService.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGStickerPanelView (StatusAndInteraction)

#pragma mark - status

- (void)updateStatus {
	BOOL searchPending = self.searchQuery.length > 0 && self.searchLoading;
	BOOL empty = (!self.loading && !searchPending && self.sections.count == 0);

	if (self.loading)
		[self.spinner startAnimating];
	else
		[self.spinner stopAnimating];

	self.statusLabel.hidden = !empty;
	self.retryButton.hidden = !(empty && self.failed && self.searchQuery.length == 0);
	self.grid.hidden = empty;

	if (!empty)
		return;

	if (self.searchQuery.length > 0)
		self.statusLabel.text = TGL(@"Stickers.NoStickersFound", @"No sticker sets found.");
	else
		self.statusLabel.text = self.failed ? TGL(@"StickerPanel.StickersCouldNotBeLoaded", @"Stickers could not be loaded.")
											: TGL(@"StickerPanel.NoStickerSetsInstalledYet", @"No sticker sets installed yet.");
}

#pragma mark - interaction

- (void)tileTapped:(TGStickerTile *)tile {
	NSDictionary *sticker = tile.sticker;
	if (sticker == nil)
		return;

	if (self.searchVisible)
		[self.searchBar resignFirstResponder];

	long long fileId = [sticker[@"fileId"] longLongValue];
	if (fileId != 0 && !self.suppressesRecentStickerTracking)
		[TGStickerCatalogService addRecentStickerWithFileId:fileId];

	if (self.onStickerPicked)
		self.onStickerPicked(sticker);
}

@end
