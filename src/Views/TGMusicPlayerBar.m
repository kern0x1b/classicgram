#import "TGMusicPlayerBar.h"
#import "TGLocalization.h"
#import "TGMusicPlayer.h"
#import "TGTheme.h"
#import "TGDateUtils.h"
#import "TGAudioMetadata.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kBarHeight = 40.0f;
static const CGFloat kArtSide = 28.0f;
static const CGFloat kLineHeight = 2.0f;
static const CGFloat kGlyphSide = 24.0f;
static const CGFloat kRateWidth = 38.0f;

static TGMusicPlayerBar *sBar = nil;
static UIView * (^sHostProvider)(void) = nil;
static void (^sFullPlayerPresenter)(void) = nil;

#pragma mark - glyphs

static UIColor *TGMusicShade(UIColor *colour, CGFloat factor) {
	CGFloat r = 1, g = 1, b = 1, a = 1;
	if (![colour getRed:&r green:&g blue:&b alpha:&a]) {
		CGFloat white = 1;
		if ([colour getWhite:&white alpha:&a])
			r = g = b = white;
	}
	return [UIColor colorWithRed:MIN((CGFloat)1, r * factor)
						   green:MIN((CGFloat)1, g * factor)
							blue:MIN((CGFloat)1, b * factor)
						   alpha:a];
}

static NSMutableDictionary *sGlyphs = nil;

