#import "TGArchivedCount.h"
#import "TGStickerFavouriteAction.h"
#import "TGStickersViewController.h"
#import "TGClient+Files.h"
#import "TGStickersViewControllerInternal.h"
#import "TGClient+Stickers.h"
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
#import "TGHexColour.h"

@implementation TGStickersViewController (Loading)

#pragma mark - loading

- (void)reload {
	if (self.searching)
		return;
	if ([self isMaskPage]) {
		[self reloadMasks];
		return;
	}
	if ([self isEmojiListPage]) {
		[self reloadEmojiSets];
		return;
	}
	if ([self isTrendingPage]) {
		[self reloadTrending];
		return;
	}
	if ([self isArchivePage]) {
		[self reloadArchived];
		return;
	}
	if ((NSInteger)self.page == kStickersPageRecent) {
		[self reloadRecent];
		return;
	}
	if ((NSInteger)self.page == kStickersPagePremium) {
		[self reloadPremium];
		return;
	}
	if ((NSInteger)self.page == kStickersPageGreeting) {
		[self reloadGreeting];
		return;
	}
	switch (self.page) {
		case TGStickersPageFavourites:
			[self reloadFavourites];
			break;
		case TGStickersPageSet:
			[self reloadSet];
			break;
		default:
			[self reloadRoot];
			break;
	}
}

- (void)fetchArchivedFromSetId:(int64_t)offsetSetId
					completion:(void (^)(NSArray *sets, NSInteger totalCount))completion {
	TGClient *client = [TGClient shared];
	if ((NSInteger)self.page == kStickersPageEmojiArchived)
		[client archivedEmojiStickerSetsFromSetId:offsetSetId limit:kArchivedPageSize completion:completion];
	else if ((NSInteger)self.page == kStickersPageMasksArchived)
		[client archivedMaskStickerSetsFromSetId:offsetSetId limit:kArchivedPageSize completion:completion];
	else
		[client archivedStickerSetsFromSetId:offsetSetId limit:kArchivedPageSize completion:completion];
}

- (void)fetchTrendingFromOffset:(NSInteger)offset
					 completion:(void (^)(NSArray *sets, NSInteger totalCount))completion {
	TGClient *client = [TGClient shared];
	if ((NSInteger)self.page == kStickersPageEmojiTrending)
		[client trendingEmojiStickerSetsWithOffset:offset limit:kTrendingPageSize completion:completion];
	else
		[client trendingStickerSetsWithOffset:offset limit:kTrendingPageSize completion:completion];
}

- (void)reloadEmojiSets {
	if (!self.loaded)
		[self showLoading];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] installedEmojiStickerSetsWithCompletion:^(NSArray *sets) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if (!sets && strongSelf.sets.count == 0) {
			[strongSelf showFailure];
			return;
		}
		if (sets)
			strongSelf.sets = [NSMutableArray arrayWithArray:sets];
		strongSelf.emojiSetCount = (NSInteger)strongSelf.sets.count;
		[strongSelf showContent];
		[strongSelf.table reloadData];
		[strongSelf installEditButton];
	}];

	[[TGClient shared] archivedEmojiStickerSetsFromSetId:0 limit:kArchivedPageSize completion:^(NSArray *sets, NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !sets)
			return;
		strongSelf.archivedCount = TGArchivedCount(total, sets.count, kArchivedPageSize);
		[strongSelf reloadSubpageSection];
	}];

	[[TGClient shared] trendingEmojiStickerSetsWithOffset:0 limit:kTrendingPageSize completion:^(NSArray *sets, NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !sets)
			return;
		strongSelf.subpageTrendingCount = total > 0 ? total : (NSInteger)sets.count;
		[strongSelf reloadSubpageSection];
	}];
}

- (void)reloadSubpageSection {
	if (![self isTwoSectionListPage] || self.table.hidden || !self.loaded)
		return;
	if ([self.table numberOfSections] < 2)
		return;
	[self.table reloadSections:[NSIndexSet indexSetWithIndex:0]
			  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)reloadRecent {
	[self showLoading];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recentStickersAttached:NO completion:^(NSArray *stickers) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if (!stickers) {
			[strongSelf showFailure];
			return;
		}
		strongSelf.stickers = stickers;
		strongSelf.recentCount = (NSInteger)stickers.count;
		[strongSelf showContent];
		[strongSelf.table reloadData];
	}];
}

