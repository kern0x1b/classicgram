#import "TGMusicPlayerViewController.h"
#import "TGLocalization.h"
#import "TGMusicPlayer.h"
#import "TGTheme.h"
#import "TGAudioMetadata.h"
#import "TGIcons.h"
#import "TGPlayerClock.h"

static const CGFloat kTitleHeight = 22.0f;
static const CGFloat kPerformerHeight = 18.0f;
static const CGFloat kGapArtTitle = 16.0f;
static const CGFloat kGapTitleScrub = 10.0f;
static const CGFloat kGapScrubTransport = 4.0f;
static const CGFloat kStageTopGap = 10.0f;
static const CGFloat kScrubHeight = 44.0f;
static const CGFloat kScrubSliderRow = 22.0f;
static const CGFloat kTrackThickness = 4.0f;
static const CGFloat kKnobSide = 18.0f;
static const CGFloat kModeSide = 30.0f;
static const CGFloat kModeGlyph = 22.0f;
static const CGFloat kClockWidth = 70.0f;
static const CGFloat kArtCorner = 6.0f;
static const CGFloat kArtMaxSide = 620.0f;
static const CGFloat kColumnMinWidth = 300.0f;
static const CGFloat kRowHeight = 48.0f;
static const CGFloat kRowTile = 34.0f;
static const CGFloat kTransportPhone = 60.0f;
static const CGFloat kTransportPad = 72.0f;
static const CGFloat kPlayGlyph = 44.0f;
static const CGFloat kSkipGlyph = 40.0f;

static NSMutableDictionary *sPlayerGlyphs = nil;

