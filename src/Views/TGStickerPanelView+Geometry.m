#import "TGStickerPanelView.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import "TGStickerCatalogService.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGStickerPanelView (Geometry)

#pragma mark - geometry

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect bounds = self.bounds;
	CGFloat separator = 1.0f / [UIScreen mainScreen].scale;
	CGFloat searchHeight = self.searchVisible ? kStickerPanelSearchHeight : 0.0f;
	CGFloat barHeight = kStickerPanelKeyBarHeight;
	self.keyBar.hidden = self.searchVisible;

	if (self.ground != nil) {
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		self.ground.frame = bounds;
		[CATransaction commit];
	}

	self.topSeparator.frame = CGRectMake(0, 0, bounds.size.width, separator);
	self.searchBar.frame = CGRectMake(0, separator, bounds.size.width, kStickerPanelSearchHeight);

	CGFloat barTop = MAX(0.0f, bounds.size.height - barHeight);
	self.keyBar.frame = CGRectMake(0, barTop, bounds.size.width, barHeight);
	self.keyBarSeam.frame = CGRectMake(0, 0, bounds.size.width, separator);
	self.keyBarSheen.frame = CGRectMake(0, separator, bounds.size.width, separator);

	CGFloat gridTop = separator + searchHeight;
	CGFloat gridBottom = self.searchVisible ? bounds.size.height : barTop;
	self.grid.frame = CGRectMake(0, gridTop, bounds.size.width,
		MAX(0.0f, gridBottom - gridTop));

	CGFloat centreY = floorf(self.grid.frame.origin.y + self.grid.frame.size.height / 2.0f);
	self.spinner.frame = CGRectMake(floorf((bounds.size.width - 20) / 2.0f), centreY - 10, 20, 20);
	self.statusLabel.frame = CGRectMake(20, centreY - 34, bounds.size.width - 40, 40);
	self.retryButton.frame = CGRectMake(floorf((bounds.size.width - 120) / 2.0f), centreY + 12, 120, 43);

	CGFloat pixel = 1.0f / [UIScreen mainScreen].scale;
	CGFloat available = bounds.size.width - kStickerPanelSideInset * 2.0f;
	NSInteger columns = (NSInteger)floorf(available / kStickerPanelTileSide);
	if (columns < kStickerPanelMinColumns)
		columns = kStickerPanelMinColumns;

	CGFloat tileSide = MIN(floorf(available / columns), kStickerPanelTileSide);
	if (tileSide < 1.0f)
		tileSide = kStickerPanelTileSide;
	CGFloat spacing = (columns > 1)
		? floorf((available - tileSide * columns) / (columns - 1) / pixel) * pixel
		: 0.0f;
	if (spacing < 0.0f)
		spacing = 0.0f;
	CGFloat contentWidth = tileSide * columns + spacing * (columns - 1);
	CGFloat sideInset = floorf((bounds.size.width - contentWidth) / 2.0f);
	if (sideInset < 0.0f)
		sideInset = 0.0f;
	self.rowSpacing = kStickerPanelRowSpacing;

	BOOL metricsChanged = (columns != self.columns ||
		fabsf(tileSide - self.tileSide) > 0.01f ||
		fabsf(spacing - self.tileSpacing) > 0.01f);
	BOOL widthChanged = fabsf(bounds.size.width - self.laidOutWidth) > 0.01f;
	self.columns = columns;
	self.tileSide = tileSide;
	self.tileSpacing = spacing;
	self.sideInset = sideInset;
	self.laidOutWidth = bounds.size.width;
	if (metricsChanged || widthChanged || (self.sections.count > 0 && self.grid.contentSize.height < 1.0f))
		[self relayoutSections];
	[self layoutTabs];
	[self layoutPreview];
	[self updateVisibleTiles];
}

