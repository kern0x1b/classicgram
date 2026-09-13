#import "TGStickerPanelView.h"
#import "TGStickerTabTitle.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGStickerPanelView (Tabs)

#pragma mark - tabs

- (void)rebuildTabs {
	[self cancelTabImageLoads];
	for (UIView *view in [self.tabStrip.subviews copy])
		[view removeFromSuperview];
	[self.tabButtons removeAllObjects];
	[self.tabDividers removeAllObjects];

	NSInteger index = 0;

	for (NSMutableDictionary *section in self.sections) {
		UIButton *button = [self tabKey];
		button.tag = index;
		[button addTarget:self action:@selector(tabTapped:)
			forControlEvents:UIControlEventTouchUpInside];

		NSNumber *thumbId = section[@"tabThumbId"];
		NSString *thumbUniqueId = section[@"tabThumbUniqueId"];
		if (![thumbUniqueId isKindOfClass:[NSString class]])
			thumbUniqueId = @"";

		if (thumbId != nil || thumbUniqueId.length > 0) {
			UIImage *cached = [TGStickerThumbnailCache
				cachedThumbnailForUniqueId:thumbUniqueId
									  side:kStickerPanelTabThumbSide];
			if (cached != nil) {
				[button setImage:cached forState:UIControlStateNormal];
			} else {
				[button setTitle:[self shortTabTitle:section[@"tabTitle"]] forState:UIControlStateNormal];
				__weak UIButton *weakButton = button;
				void (^thumbCompletion)(UIImage *) = ^(UIImage *image) {
					UIButton *target = weakButton;
					if (target == nil || image == nil)
						return;
					[target setTitle:@"" forState:UIControlStateNormal];
					[target setImage:image forState:UIControlStateNormal];
				};
				id token = [TGStickerThumbnailCache thumbnailForFileId:[thumbId longLongValue] uniqueId:thumbUniqueId side:kStickerPanelTabThumbSide completion:thumbCompletion];
				if (token != nil)
					[self.tabImageTokens addObject:token];
			}
		} else {
			[button setTitle:[self shortTabTitle:section[@"tabTitle"]] forState:UIControlStateNormal];
		}

		[self.tabStrip addSubview:button];
		[self.tabButtons addObject:button];
		index += 1;
	}

	[self layoutTabs];
	[self updateTabSelection];
}

- (NSString *)shortTabTitle:(NSString *)title {
	return TGStickerTabTitle(title);
}

- (void)styleKey:(UIButton *)button {
	UIImage *plate = TGStickerPanelKeyPlate(NO);
	UIImage *pressed = TGStickerPanelKeyPlate(YES);
	if (plate != nil)
		[button setBackgroundImage:plate forState:UIControlStateNormal];
	if (pressed != nil) {
		[button setBackgroundImage:pressed forState:UIControlStateHighlighted];
		[button setBackgroundImage:pressed forState:UIControlStateSelected];
		[button setBackgroundImage:pressed
						  forState:UIControlStateSelected | UIControlStateHighlighted];
	}
	if (plate == nil) {
		button.backgroundColor = [[TGTheme shared] listBackgroundColour];
		button.layer.cornerRadius = 4.0f;
	}
	button.adjustsImageWhenHighlighted = NO;
	button.adjustsImageWhenDisabled = NO;
	button.exclusiveTouch = YES;
	button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	button.titleLabel.shadowOffset = CGSizeMake(0, 1);
	button.imageView.contentMode = UIViewContentModeScaleAspectFit;
	[button setTitleColor:TGStickerPanelEngravedColour() forState:UIControlStateNormal];
	[button setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.25f]
					   forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
	[button setTitleShadowColor:[UIColor colorWithRed:0x11 / 255.0f green:0x2e / 255.0f
												 blue:0x5c / 255.0f
												alpha:0.2f]
					   forState:UIControlStateSelected];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
}

- (UIButton *)tabKey {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	[self styleKey:button];
	return button;
}

- (UIButton *)functionKeyWithGlyph:(UIImage *)glyph title:(NSString *)title {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	[self styleKey:button];
	if (glyph != nil)
		[button setImage:glyph forState:UIControlStateNormal];
	else if (title.length > 0)
		[button setTitle:title forState:UIControlStateNormal];
	return button;
}