static UIImage *TGPlayerGlyph(NSString *name, UIColor *colour, CGFloat side) {
	if (!sPlayerGlyphs)
		sPlayerGlyphs = [NSMutableDictionary dictionary];
	NSString *key = [NSString stringWithFormat:@"%@-%@-%.1f", name, colour, side];
	UIImage *cached = sPlayerGlyphs[key];
	if (cached)
		return cached;

	const CGFloat s = side;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(ctx, colour.CGColor);
	CGContextSetStrokeColorWithColor(ctx, colour.CGColor);
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);

	if ([name isEqualToString:@"play"]) {
		CGFloat h = s * 0.56f, w = s * 0.50f;
		CGFloat x = (s - w) / 2 + s * 0.035f;
		CGContextMoveToPoint(ctx, x, (s - h) / 2);
		CGContextAddLineToPoint(ctx, x + w, s / 2);
		CGContextAddLineToPoint(ctx, x, (s + h) / 2);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	} else if ([name isEqualToString:@"pause"]) {
		CGFloat h = s * 0.52f, w = s * 0.15f, gap = s * 0.14f;
		CGContextFillRect(ctx, CGRectMake(s / 2 - gap / 2 - w, (s - h) / 2, w, h));
		CGContextFillRect(ctx, CGRectMake(s / 2 + gap / 2, (s - h) / 2, w, h));
	} else if ([name isEqualToString:@"previous"] || [name isEqualToString:@"next"]) {
		CGContextSaveGState(ctx);
		CGContextTranslateCTM(ctx, s / 2, s / 2);
		if ([name isEqualToString:@"previous"])
			CGContextScaleCTM(ctx, -1, 1);
		CGFloat h = s * 0.46f, w = s * 0.34f, bar = s * 0.09f;
		for (NSInteger i = 0; i < 2; i++) {
			CGFloat x = -w + i * w * 0.92f;
			CGContextMoveToPoint(ctx, x, -h / 2);
			CGContextAddLineToPoint(ctx, x + w * 0.92f, 0);
			CGContextAddLineToPoint(ctx, x, h / 2);
			CGContextClosePath(ctx);
			CGContextFillPath(ctx);
		}
		CGContextFillRect(ctx, CGRectMake(w * 0.86f, -h / 2, bar, h));
		CGContextRestoreGState(ctx);
	} else if ([name isEqualToString:@"shuffle"]) {
		CGFloat f = s / 24.0f;
		CGContextSetLineWidth(ctx, 2.0f * f);
		CGContextMoveToPoint(ctx, 2 * f, 7 * f);
		CGContextAddLineToPoint(ctx, 8 * f, 7 * f);
		CGContextAddLineToPoint(ctx, 15 * f, 17 * f);
		CGContextAddLineToPoint(ctx, 18 * f, 17 * f);
		CGContextStrokePath(ctx);
		CGContextMoveToPoint(ctx, 2 * f, 17 * f);
		CGContextAddLineToPoint(ctx, 8 * f, 17 * f);
		CGContextAddLineToPoint(ctx, 15 * f, 7 * f);
		CGContextAddLineToPoint(ctx, 18 * f, 7 * f);
		CGContextStrokePath(ctx);
		for (NSInteger i = 0; i < 2; i++) {
			CGFloat y = i ? 17 * f : 7 * f;
			CGContextMoveToPoint(ctx, 17 * f, y - 4 * f);
			CGContextAddLineToPoint(ctx, 22.5f * f, y);
			CGContextAddLineToPoint(ctx, 17 * f, y + 4 * f);
			CGContextClosePath(ctx);
			CGContextFillPath(ctx);
		}
	} else if ([name isEqualToString:@"repeat"] || [name isEqualToString:@"repeatone"]) {
		CGFloat f = s / 24.0f;
		CGFloat line = 2.0f * f;
		CGRect loop = CGRectMake(3.5f * f, 5 * f, 17 * f, 14 * f);
		CGContextSetLineWidth(ctx, line);
		CGFloat radius = 4.5f * f;
		CGContextMoveToPoint(ctx, CGRectGetMinX(loop) + radius, CGRectGetMinY(loop));
		CGContextAddLineToPoint(ctx, CGRectGetMaxX(loop) - radius - 3 * f,
			CGRectGetMinY(loop));
		CGContextStrokePath(ctx);
		CGContextAddArc(ctx, CGRectGetMaxX(loop) - radius, CGRectGetMinY(loop) + radius,
			radius, -(CGFloat)M_PI_2, 0, 0);
		CGContextAddLineToPoint(ctx, CGRectGetMaxX(loop), CGRectGetMaxY(loop) - radius);
		CGContextAddArc(ctx, CGRectGetMaxX(loop) - radius, CGRectGetMaxY(loop) - radius,
			radius, 0, (CGFloat)M_PI_2, 0);
		CGContextAddLineToPoint(ctx, CGRectGetMinX(loop) + radius, CGRectGetMaxY(loop));
		CGContextAddArc(ctx, CGRectGetMinX(loop) + radius, CGRectGetMaxY(loop) - radius,
			radius, (CGFloat)M_PI_2, (CGFloat)M_PI, 0);
		CGContextAddLineToPoint(ctx, CGRectGetMinX(loop), CGRectGetMinY(loop) + radius);
		CGContextAddArc(ctx, CGRectGetMinX(loop) + radius, CGRectGetMinY(loop) + radius,
			radius, (CGFloat)M_PI, (CGFloat)(M_PI * 1.5f), 0);
		CGContextStrokePath(ctx);
		CGFloat tipX = CGRectGetMaxX(loop) - radius - 3 * f;
		CGContextMoveToPoint(ctx, tipX - 3.4f * f, CGRectGetMinY(loop) - 3.6f * f);
		CGContextAddLineToPoint(ctx, tipX + 1.6f * f, CGRectGetMinY(loop));
		CGContextAddLineToPoint(ctx, tipX - 3.4f * f, CGRectGetMinY(loop) + 3.6f * f);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
		if ([name isEqualToString:@"repeatone"]) {
			UIFont *font = [UIFont boldSystemFontOfSize:9 * f];
			CGRect box = CGRectMake(0, (s - font.lineHeight) / 2 + f, s, font.lineHeight);
			[@"1" drawInRect:box withFont:font
				lineBreakMode:NSLineBreakByClipping
					alignment:NSTextAlignmentCenter];
		}
	} else if ([name isEqualToString:@"list"]) {
		CGFloat rowH = MAX((CGFloat)1.5, s * 0.10f);
		CGFloat dot = s * 0.16f;
		for (NSInteger i = 0; i < 3; i++) {
			CGFloat y = s * 0.20f + i * s * 0.30f;
			CGContextFillEllipseInRect(ctx, CGRectMake(0, y - dot / 2, dot, dot));
			CGContextFillRect(ctx, CGRectMake(dot * 1.8f, y - rowH / 2, s - dot * 1.8f, rowH));
		}
	} else if ([name isEqualToString:@"artwork"]) {
		CGFloat line = MAX((CGFloat)1.5, s * 0.08f);
		CGContextSetLineWidth(ctx, line);
		CGContextStrokeRect(ctx, CGRectInset(CGRectMake(0, 0, s, s), line, line));
		CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.26f, s * 0.26f, s * 0.2f, s * 0.2f));
		CGContextMoveToPoint(ctx, s * 0.16f, s * 0.78f);
		CGContextAddLineToPoint(ctx, s * 0.42f, s * 0.46f);
		CGContextAddLineToPoint(ctx, s * 0.66f, s * 0.78f);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	sPlayerGlyphs[key] = image;
	return image;
}

