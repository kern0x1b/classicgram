#import "TGStickerPanelView.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import "TGStickerCatalogService.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGStickerPanelView (Tiles)

#pragma mark - tiles

- (void)clearTiles {
	for (NSString *key in [self.visibleTiles allKeys]) {
		TGStickerTile *tile = self.visibleTiles[key];
		[self releaseImageForTile:tile];
		[self.recycler recycleView:tile];
	}
	[self.visibleTiles removeAllObjects];
}

- (void)updateVisibleTiles {
	if (self.sections.count == 0)
		return;

	CGFloat row = self.tileSide + self.rowSpacing;
	CGRect visible = CGRectMake(0, self.grid.contentOffset.y - row,
		self.grid.bounds.size.width, self.grid.bounds.size.height + row * 2.0f);

	NSMutableSet *wanted = [[NSMutableSet alloc] init];
	NSMutableArray *nowViewed = nil;

	for (NSInteger s = 0; s < (NSInteger)self.sections.count; s++) {
		NSMutableDictionary *section = self.sections[s];
		CGFloat sectionY = [section[@"y"] floatValue];
		CGFloat sectionHeight = [section[@"height"] floatValue];
		if (sectionY + sectionHeight < CGRectGetMinY(visible) || sectionY > CGRectGetMaxY(visible))
			continue;

		if ([section[@"kind"] integerValue] == kStickerSectionTrending &&
			section[@"viewedSent"] == nil && section[@"setId"] != nil) {
			section[@"viewedSent"] = @YES;
			if (nowViewed == nil)
				nowViewed = [[NSMutableArray alloc] init];
			[nowViewed addObject:section[@"setId"]];
		}

		NSArray *stickers = section[@"stickers"];
		NSInteger count = [section[@"count"] integerValue];
		NSInteger highestWanted = -1;

		for (NSInteger i = 0; i < count; i++) {
			CGRect frame = [self frameForItem:i inSection:s];
			if (CGRectGetMaxY(frame) < CGRectGetMinY(visible))
				continue;
			if (frame.origin.y > CGRectGetMaxY(visible))
				break;

			highestWanted = i;
			NSString *key = [NSString stringWithFormat:@"%d.%d", (int)s, (int)i];
			[wanted addObject:key];

			TGStickerTile *tile = self.visibleTiles[key];
			if (tile == nil) {
				tile = (TGStickerTile *)[self.recycler dequeueReusableViewWithIdentifier:@"stickerTile"];
				if (tile == nil)
					tile = [[TGStickerTile alloc] initWithFrame:frame];
				[tile addTarget:self action:@selector(tileTapped:)
					forControlEvents:UIControlEventTouchUpInside];
				UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
					initWithTarget:self
							action:@selector(tileLongPressed:)];
				press.minimumPressDuration = 0.2;
				[tile addGestureRecognizer:press];
				[self.grid addSubview:tile];
				self.visibleTiles[key] = tile;
			}
			tile.frame = frame;
			tile.sectionIndex = s;
			tile.itemIndex = i;

			NSDictionary *sticker = (stickers != nil && i < (NSInteger)stickers.count) ? stickers[i] : nil;
			[self configureTile:tile withSticker:sticker];
		}

		[self ensureSection:s loadedUpToItem:MAX(highestWanted, 0)];
	}

	for (NSString *key in [self.visibleTiles allKeys]) {
		if ([wanted containsObject:key])
			continue;
		[self releaseImageForTile:self.visibleTiles[key]];
		[self.recycler recycleView:self.visibleTiles[key]];
		[self.visibleTiles removeObjectForKey:key];
	}

	if (nowViewed.count > 0)
		[TGStickerCatalogService markTrendingStickerSetsViewed:nowViewed];

	[self reportOpenTiming];
	[self purgeDistantSectionsAggressively:NO];
}

- (void)reportOpenTiming {
	if (self.openTimingReported || self.visibleTiles.count == 0)
		return;
	for (NSString *key in self.visibleTiles) {
		TGStickerTile *tile = self.visibleTiles[key];

		if (tile.sticker == nil || tile.imageToken != nil)
			return;
	}

	self.openTimingReported = YES;
	NSLog(@"PERF stickers open +%.0f ms: %lu tiles, %@, %@",
		([NSDate timeIntervalSinceReferenceDate] - self.openedAt) * 1000.0,
		(unsigned long)self.visibleTiles.count,
		self.restoredFromSnapshot ? @"restored" : @"cold",
		[TGStickerThumbnailCache statisticsSummary]);
}

