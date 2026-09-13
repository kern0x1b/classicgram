#import "TGClient+Messages.h"
#import "TGStickerSearchFooter.h"
#import "TGStickersViewController.h"
#import "TGStickersViewControllerInternal.h"
#import "TGClient+Stickers.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "UIImage+WebP.h"
#import "TGOwnedStickerSetsViewController.h"
#import "TGStickerSetEditorViewController.h"
#import "TGStickerEmojiKeywordsViewController.h"
#import "TGStickerTilesCell.h"
#import "TGStickerTrendCell.h"
#import "TGForwardPicker.h"

@implementation TGStickersViewController (Actions)

#pragma mark - action sheets

- (void)presentSheetWithTitle:(NSString *)title actions:(NSArray *)actions {
	__weak typeof(self) weakSelf = self;
	void (^actionBlock)(id, NSString *) = ^(__unused id target, NSString *action) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.currentActionSheet = nil;
		[strongSelf performAction:action];
	};
	self.currentActionSheet = [[TGActionSheet alloc] initWithTitle:title actions:actions actionBlock:actionBlock target:self];

	UIView *host = self.navigationController.view ?: self.view;
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(host.bounds), CGRectGetMidY(host.bounds), 1, 1)
									   inView:host];
}

- (void)performAction:(NSString *)action {
	NSDictionary *set = self.actionSheetSet;
	self.actionSheetSet = nil;

	if ([action isEqualToString:@"archiveSet"] && set)
		[self archiveSet:set];
	else if ([action isEqualToString:@"restoreSet"] && set)
		[self restoreArchivedSet:set];
	else if ([action isEqualToString:@"removeSet"] && set)
		[self uninstallSet:set];
	else if ([action isEqualToString:@"clearRecent"])
		[self clearRecent];
	else if ([action isEqualToString:@"removeFavourite"])
		[self removeCurrentFavourite];
	else if ([action isEqualToString:@"openArchive"])
		[self openPage:[self archivedPageForStickerType:[self archiveCheckStickerType]]];
	else if ([action isEqualToString:@"suggestAll"])
		[self applySuggestMode:TGStickerSuggestModeAll];
	else if ([action isEqualToString:@"suggestInstalled"])
		[self applySuggestMode:TGStickerSuggestModeInstalled];
	else if ([action isEqualToString:@"suggestNone"])
		[self applySuggestMode:TGStickerSuggestModeNone];
	else if ([action isEqualToString:@"copyLink"] && set)
		[self copyLinkForSet:set];
	else if ([action isEqualToString:@"shareSet"] && set)
		[self shareLinkForSet:set];
	else if ([action isEqualToString:@"favouriteSticker"])
		[self setCurrentStickerFavourite:YES];
	else if ([action isEqualToString:@"unfavouriteSticker"])
		[self setCurrentStickerFavourite:NO];
	else if ([action isEqualToString:@"removeRecent"])
		[self removeCurrentRecent];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
	TGAlertView *alert = [[TGAlertView alloc] initWithTitle:title message:message
										  cancelButtonTitle:TGL(@"Common.OK", @"OK")
											  okButtonTitle:nil
											completionBlock:nil];
	[alert show];
}

- (void)copyLinkForSet:(NSDictionary *)set {
	int64_t identifier = [set[@"id"] longLongValue];
	if (identifier == 0)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickerSetNameForId:identifier completion:^(NSString *name) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!name.length)
			return;
		NSString *link = [NSString stringWithFormat:@"https://telegram.me/addstickers/%@", name];
		[UIPasteboard generalPasteboard].string = link;
		[strongSelf showAlertWithTitle:TGL(@"Story.ToastLinkCopied", @"Link Copied") message:link];
	}];
}

