#import "TGStickerPanelView.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import <QuartzCore/QuartzCore.h>

#import "TGActionSheet.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"
#import "TGReusableView.h"
#import "UIView+SafeTint.h"

const CGFloat kStickerPanelKeyBarHeight = 44.0f;
const CGFloat kStickerPanelKeyHeight = 30.0f;
const CGFloat kStickerPanelKeyTop = 7.0f;
const CGFloat kStickerPanelKeyMinWidth = 48.0f;
const CGFloat kStickerPanelFunctionKeyWidth = 44.0f;
const CGFloat kStickerPanelHeaderHeight = 22.0f;
const CGFloat kStickerPanelTileSide = 62.0f;
const CGFloat kStickerPanelSideInset = 3.0f;
const CGFloat kStickerPanelRowSpacing = 7.0f;
const NSInteger kStickerPanelMinColumns = 4;
const CGFloat kStickerPanelTileCornerRadius = 6.0f;
const CGFloat kStickerPanelPreviewSide = 180.0f;
const CGFloat kStickerPanelSearchHeight = 44.0f;
const CGFloat kStickerPanelTabThumbSide = 24.0f;
const CGFloat kStickerPanelPurgeDistance = 900.0f;
const NSInteger kStickerPanelPageSize = 40;

const CGFloat kStickerPanelKeyboardHeightPortrait = 216.0f;
const CGFloat kStickerPanelKeyboardHeightLandscape = 162.0f;

CGFloat TGStickerPanelMeasuredPortrait = 0.0f;
CGFloat TGStickerPanelMeasuredLandscape = 0.0f;
const NSInteger kStickerSectionRecent = 0;
const NSInteger kStickerSectionFavourite = 1;
const NSInteger kStickerSectionSet = 2;
const NSInteger kStickerSectionEmojiSet = 3;
const NSInteger kStickerSectionTrending = 4;
const NSInteger kStickerSectionPublicSet = 5;
const NSInteger kStickerSectionSearch = 6;

const NSInteger kStickerPanelTrendingLimit = 6;
const NSInteger kStickerPanelAddButtonTag = 9902;

BOOL TGStickerSectionIsSet(NSInteger kind) {
	return kind == kStickerSectionSet || kind == kStickerSectionEmojiSet ||
		kind == kStickerSectionTrending || kind == kStickerSectionPublicSet;
}

UIColor *TGStickerPanelGroundTopColour(void) {
	return [UIColor colorWithRed:0xd5 / 255.0f green:0xdc / 255.0f blue:0xe5 / 255.0f alpha:1.0f];
}

UIColor *TGStickerPanelGroundBottomColour(void) {
	return [UIColor colorWithRed:0xae / 255.0f green:0xb8 / 255.0f blue:0xc4 / 255.0f alpha:1.0f];
}

UIColor *TGStickerPanelSeamColour(void) {
	return [UIColor colorWithRed:0x81 / 255.0f green:0x92 / 255.0f blue:0x9f / 255.0f alpha:1.0f];
}

UIColor *TGStickerPanelEngravedColour(void) {
	return [UIColor colorWithRed:0x5c / 255.0f green:0x70 / 255.0f blue:0x8b / 255.0f alpha:1.0f];
}

UIImage *TGStickerPanelKeyPlate(BOOL pressed) {
	static UIImage *plainPlate = nil;
	static UIImage *pressedPlate = nil;
	UIImage *cached = pressed ? pressedPlate : plainPlate;
	if (cached != nil)
		return cached;

	UIImage *plate = [UIImage imageNamed:pressed
			? @"SearchBarScopeButton_Highlighted.png"
			: @"SearchBarScopeButton.png"];
	if (plate == nil)
		return nil;
	cached = [plate stretchableImageWithLeftCapWidth:(int)(plate.size.width / 2.0f)
										topCapHeight:(int)(plate.size.height / 2.0f)];
	if (pressed)
		pressedPlate = cached;
	else
		plainPlate = cached;
	return cached;
}

UIImage *TGStickerPanelBackspaceGlyph(void) {
	static UIImage *glyph = nil;
	if (glyph != nil)
		return glyph;

	CGSize size = CGSizeMake(22.0f, 16.0f);
	UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
	CGContextRef context = UIGraphicsGetCurrentContext();

	CGFloat notch = 7.0f;
	CGContextBeginPath(context);
	CGContextMoveToPoint(context, 0.5f, 8.0f);
	CGContextAddLineToPoint(context, notch, 0.5f);
	CGContextAddLineToPoint(context, 21.5f, 0.5f);
	CGContextAddLineToPoint(context, 21.5f, 15.5f);
	CGContextAddLineToPoint(context, notch, 15.5f);
	CGContextClosePath(context);
	CGContextSetFillColorWithColor(context,
		[UIColor colorWithWhite:0.24f alpha:1.0f].CGColor);
	CGContextFillPath(context);

	CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
	CGContextSetLineWidth(context, 1.6f);
	CGContextSetLineCap(context, kCGLineCapRound);
	CGContextMoveToPoint(context, 11.0f, 5.0f);
	CGContextAddLineToPoint(context, 17.0f, 11.0f);
	CGContextMoveToPoint(context, 17.0f, 5.0f);
	CGContextAddLineToPoint(context, 11.0f, 11.0f);
	CGContextStrokePath(context);

	glyph = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return glyph;
}