static UIImage *TGMusicGlyph(NSString *name, UIColor *colour) {
	if (!sGlyphs)
		sGlyphs = [NSMutableDictionary dictionary];
	NSString *key = [NSString stringWithFormat:@"%@-%@", name, colour];
	UIImage *cached = sGlyphs[key];
	if (cached)
		return cached;

	const CGFloat s = kGlyphSide;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(ctx, colour.CGColor);
	CGContextSetStrokeColorWithColor(ctx, colour.CGColor);

	if ([name isEqualToString:@"play"]) {
		CGContextMoveToPoint(ctx, 7, 4);
		CGContextAddLineToPoint(ctx, s - 6, s / 2);
		CGContextAddLineToPoint(ctx, 7, s - 4);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	} else if ([name isEqualToString:@"pause"]) {
		CGContextFillRect(ctx, CGRectMake(7, 4, 3.5f, s - 8));
		CGContextFillRect(ctx, CGRectMake(s - 10.5f, 4, 3.5f, s - 8));
	} else if ([name isEqualToString:@"previous"] || [name isEqualToString:@"next"]) {
		BOOL back = [name isEqualToString:@"previous"];
		CGContextSaveGState(ctx);
		if (back) {
			CGContextTranslateCTM(ctx, s, 0);
			CGContextScaleCTM(ctx, -1, 1);
		}
		for (NSInteger i = 0; i < 2; i++) {
			CGFloat x = 4 + i * 7.0f;
			CGContextMoveToPoint(ctx, x, 5);
			CGContextAddLineToPoint(ctx, x + 6.5f, s / 2);
			CGContextAddLineToPoint(ctx, x, s - 5);
			CGContextClosePath(ctx);
		}
		CGContextFillPath(ctx);
		CGContextFillRect(ctx, CGRectMake(s - 6, 5, 2.5f, s - 10));
		CGContextRestoreGState(ctx);
	} else if ([name isEqualToString:@"close"]) {
		CGContextSetLineWidth(ctx, 1.5f);
		CGContextSetLineCap(ctx, kCGLineCapRound);
		CGContextMoveToPoint(ctx, 7, 7);
		CGContextAddLineToPoint(ctx, s - 7, s - 7);
		CGContextMoveToPoint(ctx, s - 7, 7);
		CGContextAddLineToPoint(ctx, 7, s - 7);
		CGContextStrokePath(ctx);
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	sGlyphs[key] = image;
	return image;
}

#pragma mark - hierarchy probes

static CGFloat TGNavigationBarBottom(UIView *host, UIView *view, int depth) {
	if (depth > 8 || view.hidden || view.alpha < 0.05f)
		return 0;
	if ([view isKindOfClass:UINavigationBar.class]) {
		CGRect frame = [view convertRect:view.bounds toView:host];
		return CGRectGetMaxY(frame);
	}
	CGFloat best = 0;
	for (UIView *child in view.subviews) {
		CGFloat bottom = TGNavigationBarBottom(host, child, depth + 1);
		if (bottom > best)
			best = bottom;
	}
	return best;
}

static void TGCollectCoveredScrollViews(UIView *host, UIView *view, CGRect area,
	NSMutableArray *found, int depth) {
	if (depth > 8 || view.hidden || view.alpha < 0.05f || view.window == nil)
		return;
	if ([view isKindOfClass:UIScrollView.class]) {
		CGRect frame = [view convertRect:view.bounds toView:host];
		if (frame.size.height > 120 && CGRectIntersectsRect(frame, area))
			[found addObject:view];
		return;
	}
	for (UIView *child in view.subviews)
		TGCollectCoveredScrollViews(host, child, area, found, depth + 1);
}

#pragma mark -

@interface TGMusicPlayerBar () <UIGestureRecognizerDelegate>
@end

@implementation TGMusicPlayerBar {
	UIButton *_previous;
	UIButton *_toggle;
	UIButton *_next;
	UIButton *_close;
	UIButton *_rate;
	UILabel *_title;
	UILabel *_performer;
	UIView *_track;
	UIView *_progress;
	UIView *_hairline;
	UIView *_topHighlight;
	UIImageView *_art;
	CAGradientLayer *_gradient;
	NSTimer *_anchorTimer;
	NSMutableArray *_insetViews;
	BOOL _scrubbing;
	BOOL _voice;
	CGFloat _scrubFraction;
	id _musicPlayerStateObserverToken;
	id _audioMetadataObserverToken;
	id _musicPlayerProgressObserverToken;
	id _themeChangedObserverToken;
	id _backgroundObserverToken;
	id _rotationObserverToken;
	id _foregroundObserverToken;
}

+ (CGFloat)barHeight {
	return kBarHeight;
}

+ (void)setHostProvider:(UIView * (^)(void))provider {
	sHostProvider = [provider copy];
}

+ (void)setFullPlayerPresenter:(void (^)(void))presenter {
	sFullPlayerPresenter = [presenter copy];
}

+ (void)activate {
	if (sBar)
		return;
	sBar = [[TGMusicPlayerBar alloc] initWithFrame:CGRectMake(0, 0, 0, kBarHeight)];
	[sBar sync];
}

- (instancetype)initWithFrame:(CGRect)frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.clipsToBounds = YES;
	_insetViews = [NSMutableArray array];

	_gradient = [CAGradientLayer layer];
	[self.layer insertSublayer:_gradient atIndex:0];

	_previous = [self buttonWithAccessibilityLabel:TGL(@"VoiceOver.MusicPlayer.Previous", @"Previous")
											 action:@selector(previousTapped)];
	_toggle = [self buttonWithAccessibilityLabel:TGL(@"Conversation.StopVoiceMessagePauseAction", @"Pause")
										   action:@selector(toggleTapped)];
	_next = [self buttonWithAccessibilityLabel:TGL(@"VoiceOver.MusicPlayer.Next", @"Next")
										 action:@selector(nextTapped)];
	_close = [self buttonWithAccessibilityLabel:TGL(@"VoiceOver.MusicPlayer.Close", @"Close")
										  action:@selector(closeTapped)];

	_rate = [UIButton buttonWithType:UIButtonTypeCustom];
	_rate.titleLabel.font = [UIFont boldSystemFontOfSize:11];
	_rate.hidden = YES;
	_rate.layer.cornerRadius = 3.0f;
	_rate.layer.borderWidth = 1.0f;
	[_rate addTarget:self action:@selector(rateTapped)
		forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:_rate];

	_title = [[UILabel alloc] initWithFrame:CGRectZero];
	_title.backgroundColor = [UIColor clearColor];
	_title.font = [UIFont boldSystemFontOfSize:13];
	[self addSubview:_title];

	_performer = [[UILabel alloc] initWithFrame:CGRectZero];
	_performer.backgroundColor = [UIColor clearColor];
	_performer.font = [UIFont systemFontOfSize:11];
	[self addSubview:_performer];

	_track = [[UIView alloc] initWithFrame:CGRectZero];
	[self addSubview:_track];

	_progress = [[UIView alloc] initWithFrame:CGRectZero];
	[self addSubview:_progress];

	_hairline = [[UIView alloc] initWithFrame:CGRectZero];
	[self addSubview:_hairline];

	_topHighlight = [[UIView alloc] initWithFrame:CGRectZero];
	[self addSubview:_topHighlight];

	_art = [[UIImageView alloc] initWithFrame:CGRectZero];
	_art.contentMode = UIViewContentModeScaleAspectFill;
	_art.clipsToBounds = YES;
	_art.layer.cornerRadius = 4.0f;
	[self addSubview:_art];

	UIPanGestureRecognizer *scrub = [[UIPanGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(scrubbed:)];
	[self addGestureRecognizer:scrub];

	UITapGestureRecognizer *open = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(openFullPlayer)];
	open.cancelsTouchesInView = NO;
	open.delegate = self;
	[self addGestureRecognizer:open];

	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	__weak typeof(self) weakSelf = self;
	_musicPlayerStateObserverToken = [centre
		addObserverForName:TGMusicPlayerStateChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf playerNotified:note];
				}];
	_audioMetadataObserverToken = [centre
		addObserverForName:TGAudioMetadataChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf playerNotified:note];
				}];
	_musicPlayerProgressObserverToken = [centre
		addObserverForName:TGMusicPlayerProgressNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf progressNotified:note];
				}];
	_themeChangedObserverToken = [centre
		addObserverForName:TGThemeChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf themeNotified:note];
				}];
	_backgroundObserverToken = [centre
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf backgroundNotified:note];
				}];
	_rotationObserverToken = [centre
		addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf rotationNotified:note];
				}];
	_foregroundObserverToken = [centre
		addObserverForName:UIApplicationWillEnterForegroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf playerNotified:note];
				}];

	[self restyle];
	return self;
}

