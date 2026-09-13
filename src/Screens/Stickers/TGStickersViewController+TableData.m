#import "TGStickersViewController.h"
#import "TGStringTruncation.h"
#import "TGStickersViewControllerInternal.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "UIImage+WebP.h"
#import "TGOwnedStickerSetsViewController.h"
#import "TGStickerEmojiKeywordsViewController.h"
#import "TGStickerTilesCell.h"
#import "TGStickerTrendCell.h"
#import "TGPreferenceFlags.h"
#import "TGHexColour.h"

@implementation TGStickersViewController (TableData)

#pragma mark - table data

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.page == TGStickersPageRoot)
		return 4;
	return [self isTwoSectionListPage] ? 2 : 1;
}

- (NSArray *)rootPageRows {
	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:@{@"title" : TGL(@"StickerPacksSettings.TrendingStickers", @"Trending Stickers"),
		@"detail" : self.trendingNewCount
			? [NSString stringWithFormat:TGL(@"Stickers.NewCountShort", @"%d new"), (int)self.trendingNewCount]
			: @"",
		@"page" : @(TGStickersPageTrending)}];
	if (self.archivedCount > 0)
		[rows addObject:@{@"title" : TGL(@"StickerPacksSettings.ArchivedPacks", @"Archived Stickers"),
			@"detail" : [NSString stringWithFormat:@"%d", (int)self.archivedCount],
			@"page" : @(TGStickersPageArchived)}];
	if (self.favouriteCount > 0)
		[rows addObject:@{@"title" : TGL(@"Stickers.FavoriteStickers", @"Favourite Stickers"),
			@"detail" : [NSString stringWithFormat:@"%d", (int)self.favouriteCount],
			@"page" : @(TGStickersPageFavourites)}];
	if (self.recentCount > 0)
		[rows addObject:@{@"title" : TGL(@"Stickers.FrequentlyUsed", @"Recently Used"),
			@"detail" : [NSString stringWithFormat:@"%d", (int)self.recentCount],
			@"page" : @(kStickersPageRecent)}];
	[rows addObject:@{@"title" : TGL(@"StickersList.EmojiItem", @"Custom Emoji"),
		@"detail" : self.emojiSetCount
			? [NSString stringWithFormat:@"%d", (int)self.emojiSetCount]
			: @"",
		@"page" : @(kStickersPageEmoji)}];
	if (self.maskCount > 0)
		[rows addObject:@{@"title" : TGL(@"Paint.Masks", @"Masks"),
			@"detail" : [NSString stringWithFormat:@"%d", (int)self.maskCount],
			@"page" : @(kStickersPageMasks)}];
	[rows addObject:@{@"title" : TGL(@"Stickers.PremiumStickers", @"Premium Stickers"), @"detail" : @"", @"page" : @(kStickersPagePremium)}];
	[rows addObject:@{@"title" : TGL(@"Stickers.GreetingStickersTitle", @"Greeting Stickers"), @"detail" : @"", @"page" : @(kStickersPageGreeting)}];
	[rows addObject:@{@"title" : TGL(@"Stickers.MyStickerSets", @"My Sticker Sets"), @"detail" : @"", @"page" : @0, @"ownedSets" : @YES}];
	return rows;
}