static UIImage *TGPlayerRowPlate(void) {
	TGTheme *theme = [TGTheme shared];
	if (!sPlayerGlyphs)
		sPlayerGlyphs = [NSMutableDictionary dictionary];
	NSString *key = [NSString stringWithFormat:@"plate-%@", [theme fileTileColour]];
	UIImage *cached = sPlayerGlyphs[key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(kRowTile, kRowTile), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect box = CGRectMake(0, 0, kRowTile, kRowTile);
	[[UIBezierPath bezierPathWithRoundedRect:box cornerRadius:3.0f] addClip];
	[[theme fileTileColour] set];
	CGContextFillRect(ctx, box);
	[[theme separatorColour] setStroke];
	CGContextSetLineWidth(ctx, 1);
	CGContextStrokeRect(ctx, CGRectInset(box, 0.5f, 0.5f));
	UIImage *note = [TGIcons musicNoteOfSide:kRowTile * 0.52f
									  colour:[[theme secondaryTextColour]
												 colorWithAlphaComponent:0.5f]];
	[note drawAtPoint:CGPointMake((kRowTile - note.size.width) / 2,
						  (kRowTile - note.size.height) / 2)];
	UIImage *plate = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	sPlayerGlyphs[key] = plate;
	return plate;
}

static UIImage *TGPlayerRowTile(UIImage *cover, BOOL current, BOOL playing) {
	UIImage *base = cover ? cover : TGPlayerRowPlate();
	if (!current)
		return base;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(kRowTile, kRowTile), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[base drawInRect:CGRectMake(0, 0, kRowTile, kRowTile)];
	CGFloat disc = kRowTile * 0.74f;
	[[UIColor colorWithWhite:0 alpha:0.45f] set];
	CGContextFillEllipseInRect(ctx, CGRectMake((kRowTile - disc) / 2, (kRowTile - disc) / 2, disc, disc));
	UIImage *glyph = TGPlayerGlyph(playing ? @"pause" : @"play",
		[UIColor whiteColor], disc);
	[glyph drawAtPoint:CGPointMake((kRowTile - glyph.size.width) / 2,
						   (kRowTile - glyph.size.height) / 2)];
	UIImage *tile = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return tile;
}

@interface TGMusicPlayerViewController () <UITableViewDataSource, UITableViewDelegate,
	UIGestureRecognizerDelegate>
@end

@implementation TGMusicPlayerViewController {
	UIView *_stage;
	UIView *_artworkPlate;
	UIImageView *_artwork;
	UIImageView *_placeholder;
	UILabel *_title;
	UILabel *_performer;

	UIView *_scrubArea;
	UIView *_trackLine;
	UIView *_fillLine;
	UIView *_knob;
	CGFloat _knobSide;
	UILabel *_elapsed;
	UILabel *_remaining;
	UIButton *_shuffle;
	UIButton *_repeat;

	UIView *_transport;
	UIView *_transportEdge;
	UIButton *_previous;
	UIButton *_toggle;
	UIButton *_next;

	UITableView *_playlist;
	UIBarButtonItem *_flipItem;
	UIButton *_flipButton;

	BOOL _showingPlaylist;
	BOOL _twoColumn;
	BOOL _scrubbing;
	CGFloat _scrubFraction;
	CGFloat _placeholderSide;
	id _musicPlayerStateObserverToken;
	id _musicPlayerProgressObserverToken;
	id _audioMetadataObserverToken;
	id _themeChangedObserverToken;
}

- (instancetype)init {
	if (!(self = [super initWithNibName:nil bundle:nil]))
		return nil;
	self.title = TGL(@"MusicPlayer.NowPlaying", @"Now Playing");
	self.wantsFullScreenLayout = NO;
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_musicPlayerStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_musicPlayerStateObserverToken];
	if (_musicPlayerProgressObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_musicPlayerProgressObserverToken];
	if (_audioMetadataObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_audioMetadataObserverToken];
	if (_themeChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_themeChangedObserverToken];
}