- (void)reloadPremium {
	[self showLoading];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] premiumStickersWithLimit:kPremiumLimit completion:^(NSArray *stickers) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if (!stickers) {
			[strongSelf showFailure];
			return;
		}
		strongSelf.stickers = stickers;
		[strongSelf showContent];
		[strongSelf.table reloadData];
	}];
}

- (void)reloadGreeting {
	[self showLoading];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] greetingStickersWithCompletion:^(NSArray *stickers) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if (!stickers) {
			[strongSelf showFailure];
			return;
		}
		strongSelf.stickers = stickers;
		[strongSelf showContent];
		[strongSelf.table reloadData];
	}];
}

- (void)reloadRoot {
	if (!self.loaded)
		[self showLoading];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] installedStickerSetsWithCompletion:^(NSArray *sets) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		strongSelf.failed = (sets == nil);
		if (sets)
			strongSelf.sets = [NSMutableArray arrayWithArray:sets];
		if (strongSelf.failed && strongSelf.sets.count == 0) {
			[strongSelf showFailure];
			return;
		}
		[strongSelf showContent];
		[strongSelf.table reloadData];
		[strongSelf installEditButton];
	}];

	[[TGClient shared] favoriteStickersWithCompletion:^(NSArray *stickers) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !stickers)
			return;
		strongSelf.favouriteCount = (NSInteger)stickers.count;
		[strongSelf reloadFirstSection];
	}];

	[[TGClient shared] archivedStickerSetsFromSetId:0 limit:kArchivedPageSize
										 completion:^(NSArray *sets, NSInteger total) {
											 __strong typeof(weakSelf) strongSelf = weakSelf;
											 if (!strongSelf || !sets)
												 return;
											 strongSelf.archivedCount = TGArchivedCount(total, sets.count, kArchivedPageSize);
											 [strongSelf reloadFirstSection];
										 }];

	[[TGClient shared] trendingStickerSetsWithOffset:0 limit:kTrendingPageSize completion:^(NSArray *sets, NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !sets)
			return;
		NSInteger unseen = 0;
		for (NSDictionary *set in sets)
			if (![set[@"viewed"] boolValue])
				unseen++;
		strongSelf.trendingNewCount = unseen;
		[strongSelf reloadFirstSection];
	}];

	[[TGClient shared] installedMaskStickerSetsWithCompletion:^(NSArray *sets) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !sets)
			return;
		NSInteger count = (NSInteger)sets.count;
		if (count == strongSelf.maskCount)
			return;
		strongSelf.maskCount = count;
		if (strongSelf.table.hidden || !strongSelf.loaded || strongSelf.reordering)
			return;
		[strongSelf.table reloadData];
	}];

	[[TGClient shared] recentStickersAttached:NO completion:^(NSArray *stickers) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !stickers)
			return;
		strongSelf.recentCount = (NSInteger)stickers.count;
		[strongSelf reloadFirstSection];
	}];

	[[TGClient shared] installedEmojiStickerSetsWithCompletion:^(NSArray *sets) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !sets)
			return;
		strongSelf.emojiSetCount = (NSInteger)sets.count;
		[strongSelf reloadFirstSection];
	}];

	if (![[NSUserDefaults standardUserDefaults] objectForKey:TGStickerSuggestModeKey]) {
		[[NSUserDefaults standardUserDefaults] setInteger:TGStickerSuggestModeAll
													forKey:TGStickerSuggestModeKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self reloadSettingsSection];
	}
}

- (void)reloadSettingsSection {
	if (self.page != TGStickersPageRoot || self.table.hidden || !self.loaded)
		return;
	[self.table reloadSections:[NSIndexSet indexSetWithIndex:kRootSectionSettings]
			  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)reloadMasks {
	if (!self.loaded)
		[self showLoading];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] installedMaskStickerSetsWithCompletion:^(NSArray *sets) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if (!sets && strongSelf.sets.count == 0) {
			[strongSelf showFailure];
			return;
		}
		if (sets)
			strongSelf.sets = [NSMutableArray arrayWithArray:sets];
		strongSelf.maskCount = (NSInteger)strongSelf.sets.count;
		[strongSelf showContent];
		[strongSelf.table reloadData];
		[strongSelf installEditButton];
	}];

	[[TGClient shared] archivedMaskStickerSetsFromSetId:0 limit:kArchivedPageSize completion:^(NSArray *sets, NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !sets)
			return;
		strongSelf.archivedCount = TGArchivedCount(total, sets.count, kArchivedPageSize);
		[strongSelf reloadSubpageSection];
	}];
}

