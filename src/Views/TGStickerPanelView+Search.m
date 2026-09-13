#import "TGStickerPanelView.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import "TGStickerCatalogService.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGStickerPanelView (Search)

#pragma mark - search

- (void)toggleSearch {
	[self setSearchVisible:!self.searchVisible];
}

- (BOOL)searchVisible {
	return _searchVisible;
}

- (void)setSearchVisible:(BOOL)visible {
	if (self.searchVisible == visible)
		return;
	_searchVisible = visible;
	self.searchBar.hidden = !visible;
	self.searchKey.selected = visible;

	if (self.onSearchVisibilityChanged)
		self.onSearchVisibilityChanged(visible);

	if (visible) {
		self.gridOffsetBeforeSearch = self.grid.contentOffset.y;
		[self setNeedsLayout];
		[self layoutIfNeeded];
		[self.searchBar becomeFirstResponder];
		return;
	}

	[self.searchBar resignFirstResponder];
	self.searchBar.text = @"";
	if (self.searchQuery.length > 0) {
		self.searchQuery = @"";
		self.searchGeneration += 1;
		self.searchLoading = NO;
		self.searchOutstanding = 0;
		[self.searchSections removeAllObjects];
		[self applyFilter];
		[self updateStatus];
		[self restoreGridOffset:self.gridOffsetBeforeSearch];
	}
	[self setNeedsLayout];
}

- (void)restoreGridOffset:(CGFloat)offset {
	CGFloat maxOffset = MAX(0.0f,
		self.grid.contentSize.height - self.grid.bounds.size.height);
	self.grid.contentOffset = CGPointMake(0, MAX(0.0f, MIN(offset, maxOffset)));
	[self updateVisibleTiles];
}

- (void)applyFilter {
	NSString *query = self.searchQuery;
	NSMutableArray *filtered = [[NSMutableArray alloc] init];

	if (query.length == 0) {
		[filtered addObjectsFromArray:self.allSections];
	} else {
		[filtered addObjectsFromArray:self.searchSections];
		for (NSMutableDictionary *section in self.allSections) {
			NSString *title = section[@"title"];
			NSString *name = section[@"name"];
			BOOL matched = ([title rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) ||
				(name.length > 0 && [name rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound);
			if (!matched && section[@"serverMatch"] != nil)
				matched = [section[@"serverMatch"] isEqualToString:query];
			if (matched)
				[filtered addObject:section];
		}
	}

	[self.sections setArray:filtered];
	if (query.length > 0)
		[self purgeDistantSectionsAggressively:NO];
	self.selectedSection = -1;
	[self rebuildTabs];
	[self relayoutSections];
	if (self.sections.count > 0)
		[self setSelectedSection:0 scrollGrid:NO];
}

- (BOOL)searchStillCurrent:(NSString *)query
				generation:(NSInteger)generation
		  searchGeneration:(NSInteger)searchGeneration {
	if (self.generation != generation || self.searchGeneration != searchGeneration)
		return NO;
	return [self.searchQuery isEqualToString:query];
}

- (BOOL)knowsSetId:(NSNumber *)setId {
	if (setId == nil)
		return YES;
	for (NSMutableDictionary *section in self.allSections) {
		if ([setId isEqualToNumber:section[@"setId"] ?: @(0)])
			return YES;
	}
	for (NSMutableDictionary *section in self.searchSections) {
		if ([setId isEqualToNumber:section[@"setId"] ?: @(0)])
			return YES;
	}
	return NO;
}

- (void)insertSearchSection:(NSMutableDictionary *)section order:(NSInteger)order {
	section[@"order"] = @(order);
	NSInteger insertAt = (NSInteger)self.searchSections.count;
	for (NSInteger i = 0; i < (NSInteger)self.searchSections.count; i++) {
		if ([self.searchSections[i][@"order"] integerValue] > order) {
			insertAt = i;
			break;
		}
	}
	[self.searchSections insertObject:section atIndex:insertAt];
}

- (void)addSearchSection:(NSMutableDictionary *)section order:(NSInteger)order {
	[self insertSearchSection:section order:order];
	[self applyFilter];
	[self updateStatus];
}

- (NSMutableDictionary *)searchResultSectionForStickers:(NSArray *)stickers {
	if (stickers.count == 0)
		return nil;

	NSMutableDictionary *section = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			@(kStickerSectionSearch), @"kind",
		TGL(@"Stickers.SearchResults", @"Search Results"), @"title",
		TGL(@"Stickers.SearchResultsTab", @"Found"), @"tabTitle",
		[stickers mutableCopy], @"stickers",
		@(stickers.count), @"loadedCount",
		@YES, @"complete",
		@(stickers.count), @"count", nil];

	long long thumbId = [self drawableFileIdForSticker:stickers[0]];
	NSString *thumbUniqueId = [self drawableUniqueIdForSticker:stickers[0]];
	if (thumbId != 0)
		section[@"tabThumbId"] = @(thumbId);
	if (thumbUniqueId.length > 0)
		section[@"tabThumbUniqueId"] = thumbUniqueId;
	return section;
}

- (void)searchStickersByEmoji:(NSString *)emoji
					 forQuery:(NSString *)query
				   generation:(NSInteger)generation
			 searchGeneration:(NSInteger)searchGeneration {
	NSString *typed = query.length > 0 ? query : emoji;
	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService searchStickersByEmoji:emoji query:query limit:40
										completion:^(NSArray *stickers) {
											TGStickerPanelView *strongSelf = weakSelf;
											if (strongSelf == nil)
												return;
											if ([strongSelf searchStillCurrent:typed generation:generation searchGeneration:searchGeneration]) {
												NSMutableDictionary *section = [strongSelf searchResultSectionForStickers:stickers];
												if (section != nil)
													[strongSelf addSearchSection:section order:0];
											}
											[strongSelf searchRequestFinishedForGeneration:generation searchGeneration:searchGeneration];
										}];
}