- (BOOL)isPad {
	return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

- (UIButton *)buttonWithAccessibilityLabel:(NSString *)label action:(SEL)action inView:(UIView *)host {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.adjustsImageWhenHighlighted = YES;
	button.accessibilityLabel = label;
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	[host addSubview:button];
	return button;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	_stage = [[UIView alloc] initWithFrame:CGRectZero];
	_stage.clipsToBounds = YES;
	[self.view addSubview:_stage];

	_artworkPlate = [[UIView alloc] initWithFrame:CGRectZero];
	_artworkPlate.layer.cornerRadius = kArtCorner;
	_artworkPlate.layer.borderWidth = 1.0f;
	_artworkPlate.clipsToBounds = YES;
	[_stage addSubview:_artworkPlate];

	_placeholder = [[UIImageView alloc] initWithFrame:CGRectZero];
	_placeholder.contentMode = UIViewContentModeCenter;
	[_artworkPlate addSubview:_placeholder];

	_artwork = [[UIImageView alloc] initWithFrame:CGRectZero];
	_artwork.contentMode = UIViewContentModeScaleAspectFill;
	_artwork.clipsToBounds = YES;
	[_artworkPlate addSubview:_artwork];

	_title = [[UILabel alloc] initWithFrame:CGRectZero];
	_title.backgroundColor = [UIColor clearColor];
	_title.textAlignment = NSTextAlignmentCenter;
	_title.font = [UIFont boldSystemFontOfSize:[self isPad] ? 20 : 17];
	[_stage addSubview:_title];

	_performer = [[UILabel alloc] initWithFrame:CGRectZero];
	_performer.backgroundColor = [UIColor clearColor];
	_performer.textAlignment = NSTextAlignmentCenter;
	_performer.font = [UIFont systemFontOfSize:[self isPad] ? 16 : 14];
	[_stage addSubview:_performer];

	_playlist = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
	_playlist.dataSource = self;
	_playlist.delegate = self;
	_playlist.rowHeight = kRowHeight;
	_playlist.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	_playlist.hidden = YES;
	[_stage addSubview:_playlist];

	_scrubArea = [[UIView alloc] initWithFrame:CGRectZero];
	[self.view addSubview:_scrubArea];

	_trackLine = [[UIView alloc] initWithFrame:CGRectZero];
	_trackLine.layer.cornerRadius = kTrackThickness / 2;
	[_scrubArea addSubview:_trackLine];

	_fillLine = [[UIView alloc] initWithFrame:CGRectZero];
	_fillLine.layer.cornerRadius = kTrackThickness / 2;
	[_scrubArea addSubview:_fillLine];

	UIImage *knobArt = [UIImage imageNamed:@"VideoSliderHandle.png"];
	if (knobArt) {
		_knob = [[UIImageView alloc] initWithImage:knobArt];
		_knobSide = knobArt.size.width;
	} else {
		_knob = [[UIView alloc] initWithFrame:CGRectZero];
		_knobSide = kKnobSide;
		_knob.layer.cornerRadius = kKnobSide / 2;
		_knob.layer.borderWidth = 0.5f;
		_knob.layer.shadowColor = [UIColor blackColor].CGColor;
		_knob.layer.shadowOffset = CGSizeMake(0, 1);
		_knob.layer.shadowOpacity = 0.3f;
		_knob.layer.shadowRadius = 1.5f;
	}
	[_scrubArea addSubview:_knob];

	_elapsed = [[UILabel alloc] initWithFrame:CGRectZero];
	_elapsed.backgroundColor = [UIColor clearColor];
	_elapsed.font = [UIFont systemFontOfSize:12];
	_elapsed.textAlignment = NSTextAlignmentLeft;
	[_scrubArea addSubview:_elapsed];

	_remaining = [[UILabel alloc] initWithFrame:CGRectZero];
	_remaining.backgroundColor = [UIColor clearColor];
	_remaining.font = [UIFont systemFontOfSize:12];
	_remaining.textAlignment = NSTextAlignmentRight;
	[_scrubArea addSubview:_remaining];

	_repeat = [self buttonWithAccessibilityLabel:TGL(@"VoiceOver.MusicPlayer.Repeat", @"Repeat")
										 action:@selector(repeatTapped) inView:_scrubArea];
	_shuffle = [self buttonWithAccessibilityLabel:TGL(@"VoiceOver.MusicPlayer.Shuffle", @"Shuffle")
										  action:@selector(shuffleTapped) inView:_scrubArea];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(scrubbed:)];
	pan.delegate = self;
	[_scrubArea addGestureRecognizer:pan];
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(scrubTapped:)];
	tap.delegate = self;
	[_scrubArea addGestureRecognizer:tap];

	_transport = [[UIView alloc] initWithFrame:CGRectZero];
	[self.view addSubview:_transport];

	_transportEdge = [[UIView alloc] initWithFrame:CGRectZero];
	[_transport addSubview:_transportEdge];

	_previous = [self buttonWithAccessibilityLabel:TGL(@"VoiceOver.MusicPlayer.Previous", @"Previous")
										   action:@selector(previousTapped) inView:_transport];
	_toggle = [self buttonWithAccessibilityLabel:TGL(@"VoiceOver.Media.PlaybackPlay", @"Play")
										 action:@selector(toggleTapped) inView:_transport];
	_next = [self buttonWithAccessibilityLabel:TGL(@"VoiceOver.MusicPlayer.Next", @"Next")
									   action:@selector(nextTapped) inView:_transport];

	self.navigationItem.leftBarButtonItem =
		[TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Done", @"Done") bold:YES
									   target:self
									   action:@selector(doneTapped)];

	_flipButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_flipButton.exclusiveTouch = YES;
	_flipButton.adjustsImageWhenDisabled = NO;
	_flipButton.adjustsImageWhenHighlighted = NO;
	_flipButton.frame = CGRectMake(0, 0, 38, 30);
	[TGIcons styleHeaderButton:_flipButton];
	_flipButton.accessibilityLabel = TGL(@"VoiceOver.MusicPlayer.Playlist", @"Playlist");
	[_flipButton addTarget:self action:@selector(flipTapped)
		  forControlEvents:UIControlEventTouchUpInside];
	_flipItem = [[UIBarButtonItem alloc] initWithCustomView:_flipButton];
	self.navigationItem.rightBarButtonItem = _flipItem;

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

	[self restyle];
	[self sync];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self sync];
}