- (void)reloadFirstSection {
	if (self.page != TGStickersPageRoot || self.table.hidden || !self.loaded)
		return;
	[self.table reloadSections:[NSIndexSet indexSetWithIndex:kRootSectionPages]
			  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)reloadArchivedCountBadge {
	if ([self isTwoSectionListPage]) {
		[self reloadSubpageSection];
		return;
	}
	[self reloadFirstSection];
}

- (void)reloadTrending {
	[self showLoading];
	__weak typeof(self) weakSelf = self;
	[self fetchTrendingFromOffset:0 completion:^(NSArray *sets, NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		strongSelf.totalRemote = total;
		if (!sets) {
			[strongSelf showFailure];
			return;
		}
		strongSelf.sets = [NSMutableArray arrayWithArray:sets];
		strongSelf.trendingOffset = (NSInteger)sets.count;
		strongSelf.exhausted = total > 0 ? (strongSelf.trendingOffset >= total)
										  : (sets.count == 0);
		[strongSelf showContent];
		[strongSelf.table reloadData];
		[strongSelf markShownSetsViewed];
	}];
}

- (void)loadMoreTrending {
	if (self.searching)
		return;
	if (self.loadingMore || self.exhausted || self.sets.count == 0)
		return;
	self.loadingMore = YES;

	__weak typeof(self) weakSelf = self;
	[self fetchTrendingFromOffset:self.trendingOffset
					   completion:^(NSArray *sets, NSInteger total) {
						   __strong typeof(weakSelf) strongSelf = weakSelf;
						   if (!strongSelf)
							   return;
						   strongSelf.loadingMore = NO;
						   if (total > 0)
							   strongSelf.totalRemote = total;
						   if (sets.count == 0) {
							   strongSelf.exhausted = YES;
							   return;
						   }

						   NSMutableSet *known = [NSMutableSet set];
						   for (NSDictionary *existing in strongSelf.sets)
							   if (existing[@"id"])
								   [known addObject:existing[@"id"]];
						   NSMutableArray *fresh = [NSMutableArray array];
						   for (NSDictionary *set in sets)
							   if (!set[@"id"] || ![known containsObject:set[@"id"]])
								   [fresh addObject:set];

						   strongSelf.trendingOffset += (NSInteger)sets.count;
						   strongSelf.exhausted = total > 0 ? (strongSelf.trendingOffset >= total) : NO;
						   if (fresh.count == 0) {
							   [strongSelf loadMoreTrending];
							   return;
						   }
						   [strongSelf.sets addObjectsFromArray:fresh];
						   [strongSelf.table reloadData];
						   [strongSelf markSetsViewed:fresh];
					   }];
}

- (void)markShownSetsViewed {
	[self markSetsViewed:self.sets];
}

- (void)markSetsViewed:(NSArray *)sets {
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *set in sets)
		if (![set[@"viewed"] boolValue] && set[@"id"])
			[ids addObject:set[@"id"]];
	if (ids.count)
		[[TGClient shared] markTrendingStickerSetsViewed:ids];
}

- (void)reloadArchived {
	[self showLoading];
	__weak typeof(self) weakSelf = self;
	[self fetchArchivedFromSetId:0 completion:^(NSArray *sets, NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		strongSelf.totalRemote = total;
		if (!sets) {
			[strongSelf showFailure];
			return;
		}
		strongSelf.sets = [NSMutableArray arrayWithArray:sets];
		strongSelf.exhausted = ((NSInteger)sets.count < kArchivedPageSize);
		if (strongSelf.sets.count == 0) {
			[strongSelf.navigationController popViewControllerAnimated:YES];
			return;
		}
		[strongSelf showContent];
		[strongSelf.table reloadData];
	}];
}

- (void)loadMoreArchived {
	if (self.searching)
		return;
	if (self.loadingMore || self.exhausted || self.sets.count == 0)
		return;
	self.loadingMore = YES;
	int64_t last = [[self.sets lastObject][@"id"] longLongValue];

	__weak typeof(self) weakSelf = self;
	[self fetchArchivedFromSetId:last completion:^(NSArray *sets, NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loadingMore = NO;
		strongSelf.totalRemote = total;
		if (sets.count == 0) {
			strongSelf.exhausted = YES;
			[strongSelf.table reloadData];
			return;
		}
		strongSelf.exhausted = ((NSInteger)sets.count < kArchivedPageSize);
		[strongSelf.sets addObjectsFromArray:sets];
		[strongSelf.table reloadData];
	}];
}

