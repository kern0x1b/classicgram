#import "TGStoriesViewController.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGDateUtils.h"
#import "TGImageDecode.h"
#import "TGReactionPickerView.h"
#import "RootViewController.h"
#import "TGStoryAreaEditorViewController.h"
#import "TGStoryHelpers.h"
#import "TGStoryTextViewController.h"

#import "TGStoryContactPicker.h"
#import "TGStoryViewersViewController.h"
#import "TGStoryListViewController.h"

#import "TGStoryPage.h"
#import "TGStoryPostOptions.h"
#import "TGStoryComposer.h"
#import "TGStoryStatisticsViewController.h"
#import "TGStoriesViewControllerInternal.h"

@implementation TGStoriesViewController (Chrome)

#pragma mark - chrome

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.backgroundColor = [UIColor blackColor];
	self.view.clipsToBounds = YES;
	self.wantsFullScreenLayout = YES;

	_visiblePages = [[NSMutableArray alloc] init];
	_pageQueue = [[NSMutableArray alloc] init];

	_pagingView = [[UIScrollView alloc] initWithFrame:CGRectZero];
	_pagingView.pagingEnabled = YES;
	_pagingView.alwaysBounceHorizontal = YES;
	_pagingView.alwaysBounceVertical = NO;
	_pagingView.directionalLockEnabled = YES;
	_pagingView.scrollsToTop = NO;
	_pagingView.showsHorizontalScrollIndicator = NO;
	_pagingView.showsVerticalScrollIndicator = NO;
	_pagingView.delaysContentTouches = NO;
	_pagingView.backgroundColor = [UIColor clearColor];
	_pagingView.delegate = self;
	[self.view addSubview:_pagingView];

	[self buildTopPanel];

	_stripView = [[UIView alloc] initWithFrame:CGRectZero];
	_stripView.backgroundColor = [UIColor clearColor];
	_stripView.userInteractionEnabled = NO;
	[self.view addSubview:_stripView];

	[self buildBottomPanel];
	[self buildFooter];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(viewTapped:)];
	tap.delegate = self;
	[self.view addGestureRecognizer:tap];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(viewDragged:)];
	pan.delegate = self;
	pan.maximumNumberOfTouches = 1;
	[self.view addGestureRecognizer:pan];

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(viewHeld:)];
	hold.delegate = self;
	hold.minimumPressDuration = 0.2;
	hold.cancelsTouchesInView = NO;
	[self.view addGestureRecognizer:hold];

	[self updateStrip];
	[self updateChrome];
	[self discoverPosters];
}

- (UILabel *)panelLabelWithFont:(UIFont *)font frame:(CGRect)frame {
	UILabel *label = [[UILabel alloc] initWithFrame:frame];
	label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor whiteColor];
	label.font = font;
	label.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	label.shadowOffset = CGSizeMake(0, -1);
	label.textAlignment = NSTextAlignmentCenter;
	label.lineBreakMode = NSLineBreakByTruncatingTail;
	return label;
}