- (NSArray *)subpageRows {
	if ([self isEmojiListPage]) {
		return @[ @{@"title" : TGL(@"EmojiInput.TrendingEmoji", @"Trending Emoji"),
					 @"detail" : self.subpageTrendingCount
						 ? [NSString stringWithFormat:@"%d", (int)self.subpageTrendingCount]
						 : @"",
					 @"page" : @(kStickersPageEmojiTrending)},
			@{@"title" : TGL(@"StickersList.ArchivedEmojiItem", @"Archived Emoji"),
				@"detail" : self.archivedCount
					? [NSString stringWithFormat:@"%d", (int)self.archivedCount]
					: @"",
				@"page" : @(kStickersPageEmojiArchived)} ];
	}
	return @[ @{@"title" : TGL(@"StickerPacksSettings.ArchivedMasks", @"Archived Masks"),
		@"detail" : self.archivedCount
			? [NSString stringWithFormat:@"%d", (int)self.archivedCount]
			: @"",
		@"page" : @(kStickersPageMasksArchived)} ];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if ([self isGridPage])
		return [self gridRowCount];
	if ([self isTwoSectionListPage])
		return section == 0 ? (NSInteger)[self subpageRows].count : (NSInteger)self.sets.count;
	if (self.page != TGStickersPageRoot)
		return (NSInteger)self.sets.count;
	if (self.searching)
		return section == kRootSectionSets ? (NSInteger)self.sets.count : 0;
	if (section == kRootSectionSettings)
		return 4;
	if (section == kRootSectionPages)
		return (NSInteger)[self rootPageRows].count;
	if (section == kRootSectionSets)
		return (NSInteger)self.sets.count;
	return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isGridPage])
		return kGridRowHeight;
	if ([self isTrendingPage])
		return kTrendRowHeight;
	if ([self isTwoSectionListPage])
		return indexPath.section == 0 ? kPlainRowHeight : kSetRowHeight;
	if (self.page != TGStickersPageRoot)
		return kSetRowHeight;
	if (indexPath.section == kRootSectionSets)
		return kSetRowHeight;
	if (indexPath.section == kRootSectionRecent)
		return kActionRowHeight;
	return kPlainRowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if ([self isGridPage])
		return 0;
	NSString *title = [self headerTitleForSection:section];
	if (!title)
		return kGroupSpacerHeight;
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if ([self isGridPage])
		return nil;
	TGTheme *theme = [TGTheme shared];
	return [theme groupedHeaderViewWithTitle:[self headerTitleForSection:section]
									   width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if ([self isGridPage])
		return 0;
	NSString *title = [self footerTitleForSection:section];
	if (!title)
		return 1;
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentHeightForText:title width:tableView.bounds.size.width];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	if ([self isGridPage])
		return nil;
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:[self footerTitleForSection:section]
									   width:tableView.bounds.size.width];
}

- (NSDictionary *)setAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isGridPage])
		return nil;
	if (self.page == TGStickersPageRoot && indexPath.section != kRootSectionSets)
		return nil;
	if ([self isTwoSectionListPage] && indexPath.section != 1)
		return nil;
	if (indexPath.row >= (NSInteger)self.sets.count)
		return nil;
	return self.sets[indexPath.row];
}

- (NSInteger)stickerCountForSet:(NSDictionary *)set {
	NSInteger count = [set[@"count"] integerValue];
	if (count == 0)
		count = (NSInteger)[set[@"stickers"] count];
	return count;
}

- (NSString *)countTextForSet:(NSDictionary *)set {
	NSInteger count = [self stickerCountForSet:set];
	return TGLPlural(@"StickerPack.StickerCount", count, @"1 sticker", @"%d stickers");
}

- (NSString *)addButtonTitle {
	return [self isArchivePage] ? TGL(@"StickerPacks.ActionUnarchive", @"Add Back") : TGL(@"Stickers.Install", @"ADD");
}

- (UIButton *)addButton {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = CGRectMake(0, 0, [self isArchivePage] ? 86 : 70,
		TGStickersPlateHeight(@"GroupedActionButtonGreen.png", 43.0f));
	button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	[button setTitle:[self addButtonTitle] forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleColor:TGColourFromHex(0x8b97a5) forState:UIControlStateDisabled];
	[button setTitleShadowColor:TGStickersGreenShadow() forState:UIControlStateNormal];
	[button setTitleShadowColor:TGStickersGreenShadow() forState:UIControlStateHighlighted];
	[button setBackgroundImage:TGStickersPlate(@"GroupedActionButtonGreen.png")
					  forState:UIControlStateNormal];
	[button setBackgroundImage:TGStickersPlate(@"GroupedActionButtonGreen_Highlighted.png")
					  forState:UIControlStateHighlighted];
	[button addTarget:self action:@selector(addButtonTapped:)
		forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (void)configureAddButton:(UIButton *)button forRow:(NSInteger)row installed:(BOOL)installed {
	button.tag = row;
	button.enabled = !installed;
	if (installed) {
		[button setBackgroundImage:nil forState:UIControlStateNormal];
		[button setTitle:TGL(@"Stickers.Installed", @"ADDED") forState:UIControlStateDisabled];
	} else {
		[button setBackgroundImage:TGStickersPlate(@"GroupedActionButtonGreen.png")
						  forState:UIControlStateNormal];
		[button setTitle:[self addButtonTitle] forState:UIControlStateNormal];
	}
}

- (void)addButtonTapped:(UIButton *)button {
	NSInteger row = button.tag;
	if (row >= (NSInteger)self.sets.count)
		return;
	button.enabled = NO;
	[button setBackgroundImage:nil forState:UIControlStateDisabled];
	[button setTitle:TGL(@"Stickers.Installed", @"ADDED") forState:UIControlStateDisabled];
	[self installSet:self.sets[row] fromRow:row button:button];
}

- (UITableViewCell *)plainCellForTable:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"plain"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"plain"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryView = nil;
	TGStickersApplyDisclosure(cell);
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.imageView.image = nil;
	return cell;
}

- (UITableViewCell *)setCellForTable:(UITableView *)tableView
						   indexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"set"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"set"];
		cell.textLabel.font = [UIFont systemFontOfSize:19];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:13 + TGStickersRetinaPixel()];
	}
	[[TGTheme shared] styleCell:cell];
	cell.shouldIndentWhileEditing = NO;
	cell.textLabel.font = [UIFont systemFontOfSize:19];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

	NSDictionary *set = [self setAtIndexPath:indexPath];
	cell.textLabel.text = set[@"title"];
	cell.detailTextLabel.text = [self countTextForSet:set];

	UIImage *cover = [self coverForSet:set atIndexPath:indexPath];
	if (cover) {
		cell.imageView.image = cover;
	} else {
		NSString *title = set[@"title"];
		NSString *initials = title.length ? [TGSafeFirstCharacter(title) uppercaseString] : @"?";
		long long colourId = [set[@"id"] longLongValue];
		UIImage *fallback = [TGIcons avatarWithInitials:initials size:kCoverSide colourId:colourId];
		cell.imageView.image = fallback;
	}
	cell.imageView.contentMode = UIViewContentModeScaleAspectFit;

	if ([self isReorderPage]) {
		cell.accessoryView = nil;
		TGStickersApplyDisclosure(cell);
	} else {
		UIButton *add = [self addButton];
		[self configureAddButton:add forRow:indexPath.row
					   installed:[set[@"installed"] boolValue]];
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.accessoryView = add;
	}
	return cell;
}