- (void)layoutTabs {
	CGFloat barWidth = self.keyBar.bounds.size.width;
	if (barWidth < 1.0f)
		return;

	CGFloat keyWidth = kStickerPanelFunctionKeyWidth;
	self.searchKey.frame = CGRectMake(0, kStickerPanelKeyTop, keyWidth, kStickerPanelKeyHeight);
	self.backspaceKey.frame = CGRectMake(barWidth - keyWidth, kStickerPanelKeyTop,
		keyWidth, kStickerPanelKeyHeight);
	self.tabStrip.frame = CGRectMake(keyWidth, kStickerPanelKeyTop,
		MAX(0.0f, barWidth - keyWidth * 2.0f), kStickerPanelKeyHeight);

	CGFloat x = 0;
	for (UIButton *button in self.tabButtons) {
		CGFloat width = kStickerPanelKeyMinWidth;
		NSString *title = [button titleForState:UIControlStateNormal];
		if (title.length > 0) {
			CGSize size = [title sizeWithFont:button.titleLabel.font];
			width = MAX(kStickerPanelKeyMinWidth, floorf(size.width) + 18.0f);
		}
		button.frame = CGRectMake(floorf(x), 0, width, kStickerPanelKeyHeight);
		x += width;
	}
	self.tabStrip.contentSize = CGSizeMake(x, kStickerPanelKeyHeight);
	[self updateTabDividers];
}

- (void)updateTabDividers {
	for (UIView *view in self.tabDividers)
		[view removeFromSuperview];
	[self.tabDividers removeAllObjects];

	UIImage *dividerLeft = [UIImage imageNamed:@"SearchScopeBarScopeDividerLeft.png"];
	UIImage *dividerRight = [UIImage imageNamed:@"SearchScopeBarScopeDividerRight.png"];
	if (dividerLeft == nil || dividerRight == nil)
		return;

	NSInteger selected = -1;
	for (NSInteger i = 0; i < (NSInteger)self.tabButtons.count; i++) {
		UIButton *candidate = self.tabButtons[i];
		if (candidate.selected) {
			selected = i;
			break;
		}
	}
	if (selected < 0)
		return;

	for (NSInteger i = 0; i + 1 < (NSInteger)self.tabButtons.count; i++) {
		UIImage *art = nil;
		if (selected == i)
			art = dividerLeft;
		else if (selected == i + 1)
			art = dividerRight;
		if (art == nil)
			continue;

		UIButton *right = self.tabButtons[i + 1];
		UIImageView *divider = [[UIImageView alloc] initWithImage:art];
		divider.frame = CGRectMake(right.frame.origin.x - (CGFloat)(int)(art.size.width / 2.0f),
			0, art.size.width, kStickerPanelKeyHeight);
		[self.tabStrip addSubview:divider];
		[self.tabStrip bringSubviewToFront:divider];
		[self.tabDividers addObject:divider];
	}
}

- (void)updateTabSelection {
	NSInteger index = 0;
	for (UIButton *button in self.tabButtons) {
		button.selected = (button.tag >= 0 && index == self.selectedSection);
		index += 1;
	}
	self.searchKey.selected = self.searchVisible;
	[self updateTabDividers];
}

- (void)setSelectedSection:(NSInteger)index scrollGrid:(BOOL)scrollGrid {
	if (index < 0 || index >= (NSInteger)self.sections.count)
		return;
	self.selectedSection = index;
	[self updateTabSelection];

	if (index < (NSInteger)self.tabButtons.count) {
		UIButton *button = self.tabButtons[index];
		[self.tabStrip scrollRectToVisible:CGRectInset(button.frame, -20, 0) animated:YES];
	}

	if (!scrollGrid)
		return;

	CGFloat y = [self.sections[index][@"y"] floatValue];
	CGFloat maxOffset = MAX(0.0f, self.grid.contentSize.height - self.grid.bounds.size.height);
	[self.grid setContentOffset:CGPointMake(0, MIN(y, maxOffset)) animated:YES];
}

- (void)tabTapped:(UIButton *)button {
	[self setSelectedSection:button.tag scrollGrid:YES];
}

- (void)hideTapped {
	if (self.searchVisible)
		[self.searchBar resignFirstResponder];
	if (self.onCloseRequested)
		self.onCloseRequested();
}

- (void)backspaceTapped {
	if (self.searchVisible && [self.searchBar isFirstResponder]) {
		NSString *text = self.searchBar.text;
		if (text.length > 0) {
			NSRange last = [text rangeOfComposedCharacterSequenceAtIndex:text.length - 1];
			self.searchBar.text = [text substringToIndex:last.location];
			[self searchBar:self.searchBar textDidChange:self.searchBar.text];
			return;
		}
		[self setSearchVisible:NO];
		[self updateTabSelection];
		return;
	}

	if (self.onBackspace && self.onBackspace())
		return;
	[self hideTapped];
}

@end