- (void)relayoutSections {
	CGFloat previousOffset = self.grid.contentOffset.y;
	NSInteger anchorIndex = -1;
	CGFloat anchorDelta = 0.0f;
	for (NSInteger i = 0; i < (NSInteger)self.sections.count; i++) {
		NSNumber *y = self.sections[i][@"y"];
		if (y == nil)
			continue;
		if ([y floatValue] <= previousOffset) {
			anchorIndex = i;
			anchorDelta = previousOffset - [y floatValue];
		} else
			break;
	}

	for (UIView *header in self.headerViews)
		[header removeFromSuperview];
	[self.headerViews removeAllObjects];

	CGFloat y = 0;
	CGFloat width = self.grid.bounds.size.width;
	if (width < 1.0f)
		return;

	NSInteger index = 0;
	for (NSMutableDictionary *section in self.sections) {
		NSInteger count = [section[@"count"] integerValue];
		NSInteger rows = (count + self.columns - 1) / self.columns;
		if (rows < 1)
			rows = 1;

		section[@"y"] = @(y);

		UIView *header = [[UIView alloc] initWithFrame:
				CGRectMake(0, y, width, kStickerPanelHeaderHeight)];
		header.backgroundColor = [UIColor clearColor];
		header.userInteractionEnabled = [section[@"canInstall"] boolValue];

		UILabel *label = [[UILabel alloc] initWithFrame:
				CGRectMake(self.sideInset + 5.0f, 0,
					width - (self.sideInset + 5.0f) * 2, kStickerPanelHeaderHeight)];
		label.backgroundColor = [UIColor clearColor];
		label.font = [UIFont boldSystemFontOfSize:11];
		label.textColor = TGStickerPanelEngravedColour();
		label.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.55f];
		label.shadowOffset = CGSizeMake(0, 1);
		NSString *caption = section[@"title"];
		label.text = [caption isKindOfClass:[NSString class]] ? [caption uppercaseString] : nil;
		[header addSubview:label];

		if ([section[@"canInstall"] boolValue]) {
			UIButton *add = [self addButtonForSectionIndex:index];
			CGFloat addWidth = 52.0f;
			add.frame = CGRectMake(width - self.sideInset - 5.0f - addWidth,
				floorf((kStickerPanelHeaderHeight - 19.0f) / 2.0f), addWidth, 19.0f);
			label.frame = CGRectMake(self.sideInset + 5.0f, 0,
				MAX(20.0f, width - (self.sideInset + 5.0f) * 2 - addWidth - 6.0f),
				kStickerPanelHeaderHeight);
			[header addSubview:add];
		}
		[self.grid addSubview:header];
		[self.headerViews addObject:header];

		CGFloat body = self.rowSpacing * 2.0f + rows * self.tileSide +
			(rows - 1) * self.rowSpacing;
		section[@"height"] = @(kStickerPanelHeaderHeight + body);
		y += kStickerPanelHeaderHeight + body;
		index += 1;
	}

	self.grid.contentSize = CGSizeMake(width, y);

	if (anchorIndex >= 0 && anchorIndex < (NSInteger)self.sections.count) {
		CGFloat restored = [self.sections[anchorIndex][@"y"] floatValue] + anchorDelta;
		CGFloat maxOffset = MAX(0.0f, self.grid.contentSize.height - self.grid.bounds.size.height);
		restored = MAX(0.0f, MIN(restored, maxOffset));
		if (fabsf(restored - previousOffset) > 0.5f)
			self.grid.contentOffset = CGPointMake(0, restored);
	}

	[self clearTiles];
	[self updateVisibleTiles];
}