- (UITableViewCell *)trendCellForTable:(UITableView *)tableView
							 indexPath:(NSIndexPath *)indexPath {
	TGStickerTrendCell *cell = (TGStickerTrendCell *)
		[tableView dequeueReusableCellWithIdentifier:@"trend"];
	if (!cell) {
		cell = [[TGStickerTrendCell alloc] initWithStyle:UITableViewCellStyleDefault
										 reuseIdentifier:@"trend"];
		[cell.addButton addTarget:self action:@selector(addButtonTapped:)
				 forControlEvents:UIControlEventTouchUpInside];
	}
	[[TGTheme shared] styleCell:cell];

	NSDictionary *set = [self setAtIndexPath:indexPath];
	cell.packTitleLabel.text = set[@"title"];
	cell.packTitleLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.packCountLabel.text = [self countTextForSet:set];
	[self configureAddButton:cell.addButton forRow:indexPath.row
				   installed:[set[@"installed"] boolValue]];

	NSArray *covers = set[@"covers"];
	NSInteger index = 0;
	for (UIImageView *view in cell.coverViews) {
		UIImage *image = nil;
		if (index < (NSInteger)covers.count) {
			NSDictionary *sticker = covers[index];
			if ([self stickerIsStill:sticker])
				image = [self imageForFileId:[sticker[@"fileId"] longLongValue]
										side:kTrendCoverSide
								   indexPath:indexPath];
			if (!image)
				image = [self outlineForSticker:sticker side:kTrendCoverSide indexPath:indexPath];
		}
		view.image = image;
		index++;
	}
	return cell;
}

- (UITableViewCell *)clearRecentCellForTable:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"clear"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"clear"];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.backgroundColor = [UIColor clearColor];
		cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
		cell.backgroundView.backgroundColor = [UIColor clearColor];

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = 7701;
		button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		[button setTitle:TGL(@"Stickers.ClearRecent", @"Clear Recent Stickers") forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleShadowColor:TGStickersRedShadow() forState:UIControlStateNormal];
		[button setTitleShadowColor:TGStickersRedShadow() forState:UIControlStateHighlighted];
		[button setBackgroundImage:TGStickersPlate(@"MenuRedButton.png")
						  forState:UIControlStateNormal];
		[button setBackgroundImage:TGStickersPlate(@"MenuRedButton_Highlighted.png")
						  forState:UIControlStateHighlighted];
		[button addTarget:self action:@selector(clearRecentTapped)
			forControlEvents:UIControlEventTouchUpInside];
		[cell addSubview:button];
	}
	UIButton *button = (UIButton *)[cell viewWithTag:7701];
	button.frame = CGRectMake(kStickersGroupedInset, 0,
		tableView.bounds.size.width - kStickersGroupedInset * 2,
		TGStickersPlateHeight(@"MenuRedButton.png", kActionRowHeight));
	return cell;
}