- (UIButton *)platedButtonWithTitle:(NSString *)title
						   minWidth:(CGFloat)minWidth
							 action:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.exclusiveTouch = YES;
	button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	[button setTitle:title forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.5f]
					   forState:UIControlStateNormal];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	button.adjustsImageWhenHighlighted = NO;

	UIImage *plate = [UIImage imageNamed:@"GalleryDoneButton.png"];
	UIImage *platePressed = [UIImage imageNamed:@"GalleryDoneButton_Highlighted.png"];
	if (plate != nil) {
		[button setBackgroundImage:[plate stretchableImageWithLeftCapWidth:11 topCapHeight:0]
						  forState:UIControlStateNormal];
	}
	if (platePressed != nil) {
		UIImage *stretchedPressed = [platePressed stretchableImageWithLeftCapWidth:11 topCapHeight:0];
		[button setBackgroundImage:stretchedPressed forState:UIControlStateHighlighted];
	}

	CGFloat width = [title sizeWithFont:button.titleLabel.font].width + 14.0f;
	if (width < minWidth)
		width = minWidth;
	button.frame = CGRectMake(0, 0, width, kStoryPlateHeight);
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (UIButton *)panelButtonWithImageNamed:(NSString *)name
							   fallback:(NSString *)fallback
								 action:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.exclusiveTouch = YES;
	button.showsTouchWhenHighlighted = YES;
	UIImage *icon = [UIImage imageNamed:name];
	if (icon != nil) {
		[button setBackgroundImage:icon forState:UIControlStateNormal];
	} else {
		button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		[button setTitle:fallback forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.5f]
						   forState:UIControlStateNormal];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	}
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (void)buildTopPanel {
	CGFloat width = self.view.bounds.size.width;

	UIImage *panelImage = [UIImage imageNamed:@"GalleryTopPanel.png"];
	CGFloat panelHeight = panelImage != nil ? panelImage.size.height : kStoryPanelHeight;
	_topPanel = [[UIImageView alloc] initWithFrame:
			CGRectMake(0, kStoryStatusBarHeight, width, panelHeight)];
	_topPanel.image = panelImage;
	if (panelImage == nil)
		_topPanel.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
	_topPanel.userInteractionEnabled = YES;
	_topPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:_topPanel];

	UIImage *cornersImage = [UIImage imageNamed:@"NavigationBar_Corners.png"];
	if (cornersImage != nil) {
		int capWidth = (int)(cornersImage.size.width / 2);
		UIImage *stretchedCorners = [cornersImage stretchableImageWithLeftCapWidth:capWidth topCapHeight:0];
		UIImageView *corners = [[UIImageView alloc] initWithImage:stretchedCorners];
		corners.frame = CGRectMake(0, -kStoryStatusBarHeight, width, cornersImage.size.height);
		corners.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[_topPanel addSubview:corners];
	}

	_closeButton = [self platedButtonWithTitle:TGL(@"Common.Close", @"Close")
									  minWidth:55.0f
										action:@selector(closeTapped)];
	_closeButton.frame = CGRectMake(kStoryPlateLeft, kStoryPlateTop,
		_closeButton.frame.size.width, kStoryPlateHeight);
	[_topPanel addSubview:_closeButton];

	_counterLabel = [self panelLabelWithFont:[UIFont boldSystemFontOfSize:20]
									   frame:CGRectMake((CGFloat)(int)((width - 140) / 2),
												 11, 140, 20)];
	[_topPanel addSubview:_counterLabel];
}

- (void)buildBottomPanel {
	CGRect bounds = self.view.bounds;

	UIImage *panelImage = [UIImage imageNamed:@"GalleryBottomPanel.png"];
	CGFloat panelHeight = panelImage != nil ? panelImage.size.height : kStoryPanelHeight;
	_bottomPanel = [[UIImageView alloc] initWithFrame:
			CGRectMake(0, bounds.size.height - panelHeight, bounds.size.width, panelHeight)];
	if (panelImage != nil) {
		_bottomPanel.image = [panelImage
			stretchableImageWithLeftCapWidth:(int)(panelImage.size.width / 2)
								topCapHeight:0];
	} else {
		_bottomPanel.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
	}
	_bottomPanel.userInteractionEnabled = YES;
	_bottomPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self.view addSubview:_bottomPanel];

	_authorLabel = [self panelLabelWithFont:[UIFont boldSystemFontOfSize:14]
									  frame:CGRectMake((CGFloat)(int)((bounds.size.width - 220) / 2),
												4, 220, 20)];
	[_bottomPanel addSubview:_authorLabel];

	_dateLabel = [self panelLabelWithFont:[UIFont systemFontOfSize:13]
									frame:CGRectMake((CGFloat)(int)((bounds.size.width - 140) / 2),
											  23, 140, 20)];
	[_bottomPanel addSubview:_dateLabel];

	_actionButton = [self panelButtonWithImageNamed:@"GalleryActionIcon.png"
										   fallback:TGL(@"Common.More", @"More")
											 action:@selector(morePressed)];
	_actionButton.frame = CGRectMake(kStoryPanelButtonInset, kStoryPanelButtonTop,
		kStoryPanelButtonSize, kStoryPanelButtonSize);
	_actionButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
	[_bottomPanel addSubview:_actionButton];

	_deleteButton = [self panelButtonWithImageNamed:@"GalleryTrashIcon.png"
										   fallback:TGL(@"Common.Delete", @"Delete")
											 action:@selector(deleteTapped)];
	_deleteButton.frame = CGRectMake(bounds.size.width - kStoryPanelButtonSize - kStoryPanelButtonInset,
		kStoryPanelButtonTop,
		kStoryPanelButtonSize, kStoryPanelButtonSize);
	_deleteButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	_deleteButton.hidden = YES;
	[_bottomPanel addSubview:_deleteButton];
}