- (UIButton *)addButtonForSectionIndex:(NSInteger)index {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.tag = kStickerPanelAddButtonTag + index;
	UIImage *plate = [UIImage imageNamed:@"GroupedActionButton.png"];
	UIImage *platePressed = [UIImage imageNamed:@"GroupedActionButton_Highlighted.png"];
	if (plate != nil)
		[button setBackgroundImage:[plate stretchableImageWithLeftCapWidth:24 topCapHeight:0]
						  forState:UIControlStateNormal];
	if (platePressed != nil)
		[button setBackgroundImage:[platePressed stretchableImageWithLeftCapWidth:24 topCapHeight:0]
						  forState:UIControlStateHighlighted];
	[button setTitle:TGL(@"Stickers.Install", @"ADD") forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	button.titleLabel.font = [UIFont boldSystemFontOfSize:11];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	button.exclusiveTouch = YES;
	[button addTarget:self action:@selector(addSetTapped:)
		forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (void)addSetTapped:(UIButton *)button {
	NSInteger index = button.tag - kStickerPanelAddButtonTag;
	if (index < 0 || index >= (NSInteger)self.sections.count)
		return;

	NSMutableDictionary *section = self.sections[index];
	int64_t setId = [section[@"setId"] longLongValue];
	if (setId == 0)
		return;

	button.enabled = NO;
	NSInteger generation = self.generation;
	NSMutableDictionary *target = section;

	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService installStickerSet:setId completion:^(BOOL ok) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.generation != generation)
			return;
		if (!ok) {
			button.enabled = YES;
			return;
		}
		[target removeObjectForKey:@"canInstall"];
		[strongSelf relayoutSections];
		[strongSelf checkArchivedAfterInstall];
	}];
}

- (void)checkArchivedAfterInstall {
	NSInteger generation = self.generation;
	__weak TGStickerPanelView *weakSelf = self;
	[TGStickerCatalogService installedStickerSetsWithCompletion:^(NSArray *installed) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.generation != generation || installed == nil)
			return;

		NSMutableSet *installedIds = [[NSMutableSet alloc] init];
		for (NSDictionary *set in installed) {
			NSNumber *setId = set[@"id"];
			if (setId != nil)
				[installedIds addObject:setId];
		}

		NSMutableArray *lost = [[NSMutableArray alloc] init];
		for (NSMutableDictionary *section in strongSelf.allSections) {
			if ([section[@"kind"] integerValue] != kStickerSectionSet)
				continue;
			NSNumber *setId = section[@"setId"];
			if (setId != nil && ![installedIds containsObject:setId] && section[@"title"] != nil)
				[lost addObject:section[@"title"]];
		}

		if (lost.count > 0)
			[strongSelf showArchivedNoticeForTitles:lost];
	}];
}

- (void)showArchivedNoticeForTitles:(NSArray *)titles {
	if (self.currentActionSheet != nil)
		return;

	NSString *names = [titles componentsJoinedByString:@", "];
	NSString *message = [NSString stringWithFormat:
			TGL(@"StickerPanel.PacksArchivedNotice", @"You have too many sticker packs. These were moved to the archive:\n%@"),
		names];

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	[actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGL(@"StickerPanel.RefreshPacks", @"Refresh Packs") action:@"refresh"]];
	TGActionSheetAction *okAction = [[TGActionSheetAction alloc]
		initWithTitle:TGL(@"Common.OK", @"OK")
			   action:@"cancel"
				 type:TGActionSheetActionTypeCancel];
	[actions addObject:okAction];

	__weak TGStickerPanelView *weakSelf = self;
	void (^handler)(id, NSString *) = ^(__unused id target, NSString *action) {
		TGStickerPanelView *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf.currentActionSheet = nil;
		if ([action isEqualToString:@"refresh"])
			[strongSelf reload];
	};
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:message
			  actions:actions
		  actionBlock:handler
			   target:self];
	self.currentActionSheet = sheet;
	UIView *sheetHost = self.window ?: self;
	[self.currentActionSheet tg_showFromRect:sheetHost.bounds inView:sheetHost];
}

- (CGRect)frameForItem:(NSInteger)item inSection:(NSInteger)sectionIndex {
	NSDictionary *section = self.sections[sectionIndex];
	CGFloat sectionY = [section[@"y"] floatValue];
	NSInteger row = item / self.columns;
	NSInteger column = item % self.columns;
	CGFloat x = self.sideInset + column * (self.tileSide + self.tileSpacing);
	CGFloat y = sectionY + kStickerPanelHeaderHeight + self.rowSpacing +
		row * (self.tileSide + self.rowSpacing);
	return CGRectMake(floorf(x), floorf(y), self.tileSide, self.tileSide);
}

@end