- (void)reloadFavourites {
	[self showLoading];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] favoriteStickersWithCompletion:^(NSArray *stickers) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if (!stickers) {
			[strongSelf showFailure];
			return;
		}
		strongSelf.stickers = stickers;
		[strongSelf showContent];
		[strongSelf.table reloadData];
	}];
}

- (void)reloadSet {
	[self showLoading];
	int64_t identifier = self.setId ?: [self.set[@"id"] longLongValue];
	if (identifier == 0) {
		[self showFailure];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickerSetWithId:identifier completion:^(NSDictionary *set) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if (!set) {
			[strongSelf showFailure];
			return;
		}
		NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:set];
		if (strongSelf.installedHere)
			merged[@"installed"] = @YES;
		strongSelf.set = merged;
		strongSelf.title = [strongSelf pageTitle];
		strongSelf.stickers = set[@"stickers"];
		[strongSelf refreshSetBarButton];
		[strongSelf refreshBottomBar];
		[strongSelf showContent];
		[strongSelf.table reloadData];
		[strongSelf refreshBottomBar];
	}];
}

#pragma mark - images

- (void)flushCovers {
	[self.covers removeAllObjects];
	[self.coverOrder removeAllObjects];
	self.coverBytes = 0;
}

- (NSUInteger)byteCostOfImage:(UIImage *)image {
	CGImageRef bitmap = image.CGImage;
	if (!bitmap)
		return 4096;
	return CGImageGetWidth(bitmap) * CGImageGetHeight(bitmap) * 4;
}

- (void)storeCover:(UIImage *)image forKey:(NSString *)key {
	if (!image || !key)
		return;

	UIImage *existing = self.covers[key];
	if (existing) {
		self.coverBytes -= MIN(self.coverBytes, [self byteCostOfImage:existing]);
		[self.coverOrder removeObject:key];
	}

	self.covers[key] = image;
	[self.coverOrder addObject:key];
	self.coverBytes += [self byteCostOfImage:image];

	while (self.coverOrder.count > 1 &&
		(self.coverBytes > kCoverCacheByteLimit ||
			self.covers.count > kCoverCacheLimit)) {
		NSString *oldest = self.coverOrder[0];
		UIImage *evicted = self.covers[oldest];
		self.coverBytes -= MIN(self.coverBytes, [self byteCostOfImage:evicted]);
		[self.covers removeObjectForKey:oldest];
		[self.coverOrder removeObjectAtIndex:0];
	}
}

- (UIImage *)scale:(UIImage *)image toSide:(CGFloat)side {
	if (!image)
		return nil;
	CGFloat scale = [UIScreen mainScreen].scale;
	CGFloat width = image.size.width;
	CGFloat height = image.size.height;
	if (width <= 0 || height <= 0)
		return nil;
	CGFloat factor = MIN(side / width, side / height);
	CGSize target = CGSizeMake(floorf(width * factor), floorf(height * factor));
	if (target.width < 1 || target.height < 1)
		return nil;

	UIGraphicsBeginImageContextWithOptions(target, NO, scale);
	[image drawInRect:CGRectMake(0, 0, target.width, target.height)];
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

- (BOOL)stickerIsStill:(NSDictionary *)sticker {
	return !([sticker[@"isAnimated"] boolValue] || [sticker[@"isVideo"] boolValue]);
}

- (UIImage *)imageForFileId:(long long)fileId side:(CGFloat)side
				  indexPath:(NSIndexPath *)indexPath {
	if (fileId == 0)
		return nil;
	NSString *key = TGStickersCacheKey(fileId, side);
	UIImage *cached = self.covers[key];
	if (cached)
		return cached;
	if ([self.coversInFlight containsObject:key])
		return nil;
	[self.coversInFlight addObject:key];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId completion:^(NSString *path) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.coversInFlight removeObject:key];
		if (!path)
			return;
		UIImage *small = nil;
		@autoreleasepool {
			UIImage *decoded = [UIImage convertFromWebP:path compressedData:nil error:nil];
			small = [strongSelf scale:decoded toSide:side];
		}
		if (!small)
			return;
		[strongSelf storeCover:small forKey:key];
		if (!indexPath)
			return;
		if (indexPath.section >= [strongSelf.table numberOfSections])
			return;
		if (indexPath.row >= [strongSelf.table numberOfRowsInSection:indexPath.section])
			return;
		if (![strongSelf.table cellForRowAtIndexPath:indexPath])
			return;
		[strongSelf.table reloadRowsAtIndexPaths:@[ indexPath ]
								withRowAnimation:UITableViewRowAnimationNone];
	}];
	return nil;
}