- (void)closeTapped {
	[self dismissViewer];
}

- (void)deleteTapped {
	NSInteger storyId = [self currentStoryId];
	if (storyId == 0)
		return;
	[self confirmDeleteStoryId:storyId];
}

- (UIButton *)footerButtonWithTitle:(NSString *)title action:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.exclusiveTouch = YES;
	[button setTitle:title forState:UIControlStateNormal];
	button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
	[button setTitleShadowColor:[UIColor colorWithRed:0.055f green:0.157f blue:0.302f alpha:0.4f]
					   forState:UIControlStateNormal];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	button.adjustsImageWhenHighlighted = NO;
	[button addTarget:self action:action forControlEvents:UIControlEventTouchDown];
	return button;
}

- (void)buildFooter {
	_footerView = [[UIView alloc] initWithFrame:CGRectZero];
	_footerView.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_footerView];

	_replyButton = [self footerButtonWithTitle:TGL(@"Notification.Reply", @"Reply") action:@selector(replyPressed)];
	_middleButton = [self footerButtonWithTitle:@"" action:@selector(middlePressed)];
	[_middleButton removeTarget:self
						 action:@selector(middlePressed)
			   forControlEvents:UIControlEventTouchDown];
	[_middleButton addTarget:self
					  action:@selector(middlePressed)
			forControlEvents:UIControlEventTouchUpInside];
	UILongPressGestureRecognizer *reactionHold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(middleHeld:)];
	reactionHold.minimumPressDuration = 0.4;
	[_middleButton addGestureRecognizer:reactionHold];
	_shareButton = [self footerButtonWithTitle:TGL(@"Share.Title", @"Share") action:@selector(sharePressed)];

	UIImage *left = TGStoryStretch(@"ButtonGroupLeft.png", 8);
	UIImage *leftPressed = TGStoryStretch(@"ButtonGroupLeft_Highlighted.png", 8);
	UIImage *center = TGStoryStretch(@"ButtonGroupCenter.png", 1);
	UIImage *centerPressed = TGStoryStretch(@"ButtonGroupCenter_Highlighted.png", 1);
	UIImage *right = TGStoryStretch(@"ButtonGroupRight.png", 1);
	UIImage *rightPressed = TGStoryStretch(@"ButtonGroupRight_Highlighted.png", 1);

	[_replyButton setBackgroundImage:left forState:UIControlStateNormal];
	[_replyButton setBackgroundImage:leftPressed forState:UIControlStateHighlighted];
	[_middleButton setBackgroundImage:center forState:UIControlStateNormal];
	[_middleButton setBackgroundImage:centerPressed forState:UIControlStateHighlighted];
	[_shareButton setBackgroundImage:right forState:UIControlStateNormal];
	[_shareButton setBackgroundImage:rightPressed forState:UIControlStateHighlighted];

	if (left == nil) {
		UIColor *plate = [[TGTheme shared] accentColour];
		_replyButton.backgroundColor = plate;
		_middleButton.backgroundColor = plate;
		_shareButton.backgroundColor = plate;
	}

	[_footerView addSubview:_replyButton];
	[_footerView addSubview:_middleButton];
	[_footerView addSubview:_shareButton];

	UIImage *divider = TGStoryStretch(@"ButtonGroupDivider.png", 6);
	for (NSInteger i = 0; i < 2; i++) {
		UIImageView *seam = [[UIImageView alloc] initWithImage:divider];
		seam.tag = 900 + i;
		if (divider == nil)
			seam.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.3f];
		[_footerView addSubview:seam];
	}
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];

	CGRect bounds = self.view.bounds;
	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;

	CGFloat topPanelHeight = _topPanel.frame.size.height;
	_topPanel.frame = CGRectMake(0, kStoryStatusBarHeight, width, topPanelHeight);

	CGFloat bottomPanelHeight = _bottomPanel.frame.size.height;
	_bottomPanel.frame = CGRectMake(0, height - bottomPanelHeight, width, bottomPanelHeight);

	CGFloat footerY = height - bottomPanelHeight - kStoryFooterBottom - kStoryFooterHeight;
	_footerView.frame = CGRectMake(kStoryFooterInset, footerY,
		width - kStoryFooterInset * 2.0f, kStoryFooterHeight);
	[self layoutFooter];

	_stripView.frame = CGRectMake(0, kStoryStatusBarHeight + topPanelHeight,
		width, kStoryStripHeight);
	[self layoutStrip];

	CGRect area = CGRectMake(0, 0, width, height);
	if (!CGRectEqualToRect(_pagingView.frame, area)) {
		_pagingView.frame = area;
		[self resetPagingGeometry];
	}

	CGFloat captionInset = height - footerY + kStoryFooterBottom;
	for (TGStoryPage *page in _visiblePages)
		page.captionBottomInset = captionInset;
}