- (void)shareLinkForSet:(NSDictionary *)set {
	int64_t identifier = [set[@"id"] longLongValue];
	if (identifier == 0)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickerSetNameForId:identifier completion:^(NSString *name) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!name.length)
			return;
		NSString *link = [NSString stringWithFormat:@"https://telegram.me/addstickers/%@", name];
		TGForwardPicker *picker = [[TGForwardPicker alloc] init];
		picker.onPicked = ^(NSArray *chatIds) {
			__strong typeof(weakSelf) innerSelf = weakSelf;
			for (NSNumber *chatId in chatIds) {
				if ([chatId longLongValue] != 0)
					[[TGClient shared] sendText:link toChat:[chatId longLongValue]];
			}
			[innerSelf dismissViewControllerAnimated:YES completion:nil];
		};
		UINavigationController *navigation =
			[[UINavigationController alloc] initWithRootViewController:picker];
		[strongSelf presentViewController:navigation animated:YES completion:nil];
	}];
}

- (void)setCurrentStickerFavourite:(BOOL)favourite {
	NSDictionary *sticker = self.actionSheetSticker;
	self.actionSheetSticker = nil;
	long long fileId = [sticker[@"fileId"] longLongValue];
	if (fileId == 0)
		return;

	if (!favourite) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] removeFavoriteStickerWithFileId:fileId completion:^(BOOL ok) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf showAlertWithTitle:TGL(@"Stickers.Favorites", @"Favourites")
									message:ok ? TGL(@"Conversation.StickerRemovedFromFavorites", @"Sticker removed from favourites.")
											   : TGL(@"Stickers.CouldNotRemoveFromFavorites", @"Couldn't remove the sticker from favourites.")];
		}];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] addFavoriteStickerWithFileId:fileId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf showAlertWithTitle:TGL(@"Stickers.Favorites", @"Favourites")
							   message:ok ? TGL(@"Conversation.StickerAddedToFavorites", @"Sticker added to favourites.")
										  : TGL(@"Stickers.CouldNotAddToFavorites", @"Couldn't add the sticker to favourites.")];
	}];
}

- (void)removeCurrentRecent {
	NSDictionary *sticker = self.actionSheetSticker;
	self.actionSheetSticker = nil;
	if (!sticker)
		return;
	[[TGClient shared] removeRecentStickerWithFileId:[sticker[@"fileId"] longLongValue]];

	NSMutableArray *remaining = [NSMutableArray arrayWithArray:self.stickers];
	[remaining removeObject:sticker];
	self.stickers = remaining;
	self.recentCount = (NSInteger)remaining.count;
	if (remaining.count == 0) {
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}
	[self.table reloadData];
}

- (void)applySuggestMode:(TGStickerSuggestMode)mode {
	[[NSUserDefaults standardUserDefaults] setInteger:mode forKey:TGStickerSuggestModeKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self reloadSettingsSection];
}

- (void)presentSuggestModeSheet {
	NSArray *actions = @[
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Stickers.SuggestAll", @"All Sets") action:@"suggestAll"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Stickers.SuggestAdded", @"My Sets") action:@"suggestInstalled"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Stickers.SuggestNone", @"None") action:@"suggestNone"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel"
											  type:TGActionSheetActionTypeCancel]
	];
	[self presentSheetWithTitle:TGL(@"Stickers.SuggestStickers", @"Suggest by Emoji") actions:actions];
}