#pragma mark - notifications

- (void)playerNotified:(NSNotification *)note {
	[self sync];
}
- (void)progressNotified:(NSNotification *)note {
	[self progressed];
}

- (void)themeNotified:(NSNotification *)note {
	[sPlayerGlyphs removeAllObjects];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self restyle];
	[self sync];
}

#pragma mark - appearance

- (UIColor *)barGlyphColour {
	TGTheme *theme = [TGTheme shared];
	return [theme barTitleColour];
}

- (void)restyle {
	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme listBackgroundColour];
	_stage.backgroundColor = [theme listBackgroundColour];
	_artworkPlate.backgroundColor = [theme fileTileColour];
	_artworkPlate.layer.borderColor = [theme separatorColour].CGColor;
	_title.textColor = [theme primaryTextColour];
	_performer.textColor = [theme secondaryTextColour];
	_trackLine.backgroundColor = [theme separatorColour];
	_fillLine.backgroundColor = [theme accentColour];
	if (![_knob isKindOfClass:[UIImageView class]]) {
		_knob.backgroundColor = [UIColor whiteColor];
		_knob.layer.borderColor = [theme separatorColour].CGColor;
	}
	_elapsed.textColor = [theme secondaryTextColour];
	_remaining.textColor = [theme secondaryTextColour];
	_playlist.backgroundColor = [theme listBackgroundColour];
	_playlist.separatorColor = [theme separatorColour];
	_transport.backgroundColor = [theme inputBarColour];
	_transportEdge.backgroundColor = [theme separatorColour];
	_placeholderSide = 0;
	if (_flipButton)
		[TGIcons styleHeaderButton:_flipButton];
	[self applyGlyphs];
	[_playlist reloadData];
}

- (void)applyGlyphs {
	TGTheme *theme = [TGTheme shared];
	UIColor *ink = [theme accentColour];
	UIColor *idle = [theme secondaryTextColour];
	TGMusicPlayer *player = [TGMusicPlayer shared];
	CGFloat scale = [self isPad] ? 1.3f : 1.0f;

	[_previous setImage:TGPlayerGlyph(@"previous", ink, kSkipGlyph * scale)
			   forState:UIControlStateNormal];
	[_next setImage:TGPlayerGlyph(@"next", ink, kSkipGlyph * scale)
		   forState:UIControlStateNormal];
	[_toggle setImage:TGPlayerGlyph(player.playing ? @"pause" : @"play",
						  ink, kPlayGlyph * scale)
			 forState:UIControlStateNormal];
	_toggle.accessibilityLabel = player.playing
		? TGL(@"Conversation.StopVoiceMessagePauseAction", @"Pause")
		: TGL(@"VoiceOver.Media.PlaybackPlay", @"Play");
	[_shuffle setImage:TGPlayerGlyph(@"shuffle",
						   player.shuffleEnabled ? ink : idle, kModeGlyph)
			  forState:UIControlStateNormal];

	NSString *repeatName = (player.repeatMode == TGMusicRepeatOne) ? @"repeatone" : @"repeat";
	UIColor *repeatInk = (player.repeatMode == TGMusicRepeatOff) ? idle : ink;
	[_repeat setImage:TGPlayerGlyph(repeatName, repeatInk, kModeGlyph)
			 forState:UIControlStateNormal];

	[_flipButton setImage:TGPlayerGlyph(_showingPlaylist ? @"artwork" : @"list",
							  [self barGlyphColour], 18)
				 forState:UIControlStateNormal];
}