- (void)layoutFooter {
	CGRect bounds = _footerView.bounds;
	CGFloat total = bounds.size.width;
	UIImage *divider = [UIImage imageNamed:@"ButtonGroupDivider.png"];
	CGFloat seam = divider != nil ? divider.size.width : 2.0f;
	CGFloat segment = (CGFloat)(int)((total - seam * 2.0f) / 3.0f);

	CGFloat x = 0.0f;
	_replyButton.frame = CGRectMake(x, 0, segment, kStoryFooterHeight);
	x += segment;
	UIView *leftSeam = [_footerView viewWithTag:900];
	leftSeam.frame = CGRectMake(x, 0, seam, kStoryFooterHeight);
	x += seam;
	_middleButton.frame = CGRectMake(x, 0, segment, kStoryFooterHeight);
	x += segment;
	UIView *rightSeam = [_footerView viewWithTag:901];
	rightSeam.frame = CGRectMake(x, 0, seam, kStoryFooterHeight);
	x += seam;
	_shareButton.frame = CGRectMake(x, 0, total - x, kStoryFooterHeight);
}

- (void)layoutStrip {
	NSInteger count = (NSInteger)_storyIds.count;
	if (count <= 0)
		return;

	CGFloat width = _stripView.bounds.size.width - kStoryStripInset * 2.0f;
	CGFloat segment = floorf((width - kStoryStripGap * (count - 1)) / count);
	if (segment < 1.0f)
		segment = 1.0f;

	NSArray *existing = [_stripView.subviews copy];
	if ((NSInteger)existing.count != count) {
		for (UIView *view in existing)
			[view removeFromSuperview];
		for (NSInteger i = 0; i < count; i++) {
			UIView *bar = [[UIView alloc] initWithFrame:CGRectZero];
			bar.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.3f];
			UIView *fill = [[UIView alloc] initWithFrame:CGRectZero];
			fill.tag = 1;
			fill.backgroundColor = [UIColor whiteColor];
			[bar addSubview:fill];
			[_stripView addSubview:bar];
		}
	}

	CGFloat x = kStoryStripInset;
	NSArray *bars = _stripView.subviews;
	for (NSInteger i = 0; i < count; i++) {
		UIView *bar = [bars objectAtIndex:(NSUInteger)i];
		CGFloat thisWidth = (i == count - 1)
			? (_stripView.bounds.size.width - kStoryStripInset - x)
			: segment;
		bar.frame = CGRectMake(x, 0, thisWidth, kStoryStripHeight);
		x += thisWidth + kStoryStripGap;
	}
	[self updateStrip];
}

- (void)updateStrip {
	NSArray *bars = _stripView.subviews;
	for (NSInteger i = 0; i < bars.count && i < _storyIds.count; i++) {
		UIView *bar = [bars objectAtIndex:i];
		UIView *fill = [bar viewWithTag:1];
		CGFloat portion;
		if ((NSInteger)i < _index)
			portion = 1.0f;
		else if ((NSInteger)i > _index)
			portion = [_seen containsObject:[_storyIds objectAtIndex:i]] ? 1.0f : 0.0f;
		else
			portion = (CGFloat)MIN(1.0, _elapsed / [self currentStoryDuration]);
		fill.frame = CGRectMake(0, 0, floorf(bar.bounds.size.width * portion),
			bar.bounds.size.height);
	}
}

@end
