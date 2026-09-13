#import "TGMediaFullscreenControllerInternal.h"
#import "TGMediaViewControllerInternal.h"
#import "TGProgressIndicatorView.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGClient.h"

@implementation TGMediaFullscreenController (Chrome)

- (void)buildCaptionPanel {
	CGRect bounds = self.view.bounds;

	_captionPanel = [[UIView alloc] initWithFrame:
			CGRectMake(0, _bottomBar.frame.origin.y, bounds.size.width, 0)];
	_captionPanel.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.65f];
	_captionPanel.userInteractionEnabled = NO;
	_captionPanel.hidden = YES;
	_captionPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self.view insertSubview:_captionPanel belowSubview:_bottomBar];

	_captionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_captionLabel.backgroundColor = [UIColor clearColor];
	_captionLabel.textColor = [UIColor whiteColor];
	_captionLabel.font = [UIFont systemFontOfSize:14];
	_captionLabel.numberOfLines = 3;
	_captionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_captionLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	_captionLabel.shadowOffset = CGSizeMake(0, -1);
	_captionLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	_captionLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[_captionPanel addSubview:_captionLabel];
}

- (void)layoutCaptionPanel {
	NSString *text = _captionLabel.text;
	if (text.length == 0) {
		_captionPanel.hidden = YES;
		return;
	}

	CGFloat width = self.view.bounds.size.width;
	CGFloat inset = 10.0f;
	CGSize wanted = [text sizeWithFont:_captionLabel.font
					 constrainedToSize:CGSizeMake(width - inset * 2, 3 * 18.0f)
						 lineBreakMode:_captionLabel.lineBreakMode];
	CGFloat height = (CGFloat)(int)(wanted.height + 12.0f);

	_captionPanel.hidden = NO;
	_captionPanel.frame = CGRectMake(0, _bottomBar.frame.origin.y - height, width, height);
	_captionLabel.frame = CGRectMake(inset, 6.0f, width - inset * 2, height - 12.0f);
}

- (void)buildPagingView {
	CGRect bounds = self.view.bounds;

	_pagingView = [[UIScrollView alloc] initWithFrame:
			CGRectMake(-kMediaPageGap / 2.0f, 0,
				bounds.size.width + kMediaPageGap, bounds.size.height)];
	_pagingView.pagingEnabled = YES;
	_pagingView.alwaysBounceHorizontal = YES;
	_pagingView.alwaysBounceVertical = NO;
	_pagingView.showsHorizontalScrollIndicator = NO;
	_pagingView.showsVerticalScrollIndicator = NO;
	_pagingView.scrollsToTop = NO;
	_pagingView.delaysContentTouches = NO;
	_pagingView.backgroundColor = [UIColor clearColor];
	_pagingView.delegate = self;
	[self.view addSubview:_pagingView];
}

- (void)buildTopBar {
	CGRect bounds = self.view.bounds;

	UIImage *topPanelImage = [UIImage imageNamed:@"GalleryTopPanel.png"];
	CGFloat inset = TGMediaStatusBarInset();
	_topBar = [[UIImageView alloc] initWithFrame:
			CGRectMake(0, inset, bounds.size.width, TGMediaTopBarHeight())];
	if (topPanelImage)
		_topBar.image = topPanelImage;
	else
		_topBar.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
	_topBar.userInteractionEnabled = YES;
	_topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:_topBar];

	UIImage *cornersImage = [UIImage imageNamed:@"NavigationBar_Corners.png"];
	if (cornersImage) {
		int cornersCap = (int)(cornersImage.size.width / 2);
		UIImage *stretchedCorners = [cornersImage stretchableImageWithLeftCapWidth:cornersCap topCapHeight:0];
		_topCorners = [[UIImageView alloc] initWithImage:stretchedCorners];
		_topCorners.frame = CGRectMake(0, -inset, bounds.size.width, cornersImage.size.height);
		_topCorners.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[_topBar addSubview:_topCorners];
	}

	[self buildCloseButton];

	_counterLabel = [[UILabel alloc] initWithFrame:
			CGRectMake((CGFloat)(int)((bounds.size.width - 140) / 2), 11, 140, 20)];
	_counterLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	_counterLabel.backgroundColor = [UIColor clearColor];
	_counterLabel.textColor = [UIColor whiteColor];
	_counterLabel.font = [UIFont boldSystemFontOfSize:20];
	_counterLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	_counterLabel.shadowOffset = CGSizeMake(0, -1);
	_counterLabel.textAlignment = NSTextAlignmentCenter;
	[_topBar addSubview:_counterLabel];

	_burnCountdownLabel = [[UILabel alloc] initWithFrame:
			CGRectMake((CGFloat)(int)((bounds.size.width - 200) / 2), 32, 200, 18)];
	_burnCountdownLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	_burnCountdownLabel.backgroundColor = [UIColor clearColor];
	_burnCountdownLabel.textColor = [UIColor whiteColor];
	_burnCountdownLabel.font = [UIFont boldSystemFontOfSize:13];
	_burnCountdownLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	_burnCountdownLabel.shadowOffset = CGSizeMake(0, -1);
	_burnCountdownLabel.textAlignment = NSTextAlignmentCenter;
	_burnCountdownLabel.hidden = YES;
	[_topBar addSubview:_burnCountdownLabel];
}

