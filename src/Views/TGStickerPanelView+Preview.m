#import "TGStickerPanelView.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import "TGStickerCatalogService.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"
#import "TGSnackbar.h"

@implementation TGStickerPanelView (Preview)

#pragma mark - preview

- (void)cancelPreviewLoad {
	if (self.previewToken != nil)
		[TGStickerThumbnailCache cancelRequest:self.previewToken];
	self.previewToken = nil;
}

- (void)layoutPreview {
	if (self.previewOverlay == nil || self.previewOverlay.hidden)
		return;
	UIView *host = self.previewOverlay.superview;
	if (host == nil)
		return;

	CGRect bounds = host.bounds;
	self.previewOverlay.frame = bounds;

	CGFloat side = MIN(kStickerPanelPreviewSide,
		MIN(bounds.size.width - 24.0f, bounds.size.height - 96.0f));
	if (side < 1.0f)
		side = 1.0f;
	CGFloat centreX = floorf(bounds.size.width / 2.0f);
	CGFloat centreY = floorf(bounds.size.height / 2.0f);
	self.previewImageView.frame = CGRectMake(floorf(centreX - side / 2.0f),
		floorf(centreY - side / 2.0f), side, side);
	self.previewPlate.frame = CGRectInset(self.previewImageView.frame, -14.0f, -14.0f);
	self.previewEmojiLabel.frame = CGRectMake(0,
		CGRectGetMinY(self.previewImageView.frame) - 48.0f, bounds.size.width, 38.0f);
}

- (void)showPreviewForSticker:(NSDictionary *)sticker {
	if (self.previewOverlay == nil) {
		self.previewOverlay = [[UIView alloc] initWithFrame:CGRectZero];
		self.previewOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45f];
		self.previewOverlay.userInteractionEnabled = NO;

		self.previewPlate = [[UIView alloc] initWithFrame:CGRectZero];
		self.previewPlate.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.94f];
		self.previewPlate.layer.cornerRadius = 10.0f;
		self.previewPlate.layer.borderWidth = 1.0f;
		self.previewPlate.layer.borderColor =
			[UIColor colorWithWhite:1.0f alpha:0.6f].CGColor;
		self.previewPlate.layer.shadowColor = [UIColor blackColor].CGColor;
		self.previewPlate.layer.shadowOffset = CGSizeMake(0, 2);
		self.previewPlate.layer.shadowOpacity = 0.45f;
		self.previewPlate.layer.shadowRadius = 8.0f;
		[self.previewOverlay addSubview:self.previewPlate];

		self.previewEmojiLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		self.previewEmojiLabel.backgroundColor = [UIColor clearColor];
		self.previewEmojiLabel.textAlignment = NSTextAlignmentCenter;
		self.previewEmojiLabel.font = [UIFont systemFontOfSize:32];
		[self.previewOverlay addSubview:self.previewEmojiLabel];

		self.previewImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
		[self.previewOverlay addSubview:self.previewImageView];
	}

	UIView *host = self.window ?: self;
	if (self.previewOverlay.superview != host)
		[host addSubview:self.previewOverlay];

	NSString *emoji = sticker[@"emoji"];
	self.previewEmojiLabel.text = [emoji isKindOfClass:[NSString class]] ? emoji : @"";
	self.previewOverlay.hidden = NO;
	[host bringSubviewToFront:self.previewOverlay];
	[self layoutPreview];

	CGFloat side = self.previewImageView.frame.size.width;
	long long fileId = [self drawableFileIdForSticker:sticker];
	NSString *uniqueId = [self drawableUniqueIdForSticker:sticker];

	UIImage *cached = [TGStickerThumbnailCache cachedThumbnailForUniqueId:uniqueId side:side];
	self.previewImageView.image = cached;
	if (cached != nil)
		return;

	self.previewImageView.image =
		[TGStickerThumbnailCache cachedThumbnailForUniqueId:uniqueId side:self.tileSide];

	[self cancelPreviewLoad];
	__weak TGStickerPanelView *weakSelf = self;
	self.previewToken = [TGStickerThumbnailCache thumbnailForFileId:fileId uniqueId:uniqueId side:side completion:^(UIImage *image) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil || image == nil)
			return;
		strongSelf.previewToken = nil;
		if (strongSelf.previewOverlay.hidden)
			return;
		strongSelf.previewImageView.image = image;
	}];
}

- (void)hidePreview {
	[self cancelPreviewLoad];
	if (self.previewOverlay == nil)
		return;
	self.previewOverlay.hidden = YES;
	self.previewImageView.image = nil;
	[self.previewOverlay removeFromSuperview];
}