- (void)dealloc {
	[_anchorTimer invalidate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_musicPlayerStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_musicPlayerStateObserverToken];
	if (_audioMetadataObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_audioMetadataObserverToken];
	if (_musicPlayerProgressObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_musicPlayerProgressObserverToken];
	if (_themeChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_themeChangedObserverToken];
	if (_backgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_backgroundObserverToken];
	if (_rotationObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_rotationObserverToken];
	if (_foregroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_foregroundObserverToken];
}

- (UIButton *)buttonWithAccessibilityLabel:(NSString *)accessibilityLabel
									 action:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.showsTouchWhenHighlighted = NO;
	button.adjustsImageWhenHighlighted = YES;
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	button.accessibilityLabel = accessibilityLabel;
	[self addSubview:button];
	return button;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
	   shouldReceiveTouch:(UITouch *)touch {
	if (![recognizer isKindOfClass:UITapGestureRecognizer.class])
		return YES;
	return ![touch.view isKindOfClass:UIControl.class];
}

#pragma mark - notifications

- (void)playerNotified:(NSNotification *)note {
	[self sync];
}
- (void)progressNotified:(NSNotification *)note {
	[self progressed];
}
- (void)themeNotified:(NSNotification *)note {
	[self restyle];
}
- (void)backgroundNotified:(NSNotification *)note {
	[self suspendAnchoring];
}
- (void)rotationNotified:(NSNotification *)note {
	if (self.superview)
		[self reanchor];
}

#pragma mark - appearance