- (void)buildCloseButton {
	UIImage *closePlate = [UIImage imageNamed:@"GalleryDoneButton.png"];
	UIImage *closePlateHighlighted = [UIImage imageNamed:@"GalleryDoneButton_Highlighted.png"];
	UIButton *done = [UIButton buttonWithType:UIButtonTypeCustom];
	done.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	NSString *closeTitle = TGL(@"Common.Close", @"Close");
	[done setTitle:closeTitle forState:UIControlStateNormal];
	[done setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[done setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.5f]
					 forState:UIControlStateNormal];
	done.titleLabel.shadowOffset = CGSizeMake(0, -1);
	if (closePlate) {
		[done setBackgroundImage:[closePlate stretchableImageWithLeftCapWidth:11 topCapHeight:0]
						forState:UIControlStateNormal];
		if (closePlateHighlighted) {
			UIImage *stretchedClosePlateHighlighted = [closePlateHighlighted stretchableImageWithLeftCapWidth:11 topCapHeight:0];
			[done setBackgroundImage:stretchedClosePlateHighlighted forState:UIControlStateHighlighted];
		}
	}
	CGSize closeTitleSize = [closeTitle sizeWithFont:done.titleLabel.font];
	CGFloat closeWidth = closeTitleSize.width + 7.0f + 7.0f;
	if (closeWidth < 55.0f)
		closeWidth = 55.0f;
	done.frame = CGRectMake(5, 7, closeWidth, 30);
	[done addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
	[_topBar addSubview:done];
}

- (void)buildBottomBar {
	CGRect bounds = self.view.bounds;

	UIImage *bottomPanelImage = [UIImage imageNamed:@"GalleryBottomPanel.png"];
	CGFloat bottomPanelHeight = bottomPanelImage ? bottomPanelImage.size.height : 44.0f;
	_bottomBar = [[UIImageView alloc] initWithFrame:
			CGRectMake(0, bounds.size.height - bottomPanelHeight,
				bounds.size.width, bottomPanelHeight)];
	if (bottomPanelImage)
		_bottomBar.image = [bottomPanelImage
			stretchableImageWithLeftCapWidth:(int)(bottomPanelImage.size.width / 2)
								topCapHeight:0];
	else
		_bottomBar.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
	_bottomBar.userInteractionEnabled = YES;
	_bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self.view addSubview:_bottomBar];

	_controlsContainer = [[UIView alloc] initWithFrame:_bottomBar.bounds];
	_controlsContainer.backgroundColor = [UIColor clearColor];
	_controlsContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[_bottomBar addSubview:_controlsContainer];

	_authorLabel = [[UILabel alloc] initWithFrame:
			CGRectMake((CGFloat)(int)((bounds.size.width - 220) / 2), 4, 220, 20)];
	_authorLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	_authorLabel.backgroundColor = [UIColor clearColor];
	_authorLabel.textColor = [UIColor whiteColor];
	_authorLabel.font = [UIFont boldSystemFontOfSize:14];
	_authorLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	_authorLabel.shadowOffset = CGSizeMake(0, -1);
	_authorLabel.textAlignment = NSTextAlignmentCenter;
	[_controlsContainer addSubview:_authorLabel];

	_dateLabel = [[UILabel alloc] initWithFrame:
			CGRectMake((CGFloat)(int)((bounds.size.width - 140) / 2), 23, 140, 20)];
	_dateLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	_dateLabel.backgroundColor = [UIColor clearColor];
	_dateLabel.textColor = [UIColor whiteColor];
	_dateLabel.font = [UIFont systemFontOfSize:13];
	_dateLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	_dateLabel.shadowOffset = CGSizeMake(0, -1);
	_dateLabel.textAlignment = NSTextAlignmentCenter;
	[_controlsContainer addSubview:_dateLabel];

	[self buildPlaybackControlsWithPanelHeight:bottomPanelHeight];
	[self buildBottomBarButtons];
}