- (void)tileLongPressed:(UILongPressGestureRecognizer *)recogniser {
	if (![recogniser.view isKindOfClass:[TGStickerTile class]])
		return;

	TGStickerTile *tile = (TGStickerTile *)recogniser.view;
	NSDictionary *sticker = tile.sticker;
	long long fileId = [sticker[@"fileId"] longLongValue];

	if (recogniser.state == UIGestureRecognizerStateBegan) {
		if (fileId == 0 || self.currentActionSheet != nil)
			return;
		[self showPreviewForSticker:sticker];
		return;
	}

	if (recogniser.state != UIGestureRecognizerStateEnded &&
		recogniser.state != UIGestureRecognizerStateCancelled &&
		recogniser.state != UIGestureRecognizerStateFailed)
		return;

	BOOL wasPreviewing = (self.previewOverlay != nil && !self.previewOverlay.hidden);
	[self hidePreview];

	if (!wasPreviewing || recogniser.state != UIGestureRecognizerStateEnded)
		return;
	if (fileId == 0 || self.currentActionSheet != nil)
		return;

	NSInteger sectionIndex = tile.sectionIndex;
	NSInteger generation = self.generation;
	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService isStickerFavoriteWithFileId:fileId completion:^(BOOL favourite, BOOL failed) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.generation != generation || failed)
			return;
		[strongSelf presentMenuForSticker:sticker sectionIndex:sectionIndex favourite:favourite];
	}];
}

- (NSInteger)sectionIndexForSetId:(NSNumber *)setId {
	if (setId == nil || [setId longLongValue] == 0)
		return -1;
	for (NSInteger i = 0; i < (NSInteger)self.sections.count; i++) {
		NSNumber *candidate = self.sections[i][@"setId"];
		if (candidate != nil && [candidate isEqualToNumber:setId])
			return i;
	}
	return -1;
}

- (void)presentMenuForSticker:(NSDictionary *)sticker
				 sectionIndex:(NSInteger)sectionIndex
					favourite:(BOOL)favourite {
	if (self.currentActionSheet != nil)
		return;
	if (sectionIndex < 0 || sectionIndex >= (NSInteger)self.sections.count)
		return;

	NSMutableDictionary *section = self.sections[sectionIndex];
	NSInteger kind = [section[@"kind"] integerValue];

	self.menuSticker = sticker;
	self.menuSectionIndex = sectionIndex;
	self.menuStickerFavourite = favourite;

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	[actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerPack.Send", @"Send Sticker") action:@"send"]];
	NSString *favouriteTitle = favourite ? TGL(@"Stickers.RemoveFromFavorites", @"Remove from Favourites") : TGL(@"Stickers.AddToFavorites", @"Add to Favourites");
	[actions addObject:[[TGActionSheetAction alloc] initWithTitle:favouriteTitle action:@"favourite"]];

	NSNumber *setId = sticker[@"setId"];
	if (setId == nil || [setId longLongValue] == 0)
		setId = section[@"setId"];
	if (TGStickerSectionIsSet(kind) == NO && [self sectionIndexForSetId:setId] >= 0)
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerPack.ViewPack", @"View Pack") action:@"pack"]];

	if (kind == kStickerSectionRecent) {
		TGActionSheetAction *unrecent = [TGActionSheetAction alloc];
		unrecent = [unrecent initWithTitle:TGL(@"Stickers.RemoveFromRecent", @"Remove from Recent")
									action:@"unrecent"
									  type:TGActionSheetActionTypeDestructive];
		[actions addObject:unrecent];
	}

	TGActionSheetAction *cancel = [TGActionSheetAction alloc];
	cancel = [cancel initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel];
	[actions addObject:cancel];

	NSString *title = sticker[@"emoji"];
	if (title.length == 0)
		title = section[@"title"];

	__weak TGStickerPanelView *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:title actions:actions
					 actionBlock:^(__unused id target, NSString *action) {
						 TGStickerPanelView *strongSelf = weakSelf;
						 if (strongSelf == nil)
							 return;
						 strongSelf.currentActionSheet = nil;
						 [strongSelf performStickerMenuAction:action];
					 }
						  target:self];
	self.currentActionSheet = sheet;
	UIView *sheetHost = self.window ?: self;
	[self.currentActionSheet tg_showFromRect:sheetHost.bounds inView:sheetHost];
}