- (void)runStickerSearchForQuery:(NSString *)query
					  generation:(NSInteger)generation
				searchGeneration:(NSInteger)searchGeneration {
	if ([query canBeConvertedToEncoding:NSASCIIStringEncoding]) {
		__weak TGStickerPanelView *weakSelf = self;
		[TGStickerCatalogService allStickerEmojisForQuery:query completion:^(NSArray *emojis) {
			TGStickerPanelView *strongSelf = weakSelf;
			if (strongSelf == nil)
				return;
			if (![strongSelf searchStillCurrent:query generation:generation searchGeneration:searchGeneration]) {
				[strongSelf searchRequestFinishedForGeneration:generation searchGeneration:searchGeneration];
				return;
			}

			if (emojis.count > 0) {
				NSArray *head = emojis.count > 5 ? [emojis subarrayWithRange:NSMakeRange(0, 5)] : emojis;
				[strongSelf searchStickersByEmoji:[head componentsJoinedByString:@" "] forQuery:query
							   generation:generation
						 searchGeneration:searchGeneration];
				return;
			}

			void (^installedCompletion)(NSArray *) = ^(NSArray *stickers) {
				TGStickerPanelView *innerSelf = weakSelf;
				if (innerSelf == nil)
					return;
				if ([innerSelf searchStillCurrent:query generation:generation searchGeneration:searchGeneration]) {
					NSMutableDictionary *section = [innerSelf searchResultSectionForStickers:stickers];
					if (section != nil)
						[innerSelf addSearchSection:section order:0];
				}
				[innerSelf searchRequestFinishedForGeneration:generation searchGeneration:searchGeneration];
			};
			[TGStickerCatalogService installedStickersMatching:query limit:40 completion:installedCompletion];
		}];
		return;
	}

	[self searchStickersByEmoji:query forQuery:nil generation:generation
			   searchGeneration:searchGeneration];
}

- (void)runPublicSetSearchForQuery:(NSString *)query
						generation:(NSInteger)generation
				  searchGeneration:(NSInteger)searchGeneration {
	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService searchStickerSets:query completion:^(NSArray *sets) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if ([strongSelf searchStillCurrent:query generation:generation searchGeneration:searchGeneration]) {
			NSInteger added = 0;
			for (NSDictionary *set in sets) {
				if (added >= 6)
					break;
				NSNumber *setId = set[@"id"];
				if ([strongSelf knowsSetId:setId])
					continue;
				NSMutableDictionary *section = [strongSelf sectionForSet:set kind:kStickerSectionPublicSet];
				if (section == nil)
					continue;
				section[@"serverMatch"] = query;
				[strongSelf insertSearchSection:section order:1];
				added += 1;
			}

			if (added > 0) {
				[strongSelf applyFilter];
				[strongSelf updateStatus];
			}
		}
		[strongSelf searchRequestFinishedForGeneration:generation searchGeneration:searchGeneration];
	}];
}

- (void)runServerSearch {
	NSString *query = self.searchQuery;
	if (query.length == 0)
		return;

	self.searchGeneration += 1;
	NSInteger searchGeneration = self.searchGeneration;
	NSInteger generation = self.generation;
	self.searchOutstanding = 3;
	self.searchLoading = YES;

	[self runStickerSearchForQuery:query generation:generation searchGeneration:searchGeneration];
	[self runPublicSetSearchForQuery:query generation:generation searchGeneration:searchGeneration];

	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService searchInstalledStickerSets:query limit:40 completion:^(NSArray *sets) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (strongSelf.generation == generation && strongSelf.searchGeneration == searchGeneration &&
			sets.count > 0 && [strongSelf.searchQuery isEqualToString:query]) {
			NSMutableSet *ids = [[NSMutableSet alloc] init];
			for (NSDictionary *set in sets) {
				NSNumber *setId = set[@"id"];
				if (setId != nil)
					[ids addObject:setId];
			}

			BOOL changed = NO;
			for (NSMutableDictionary *section in strongSelf.allSections) {
				NSNumber *setId = section[@"setId"];
				if (setId != nil && [ids containsObject:setId] &&
					![section[@"serverMatch"] isEqualToString:query]) {
					section[@"serverMatch"] = query;
					changed = YES;
				}
			}
			if (changed) {
				[strongSelf applyFilter];
				[strongSelf updateStatus];
			}
		}
		[strongSelf searchRequestFinishedForGeneration:generation searchGeneration:searchGeneration];
	}];
}

- (void)searchRequestFinishedForGeneration:(NSInteger)generation
						  searchGeneration:(NSInteger)searchGeneration {
	if (self.generation != generation || self.searchGeneration != searchGeneration)
		return;
	if (self.searchOutstanding > 0)
		self.searchOutstanding -= 1;
	if (self.searchOutstanding == 0) {
		self.searchLoading = NO;
		[self updateStatus];
	}
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	NSString *query = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([query isEqualToString:self.searchQuery])
		return;

	self.searchQuery = query;
	self.searchGeneration += 1;
	self.searchLoading = (query.length > 0);
	self.searchOutstanding = 0;
	[self.searchSections removeAllObjects];
	[self applyFilter];
	[self updateStatus];

	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runServerSearch)
											   object:nil];
	if (query.length > 0)
		[self performSelector:@selector(runServerSearch) withObject:nil afterDelay:0.3];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[self setSearchVisible:NO];
}

@end