#pragma mark - layout

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];

	CGFloat w = self.view.bounds.size.width;
	CGFloat h = self.view.bounds.size.height;
	if (w <= 0 || h <= 0)
		return;

	BOOL pad = [self isPad];
	CGFloat inset = MAX((CGFloat)16, MIN((CGFloat)44, w * 0.0625f));
	CGFloat transportH = pad ? kTransportPad : kTransportPhone;

	_transport.frame = CGRectMake(0, h - transportH, w, transportH);
	_transportEdge.frame = CGRectMake(0, 0, w, 0.5f);
	[self layoutTransportInWidth:w height:transportH];

	CGFloat stageH = h - transportH;
	CGFloat fixed = kStageTopGap + kGapArtTitle + kTitleHeight + kPerformerHeight +
		kGapTitleScrub + kScrubHeight + kGapScrubTransport;
	BOOL twoColumn = (stageH - fixed) < 140.0f && w > h;

	_twoColumn = twoColumn;
	if (twoColumn) {
		CGFloat art = MIN(stageH - 2 * kStageTopGap, (w - 3 * inset) * 0.42f);
		CGFloat artY = (stageH - art) / 2;
		CGFloat columnX = inset * 2 + art;
		CGFloat columnW = MAX((CGFloat)120, w - columnX - inset);
		CGFloat block = kTitleHeight + kPerformerHeight + kGapTitleScrub + kScrubHeight;
		CGFloat blockY = (stageH - block) / 2;

		_stage.frame = CGRectMake(0, 0, w, stageH);
		_artworkPlate.frame = CGRectMake(inset, artY, art, art);
		_title.frame = CGRectMake(columnX, blockY, columnW, kTitleHeight);
		_performer.frame = CGRectMake(columnX, blockY + kTitleHeight,
			columnW, kPerformerHeight);
		_title.textAlignment = TGLocalizedLeadingTextAlignment();
		_performer.textAlignment = TGLocalizedLeadingTextAlignment();
		_playlist.frame = _stage.bounds;
		_scrubArea.frame = CGRectMake(columnX,
			blockY + kTitleHeight + kPerformerHeight +
				kGapTitleScrub,
			columnW, kScrubHeight);
	} else {
		CGFloat art = MIN(MIN(w - 2 * inset, stageH - fixed), kArtMaxSide);
		CGFloat column = MIN(w - 2 * inset, MAX(art, kColumnMinWidth));
		CGFloat columnX = (w - column) / 2;
		CGFloat group = art + kGapArtTitle + kTitleHeight + kPerformerHeight +
			kGapTitleScrub + kScrubHeight;
		CGFloat y = MAX(kStageTopGap, (stageH - kGapScrubTransport - group) / 2);

		_artworkPlate.frame = CGRectMake((w - art) / 2, y, art, art);
		y += art + kGapArtTitle;
		_title.textAlignment = NSTextAlignmentCenter;
		_performer.textAlignment = NSTextAlignmentCenter;
		_title.frame = CGRectMake(columnX, y, column, kTitleHeight);
		y += kTitleHeight;
		_performer.frame = CGRectMake(columnX, y, column, kPerformerHeight);
		y += kPerformerHeight + kGapTitleScrub;
		_stage.frame = CGRectMake(0, 0, w, y);
		_playlist.frame = _stage.bounds;
		_scrubArea.frame = CGRectMake(columnX, y, column, kScrubHeight);
	}

	[self syncStageVisibility];
	_artwork.frame = _artworkPlate.bounds;
	_placeholder.frame = _artworkPlate.bounds;
	[self applyPlaceholderForSide:_artworkPlate.bounds.size.width];

	CGFloat sw = _scrubArea.bounds.size.width;
	_trackLine.frame = CGRectMake(0, kScrubSliderRow / 2 - kTrackThickness / 2,
		sw, kTrackThickness);
	CGFloat labelY = kScrubSliderRow;
	CGFloat labelH = kScrubHeight - kScrubSliderRow;
	_repeat.frame = CGRectMake(0, labelY + (labelH - kModeSide) / 2, kModeSide, kModeSide);
	_shuffle.frame = CGRectMake(sw - kModeSide, labelY + (labelH - kModeSide) / 2,
		kModeSide, kModeSide);
	CGFloat clockW = MIN(kClockWidth, MAX((CGFloat)40, (sw - 2 * kModeSide - 16) / 2));
	_elapsed.frame = CGRectMake(kModeSide + 6, labelY, clockW, labelH);
	_remaining.frame = CGRectMake(sw - kModeSide - 6 - clockW, labelY, clockW, labelH);

	[self layoutProgress];
}

- (void)layoutTransportInWidth:(CGFloat)w height:(CGFloat)transportH {
	CGFloat spread = MAX((CGFloat)72, MIN((CGFloat)130, w * 0.22f));
	CGFloat wide = [self isPad] ? 80.0f : 64.0f;
	CGFloat side = [self isPad] ? 72.0f : 56.0f;
	_toggle.frame = CGRectMake(w / 2 - wide / 2, 0, wide, transportH);
	_previous.frame = CGRectMake(w / 2 - spread - side / 2, 0, side, transportH);
	_next.frame = CGRectMake(w / 2 + spread - side / 2, 0, side, transportH);
}

- (void)applyPlaceholderForSide:(CGFloat)side {
	if (side <= 0 || fabsf(side - _placeholderSide) < 0.5f)
		return;
	_placeholderSide = side;
	_placeholder.image = [TGIcons musicNoteOfSide:floorf(side * 0.42f)
										   colour:[[TGTheme shared] separatorColour]];
}

- (void)layoutProgress {
	CGFloat sw = _scrubArea.bounds.size.width;
	if (sw <= 0)
		return;
	CGFloat fraction = _scrubbing ? _scrubFraction : [TGMusicPlayer shared].playedFraction;
	fraction = MAX((CGFloat)0, MIN((CGFloat)1, fraction));
	CGFloat trackY = kScrubSliderRow / 2 - kTrackThickness / 2;
	_fillLine.frame = CGRectMake(0, trackY, sw * fraction, kTrackThickness);
	_knob.frame = CGRectMake(sw * fraction - _knobSide / 2,
		kScrubSliderRow / 2 - _knobSide / 2,
		_knobSide, _knobSide);
	[self syncClocks:fraction];
}