- (void)restyle {
	[sGlyphs removeAllObjects];
	TGTheme *theme = [TGTheme shared];
	UIColor *panel = [theme inputBarColour];
	self.backgroundColor = panel;
	_gradient.colors = @[ (id)[TGMusicShade(panel, 1.09f) CGColor],
		(id)[TGMusicShade(panel, 1.01f) CGColor],
		(id)[TGMusicShade(panel, 0.93f) CGColor] ];
	_gradient.locations = @[ @0, @(0.55f), @1 ];
	_topHighlight.backgroundColor = [UIColor colorWithWhite:1 alpha:0.55f];
	_title.textColor = [theme primaryTextColour];
	_performer.textColor = [theme secondaryTextColour];
	_track.backgroundColor = [theme separatorColour];
	_progress.backgroundColor = [theme accentColour];
	_hairline.backgroundColor = [theme separatorColour];

	UIColor *ink = [theme accentColour];
	[_previous setImage:TGMusicGlyph(@"previous", ink) forState:UIControlStateNormal];
	[_next setImage:TGMusicGlyph(@"next", ink) forState:UIControlStateNormal];
	[_close setImage:TGMusicGlyph(@"close", [theme secondaryTextColour])
			forState:UIControlStateNormal];
	[_rate setTitleColor:ink forState:UIControlStateNormal];
	_rate.layer.borderColor = ink.CGColor;
	[self syncToggleGlyph];
}

- (void)syncRateTitle {
	float rate = [TGMusicPlayer shared].voiceRate;
	NSString *title = (rate > 1.75f) ? @"2x" : ((rate > 1.25f) ? @"1.5x" : @"1x");
	[_rate setTitle:title forState:UIControlStateNormal];
}

- (void)syncToggleGlyph {
	UIColor *ink = [[TGTheme shared] accentColour];
	BOOL playing = [TGMusicPlayer shared].playing;
	[_toggle setImage:TGMusicGlyph(playing ? @"pause" : @"play", ink)
			 forState:UIControlStateNormal];
	_toggle.accessibilityLabel = playing
		? TGL(@"Conversation.StopVoiceMessagePauseAction", @"Pause")
		: TGL(@"VoiceOver.Media.PlaybackPlay", @"Play");
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat w = self.bounds.size.width;
	CGFloat row = kBarHeight - kLineHeight;

	_gradient.frame = CGRectMake(0, 0, w, kBarHeight);
	_topHighlight.frame = CGRectMake(0, 0, w, 0.5f);

	BOOL showsArt = _art.image != nil;
	CGFloat artX = 8;
	_art.frame = CGRectMake(artX, (row - kArtSide) / 2, kArtSide, kArtSide);
	_art.hidden = !showsArt;

	CGFloat transportX = showsArt ? (artX + kArtSide + 4) : 2;
	_previous.frame = CGRectMake(transportX, 0, 30, row);
	_toggle.frame = CGRectMake(transportX + 30, 0, 34, row);
	_next.frame = CGRectMake(transportX + 64, 0, 30, row);
	_close.frame = CGRectMake(w - 34, 0, 32, row);
	_rate.frame = CGRectMake(w - 36 - kRateWidth, (row - 20) / 2, kRateWidth, 20);

	CGFloat left = transportX + 94 + 6;
	CGFloat right = _voice ? (40 + kRateWidth) : 40;
	CGFloat width = MAX((CGFloat)40, w - left - right);
	BOOL twoLines = _performer.text.length > 0;
	if (twoLines) {
		_title.frame = CGRectMake(left, 2, width, 16);
		_performer.frame = CGRectMake(left, 18, width, 14);
	} else {
		_title.frame = CGRectMake(left, (row - 17) / 2, width, 17);
		_performer.frame = CGRectZero;
	}
	_performer.hidden = !twoLines;

	_track.frame = CGRectMake(0, row, w, kLineHeight);
	_hairline.frame = CGRectMake(0, kBarHeight - 0.5f, w, 0.5f);
	[self layoutProgress];
}