- (void)largeEmojiToggled:(UISwitch *)toggle {
	[[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:TGStickerLargeEmojiKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loopAnimatedToggled:(UISwitch *)toggle {
	[[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:TGStickerLoopAnimatedKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - acts

- (void)archiveSet:(NSDictionary *)set {
	NSInteger index = [self.sets indexOfObject:set];
	if (index == NSNotFound)
		return;
	[self.sets removeObjectAtIndex:index];
	[self.table reloadData];
	[self installEditButton];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] archiveStickerSet:[set[@"id"] longLongValue] completion:^(BOOL ok) {
		if (ok)
			return;
		TGStickersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSInteger insertAt = MIN(index, (NSInteger)strongSelf.sets.count);
		[strongSelf.sets insertObject:set atIndex:insertAt];
		if (strongSelf.archivedCount > 0)
			strongSelf.archivedCount--;
		[strongSelf.table reloadData];
		[strongSelf installEditButton];
		[strongSelf reloadArchivedCountBadge];
		[TGSnackbar showInView:strongSelf.view
						  text:TGL(@"Stickers.CouldNotArchiveSet", @"Couldn't Archive the Sticker Set")
					   seconds:2
					  onCommit:nil];
	}];
	self.archivedCount++;
	[self reloadArchivedCountBadge];
}

- (void)uninstallSet:(NSDictionary *)set {
	NSInteger index = [self.sets indexOfObject:set];
	if (index == NSNotFound)
		return;
	BOOL wasArchivePage = [self isArchivePage];
	if (wasArchivePage) {
		[self removeArchivedRow:(NSInteger)index];
	} else {
		[self.sets removeObjectAtIndex:index];
		[self.table reloadData];
		[self installEditButton];
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] uninstallStickerSet:[set[@"id"] longLongValue] completion:^(BOOL ok) {
		if (ok)
			return;
		TGStickersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSInteger insertAt = MIN(index, (NSInteger)strongSelf.sets.count);
		[strongSelf.sets insertObject:set atIndex:insertAt];
		if (wasArchivePage) {
			strongSelf.archivedCount++;
			[strongSelf reloadArchivedCountBadge];
		}
		[strongSelf.table reloadData];
		[strongSelf installEditButton];
		[TGSnackbar showInView:strongSelf.view
						  text:TGL(@"Stickers.CouldNotUninstallSet", @"Couldn't Remove the Sticker Set")
					   seconds:2
					  onCommit:nil];
	}];
}

- (void)installSet:(NSDictionary *)set fromRow:(NSInteger)row button:(UIButton *)button {
	__weak typeof(self) weakSelf = self;
	__weak UIButton *weakButton = button;
	[[TGClient shared] installStickerSet:[set[@"id"] longLongValue] completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		__strong UIButton *strongButton = weakButton;
		if (!strongSelf)
			return;
		if (!ok) {
			strongButton.enabled = YES;
			[strongButton setTitle:[strongSelf addButtonTitle] forState:UIControlStateNormal];
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"Stickers.CouldNotInstallSet", @"Couldn't Add the Sticker Set")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[strongSelf checkAutoArchivedSets];
		if (row >= (NSInteger)strongSelf.sets.count)
			return;
		if ([strongSelf isArchivePage]) {
			[strongSelf removeArchivedRow:row];
			return;
		}
		NSMutableDictionary *updated = [NSMutableDictionary
			dictionaryWithDictionary:strongSelf.sets[row]];
		updated[@"installed"] = @YES;
		updated[@"archived"] = @NO;
		strongSelf.sets[row] = updated;
		[strongSelf.table reloadData];
	}];
}

- (void)removeArchivedRow:(NSInteger)row {
	if (row >= (NSInteger)self.sets.count)
		return;
	[self.sets removeObjectAtIndex:row];
	if (self.archivedCount > 0)
		self.archivedCount--;
	[self reloadArchivedCountBadge];
	if (self.sets.count == 0) {
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}
	[self.table reloadData];
}

- (void)restoreArchivedSet:(NSDictionary *)set {
	NSInteger row = [self.sets indexOfObject:set];
	if (row == NSNotFound)
		return;
	[self installSet:set fromRow:(NSInteger)row button:nil];
}

- (void)applyCurrentSetInstalled:(BOOL)installed {
	self.installedHere = installed;
	NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:self.set];
	updated[@"installed"] = installed ? @YES : @NO;
	if (installed)
		updated[@"archived"] = @NO;
	self.set = updated;
	[self refreshSetBarButton];
	[self refreshBottomBar];
	if (self.setStateChanged)
		self.setStateChanged(installed);
}

- (void)toggleCurrentSet {
	int64_t identifier = self.setId ?: [self.set[@"id"] longLongValue];
	if (identifier == 0)
		return;
	BOOL installed = [self currentSetInstalled];
	[self applyCurrentSetInstalled:!installed];
	self.bottomButton.enabled = NO;

	__weak typeof(self) weakSelf = self;
	void (^done)(BOOL) = ^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.bottomButton.enabled = YES;
		if (!ok) {
			[strongSelf applyCurrentSetInstalled:installed];
			return;
		}
		if (!installed)
			[strongSelf checkAutoArchivedSets];
	};

	if (installed)
		[[TGClient shared] uninstallStickerSet:identifier completion:done];
	else
		[[TGClient shared] installStickerSet:identifier completion:done];
}

