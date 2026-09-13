#import "TGStickerPanelView.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import "TGStickerCatalogService.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGStickerPanelView (Loading)

#pragma mark - loading

+ (void)resetSectionSnapshotForAccountSwitch {
	TGStickerPanelSectionSnapshot = nil;
	TGStickerPanelSnapshotTaken = 0;
}

- (void)takeSectionSnapshot {
	if (self.searchQuery.length > 0 || self.allSections.count == 0)
		return;
	TGStickerPanelSectionSnapshot = [self.allSections mutableCopy];
	TGStickerPanelSnapshotTaken = [NSDate timeIntervalSinceReferenceDate];
}

- (BOOL)restoreSectionSnapshot {
	if (TGStickerPanelSectionSnapshot.count == 0)
		return NO;
	if ([NSDate timeIntervalSinceReferenceDate] - TGStickerPanelSnapshotTaken >
			kStickerPanelSnapshotLifetime){
		TGStickerPanelSectionSnapshot = nil;
		return NO;
	}

	[self.allSections setArray:TGStickerPanelSectionSnapshot];
	self.loading = NO;
	self.failed = NO;
	[self applyFilter];
	[self updateStatus];
	return YES;
}

- (void)reload {
	[self reloadShowingSpinner:YES];
}

- (void)reloadShowingSpinner:(BOOL)showSpinner {
	self.generation += 1;
	NSInteger generation = self.generation;

	[self clearTiles];
	[self cancelAllPendingImageLoads];
	if (showSpinner){
		[self.allSections removeAllObjects];
		[self.sections removeAllObjects];
		[self.searchSections removeAllObjects];
		self.selectedSection = -1;
		self.loading = YES;
		self.failed = NO;
		[self updateStatus];
		[self rebuildTabs];
	}

	__block BOOL anyFailure = NO;
	__block NSInteger outstanding = 5;
	__block NSArray *recent = nil;
	__block NSArray *favourites = nil;
	__block NSArray *sets = nil;
	__block NSArray *emojiSets = nil;
	__block NSArray *trending = nil;

	__weak TGStickerPanelView *weakSelf = self;
	void (^finish)(void) = ^{
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.generation != generation)
			return;
		outstanding -= 1;
		if (outstanding > 0)
			return;
		[strongSelf buildSectionsWithRecent:recent favourites:favourites sets:sets
						  emojiSets:emojiSets trending:trending failed:anyFailure];
	};

	[TGStickerCatalogService recentStickersWithCompletion:^(NSArray *stickers){
		recent = stickers;
		if (stickers == nil)
			anyFailure = YES;
		finish();
	}];
	[TGStickerCatalogService favoriteStickersWithCompletion:^(NSArray *stickers){
		favourites = stickers;
		if (stickers == nil)
			anyFailure = YES;
		finish();
	}];
	[TGStickerCatalogService installedStickerSetsWithCompletion:^(NSArray *installed){
		sets = installed;
		if (installed == nil)
			anyFailure = YES;
		finish();
	}];
	[TGStickerCatalogService installedEmojiStickerSetsWithCompletion:^(NSArray *installed){
		emojiSets = installed;
		finish();
	}];
	void (^trendingCompletion)(NSArray *, NSInteger) = ^(NSArray *featured, __unused NSInteger totalCount) {
		trending = featured;
		if (featured == nil)
			anyFailure = YES;
		finish();
	};
	[TGStickerCatalogService trendingStickerSetsWithOffset:0 limit:kStickerPanelTrendingLimit completion:trendingCompletion];
}

- (NSMutableDictionary *)sectionForSet:(NSDictionary *)set kind:(NSInteger)kind {
	NSInteger count = [set[@"count"] integerValue];
	if (count <= 0)
		return nil;

	NSString *title = set[@"title"];
	if (title.length == 0)
		title = (kind == kStickerSectionEmojiSet)
				? TGL(@"EmojiInput.PanelTitleEmoji", @"Emoji")
				: TGL(@"EmojiInput.TabStickers", @"Stickers");

	NSMutableDictionary *section = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			@(kind), @"kind",
			title, @"title",
			title, @"tabTitle",
			set[@"id"], @"setId",
			@(count), @"count", nil];

	NSString *name = set[@"name"];
	if (name.length > 0)
		section[@"name"] = name;

	if ((kind == kStickerSectionTrending || kind == kStickerSectionPublicSet) &&
		![set[@"installed"] boolValue])
		section[@"canInstall"] = @YES;

	long long thumbId = [set[@"thumbId"] longLongValue];
	NSString *thumbUniqueId = set[@"thumbUniqueId"];
	if (thumbId == 0){
		NSArray *covers = set[@"covers"];
		NSDictionary *cover = covers.count > 0 ? covers[0] : nil;
		if (cover != nil){
			thumbId = [self drawableFileIdForSticker:cover];
			thumbUniqueId = [self drawableUniqueIdForSticker:cover];
		}
	}
	if (thumbId != 0)
		section[@"tabThumbId"] = @(thumbId);
	if ([thumbUniqueId isKindOfClass:[NSString class]] && thumbUniqueId.length > 0)
		section[@"tabThumbUniqueId"] = thumbUniqueId;

	return section;
}