- (void)layoutProgress {
	CGFloat fraction = _scrubbing ? _scrubFraction : [TGMusicPlayer shared].playedFraction;
	fraction = MAX((CGFloat)0, MIN((CGFloat)1, fraction));
	_progress.frame = CGRectMake(0, kBarHeight - kLineHeight,
		self.bounds.size.width * fraction, kLineHeight);
}

#pragma mark - placement

- (UIView *)host {
	UIView *provided = sHostProvider ? sHostProvider() : nil;
	if (provided)
		return provided;
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	if (!window)
		window = [[UIApplication sharedApplication].windows count]
			? [UIApplication sharedApplication].windows[0]
			: nil;
	return window.rootViewController.view;
}

- (void)reanchor {
	UIView *host = [self host];
	if (!host) {
		[self detach];
		return;
	}
	if (self.superview != host) {
		[self dropInset];
		[host addSubview:self];
	} else {
		[host bringSubviewToFront:self];
	}

	CGFloat top = TGNavigationBarBottom(host, host, 0);
	if (top <= 0) {
		BOOL pad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
		BOOL landscape = UIInterfaceOrientationIsLandscape(
			[UIApplication sharedApplication].statusBarOrientation);
		top = (!pad && landscape) ? 32 : 44;
	}
	self.frame = CGRectMake(0, top, host.bounds.size.width, kBarHeight);
	[self applyInset];
}

- (void)applyInset {
	UIView *host = [self host];
	NSMutableArray *wanted = [NSMutableArray array];
	if (host && self.superview == host) {
		for (UIView *child in host.subviews) {
			if (child == self)
				continue;
			TGCollectCoveredScrollViews(host, child, self.frame, wanted, 1);
		}
	}
	for (UIScrollView *scroll in [_insetViews copy])
		if (![wanted containsObject:scroll])
			[self shiftScrollView:scroll by:-kBarHeight];
	for (UIScrollView *scroll in wanted)
		if (![_insetViews containsObject:scroll])
			[self shiftScrollView:scroll by:kBarHeight];
}

- (void)shiftScrollView:(UIScrollView *)scroll by:(CGFloat)amount {
	UIEdgeInsets content = scroll.contentInset;
	BOOL wasAtTop = scroll.contentOffset.y <= -content.top + 0.5f;
	content.top += amount;
	scroll.contentInset = content;
	UIEdgeInsets indicator = scroll.scrollIndicatorInsets;
	indicator.top += amount;
	scroll.scrollIndicatorInsets = indicator;
	if (wasAtTop)
		scroll.contentOffset = CGPointMake(scroll.contentOffset.x, -content.top);
	if (amount > 0)
		[_insetViews addObject:scroll];
	else
		[_insetViews removeObject:scroll];
}

- (void)dropInset {
	for (UIScrollView *scroll in [_insetViews copy])
		[self shiftScrollView:scroll by:-kBarHeight];
}

- (void)detach {
	[self suspendAnchoring];
	[self dropInset];
	[self removeFromSuperview];
}

- (void)suspendAnchoring {
	[_anchorTimer invalidate];
	_anchorTimer = nil;
}

#pragma mark - state