- (void)shareCurrentSet {
	if (self.set)
		[self shareLinkForSet:self.set];
}

- (void)editCurrentSet {
	if (!self.set)
		return;
	TGStickerSetEditorViewController *editor = [[TGStickerSetEditorViewController alloc] init];
	editor.userId = [[TGClient shared].me[@"id"] longLongValue];
	editor.set = self.set;
	[self.navigationController pushViewController:editor animated:YES];
}

- (void)clearRecent {
	[[TGClient shared] clearRecentStickers];

	self.stickers = [NSMutableArray array];
	self.recentCount = 0;
	if (self.page == TGStickersPageRoot)
		[self reloadFirstSection];
	else
		[self.table reloadData];
}

- (void)removeCurrentFavourite {
	NSDictionary *sticker = self.actionSheetSticker;
	self.actionSheetSticker = nil;
	if (!sticker)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeFavoriteStickerWithFileId:[sticker[@"fileId"] longLongValue] completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Stickers.CouldNotRemoveFromFavorites", @"Couldn't remove the sticker from favourites.")
						seconds:2
					   onCommit:nil];
	}];

	NSMutableArray *remaining = [NSMutableArray arrayWithArray:self.stickers];
	[remaining removeObject:sticker];
	self.stickers = remaining;
	self.favouriteCount = (NSInteger)remaining.count;
	if (remaining.count == 0) {
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}
	[self.table reloadData];
}

#pragma mark - reordering

- (void)editTapped {
	if (self.reordering) {
		[self commitOrder];
		self.reordering = NO;
		[self.table setEditing:NO animated:YES];
	} else {
		self.reordering = YES;
		self.orderBeforeEdit = [NSArray arrayWithArray:self.sets];
		[self.table setEditing:YES animated:YES];
	}
	[self installEditButton];
}

- (void)commitOrder {
	self.reordering = NO;
	NSArray *previous = self.orderBeforeEdit;
	self.orderBeforeEdit = nil;
	if (self.sets.count == 0)
		return;
	if (previous && [previous isEqualToArray:self.sets])
		return;

	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *set in self.sets)
		if (set[@"id"])
			[ids addObject:set[@"id"]];
	if (ids.count == 0)
		return;

	__weak typeof(self) weakSelf = self;
	void (^done)(BOOL) = ^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ok || !previous)
			return;
		strongSelf.sets = [NSMutableArray arrayWithArray:previous];
		[strongSelf.table reloadData];
	};
	if ([self isMaskPage])
		[[TGClient shared] reorderInstalledMaskStickerSets:ids completion:done];
	else if ([self isEmojiListPage])
		[[TGClient shared] reorderInstalledEmojiStickerSets:ids completion:done];
	else
		[[TGClient shared] reorderInstalledStickerSets:ids completion:done];
}

#pragma mark - search

- (NSString *)trimmedQuery {
	return [self.searchBar.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)endSearch {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
	if (!self.searching)
		return;
	self.searching = NO;
	if (self.setsBeforeSearch)
		self.sets = self.setsBeforeSearch;
	self.setsBeforeSearch = nil;
	[self.table reloadData];
	[self reload];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
	if (self.reordering)
		[self editTapped];
	[searchBar setShowsCancelButton:YES animated:YES];
	return YES;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	[self endSearch];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
	if ([self trimmedQuery].length == 0) {
		[self endSearch];
		return;
	}
	[self performSelector:@selector(runSearch) withObject:nil afterDelay:0.3];
}

- (void)runSearch {
	NSString *query = [self trimmedQuery];
	if (query.length == 0) {
		[self endSearch];
		return;
	}
	if (!self.searching) {
		self.searching = YES;
		self.searchFailed = NO;
		self.setsBeforeSearch = self.sets;
	}

	__weak typeof(self) weakSelf = self;
	void (^done)(NSArray *) = ^(NSArray *sets) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.searching)
			return;
		if (![[strongSelf trimmedQuery] isEqualToString:query])
			return;
		strongSelf.searchFailed = (sets == nil);
		strongSelf.sets = [NSMutableArray arrayWithArray:(sets ?: @[])];
		[strongSelf showContent];
		[strongSelf.table reloadData];
	};

	if ([self isMaskPage])
		[[TGClient shared] searchInstalledMaskStickerSets:query limit:kSearchLimit
											   completion:done];
	else if (self.page == TGStickersPageRoot)
		[[TGClient shared] searchInstalledStickerSets:query limit:kSearchLimit
										   completion:done];
	else if (self.page == TGStickersPageTrending)
		[[TGClient shared] searchStickerSets:query completion:done];
	else
		[[TGClient shared] searchEmojiStickerSets:query completion:done];
}