- (void)clearRecentTapped {
	NSArray *actions = @[
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Stickers.ClearRecent", @"Clear Recent Stickers")
											action:@"clearRecent"
											  type:TGActionSheetActionTypeDestructive],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel"
											  type:TGActionSheetActionTypeCancel]
	];
	[self presentSheetWithTitle:nil actions:actions];
}

- (UITableViewCell *)settingsCellForTable:(UITableView *)tableView row:(NSInteger)row {
	UITableViewCell *cell = [self plainCellForTable:tableView];

	if (row == 0) {
		cell.textLabel.text = TGL(@"Stickers.SuggestStickers", @"Suggest by Emoji");
		cell.detailTextLabel.text = TGStickersSuggestModeName(TGStickersSuggestMode());
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if (row == 2) {
		cell.textLabel.text = TGL(@"Stickers.EmojiKeywords", @"Emoji Keywords");
		cell.detailTextLabel.text = @"";
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	BOOL large = (row == 3);
	cell.textLabel.text = large ? TGL(@"Appearance.LargeEmoji", @"Large Emoji")
								: TGL(@"StickerPacksSettings.AnimatedStickers", @"Loop Animated Stickers");
	cell.detailTextLabel.text = @"";
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = large
		? [TGPreferenceFlags stickersLargeEmojiEnabled]
		: [TGPreferenceFlags stickersLoopAnimatedEnabled];
	[toggle addTarget:self
			   action:(large ? @selector(largeEmojiToggled:)
							 : @selector(loopAnimatedToggled:))
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isGridPage])
		return [self tilesCellForTable:tableView indexPath:indexPath];
	if ([self isTrendingPage])
		return [self trendCellForTable:tableView indexPath:indexPath];
	if ([self isTwoSectionListPage]) {
		if (indexPath.section == 0) {
			NSArray *rows = [self subpageRows];
			if (indexPath.row >= (NSInteger)rows.count)
				return [self plainCellForTable:tableView];
			return [self subpageCellForTable:tableView rowInfo:rows[indexPath.row]];
		}
		return [self setCellForTable:tableView indexPath:indexPath];
	}
	if (self.page != TGStickersPageRoot)
		return [self setCellForTable:tableView indexPath:indexPath];

	if (indexPath.section == kRootSectionSets)
		return [self setCellForTable:tableView indexPath:indexPath];
	if (indexPath.section == kRootSectionRecent)
		return [self clearRecentCellForTable:tableView];

	if (indexPath.section == kRootSectionSettings)
		return [self settingsCellForTable:tableView row:indexPath.row];

	NSArray *rows = [self rootPageRows];
	if (indexPath.row >= (NSInteger)rows.count)
		return [self plainCellForTable:tableView];
	return [self subpageCellForTable:tableView rowInfo:rows[indexPath.row]];
}

- (UITableViewCell *)subpageCellForTable:(UITableView *)tableView
								 rowInfo:(NSDictionary *)rowInfo {
	UITableViewCell *cell = [self plainCellForTable:tableView];
	cell.textLabel.text = rowInfo[@"title"];
	cell.detailTextLabel.text = rowInfo[@"detail"];
	return cell;
}

#pragma mark - table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if ([self isGridPage])
		return;

	if ([self isTwoSectionListPage]) {
		if (indexPath.section == 0) {
			NSArray *rows = [self subpageRows];
			if (indexPath.row < (NSInteger)rows.count)
				[self openPage:(TGStickersPage)[rows[indexPath.row][@"page"] integerValue]];
			return;
		}
		NSDictionary *set = [self setAtIndexPath:indexPath];
		if (set)
			[self openSet:set];
		return;
	}

	if (self.page != TGStickersPageRoot) {
		NSDictionary *set = [self setAtIndexPath:indexPath];
		if (set)
			[self openSet:set];
		return;
	}

	if (indexPath.section == kRootSectionSettings) {
		if (indexPath.row == 0)
			[self presentSuggestModeSheet];
		else if (indexPath.row == 2)
			[self.navigationController pushViewController:
					[[TGStickerEmojiKeywordsViewController alloc] init]
												 animated:YES];
		return;
	}
	if (indexPath.section == kRootSectionPages) {
		NSArray *rows = [self rootPageRows];
		if (indexPath.row >= (NSInteger)rows.count)
			return;
		NSDictionary *rowInfo = rows[indexPath.row];
		if ([rowInfo[@"ownedSets"] boolValue]) {
			[self.navigationController pushViewController:
					[[TGOwnedStickerSetsViewController alloc] init]
												 animated:YES];
			return;
		}
		[self openPage:(TGStickersPage)[rowInfo[@"page"] integerValue]];
		return;
	}
	if (indexPath.section == kRootSectionSets) {
		NSDictionary *set = [self setAtIndexPath:indexPath];
		if (set)
			[self openSet:set];
		return;
	}

	[self clearRecentTapped];
}

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![self isArchivePage] && ![self isTrendingPage])
		return;
	if (indexPath.row < (NSInteger)self.sets.count - 3)
		return;
	if ([self isArchivePage])
		[self loadMoreArchived];
	else
		[self loadMoreTrending];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isGridPage] || self.searching)
		return NO;
	if ([self isArchivePage])
		return YES;
	if ([self isTwoSectionListPage])
		return indexPath.section == 1;
	return self.page == TGStickersPageRoot && indexPath.section == kRootSectionSets;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.searching)
		return NO;
	if ([self isTwoSectionListPage])
		return indexPath.section == 1;
	return self.page == TGStickersPageRoot && indexPath.section == kRootSectionSets;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.reordering || self.searching)
		return UITableViewCellEditingStyleNone;
	if ([self isArchivePage])
		return UITableViewCellEditingStyleDelete;
	if ([self isTwoSectionListPage])
		return indexPath.section == 1 ? UITableViewCellEditingStyleDelete
									  : UITableViewCellEditingStyleNone;
	if (self.page == TGStickersPageRoot && indexPath.section == kRootSectionSets)
		return UITableViewCellEditingStyleDelete;
	return UITableViewCellEditingStyleNone;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"Appearance.RemoveTheme", @"Remove");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	NSDictionary *set = [self setAtIndexPath:indexPath];
	if (!set)
		return;
	self.actionSheetSet = set;

	if ([self isArchivePage]) {
		TGActionSheetAction *deleteAction = [TGActionSheetAction alloc];
		deleteAction = [deleteAction initWithTitle:TGL(@"Common.Delete", @"Delete")
											action:@"removeSet"
											  type:TGActionSheetActionTypeDestructive];
		TGActionSheetAction *cancelAction = [TGActionSheetAction alloc];
		cancelAction = [cancelAction initWithTitle:TGL(@"Common.Cancel", @"Cancel")
											action:@"cancel"
											  type:TGActionSheetActionTypeCancel];
		NSArray *archivedActions = @[
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerPacks.ActionUnarchive", @"Add Back") action:@"restoreSet"],
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerPack.CopyLink", @"Copy Link") action:@"copyLink"],
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerPack.ShareLink", @"Share Link") action:@"shareSet"],
			deleteAction,
			cancelAction
		];
		[self presentSheetWithTitle:set[@"title"] actions:archivedActions];
		return;
	}

	NSArray *actions = @[
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerSettings.ContextHide", @"Archive") action:@"archiveSet"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerPack.CopyLink", @"Copy Link") action:@"copyLink"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerPack.ShareLink", @"Share Link") action:@"shareSet"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Appearance.RemoveTheme", @"Remove") action:@"removeSet"
											  type:TGActionSheetActionTypeDestructive],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel"
											  type:TGActionSheetActionTypeCancel]
	];
	[self presentSheetWithTitle:set[@"title"] actions:actions];
}

- (NSIndexPath *)tableView:(UITableView *)tableView
	targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
						 toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
	NSInteger section = [self setsSection];
	if (proposedDestinationIndexPath.section == section)
		return proposedDestinationIndexPath;
	if (proposedDestinationIndexPath.section < section)
		return [NSIndexPath indexPathForRow:0 inSection:section];
	return [NSIndexPath indexPathForRow:(NSInteger)self.sets.count - 1 inSection:section];
}

- (void)tableView:(UITableView *)tableView
	moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
		   toIndexPath:(NSIndexPath *)destinationIndexPath {
	if (sourceIndexPath.row >= (NSInteger)self.sets.count)
		return;
	NSDictionary *moved = self.sets[sourceIndexPath.row];
	[self.sets removeObjectAtIndex:sourceIndexPath.row];
	NSInteger target = destinationIndexPath.row;
	if (target > (NSInteger)self.sets.count)
		target = (NSInteger)self.sets.count;
	[self.sets insertObject:moved atIndex:target];
}

@end