- (UIImage *)renderOutlinePaths:(NSArray *)paths
						  width:(CGFloat)width
						 height:(CGFloat)height
						   side:(CGFloat)side {
	if (paths.count == 0 || width <= 0 || height <= 0)
		return nil;

	CGFloat factor = MIN(side / width, side / height);
	CGSize target = CGSizeMake(floorf(width * factor), floorf(height * factor));
	if (target.width < 1 || target.height < 1)
		return nil;

	UIBezierPath *bezier = [UIBezierPath bezierPath];
	for (NSArray *path in paths) {
		if (![path isKindOfClass:[NSArray class]] || path.count == 0)
			continue;
		NSInteger index = 0;
		for (NSDictionary *command in path) {
			if (![command isKindOfClass:[NSDictionary class]])
				continue;
			CGPoint point = CGPointMake([command[@"x"] doubleValue] * factor,
				[command[@"y"] doubleValue] * factor);
			if (index == 0) {
				[bezier moveToPoint:point];
			} else if ([command[@"type"] isEqualToString:@"curve"]) {
				CGPoint control1 = CGPointMake([command[@"c1x"] doubleValue] * factor,
					[command[@"c1y"] doubleValue] * factor);
				CGPoint control2 = CGPointMake([command[@"c2x"] doubleValue] * factor,
					[command[@"c2y"] doubleValue] * factor);
				[bezier addCurveToPoint:point controlPoint1:control1 controlPoint2:control2];
			} else {
				[bezier addLineToPoint:point];
			}
			index++;
		}
		[bezier closePath];
	}
	if (bezier.isEmpty)
		return nil;

	UIImage *result = nil;
	@autoreleasepool {
		UIGraphicsBeginImageContextWithOptions(target, NO, [UIScreen mainScreen].scale);
		UIColor *fill = TGColourFromHex(0xd8dde2);
		[fill setFill];
		[bezier fill];
		result = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	}
	return result;
}

- (UIImage *)outlineForSticker:(NSDictionary *)sticker
						  side:(CGFloat)side
					 indexPath:(NSIndexPath *)indexPath {
	long long fileId = [sticker[@"fileId"] longLongValue];
	if (fileId == 0)
		return nil;

	NSString *key = [@"o" stringByAppendingString:TGStickersCacheKey(fileId, side)];
	UIImage *cached = self.covers[key];
	if (cached)
		return cached;
	if ([self.coversInFlight containsObject:key])
		return nil;
	[self.coversInFlight addObject:key];

	CGFloat width = [sticker[@"width"] doubleValue];
	CGFloat height = [sticker[@"height"] doubleValue];
	if (width <= 0 || height <= 0) {
		width = 512;
		height = 512;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickerOutlineForFileId:fileId completion:^(NSArray *paths) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.coversInFlight removeObject:key];
		UIImage *outline = [strongSelf renderOutlinePaths:paths width:width height:height side:side];
		if (!outline)
			return;
		[strongSelf storeCover:outline forKey:key];
		if (!indexPath)
			return;
		if (indexPath.section >= [strongSelf.table numberOfSections])
			return;
		if (indexPath.row >= [strongSelf.table numberOfRowsInSection:indexPath.section])
			return;
		if (![strongSelf.table cellForRowAtIndexPath:indexPath])
			return;
		[strongSelf.table reloadRowsAtIndexPaths:@[ indexPath ]
								withRowAnimation:UITableViewRowAnimationNone];
	}];
	return nil;
}

- (long long)coverFileIdForSet:(NSDictionary *)set {
	NSArray *covers = set[@"covers"];
	for (NSDictionary *sticker in covers) {
		if (![self stickerIsStill:sticker])
			continue;
		return [sticker[@"fileId"] longLongValue];
	}
	return 0;
}

- (UIImage *)coverForSet:(NSDictionary *)set atIndexPath:(NSIndexPath *)indexPath {
	return [self imageForFileId:[self coverFileIdForSet:set] side:kCoverSide
					  indexPath:indexPath];
}

#pragma mark - grid

- (NSInteger)gridColumns {
	CGFloat width = self.table.bounds.size.width;
	if (width <= 0)
		width = self.view.bounds.size.width;
	NSInteger columns = (NSInteger)floorf((width - kTileInset * 2 + kTileGap) /
		(kTileSide + kTileGap));
	if (columns < 3)
		columns = 3;
	return columns;
}