UIImage *TGStickerPanelSearchGlyph(void) {
	UIImage *icon = [UIImage imageNamed:@"SearchBarIcon.png"];
	return icon;
}

NSMutableArray *TGStickerPanelSectionSnapshot = nil;
NSTimeInterval TGStickerPanelSnapshotTaken = 0;
const NSTimeInterval kStickerPanelSnapshotLifetime = 600.0;

@implementation TGStickerPanelView

@dynamic searchVisible;

+ (void)noteSystemKeyboardHeight:(CGFloat)height landscape:(BOOL)landscape {
	if (height < 80.0f || height > 400.0f)
		return;
	if (landscape)
		TGStickerPanelMeasuredLandscape = height;
	else
		TGStickerPanelMeasuredPortrait = height;
}

+ (CGFloat)preferredHeightForLandscape:(BOOL)landscape {
	CGFloat measured = landscape ? TGStickerPanelMeasuredLandscape : TGStickerPanelMeasuredPortrait;
	if (measured > 80.0f)
		return measured;
	return landscape ? kStickerPanelKeyboardHeightLandscape
					 : kStickerPanelKeyboardHeightPortrait;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.backgroundColor = [[TGTheme shared] listBackgroundColour];
		self.clipsToBounds = YES;

		_ground = [CAGradientLayer layer];
		_ground.colors = [NSArray arrayWithObjects:
				(id)TGStickerPanelGroundTopColour().CGColor,
			(id)TGStickerPanelGroundBottomColour().CGColor, nil];
		_ground.frame = self.bounds;
		[self.layer insertSublayer:_ground atIndex:0];

		_recycler = [[TGViewRecycler alloc] init];
		_allSections = [[NSMutableArray alloc] init];
		_sections = [[NSMutableArray alloc] init];
		_searchSections = [[NSMutableArray alloc] init];
		_menuSectionIndex = -1;
		_visibleTiles = [[NSMutableDictionary alloc] init];
		_headerViews = [[NSMutableArray alloc] init];
		_tabButtons = [[NSMutableArray alloc] init];
		_tabDividers = [[NSMutableArray alloc] init];
		_tabImageTokens = [[NSMutableArray alloc] init];
		_columns = kStickerPanelMinColumns;
		_tileSide = kStickerPanelTileSide;
		_tileSpacing = 0.0f;
		_rowSpacing = kStickerPanelRowSpacing;
		_sideInset = kStickerPanelSideInset;

		_selectedSection = -1;
		_searchQuery = @"";

		_grid = [[UIScrollView alloc] initWithFrame:CGRectZero];
		_grid.delegate = self;
		_grid.showsVerticalScrollIndicator = YES;
		_grid.alwaysBounceVertical = YES;
		_grid.backgroundColor = [UIColor clearColor];
		[self addSubview:_grid];

		_keyBar = [[UIView alloc] initWithFrame:CGRectZero];
		_keyBar.backgroundColor = [UIColor clearColor];
		_keyBar.clipsToBounds = NO;
		[self addSubview:_keyBar];

		_keyBarSeam = [[UIView alloc] initWithFrame:CGRectZero];
		_keyBarSeam.backgroundColor =
			[TGStickerPanelSeamColour() colorWithAlphaComponent:0.45f];
		[_keyBar addSubview:_keyBarSeam];

		_keyBarSheen = [[UIView alloc] initWithFrame:CGRectZero];
		_keyBarSheen.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.35f];
		[_keyBar addSubview:_keyBarSheen];

		_tabStrip = [[UIScrollView alloc] initWithFrame:CGRectZero];
		_tabStrip.showsHorizontalScrollIndicator = NO;
		_tabStrip.backgroundColor = [UIColor clearColor];
		[_keyBar addSubview:_tabStrip];

		_searchKey = [self functionKeyWithGlyph:TGStickerPanelSearchGlyph() title:TGL(@"Stickers.FindButton", @"Find")];
		[_searchKey addTarget:self action:@selector(toggleSearch)
			 forControlEvents:UIControlEventTouchUpInside];
		[_keyBar addSubview:_searchKey];

		_backspaceKey = [self functionKeyWithGlyph:TGStickerPanelBackspaceGlyph() title:nil];
		[_backspaceKey addTarget:self action:@selector(backspaceTapped)
				forControlEvents:UIControlEventTouchUpInside];
		[_keyBar addSubview:_backspaceKey];

		_searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
		_searchBar.delegate = self;
		_searchBar.placeholder = TGL(@"Stickers.Search", @"Search Stickers");
		_searchBar.showsCancelButton = YES;
		_searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
		_searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
		_searchBar.barStyle = UIBarStyleDefault;
		[_searchBar tg_setTintColor:[[TGTheme shared] accentColour]];
		_searchBar.hidden = YES;
		[self addSubview:_searchBar];

		_topSeparator = [[UIView alloc] initWithFrame:CGRectZero];
		_topSeparator.backgroundColor = TGStickerPanelSeamColour();
		[self addSubview:_topSeparator];

		_spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
				UIActivityIndicatorViewStyleGray];
		_spinner.hidesWhenStopped = YES;
		[self addSubview:_spinner];

		_statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_statusLabel.backgroundColor = [UIColor clearColor];
		_statusLabel.textAlignment = NSTextAlignmentCenter;
		_statusLabel.font = [UIFont boldSystemFontOfSize:14];
		_statusLabel.textColor = TGStickerPanelEngravedColour();
		_statusLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.5f];
		_statusLabel.shadowOffset = CGSizeMake(0, 1);
		_statusLabel.numberOfLines = 2;
		_statusLabel.hidden = YES;
		[self addSubview:_statusLabel];

		_retryButton = [UIButton buttonWithType:UIButtonTypeCustom];
		UIImage *plate = [UIImage imageNamed:@"GroupedActionButton.png"];
		UIImage *platePressed = [UIImage imageNamed:@"GroupedActionButton_Highlighted.png"];
		[_retryButton setBackgroundImage:[plate stretchableImageWithLeftCapWidth:24 topCapHeight:0]
								forState:UIControlStateNormal];
		[_retryButton setBackgroundImage:[platePressed stretchableImageWithLeftCapWidth:24 topCapHeight:0]
								forState:UIControlStateHighlighted];
		[_retryButton setTitle:TGL(@"Conversation.MessageDialogRetry", @"Resend") forState:UIControlStateNormal];
		[_retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		_retryButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		_retryButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
		UIColor *retryShadowColour = [UIColor colorWithRed:0x0e / 255.0f green:0x28 / 255.0f blue:0x4d / 255.0f alpha:0.4f];
		[_retryButton setTitleShadowColor:retryShadowColour forState:UIControlStateNormal];
		_retryButton.hidden = YES;
		[_retryButton addTarget:self action:@selector(reload)
			   forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:_retryButton];

		NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
		__weak typeof(self) weakSelf = self;
		self.memoryWarningObserverToken = [centre
			addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf handleMemoryWarning];
					}];

		self.stickerSetsObserverToken = [centre
			addObserverForName:TGInstalledStickerSetsDidChangeNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf installedStickerSetsChanged:note];
					}];

		self.recentStickersObserverToken = [centre
			addObserverForName:TGRecentStickersDidChangeNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf refreshRecent];
					}];

		self.favoriteStickersObserverToken = [centre
			addObserverForName:TGFavoriteStickersDidChangeNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf refreshFavourites];
					}];

		_openedAt = [NSDate timeIntervalSinceReferenceDate];
		[TGStickerThumbnailCache resetStatistics];

		_restoredFromSnapshot = [self restoreSectionSnapshot];
		if (_restoredFromSnapshot)
			[self reloadShowingSpinner:NO];
		else
			[self reload];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.memoryWarningObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.memoryWarningObserverToken];
	if (self.stickerSetsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.stickerSetsObserverToken];
	if (self.recentStickersObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.recentStickersObserverToken];
	if (self.favoriteStickersObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.favoriteStickersObserverToken];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self cancelAllPendingImageLoads];
	[_previewOverlay removeFromSuperview];
	_grid.delegate = nil;
	_searchBar.delegate = nil;
}

- (void)releaseImageForTile:(TGStickerTile *)tile {
	if (tile.imageToken != nil)
		[TGStickerThumbnailCache cancelRequest:tile.imageToken];
	tile.imageToken = nil;
	tile.imageKey = nil;
}

- (void)cancelTabImageLoads {
	for (id token in self.tabImageTokens)
		[TGStickerThumbnailCache cancelRequest:token];
	[self.tabImageTokens removeAllObjects];
}

- (void)cancelAllPendingImageLoads {
	for (NSString *key in [self.visibleTiles allKeys])
		[self releaseImageForTile:self.visibleTiles[key]];
	[self cancelTabImageLoads];
	[self cancelPreviewLoad];
}

- (void)handleMemoryWarning {
	[TGStickerThumbnailCache purgeMemory];
	[self.recycler removeAllViews];
	[self purgeDistantSectionsAggressively:YES];
	[self invalidateSectionSnapshot];
}

- (void)installedStickerSetsChanged:(NSNotification *)note {
	[self invalidateSectionSnapshot];
}

- (void)invalidateSectionSnapshot {
	TGStickerPanelSectionSnapshot = nil;
	TGStickerPanelSnapshotTaken = 0;
}

@end