#pragma mark - navigation

- (void)openPage:(TGStickersPage)page {
	TGStickersViewController *next = [[TGStickersViewController alloc] init];
	next.page = page;
	[self.navigationController pushViewController:next animated:YES];
}

- (void)openSet:(NSDictionary *)set {
	TGStickersViewController *next = [[TGStickersViewController alloc] init];
	next.page = TGStickersPageSet;
	next.set = set;
	next.setId = [set[@"id"] longLongValue];

	if ([self isTrendingPage] || [self isArchivePage]) {
		__weak typeof(self) weakSelf = self;
		next.setStateChanged = ^(BOOL installed) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf previewedSet:set becameInstalled:installed];
		};
	}
	[self.navigationController pushViewController:next animated:YES];
}

- (void)previewedSet:(NSDictionary *)set becameInstalled:(BOOL)installed {
	NSInteger index = [self.sets indexOfObject:set];
	if (index == NSNotFound)
		return;
	if ([self isArchivePage]) {
		if (installed)
			[self removeArchivedRow:(NSInteger)index];
		return;
	}
	NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:set];
	updated[@"installed"] = installed ? @YES : @NO;
	updated[@"archived"] = @NO;
	self.sets[index] = updated;
	[self.table reloadData];
}

#pragma mark - captions

- (NSString *)headerTitleForSection:(NSInteger)section {
	if (self.page == TGStickersPageRoot && section == kRootSectionSets && self.sets.count)
		return TGL(@"Watch.Stickers.StickerPacks", @"Sticker Sets");
	return nil;
}

- (NSString *)footerTitleForSection:(NSInteger)section {
	if ([self isTwoSectionListPage]) {
		if (section != 1)
			return nil;
		if (self.searching)
			return TGStickerSearchFooterText(self.searchFailed, self.sets.count);
		return [self isMaskPage]
			? TGL(@"MaskStickerSettings.Info", @"You can add masks to photos and videos you send. To do this, open the photo editor before sending a photo or video.")
			: TGL(@"EmojiStickerSettings.Info", @"Artists are welcome to add their own emoji sets using our @stickers bot.\n\nTap on a message to view and add the whole set.");
	}
	if (self.page == TGStickersPageRoot && self.searching) {
		if (section != kRootSectionSets)
			return nil;
		return TGStickerSearchFooterText(self.searchFailed, self.sets.count);
	}
	if (self.page == TGStickersPageRoot) {
		if (section != kRootSectionSets)
			return nil;
		if (self.sets.count == 0)
			return self.loaded ? nil : TGL(@"Channel.NotificationLoading", @"Loading…");
		return TGL(@"StickerPacksSettings.ManagingHelp", @"Artists are welcome to add their own sticker sets using our @stickers bot.\n\nTap on a sticker to view and add the whole set.");
	}
	if ([self isArchivePage] && section == 0 && self.sets.count)
		return TGL(@"StickerPacksSettings.ArchivedPacks.Info", @"You can have up to 200 sticker sets installed.\nUnused stickers are archived when you add more.");
	if ([self isTrendingPage] && section == 0 && self.searching)
		return TGStickerSearchFooterText(self.searchFailed, self.sets.count);
	return nil;
}

@end