- (void)purgeDistantSectionsAggressively:(BOOL)aggressive {
	CGFloat offset = self.grid.contentOffset.y;
	CGFloat height = self.grid.bounds.size.height;

	NSMutableArray *candidates = [[NSMutableArray alloc] initWithArray:self.allSections];
	for (NSMutableDictionary *section in self.searchSections) {
		if ([candidates indexOfObjectIdenticalTo:section] == NSNotFound)
			[candidates addObject:section];
	}

	for (NSMutableDictionary *section in candidates) {
		NSInteger kind = [section[@"kind"] integerValue];
		if (!TGStickerSectionIsSet(kind))
			continue;
		if (section[@"stickers"] == nil || [section[@"loading"] boolValue])
			continue;

		BOOL displayed = ([self.sections indexOfObjectIdenticalTo:section] != NSNotFound);
		BOOL purge = !displayed;
		if (displayed) {
			NSNumber *y = section[@"y"];
			if (y == nil)
				purge = YES;
			else {
				CGFloat top = [y floatValue];
				CGFloat bottom = top + [section[@"height"] floatValue];
				CGFloat distance = 0.0f;
				if (bottom < offset)
					distance = offset - bottom;
				else if (top > offset + height)
					distance = top - (offset + height);
				purge = (distance > (aggressive ? 0.0f : kStickerPanelPurgeDistance));
			}
		}

		if (!purge)
			continue;

		[section removeObjectForKey:@"stickers"];
		[section removeObjectForKey:@"loadedCount"];
		[section removeObjectForKey:@"complete"];
	}
}

- (void)configureTile:(TGStickerTile *)tile withSticker:(NSDictionary *)sticker {
	if (sticker == nil) {
		[self releaseImageForTile:tile];
		tile.sticker = nil;
		tile.emojiLabel.text = @"";
		tile.imageView.image = nil;
		tile.imageView.alpha = 1.0f;
		return;
	}

	NSString *emoji = sticker[@"emoji"];
	long long fileId = [self drawableFileIdForSticker:sticker];
	NSString *uniqueId = [self drawableUniqueIdForSticker:sticker];

	if (fileId == 0 && uniqueId.length == 0) {
		[self releaseImageForTile:tile];
		tile.sticker = sticker;
		tile.emojiLabel.text = emoji.length > 0 ? emoji : @"";
		tile.imageView.image = nil;
		tile.imageView.alpha = 1.0f;
		return;
	}

	CGFloat side = self.tileSide;
	NSString *key = [NSString stringWithFormat:@"%@|%lld@%d", uniqueId, fileId, (int)side];
	UIImage *cached = [TGStickerThumbnailCache cachedThumbnailForUniqueId:uniqueId side:side];
	if (cached != nil) {
		[self releaseImageForTile:tile];
		tile.sticker = sticker;
		tile.emojiLabel.text = @"";
		tile.imageView.image = cached;
		tile.imageView.alpha = 1.0f;
		return;
	}

	if (tile.sticker == sticker && [tile.imageKey isEqualToString:key])
		return;

	[self releaseImageForTile:tile];
	tile.sticker = sticker;
	tile.emojiLabel.text = emoji.length > 0 ? emoji : @"";
	tile.imageView.image = nil;
	tile.imageView.alpha = 1.0f;
	tile.imageKey = key;

	NSDictionary *requested = sticker;
	__weak TGStickerTile *weakTile = tile;
	id token = [TGStickerThumbnailCache
		thumbnailForFileId:fileId
				  uniqueId:uniqueId
					  side:side
				completion:^(UIImage *image) {
					TGStickerTile *target = weakTile;
					if (target == nil)
						return;
					if (target.sticker != requested || ![target.imageKey isEqualToString:key])
						return;
					target.imageToken = nil;
					if (image == nil)
						return;
					target.imageKey = nil;
					target.imageView.image = image;
					target.emojiLabel.text = @"";
					target.imageView.alpha = 0.0f;
					[UIView animateWithDuration:0.15 animations:^{
						target.imageView.alpha = 1.0f;
					}];
				}];
	tile.imageToken = token;
}

- (long long)drawableFileIdForSticker:(NSDictionary *)sticker {
	BOOL drawable = ![sticker[@"isVideo"] boolValue] && ![sticker[@"isAnimated"] boolValue];
	long long thumbId = [sticker[@"thumbId"] longLongValue];
	if (thumbId != 0)
		return thumbId;
	return drawable ? [sticker[@"fileId"] longLongValue] : 0;
}

- (NSString *)drawableUniqueIdForSticker:(NSDictionary *)sticker {
	BOOL drawable = ![sticker[@"isVideo"] boolValue] && ![sticker[@"isAnimated"] boolValue];
	NSString *thumbUniqueId = sticker[@"thumbUniqueId"];
	if ([sticker[@"thumbId"] longLongValue] != 0)
		return [thumbUniqueId isKindOfClass:[NSString class]] ? thumbUniqueId : @"";
	if (!drawable)
		return @"";
	NSString *uniqueId = sticker[@"uniqueId"];
	return [uniqueId isKindOfClass:[NSString class]] ? uniqueId : @"";
}

@end