- (void)buildSectionsWithRecent:(NSArray *)recent
					 favourites:(NSArray *)favourites
						   sets:(NSArray *)sets
					  emojiSets:(NSArray *)emojiSets
					   trending:(NSArray *)trending
						 failed:(BOOL)failed {
	self.loading = NO;
	BOOL hadSections = (self.allSections.count > 0);
	NSInteger keptSelection = self.selectedSection;
	CGFloat keptOffset = self.grid.contentOffset.y;
	[self.allSections removeAllObjects];

	if (recent.count > 0){
		[self.allSections addObject:[[NSMutableDictionary alloc] initWithObjectsAndKeys:
				@(kStickerSectionRecent), @"kind",
				TGL(@"Stickers.Recent", @"Recent"), @"title",
				TGL(@"Stickers.RecentTab", @"Recent"), @"tabTitle",
				[recent mutableCopy], @"stickers",
				@(recent.count), @"loadedCount",
				@YES, @"complete",
				@(recent.count), @"count", nil]];
	}
	if (favourites.count > 0){
		[self.allSections addObject:[[NSMutableDictionary alloc] initWithObjectsAndKeys:
				@(kStickerSectionFavourite), @"kind",
				TGL(@"Stickers.Favourites", @"Favourites"), @"title",
				TGL(@"Stickers.FavouritesTab", @"Fav"), @"tabTitle",
				[favourites mutableCopy], @"stickers",
				@(favourites.count), @"loadedCount",
				@YES, @"complete",
				@(favourites.count), @"count", nil]];
	}

	for (NSDictionary *set in sets){
		if ([set[@"isEmoji"] boolValue])
			continue;
		NSMutableDictionary *section = [self sectionForSet:set kind:kStickerSectionSet];
		if (section != nil)
			[self.allSections addObject:section];
	}

	for (NSDictionary *set in emojiSets){
		NSMutableDictionary *section = [self sectionForSet:set kind:kStickerSectionEmojiSet];
		if (section != nil)
			[self.allSections addObject:section];
	}

	NSMutableSet *knownIds = [[NSMutableSet alloc] init];
	for (NSMutableDictionary *section in self.allSections){
		NSNumber *setId = section[@"setId"];
		if (setId != nil)
			[knownIds addObject:setId];
	}

	for (NSDictionary *set in trending){
		NSNumber *setId = set[@"id"];
		if (setId == nil || [knownIds containsObject:setId])
			continue;
		if ([set[@"installed"] boolValue] || [set[@"isEmoji"] boolValue])
			continue;
		NSMutableDictionary *section = [self sectionForSet:set kind:kStickerSectionTrending];
		if (section == nil)
			continue;
		[knownIds addObject:setId];
		[self.allSections addObject:section];
	}

	self.failed = (self.allSections.count == 0 && failed);
	[self takeSectionSnapshot];
	[self applyFilter];
	[self updateStatus];

	if (self.sections.count == 0)
		return;

	if (hadSections && keptSelection >= 0 && keptSelection < (NSInteger)self.sections.count){
		CGFloat maxOffset = MAX(0.0f, self.grid.contentSize.height - self.grid.bounds.size.height);
		self.grid.contentOffset = CGPointMake(0, MAX(0.0f, MIN(keptOffset, maxOffset)));
		[self setSelectedSection:keptSelection scrollGrid:NO];
		return;
	}
	[self setSelectedSection:0 scrollGrid:NO];
}

- (void)ensureSection:(NSInteger)index loadedUpToItem:(NSInteger)item {
	if (index < 0 || index >= (NSInteger)self.sections.count)
		return;

	NSMutableDictionary *section = self.sections[index];
	NSInteger kind = [section[@"kind"] integerValue];
	if (!TGStickerSectionIsSet(kind))
		return;
	if ([section[@"loading"] boolValue] || [section[@"complete"] boolValue])
		return;

	NSInteger loaded = [section[@"loadedCount"] integerValue];
	if (loaded > item)
		return;

	NSInteger limit = MAX((NSInteger)kStickerPanelPageSize, item - loaded + 1);
	section[@"loading"] = @YES;

	NSInteger generation = self.generation;
	int64_t setId = [section[@"setId"] longLongValue];
	NSMutableDictionary *target = section;

	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService stickersFromSetId:setId offset:loaded limit:limit
							  completion:^(NSArray *stickers, NSInteger totalCount){
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.generation != generation)
			return;

		[target removeObjectForKey:@"loading"];
		if (stickers == nil)
			return;

		NSMutableArray *store = target[@"stickers"];
		if (store == nil){
			store = [[NSMutableArray alloc] init];
			target[@"stickers"] = store;
		}
		[store addObjectsFromArray:stickers];
		target[@"loadedCount"] = @(store.count);
		if (stickers.count < (NSUInteger)limit)
			target[@"complete"] = @YES;

		BOOL geometryChanged = NO;
		if (totalCount > 0 && totalCount != [target[@"count"] integerValue]){
			target[@"count"] = @(totalCount);
			geometryChanged = YES;
		}
		else if (totalCount <= 0 && [target[@"complete"] boolValue] &&
				 (NSInteger)store.count != [target[@"count"] integerValue]){
			target[@"count"] = @(store.count);
			geometryChanged = YES;
		}

		if (geometryChanged)
			[strongSelf relayoutSections];
		[strongSelf updateVisibleTiles];
	}];
}

@end