- (void)buildPlaybackControlsWithPanelHeight:(CGFloat)bottomPanelHeight {
	CGRect bounds = self.view.bounds;

	UIImage *playImage = [UIImage imageNamed:@"VideoPanelPlay.png"];
	_playButton = [UIButton buttonWithType:UIButtonTypeCustom];
	if (playImage) {
		_playButton.frame = CGRectMake(
			(CGFloat)(int)((bounds.size.width - playImage.size.width) / 2),
			(CGFloat)(int)((bottomPanelHeight - playImage.size.height) / 2),
			playImage.size.width, playImage.size.height);
		[_playButton setBackgroundImage:playImage forState:UIControlStateNormal];
	} else {
		_playButton.frame = CGRectMake((CGFloat)(int)((bounds.size.width - 60) / 2),
			(CGFloat)(int)((bottomPanelHeight - 30) / 2), 60, 30);
		_playButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		[_playButton setTitle:TGL(@"VoiceOver.Media.PlaybackPlay", @"Play") forState:UIControlStateNormal];
		[_playButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	}
	_playButton.accessibilityLabel = TGL(@"VoiceOver.Media.PlaybackPlay", @"Play");
	_playButton.showsTouchWhenHighlighted = YES;
	_playButton.exclusiveTouch = YES;
	_playButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[_playButton addTarget:self action:@selector(playTapped)
		  forControlEvents:UIControlEventTouchUpInside];
	[_controlsContainer addSubview:_playButton];

	_progressContainer = [[UIView alloc] initWithFrame:_bottomBar.bounds];
	_progressContainer.backgroundColor = [UIColor clearColor];
	_progressContainer.userInteractionEnabled = NO;
	_progressContainer.alpha = 0.0f;
	_progressContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[_bottomBar addSubview:_progressContainer];

	_progressLabel = [[UILabel alloc] initWithFrame:
			CGRectMake((CGFloat)(int)((bounds.size.width - 220) / 2), 14, 220, 20)];
	_progressLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	_progressLabel.backgroundColor = [UIColor clearColor];
	_progressLabel.textColor = [UIColor whiteColor];
	_progressLabel.font = [UIFont systemFontOfSize:13];
	_progressLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	_progressLabel.shadowOffset = CGSizeMake(0, -1);
	_progressLabel.textAlignment = NSTextAlignmentCenter;
	_progressLabel.clipsToBounds = NO;
	[_progressContainer addSubview:_progressLabel];

	_progressSpinner = [[TGProgressIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	_progressSpinner.hidesWhenStopped = YES;
	[_progressContainer addSubview:_progressSpinner];
}

- (void)buildBottomBarButtons {
	CGRect bounds = self.view.bounds;

	UIImage *actionIcon = [UIImage imageNamed:@"GalleryActionIcon.png"];
	_actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_actionButton.frame = CGRectMake(6, 2, 40, 40);
	_actionButton.exclusiveTouch = YES;
	_actionButton.showsTouchWhenHighlighted = YES;
	if (actionIcon) {
		[_actionButton setBackgroundImage:actionIcon forState:UIControlStateNormal];
		UIImage *actionIconPressed = [UIImage imageNamed:@"GalleryActionIcon_Highlighted.png"];
		if (actionIconPressed) {
			[_actionButton setBackgroundImage:actionIconPressed forState:UIControlStateHighlighted];
			_actionButton.showsTouchWhenHighlighted = NO;
		}
	} else {
		_actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		[_actionButton setTitle:@"…" forState:UIControlStateNormal];
		[_actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	}
	_actionButton.accessibilityLabel = TGL(@"Common.More", @"More");
	_actionButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
	[_actionButton addTarget:self action:@selector(actionsTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[_bottomBar addSubview:_actionButton];

	UIImage *trashIcon = [UIImage imageNamed:@"GalleryTrashIcon.png"];
	_deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_deleteButton.frame = CGRectMake(bounds.size.width - 40 - 6, 2, 40, 40);
	_deleteButton.exclusiveTouch = YES;
	_deleteButton.showsTouchWhenHighlighted = YES;
	if (trashIcon) {
		[_deleteButton setBackgroundImage:trashIcon forState:UIControlStateNormal];
		UIImage *trashIconPressed = [UIImage imageNamed:@"GalleryTrashIcon_Highlighted.png"];
		if (trashIconPressed) {
			[_deleteButton setBackgroundImage:trashIconPressed forState:UIControlStateHighlighted];
			_deleteButton.showsTouchWhenHighlighted = NO;
		}
	} else {
		_deleteButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		[_deleteButton setTitle:TGL(@"Common.Delete", @"Delete") forState:UIControlStateNormal];
		[_deleteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	}
	_deleteButton.accessibilityLabel = TGL(@"Common.Delete", @"Delete");
	_deleteButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[_deleteButton addTarget:self action:@selector(deleteTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[_bottomBar addSubview:_deleteButton];
}

- (void)buildOverlayAndGestures {
	CGRect bounds = self.view.bounds;

	_spinner = [[TGProgressIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	_spinner.center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
	_spinner.hidesWhenStopped = YES;
	_spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.view addSubview:_spinner];

	_progressRing = [[TGMediaProgressRing alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
	_progressRing.center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
	_progressRing.hidden = YES;
	_progressRing.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.view insertSubview:_progressRing belowSubview:_topBar];

	UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handleDoubleTap:)];
	doubleTap.numberOfTapsRequired = 2;
	[self.view addGestureRecognizer:doubleTap];

	UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handleSingleTap:)];
	[singleTap requireGestureRecognizerToFail:doubleTap];
	[self.view addGestureRecognizer:singleTap];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handlePan:)];
	pan.delegate = self;
	pan.maximumNumberOfTouches = 1;
	[self.view addGestureRecognizer:pan];
	_dismissPan = pan;
	[_pagingView.panGestureRecognizer requireGestureRecognizerToFail:pan];
}

- (void)updateBurnCountdownForItem:(NSDictionary *)item {
	[self stopBurnCountdown];

	NSInteger timer = [item[@"destructTimer"] integerValue];
	if (timer <= 0)
		return;

	NSTimeInterval alreadyTicking = [item[@"destructIn"] doubleValue];
	_burnSecondsRemaining = alreadyTicking > 0 ? (NSInteger)ceil(alreadyTicking) : timer;
	if (_burnSecondsRemaining <= 0)
		return;

	_burnCountdownLabel.hidden = NO;
	[self renderBurnCountdown];
	_burnCountdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tickBurnCountdown) userInfo:nil repeats:YES];
}

- (void)tickBurnCountdown {
	_burnSecondsRemaining--;
	if (_burnSecondsRemaining <= 0) {
		[self stopBurnCountdown];
		[self closeTapped];
		return;
	}
	[self renderBurnCountdown];
}

- (void)renderBurnCountdown {
	_burnCountdownLabel.text = [NSString stringWithFormat:
			TGL(@"Media.DisappearsInSeconds", @"Disappears in %lds"), (long)_burnSecondsRemaining];
}

- (void)stopBurnCountdown {
	[_burnCountdownTimer invalidate];
	_burnCountdownTimer = nil;
	_burnCountdownLabel.hidden = YES;
}

- (void)installProgressHook {
	if (_fileProgressObserverToken)
		return;

	__weak typeof(self) weakSelf = self;
	_fileProgressObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGFileProgressDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					typeof(self) strongSelf = weakSelf;
					long long fileId = [note.userInfo[TGFileProgressFileIdKey] longLongValue];
					if (!strongSelf || ![strongSelf.ringFileId isEqual:@(fileId)])
						return;
					strongSelf.progressRing.progress = [note.userInfo[TGFileProgressValueKey] floatValue];
				}];
}

- (void)removeProgressHook {
	if (!_fileProgressObserverToken)
		return;
	[[NSNotificationCenter defaultCenter] removeObserver:_fileProgressObserverToken];
	_fileProgressObserverToken = nil;
}

- (void)layoutTopBar {
	CGRect bounds = self.view.bounds;
	if (bounds.size.width < 1)
		return;

	CGFloat inset = TGMediaStatusBarInset();
	_topBar.frame = CGRectMake(0, inset, bounds.size.width, TGMediaTopBarHeight());
	if (_topCorners)
		_topCorners.frame = CGRectMake(0, -inset, bounds.size.width,
			_topCorners.image.size.height);
}

#pragma mark - chrome

- (void)updateChromeForCurrentItem {
	if (_items.count == 0)
		return;

	if (_inlinePlayer && _inlinePlayerIndex != _currentIndex)
		[self stopInlinePlayer];

	_counterLabel.text = [NSString stringWithFormat:TGL(@"Items.NOfM", @"%1$ld of %2$lu"),
		(long)(_currentIndex + 1), (unsigned long)_items.count];

	NSDictionary *item = _items[_currentIndex];
	[self updateBurnCountdownForItem:item];
	NSString *caption = item[@"caption"];
	NSString *author = item[@"author"];
	_captionLabel.text = [caption isKindOfClass:NSString.class] ? caption : @"";
	_authorLabel.text = [author isKindOfClass:NSString.class] ? author : @"";
	_dateLabel.text = TGMediaDayForDate([item[@"date"] integerValue]);
	_dateLabel.frame = CGRectMake(_dateLabel.frame.origin.x,
		_authorLabel.text.length > 0 ? 23.0f : 14.0f,
		_dateLabel.frame.size.width, _dateLabel.frame.size.height);
	[self layoutCaptionPanel];

	BOOL isVideo = [item[@"isVideo"] boolValue];
	_playButton.hidden = !isVideo;
	_authorLabel.alpha = isVideo ? 0.0f : 1.0f;
	_dateLabel.alpha = isVideo ? 0.0f : 1.0f;
	_captionPanel.alpha = (isVideo || _chromeHidden) ? 0.0f : 1.0f;
	_deleteButton.hidden = (self.chatId == 0 || [item[@"messageId"] longLongValue] == 0);

	[self updateLoadingChrome];
}

- (void)setChromeHidden:(BOOL)hidden animated:(BOOL)animated {
	_chromeHidden = hidden;
	CGFloat alpha = hidden ? 0.0f : 1.0f;
	[[UIApplication sharedApplication] setStatusBarHidden:hidden
											withAnimation:UIStatusBarAnimationFade];
	if (!hidden)
		[self layoutTopBar];
	CGFloat captionAlpha = [[self currentItem][@"isVideo"] boolValue] ? 0.0f : alpha;
	if (animated) {
		[UIView animateWithDuration:(hidden ? 0.3 : 0.15) animations:^{
			self.topBar.alpha = alpha;
			self.bottomBar.alpha = alpha;
			self.captionPanel.alpha = captionAlpha;
		}];
	} else {
		_topBar.alpha = alpha;
		_bottomBar.alpha = alpha;
		_captionPanel.alpha = captionAlpha;
	}
}

@end