- (void)syncClocks:(CGFloat)fraction {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	NSTimeInterval duration = player.duration;
	if (duration <= 0)
		duration = [player.currentTrack[TGMusicTrackDuration] doubleValue];
	NSTimeInterval position = _scrubbing ? duration * fraction : player.currentTime;
	if (duration > 0 && position > duration)
		position = duration;
	_elapsed.text = TGPlayerClock(position, NO);
	_remaining.text = duration > 0 ? TGPlayerClock(duration - position, YES) : @"-0:00";
}

#pragma mark - state

- (TGAudioMetadata *)currentTags {
	NSDictionary *track = [TGMusicPlayer shared].currentTrack;
	int64_t fileId = [track[TGMusicTrackFileId] longLongValue];
	if (!fileId)
		return nil;
	TGAudioMetadata *tags = [TGAudioMetadata cachedForFileId:fileId];
	if (!tags)
		[TGAudioMetadata requestForFileId:fileId];
	return tags;
}

- (void)sync {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	NSDictionary *track = player.currentTrack;
	if (!track) {
		[self dismiss];
		return;
	}

	self.title = player.chatTitle.length ? player.chatTitle : TGL(@"MusicPlayer.NowPlaying", @"Now Playing");

	TGAudioMetadata *tags = [self currentTags];

	NSString *title = track[TGMusicTrackTitle];
	if (!title.length)
		title = tags.title;
	if (!title.length && [track[TGMusicTrackFileName] length])
		title = [[track[TGMusicTrackFileName] lastPathComponent]
			stringByDeletingPathExtension];
	_title.text = title.length ? title : TGL(@"MediaPlayer.UnknownTrack", @"Unknown Track");

	NSString *performer = track[TGMusicTrackPerformer];
	if (!performer.length)
		performer = tags.performer;
	if (player.loading)
		_performer.text = TGL(@"MediaPlayer.Loading", @"Loading…");
	else if (performer.length)
		_performer.text = performer;
	else
		_performer.text = TGL(@"MediaPlayer.UnknownArtist", @"Unknown Artist");

	UIImage *artwork = tags.artwork;
	if (!artwork)
		artwork = [player currentArtwork];
	_artwork.image = artwork;
	_artwork.hidden = (artwork == nil);
	_placeholder.hidden = (artwork != nil);

	[_playlist reloadData];
	NSInteger index = player.currentIndex;
	if (_showingPlaylist && index >= 0 && index < (NSInteger)player.playlist.count)
		[_playlist scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
						 atScrollPosition:UITableViewScrollPositionMiddle
								 animated:NO];

	BOOL canPrevious = [player hasPrevious];
	BOOL canNext = [player hasNext];
	_previous.enabled = canPrevious;
	_next.enabled = canNext;
	_previous.alpha = canPrevious ? 1.0f : 0.35f;
	_next.alpha = canNext ? 1.0f : 0.35f;

	[self applyGlyphs];
	[self layoutProgress];
}

- (void)progressed {
	if (_scrubbing)
		return;
	[self layoutProgress];
}

#pragma mark - playlist

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[TGMusicPlayer shared].playlist.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *identifier = @"TGMusicPlaylistCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:identifier];
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
		UIView *clockBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 54, kRowHeight)];
		clockBox.backgroundColor = [UIColor clearColor];
		UILabel *clock = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 46, kRowHeight)];
		clock.tag = 0x7C10;
		clock.backgroundColor = [UIColor clearColor];
		clock.textAlignment = NSTextAlignmentRight;
		clock.font = [UIFont systemFontOfSize:13];
		[clockBox addSubview:clock];
		cell.accessoryView = clockBox;
	}

	TGMusicPlayer *player = [TGMusicPlayer shared];
	NSArray *tracks = player.playlist;
	if (indexPath.row >= (NSInteger)tracks.count)
		return cell;

	TGTheme *theme = [TGTheme shared];
	NSDictionary *track = tracks[indexPath.row];
	BOOL current = (indexPath.row == player.currentIndex);
	long long trackFileId = [track[TGMusicTrackFileId] longLongValue];
	TGAudioMetadata *tags = [TGAudioMetadata cachedForFileId:trackFileId];
	if (!tags)
		[TGAudioMetadata requestForFileId:trackFileId];

	NSString *title = track[TGMusicTrackTitle];
	if (!title.length)
		title = tags.title;
	if (!title.length && [track[TGMusicTrackFileName] length])
		title = [[track[TGMusicTrackFileName] lastPathComponent]
			stringByDeletingPathExtension];
	cell.textLabel.text = title.length ? title : TGL(@"MediaPlayer.UnknownTrack", @"Unknown Track");

	NSString *performer = track[TGMusicTrackPerformer];
	if (!performer.length)
		performer = tags.performer;
	cell.detailTextLabel.text = performer.length ? performer : TGL(@"MediaPlayer.UnknownArtist", @"Unknown Artist");

	NSInteger seconds = [track[TGMusicTrackDuration] integerValue];
	UILabel *clock = (UILabel *)[cell.accessoryView viewWithTag:0x7C10];
	clock.text = seconds > 0 ? TGPlayerClock(seconds, NO) : @"";
	clock.textColor = [theme secondaryTextColour];

	cell.textLabel.textColor = current ? [theme accentColour] : [theme primaryTextColour];
	cell.detailTextLabel.textColor = [theme secondaryTextColour];
	cell.backgroundColor = [theme listBackgroundColour];
	cell.imageView.image = TGPlayerRowTile(
		[TGAudioMetadata artworkTileOfSide:kRowTile cornerRadius:3 scrim:NO
							   forMetadata:tags],
		current, player.playing);
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[[TGMusicPlayer shared] playTrackAtIndex:indexPath.row];
	[self sync];
}