- (void)sync {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	NSDictionary *track = player.currentTrack;
	if (!track) {
		[self detach];
		return;
	}

	_voice = [track[TGMusicTrackIsVoice] boolValue];
	if (_voice) {
		NSString *sender = track[TGMusicTrackSender];
		_title.text = sender.length ? sender : TGL(@"VoiceOver.Chat.RecordModeVoiceMessage", @"Voice message");
		_performer.text = player.loading
			? TGL(@"Channel.NotificationLoading", @"Loading…")
			: [TGDateUtils stringForLastSeen:[track[TGMusicTrackDate] intValue]];
		_rate.hidden = NO;
		[self syncRateTitle];
	} else {
		int64_t fileId = [track[TGMusicTrackFileId] longLongValue];
		TGAudioMetadata *tags = [TGAudioMetadata cachedForFileId:fileId];
		NSString *title = track[TGMusicTrackTitle];
		if (!title.length)
			title = tags.title;
		NSString *performer = track[TGMusicTrackPerformer];
		if (!performer.length)
			performer = tags.performer;
		_title.text = title.length ? title : TGL(@"MediaPlayer.UnknownTrack", @"Unknown Track");
		_performer.text = player.loading
			? TGL(@"Channel.NotificationLoading", @"Loading…")
			: (performer.length ? performer : TGL(@"MediaPlayer.UnknownArtist", @"Unknown Artist"));
		_rate.hidden = YES;
	}

	int64_t artFileId = [track[TGMusicTrackFileId] longLongValue];
	TGAudioMetadata *artTags = [TGAudioMetadata cachedForFileId:artFileId];
	_art.image = _voice ? nil
						: [TGAudioMetadata artworkTileOfSide:kArtSide cornerRadius:4 scrim:NO
												 forMetadata:artTags];
	if (!_voice && !_art.image) {
		UIImage *fallbackArtwork = [player currentArtwork];
		if (fallbackArtwork) {
			TGAudioMetadata *fallbackTags = [[TGAudioMetadata alloc] init];
			fallbackTags.artwork = fallbackArtwork;
			_art.image = [TGAudioMetadata artworkTileOfSide:kArtSide cornerRadius:4 scrim:NO
												 forMetadata:fallbackTags];
		}
	}
	if (!_voice && !_art.image)
		_art.image = [TGIcons musicNoteOfSide:kArtSide
									   colour:[[TGTheme shared] secondaryTextColour]];

	BOOL canPrevious = [player hasPrevious];
	BOOL canNext = [player hasNext];
	_previous.enabled = canPrevious;
	_next.enabled = canNext;
	_previous.alpha = canPrevious ? 1.0f : 0.35f;
	_next.alpha = canNext ? 1.0f : 0.35f;
	[self syncToggleGlyph];

	[self reanchor];
	[self setNeedsLayout];

	if (!_anchorTimer) {
		_anchorTimer = [NSTimer scheduledTimerWithTimeInterval:0.8 target:self selector:@selector(reanchor) userInfo:nil repeats:YES];
	}
}

- (void)progressed {
	if (_scrubbing)
		return;
	[self layoutProgress];
}

#pragma mark - controls

- (void)toggleTapped {
	[[TGMusicPlayer shared] toggle];
}
- (void)nextTapped {
	[[TGMusicPlayer shared] playNext];
}
- (void)previousTapped {
	[[TGMusicPlayer shared] playPrevious];
}
- (void)closeTapped {
	[[TGMusicPlayer shared] stop];
}

- (void)openFullPlayer {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	if (!player.currentTrack || player.voice || player.external)
		return;
	if (sFullPlayerPresenter)
		sFullPlayerPresenter();
}

- (void)rateTapped {
	[[TGMusicPlayer shared] cycleVoiceRate];
	[self syncRateTitle];
}

- (void)scrubbed:(UIPanGestureRecognizer *)pan {
	CGFloat width = self.bounds.size.width;
	if (width <= 0 || _voice)
		return;
	CGFloat x = [pan locationInView:self].x;
	_scrubFraction = MAX((CGFloat)0, MIN((CGFloat)1, x / width));

	if (pan.state == UIGestureRecognizerStateBegan ||
		pan.state == UIGestureRecognizerStateChanged) {
		_scrubbing = YES;
		[self layoutProgress];
		return;
	}
	if (pan.state != UIGestureRecognizerStateEnded &&
		pan.state != UIGestureRecognizerStateCancelled &&
		pan.state != UIGestureRecognizerStateFailed)
		return;

	_scrubbing = NO;
	if (pan.state == UIGestureRecognizerStateEnded)
		[[TGMusicPlayer shared] seekToFraction:_scrubFraction];
	[self layoutProgress];
}

@end