- (NSInteger)gridRowCount {
	NSInteger columns = [self gridColumns];
	return ((NSInteger)self.stickers.count + columns - 1) / columns;
}

- (UITableViewCell *)tilesCellForTable:(UITableView *)tableView
							 indexPath:(NSIndexPath *)indexPath {
	TGStickerTilesCell *cell = (TGStickerTilesCell *)
		[tableView dequeueReusableCellWithIdentifier:@"tiles"];
	if (!cell)
		cell = [[TGStickerTilesCell alloc] initWithStyle:UITableViewCellStyleDefault
										 reuseIdentifier:@"tiles"];

	NSInteger columns = [self gridColumns];
	NSInteger first = indexPath.row * columns;
	NSInteger placed = 0;

	for (NSInteger column = 0; column < columns; column++) {
		NSInteger index = first + column;
		if (index >= (NSInteger)self.stickers.count)
			break;
		NSDictionary *sticker = self.stickers[index];

		UIButton *tile = [cell tileAtIndex:column];
		tile.frame = CGRectMake(kTileInset + column * (kTileSide + kTileGap), 3,
			kTileSide, kTileSide);
		tile.tag = index;
		[tile removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
		[tile addTarget:self action:@selector(tileTapped:)
			forControlEvents:UIControlEventTouchUpInside];

		UIImage *image = nil;
		if ([self stickerIsStill:sticker])
			image = [self imageForFileId:[sticker[@"fileId"] longLongValue] side:kTileSide
							   indexPath:indexPath];
		if (!image)
			image = [self outlineForSticker:sticker side:kTileSide indexPath:indexPath];
		if (image) {
			[tile setTitle:@"" forState:UIControlStateNormal];
			[tile setImage:image forState:UIControlStateNormal];
		} else {
			[tile setImage:nil forState:UIControlStateNormal];
			[tile setTitle:sticker[@"emoji"] forState:UIControlStateNormal];
		}
		placed++;
	}
	[cell hideTilesFromIndex:placed];
	return cell;
}

- (void)tileTapped:(UIButton *)tile {
	if (![self isGridPage])
		return;
	NSInteger index = tile.tag;
	if (index >= (NSInteger)self.stickers.count)
		return;
	NSDictionary *sticker = self.stickers[index];
	self.actionSheetSticker = sticker;

	if (self.page == TGStickersPageFavourites) {
		TGActionSheetAction *unfavourite = [TGActionSheetAction alloc];
		unfavourite = [unfavourite initWithTitle:TGL(@"Stickers.RemoveFromFavorites", @"Remove from Favourites")
										  action:@"removeFavourite"
											type:TGActionSheetActionTypeDestructive];
		TGActionSheetAction *cancel = [TGActionSheetAction alloc];
		cancel = [cancel initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel];
		NSArray *actions = @[ unfavourite, cancel ];
		[self presentSheetWithTitle:nil actions:actions];
		return;
	}

	long long fileId = [sticker[@"fileId"] longLongValue];
	if (fileId == 0)
		return;
	BOOL recent = ((NSInteger)self.page == kStickersPageRecent);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] isStickerFavoriteWithFileId:fileId completion:^(BOOL favourite, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || strongSelf.actionSheetSticker != sticker)
			return;
		NSMutableArray *actions = [NSMutableArray array];
		switch (TGStickerFavouriteActionFor(favourite, failed)) {
			case TGStickerFavouriteActionRemove:
				[actions addObject:[[TGActionSheetAction alloc]
									   initWithTitle:TGL(@"Stickers.RemoveFromFavorites", @"Remove from Favourites")
											  action:@"unfavouriteSticker"]];
				break;
			case TGStickerFavouriteActionAdd:
				[actions addObject:[[TGActionSheetAction alloc]
									   initWithTitle:TGL(@"Stickers.AddToFavorites", @"Add to Favourites")
											  action:@"favouriteSticker"]];
				break;
			case TGStickerFavouriteActionUnknown:
				break;
		}
		if (recent)
			[actions addObject:[[TGActionSheetAction alloc]
								   initWithTitle:TGL(@"Stickers.RemoveFromRecent", @"Remove from Recent")
										  action:@"removeRecent"
											type:TGActionSheetActionTypeDestructive]];
		TGActionSheetAction *cancel = [TGActionSheetAction alloc];
		cancel = [cancel initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel];
		[actions addObject:cancel];
		[strongSelf presentSheetWithTitle:sticker[@"emoji"] actions:actions];
	}];
}

@end