#pragma mark - controls

- (void)doneTapped {
	[self dismiss];
}

- (void)dismiss {
	UIViewController *presented = self.navigationController
		? (UIViewController *)self.navigationController
		: (UIViewController *)self;
	if (presented.presentingViewController)
		[presented dismissViewControllerAnimated:YES completion:nil];
	else if (self.navigationController.viewControllers.count > 1)
		[self.navigationController popViewControllerAnimated:YES];
}

- (void)syncStageVisibility {
	_artworkPlate.hidden = _showingPlaylist;
	_title.hidden = _showingPlaylist;
	_performer.hidden = _showingPlaylist;
	_playlist.hidden = !_showingPlaylist;
	_scrubArea.hidden = (_showingPlaylist && _twoColumn);
}

- (void)flipTapped {
	_showingPlaylist = !_showingPlaylist;
	if (_showingPlaylist)
		[_playlist reloadData];

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.4];
	[UIView setAnimationTransition:(_showingPlaylist
										   ? UIViewAnimationTransitionFlipFromRight
										   : UIViewAnimationTransitionFlipFromLeft)
						   forView:_stage
							 cache:YES];
	[self syncStageVisibility];
	[UIView commitAnimations];

	[self applyGlyphs];
	NSInteger index = [TGMusicPlayer shared].currentIndex;
	if (_showingPlaylist && index >= 0 &&
		index < (NSInteger)[TGMusicPlayer shared].playlist.count)
		[_playlist scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
						 atScrollPosition:UITableViewScrollPositionMiddle
								 animated:NO];
}

- (void)toggleTapped {
	[[TGMusicPlayer shared] toggle];
	[self applyGlyphs];
}
- (void)nextTapped {
	[[TGMusicPlayer shared] playNext];
}
- (void)previousTapped {
	[[TGMusicPlayer shared] playPrevious];
}

- (void)shuffleTapped {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	player.shuffleEnabled = !player.shuffleEnabled;
	[self applyGlyphs];
}

- (void)repeatTapped {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	if (player.repeatMode == TGMusicRepeatOff)
		player.repeatMode = TGMusicRepeatAll;
	else if (player.repeatMode == TGMusicRepeatAll)
		player.repeatMode = TGMusicRepeatOne;
	else
		player.repeatMode = TGMusicRepeatOff;
	[self applyGlyphs];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recogniser
	   shouldReceiveTouch:(UITouch *)touch {
	if ([touch.view isKindOfClass:[UIControl class]])
		return NO;
	return [touch locationInView:_scrubArea].y <= kScrubSliderRow + 8;
}

- (void)scrubTapped:(UITapGestureRecognizer *)tap {
	CGFloat width = _scrubArea.bounds.size.width;
	if (width <= 0)
		return;
	CGFloat x = [tap locationInView:_scrubArea].x;
	[[TGMusicPlayer shared] seekToFraction:MAX((CGFloat)0, MIN((CGFloat)1, x / width))];
}

- (void)scrubbed:(UIPanGestureRecognizer *)pan {
	CGFloat width = _scrubArea.bounds.size.width;
	if (width <= 0)
		return;
	CGFloat x = [pan locationInView:_scrubArea].x;
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

	CGFloat target = _scrubFraction;
	_scrubbing = NO;
	if (pan.state == UIGestureRecognizerStateEnded)
		[[TGMusicPlayer shared] seekToFraction:target];
	[self layoutProgress];
}

#pragma mark - rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	if ([self isPad])
		return YES;
	return orientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate {
	return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	if ([self isPad])
		return UIInterfaceOrientationMaskAll;
	return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