- (void)performStickerMenuAction:(NSString *)action {
	NSDictionary *sticker = self.menuSticker;
	NSInteger sectionIndex = self.menuSectionIndex;
	BOOL favourite = self.menuStickerFavourite;
	self.menuSticker = nil;
	self.menuSectionIndex = -1;

	long long fileId = [sticker[@"fileId"] longLongValue];
	if (sticker == nil || fileId == 0)
		return;

	if ([action isEqualToString:@"send"]) {
		if (!self.suppressesRecentStickerTracking)
			[TGStickerCatalogService addRecentStickerWithFileId:fileId];
		if (self.onStickerPicked)
			self.onStickerPicked(sticker);
		return;
	}

	if ([action isEqualToString:@"favourite"]) {
		if (favourite) {
			__weak TGStickerPanelView *weakSelf = self;
			[TGStickerCatalogService removeFavoriteStickerWithFileId:fileId completion:^(BOOL ok) {
				TGStickerPanelView *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				if (!ok) {
					[TGSnackbar showInView:strongSelf.window ?: strongSelf
									   text:TGL(@"Stickers.CouldNotRemoveFromFavorites", @"Couldn't remove the sticker from favourites.")
									seconds:2
								   onCommit:nil];
					return;
				}
				[strongSelf refreshFavourites];
			}];
			return;
		}
		__weak TGStickerPanelView *weakSelf = self;
		[TGStickerCatalogService addFavoriteStickerWithFileId:fileId completion:^(BOOL ok) {
			TGStickerPanelView *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok)
				[TGSnackbar showInView:strongSelf.window ?: strongSelf
								   text:TGL(@"Stickers.CouldNotAddToFavorites", @"Couldn't add the sticker to favourites.")
								seconds:2
							   onCommit:nil];
			[strongSelf refreshFavourites];
		}];
		return;
	}

	if ([action isEqualToString:@"unrecent"]) {
		[TGStickerCatalogService removeRecentStickerWithFileId:fileId];
		[self removeRecentSticker:sticker];
		return;
	}

	if ([action isEqualToString:@"pack"]) {
		NSNumber *setId = sticker[@"setId"];
		if ((setId == nil || [setId longLongValue] == 0) &&
			sectionIndex >= 0 && sectionIndex < (NSInteger)self.sections.count)
			setId = self.sections[sectionIndex][@"setId"];
		NSInteger target = [self sectionIndexForSetId:setId];
		if (target >= 0)
			[self setSelectedSection:target scrollGrid:YES];
	}
}

- (void)removeRecentSticker:(NSDictionary *)sticker {
	NSMutableDictionary *section = nil;
	for (NSMutableDictionary *candidate in self.allSections) {
		if ([candidate[@"kind"] integerValue] == kStickerSectionRecent) {
			section = candidate;
			break;
		}
	}
	if (section == nil)
		return;

	NSMutableArray *stickers = section[@"stickers"];
	NSInteger index = (NSInteger)[stickers indexOfObjectIdenticalTo:sticker];
	if (stickers == nil || index == (NSInteger)NSNotFound)
		return;

	[stickers removeObjectAtIndex:index];
	if (stickers.count == 0) {
		[self reload];
		return;
	}

	section[@"loadedCount"] = @(stickers.count);
	section[@"count"] = @(stickers.count);
	[self takeSectionSnapshot];
	[self relayoutSections];
}

- (void)refreshFavourites {
	NSInteger generation = self.generation;
	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService favoriteStickersWithCompletion:^(NSArray *stickers) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.generation != generation || stickers == nil)
			return;

		NSInteger index = -1;
		for (NSInteger i = 0; i < (NSInteger)strongSelf.allSections.count; i++) {
			if ([strongSelf.allSections[i][@"kind"] integerValue] == kStickerSectionFavourite) {
				index = i;
				break;
			}
		}

		if (index < 0) {
			if (stickers.count == 0)
				return;
			[strongSelf reload];
			return;
		}

		if (stickers.count == 0) {
			[strongSelf reload];
			return;
		}

		NSMutableDictionary *section = strongSelf.allSections[index];
		section[@"stickers"] = [stickers mutableCopy];
		section[@"loadedCount"] = @(stickers.count);
		section[@"complete"] = @YES;
		section[@"count"] = @(stickers.count);
		[strongSelf takeSectionSnapshot];
		[strongSelf relayoutSections];
	}];
}

- (void)refreshRecent {
	NSInteger generation = self.generation;
	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService recentStickersWithCompletion:^(NSArray *stickers) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.generation != generation || stickers == nil)
			return;

		NSInteger index = -1;
		for (NSInteger i = 0; i < (NSInteger)strongSelf.allSections.count; i++) {
			if ([strongSelf.allSections[i][@"kind"] integerValue] == kStickerSectionRecent) {
				index = i;
				break;
			}
		}

		if (index < 0) {
			if (stickers.count == 0)
				return;
			[strongSelf reload];
			return;
		}

		if (stickers.count == 0) {
			[strongSelf reload];
			return;
		}

		NSMutableDictionary *section = strongSelf.allSections[index];
		section[@"stickers"] = [stickers mutableCopy];
		section[@"loadedCount"] = @(stickers.count);
		section[@"complete"] = @YES;
		section[@"count"] = @(stickers.count);
		[strongSelf takeSectionSnapshot];
		[strongSelf relayoutSections];
	}];
}

@end
