#import "TGAssetPicker.h"
#import "TGLocalization.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import "TGLazyFramework.h"
#import <QuartzCore/QuartzCore.h>

#import "TGTheme.h"
#import "TGViewRecycler.h"
#import "TGReusableView.h"

static const CGFloat kTileSide = 75.0f;
static const CGFloat kTileSpacing = 4.0f;
static const CGFloat kCheckSide = 33.0f;
static const CGFloat kPanelFallback = 45.0f;
static const CGFloat kButtonWidth = 62.0f;
static const NSUInteger kThumbnailCacheCount = 64;
static const NSUInteger kDefaultSelectionLimit = 30;

static NSInteger TGAssetPickerAvailability = -1;

static dispatch_queue_t TGAssetPickerQueue(void) {
	static dispatch_queue_t queue = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("com.kern0x1b.telegram.assetpicker", NULL);
	});
	return queue;
}

static UIImage *TGAssetPickerStretch(NSString *name, int leftCap) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
}

static UIImage *TGAssetPickerCheckImage(NSInteger number, UIColor *accent) {
	CGSize size = CGSizeMake(kCheckSide, kCheckSide);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect disc = CGRectInset(CGRectMake(0, 0, size.width, size.height), 3.0f, 3.0f);

	CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1.5f,
		[UIColor colorWithWhite:0.0f alpha:0.45f].CGColor);
	if (number > 0)
		CGContextSetFillColorWithColor(context, accent.CGColor);
	else
		CGContextSetFillColorWithColor(context,
			[UIColor colorWithWhite:0.0f alpha:0.28f].CGColor);
	CGContextFillEllipseInRect(context, disc);
	CGContextSetShadowWithColor(context, CGSizeZero, 0.0f, NULL);

	CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
	CGContextSetLineWidth(context, 1.5f);
	CGContextStrokeEllipseInRect(context, CGRectInset(disc, 0.75f, 0.75f));

	if (number > 0) {
		NSString *text = [NSString stringWithFormat:@"%d", (int)number];
		UIFont *font = [UIFont boldSystemFontOfSize:(number > 99 ? 11.0f : 14.0f)];
		CGSize textSize = [text sizeWithFont:font];
		CGRect where = CGRectMake((CGFloat)(int)((size.width - textSize.width) / 2.0f),
			(CGFloat)(int)((size.height - textSize.height) / 2.0f),
			textSize.width, textSize.height);
		[[UIColor whiteColor] set];
		[text drawInRect:where withFont:font lineBreakMode:NSLineBreakByClipping];
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static UIImage *TGAssetPickerBadgeImage(void) {
	CGFloat height = 20.0f;
	CGSize size = CGSizeMake(height, height);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect body = CGRectMake(0, 0, height, height);
	CGContextSetFillColorWithColor(context,
		[UIColor colorWithRed:0.08f green:0.71f blue:0.0f alpha:1.0f].CGColor);
	CGContextFillEllipseInRect(context, body);
	CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
	CGContextSetLineWidth(context, 1.0f);
	CGContextStrokeEllipseInRect(context, CGRectInset(body, 0.5f, 0.5f));

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return [image stretchableImageWithLeftCapWidth:(int)(height / 2) topCapHeight:0];
}

static NSString *TGAssetPickerStage(ALAsset *asset, double stamp, NSInteger serial) {
	ALAssetRepresentation *representation = [asset defaultRepresentation];
	if (!representation)
		return nil;

	CGImageRef fullSized = [representation fullResolutionImage];
	if (!fullSized)
		return nil;

	UIImage *image = [[UIImage alloc] initWithCGImage:fullSized
												 scale:1.0f
										   orientation:(UIImageOrientation)[representation orientation]];
	NSData *jpeg = UIImageJPEGRepresentation(image, 0.87f);
	image = nil;
	if (!jpeg.length)
		return nil;

	NSString *name = [NSString stringWithFormat:@"album-%.0f-%d.jpg", stamp, (int)serial];
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	if (![jpeg writeToFile:path atomically:YES])
		return nil;
	return path;
}

@interface TGAssetTile : UIControl <TGReusableView>
@property (nonatomic, strong) UIImageView *thumb;
@property (nonatomic, strong) UIImageView *check;
@property (nonatomic, assign) NSInteger itemIndex;
@property (nonatomic, assign) NSInteger number;
@property (nonatomic, strong) NSString *reuseIdentifier;
@end

@implementation TGAssetTile

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	_reuseIdentifier = @"assetTile";
	_itemIndex = -1;
	_number = 0;
	self.backgroundColor = [UIColor colorWithWhite:0.12f alpha:1.0f];
	self.exclusiveTouch = YES;

	_thumb = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kTileSide, kTileSide)];
	_thumb.contentMode = UIViewContentModeScaleAspectFill;
	_thumb.clipsToBounds = YES;
	_thumb.userInteractionEnabled = NO;
	[self addSubview:_thumb];

	_check = [[UIImageView alloc] initWithFrame:
			CGRectMake(kTileSide - kCheckSide, 1.0f, kCheckSide, kCheckSide)];
	_check.userInteractionEnabled = NO;
	[self addSubview:_check];

	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGSize size = self.bounds.size;
	_thumb.frame = CGRectMake(0, 0, size.width, size.height);
	_check.frame = CGRectMake(size.width - kCheckSide, 1.0f, kCheckSide, kCheckSide);
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	_thumb.alpha = highlighted ? 0.7f : 1.0f;
}

- (void)showCheckImage:(UIImage *)image number:(NSInteger)number animated:(BOOL)animated {
	BOOL grew = (number > 0 && _number == 0);
	_number = number;
	_check.image = image;

	if (!animated) {
		_check.transform = CGAffineTransformIdentity;
		return;
	}
	if (grew) {
		_check.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
		[UIView animateWithDuration:0.12 delay:0
			options:UIViewAnimationOptionCurveEaseOut
			animations:^{
				_check.transform = CGAffineTransformMakeScale(1.16f, 1.16f);
			} completion:^(BOOL finished) {
				if (!finished)
					return;
				[UIView animateWithDuration:0.08 delay:0
									options:UIViewAnimationOptionCurveEaseIn
								 animations:^{
									 _check.transform = CGAffineTransformIdentity;
								 }
								 completion:nil];
			}];
		return;
	}
	_check.transform = CGAffineTransformIdentity;
}

- (void)prepareForReuse {
	_itemIndex = -1;
	_number = 0;
	_thumb.image = nil;
	_thumb.alpha = 1.0f;
	_check.image = nil;
	_check.transform = CGAffineTransformIdentity;
}

- (void)prepareForRecycle:(TGViewRecycler *)recycler {
	[self prepareForReuse];
}

@end

@interface TGAssetPicker () <UIScrollViewDelegate>
@property (nonatomic, strong) ALAssetsLibrary *library;
@property (nonatomic, strong) ALAssetsGroup *group;
@property (nonatomic, strong) NSArray *assets;
@property (nonatomic, strong) NSMutableArray *selection;
@property (nonatomic, strong) UIScrollView *grid;
@property (nonatomic, strong) TGViewRecycler *recycler;
@property (nonatomic, strong) NSMutableDictionary *visibleTiles;
@property (nonatomic, strong) NSCache *thumbnails;
@property (nonatomic, strong) NSMutableSet *loadingIndexes;
@property (nonatomic, strong) NSMutableDictionary *checkImages;
@property (nonatomic, strong) UIImageView *panel;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *spoilerButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, assign) BOOL spoiler;
@property (nonatomic, strong) UIImageView *countBadge;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *groupLabel;
@property (nonatomic, strong) UILabel *noticeLabel;
@property (nonatomic, strong) UIView *busyView;
@property (nonatomic, assign) NSInteger columns;
@property (nonatomic, assign) CGFloat sideInset;
@property (nonatomic, assign) CGFloat laidOutWidth;
@property (nonatomic, assign) BOOL scrolledToEnd;
@property (nonatomic, assign) BOOL staging;
@end

@implementation TGAssetPicker

+ (void)load {
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(invalidateAvailability)
												 name:UIApplicationWillEnterForegroundNotification
											   object:nil];
}

+ (void)invalidateAvailability {
	@synchronized(self) {
		TGAssetPickerAvailability = -1;
	}
}

+ (BOOL)readAvailability {
	Class library = TGALClass(ALAssetsLibrary);
	if (![library respondsToSelector:@selector(authorizationStatus)])
		return YES;
	ALAuthorizationStatus status = [library authorizationStatus];
	return status != ALAuthorizationStatusDenied && status != ALAuthorizationStatusRestricted;
}

+ (BOOL)available {
	@synchronized(self) {
		if (TGAssetPickerAvailability >= 0)
			return TGAssetPickerAvailability == 1;
	}
	BOOL ok = [self readAvailability];
	@synchronized(self) {
		TGAssetPickerAvailability = ok ? 1 : 0;
	}
	return ok;
}

+ (void)warmAvailability {
	@synchronized(self) {
		if (TGAssetPickerAvailability >= 0)
			return;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		TGALClass(ALAssetsLibrary);
		dispatch_async(dispatch_get_main_queue(), ^{ [self available]; });
	});
}

- (id)init {
	self = [super initWithNibName:nil bundle:nil];
	if (!self)
		return nil;
	_selectionLimit = kDefaultSelectionLimit;
	_selection = [[NSMutableArray alloc] init];
	_visibleTiles = [[NSMutableDictionary alloc] init];
	_loadingIndexes = [[NSMutableSet alloc] init];
	_checkImages = [[NSMutableDictionary alloc] init];
	_recycler = [[TGViewRecycler alloc] init];
	_thumbnails = [[NSCache alloc] init];
	_thumbnails.countLimit = (NSUInteger)kThumbnailCacheCount;
	_columns = 1;
	return self;
}

#pragma mark - view

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.view.backgroundColor = [UIColor blackColor];

	_grid = [[UIScrollView alloc] initWithFrame:self.view.bounds];
	_grid.backgroundColor = [UIColor blackColor];
	_grid.delegate = self;
	_grid.alwaysBounceVertical = YES;
	_grid.showsHorizontalScrollIndicator = NO;
	_grid.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	_grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_grid];

	[self buildPanel];
	[self buildNotice];

	[self loadCameraRoll];
}

- (void)buildPanel {
	UIImage *panelImage = [UIImage imageNamed:@"GalleryBottomPanel.png"];
	CGFloat height = panelImage ? panelImage.size.height : kPanelFallback;
	CGRect bounds = self.view.bounds;

	_panel = [[UIImageView alloc] initWithFrame:
			CGRectMake(0, bounds.size.height - height, bounds.size.width, height)];
	if (panelImage)
		_panel.image = [panelImage
			stretchableImageWithLeftCapWidth:(int)(panelImage.size.width / 2)
								topCapHeight:0];
	else
		_panel.backgroundColor = [UIColor colorWithWhite:0.11f alpha:1.0f];
	_panel.userInteractionEnabled = YES;
	_panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self.view addSubview:_panel];

	UIImage *grey = TGAssetPickerStretch(@"GalleryDoneButton.png", 11);
	UIImage *greyDown = TGAssetPickerStretch(@"GalleryDoneButton_Highlighted.png", 11);
	CGFloat buttonHeight = grey ? grey.size.height : 30.0f;
	CGFloat buttonY = (CGFloat)(int)((height - buttonHeight) / 2.0f);

	_cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_cancelButton.frame = CGRectMake(7, buttonY, kButtonWidth, buttonHeight);
	_cancelButton.exclusiveTouch = YES;
	_cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
	_cancelButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
	[_cancelButton setTitle:TGL(@"Common.Cancel", @"Cancel") forState:UIControlStateNormal];
	[_cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[_cancelButton setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.5f]
							  forState:UIControlStateNormal];
	if (grey) {
		[_cancelButton setBackgroundImage:grey forState:UIControlStateNormal];
		if (greyDown)
			[_cancelButton setBackgroundImage:greyDown forState:UIControlStateHighlighted];
	} else {
		_cancelButton.backgroundColor = [UIColor colorWithWhite:0.3f alpha:1.0f];
	}
	[_cancelButton addTarget:self action:@selector(cancelTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[_panel addSubview:_cancelButton];

	CGFloat spoilerSide = 30.0f;
	_spoilerButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_spoilerButton.frame = CGRectMake(CGRectGetMaxX(_cancelButton.frame) + 8,
		(CGFloat)(int)((height - spoilerSide) / 2.0f), spoilerSide, spoilerSide);
	_spoilerButton.exclusiveTouch = YES;
	_spoilerButton.layer.cornerRadius = spoilerSide / 2.0f;
	_spoilerButton.layer.borderWidth = 1.5f;
	_spoilerButton.layer.borderColor = [UIColor whiteColor].CGColor;
	_spoilerButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	[_spoilerButton setTitle:@"S" forState:UIControlStateNormal];
	[_spoilerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[_spoilerButton addTarget:self action:@selector(toggleSpoiler)
			 forControlEvents:UIControlEventTouchUpInside];
	[_panel addSubview:_spoilerButton];
	[self updateSpoilerButtonAppearance];

	UIImage *blue = TGAssetPickerStretch(@"SendButton.png", 11);
	UIImage *blueDown = TGAssetPickerStretch(@"SendButton_Pressed.png", 11);

	_sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_sendButton.frame = CGRectMake(bounds.size.width - 7 - kButtonWidth, buttonY,
		kButtonWidth, buttonHeight);
	_sendButton.exclusiveTouch = YES;
	_sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	_sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
	_sendButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
	_sendButton.adjustsImageWhenDisabled = NO;
	[_sendButton setTitle:TGL(@"MediaPicker.Send", @"Send") forState:UIControlStateNormal];
	[_sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[_sendButton setTitleColor:[UIColor colorWithWhite:1.0f alpha:0.5f]
					  forState:UIControlStateDisabled];
	[_sendButton setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.4f]
							forState:UIControlStateNormal];
	if (blue) {
		[_sendButton setBackgroundImage:blue forState:UIControlStateNormal];
		if (blueDown)
			[_sendButton setBackgroundImage:blueDown forState:UIControlStateHighlighted];
	} else {
		_sendButton.backgroundColor = [[TGTheme shared] accentColour];
	}
	[_sendButton addTarget:self action:@selector(sendTapped)
		  forControlEvents:UIControlEventTouchUpInside];
	[_panel addSubview:_sendButton];

	_countBadge = [[UIImageView alloc] initWithImage:TGAssetPickerBadgeImage()];
	_countBadge.alpha = 0.0f;
	[_sendButton addSubview:_countBadge];

	_countLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_countLabel.backgroundColor = [UIColor clearColor];
	_countLabel.textColor = [UIColor whiteColor];
	_countLabel.font = [UIFont boldSystemFontOfSize:12];
	_countLabel.textAlignment = NSTextAlignmentCenter;
	[_countBadge addSubview:_countLabel];

	CGFloat groupLabelLeft = CGRectGetMaxX(_spoilerButton.frame) + 14;
	_groupLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(groupLabelLeft, 0,
				MAX(20.0f, bounds.size.width - groupLabelLeft - (kButtonWidth + 14)), height)];
	_groupLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_groupLabel.backgroundColor = [UIColor clearColor];
	_groupLabel.textColor = [UIColor whiteColor];
	_groupLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	_groupLabel.shadowOffset = CGSizeMake(0, -1);
	_groupLabel.font = [UIFont boldSystemFontOfSize:17];
	_groupLabel.textAlignment = NSTextAlignmentCenter;
	_groupLabel.text = TGL(@"MediaPicker.CameraRoll", @"Camera Roll");
	[_panel addSubview:_groupLabel];

	[self updatePanel];
}

- (void)buildNotice {
	CGRect bounds = self.view.bounds;
	_noticeLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(20, (CGFloat)(int)(bounds.size.height / 2.0f) - 40,
				MAX(40.0f, bounds.size.width - 40), 80)];
	_noticeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	_noticeLabel.backgroundColor = [UIColor clearColor];
	_noticeLabel.textColor = [UIColor colorWithWhite:0.66f alpha:1.0f];
	_noticeLabel.font = [UIFont boldSystemFontOfSize:14];
	_noticeLabel.textAlignment = NSTextAlignmentCenter;
	_noticeLabel.numberOfLines = 0;
	_noticeLabel.hidden = YES;
	[self.view addSubview:_noticeLabel];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutGrid];
}

- (void)layoutGrid {
	CGFloat panelHeight = _panel.frame.size.height;
	CGRect bounds = self.view.bounds;
	CGRect gridFrame = CGRectMake(0, 0, bounds.size.width, bounds.size.height - panelHeight);
	if (!CGRectEqualToRect(_grid.frame, gridFrame))
		_grid.frame = gridFrame;

	CGFloat width = gridFrame.size.width;
	if (width < 1.0f)
		return;

	NSInteger columns = (NSInteger)floorf((width - kTileSpacing) / (kTileSide + kTileSpacing));
	if (columns < 1)
		columns = 1;
	CGFloat used = columns * kTileSide + (columns - 1) * kTileSpacing;
	CGFloat sideInset = (CGFloat)(int)((width - used) / 2.0f);

	BOOL changed = (columns != _columns) || (fabsf(width - _laidOutWidth) > 0.5f);
	_columns = columns;
	_sideInset = sideInset;
	_laidOutWidth = width;

	NSInteger count = (NSInteger)_assets.count;
	NSInteger rows = (count + columns - 1) / columns;
	CGFloat contentHeight = kTileSpacing + rows * (kTileSide + kTileSpacing);
	_grid.contentSize = CGSizeMake(width, MAX(contentHeight, gridFrame.size.height));

	if (changed)
		[self dropAllTiles];
	[self updateVisibleTiles];

	if (!_scrolledToEnd && count > 0) {
		_scrolledToEnd = YES;
		CGFloat maxOffset = MAX(0.0f, _grid.contentSize.height - _grid.bounds.size.height);
		[_grid setContentOffset:CGPointMake(0, maxOffset) animated:NO];
		[self updateVisibleTiles];
	}
}

#pragma mark - camera roll

- (void)loadCameraRoll {
	if (![TGAssetPicker available]) {
		[self showNotice:TGL(@"AccessDenied.PhotosAndVideos",
							 @"Telegram needs access to your photo library to send photos and videos.\n\nPlease go to Settings > Privacy > Photos and set Telegram to ON."
							  "videos.\n\nPlease go to Settings > Privacy > Photos and set "
							  "Telegram to ON.")];
		return;
	}

	self.library = [[TGALClass(ALAssetsLibrary) alloc] init];
	__weak TGAssetPicker *weakSelf = self;
	[self.library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
		usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
			TGAssetPicker *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!group) {
				[strongSelf readGroupContents];
				return;
			}
			[group setAssetsFilter:[TGALClass(ALAssetsFilter) allPhotos]];
			if ([group numberOfAssets] == 0)
				return;
			if (strongSelf.group)
				return;
			strongSelf.group = group;
			NSString *name = [group valueForProperty:TGALString(ALAssetsGroupPropertyName)];
			if (name.length)
				strongSelf.groupLabel.text = name;
		} failureBlock:^(NSError *error) {
			TGAssetPicker *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			NSLog(@"asset picker: %@", error);
			[strongSelf showNotice:TGL(@"AssetPicker.PhotosCouldNotBeRead",
							   @"Your photos could not be read.")];
		}];
}

- (void)readGroupContents {
	ALAssetsGroup *group = self.group;
	if (!group) {
		[self showNotice:TGL(@"AssetPicker.NoPhotosOnThisDevice",
							 @"There are no photos on this device yet.")];
		return;
	}

	__weak TGAssetPicker *weakSelf = self;
	dispatch_async(TGAssetPickerQueue(), ^{
		NSMutableArray *found = [[NSMutableArray alloc] init];
		[group enumerateAssetsUsingBlock:^(ALAsset *asset, NSUInteger index, BOOL *stop) {
			if (asset)
				[found addObject:asset];
		}];
		dispatch_async(dispatch_get_main_queue(), ^{
			TGAssetPicker *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			strongSelf.assets = found;
			if (!found.count) {
				[strongSelf showNotice:TGL(@"AssetPicker.NoPhotosOnThisDevice",
									@"There are no photos on this device yet.")];
				return;
			}
			[strongSelf showNotice:nil];
			[strongSelf layoutGrid];
		});
	});
}

- (void)showNotice:(NSString *)text {
	_noticeLabel.text = text ?: @"";
	_noticeLabel.hidden = !text.length;
}

#pragma mark - tiles

- (CGRect)frameForIndex:(NSInteger)index {
	NSInteger row = index / _columns;
	NSInteger column = index % _columns;
	CGFloat x = _sideInset + column * (kTileSide + kTileSpacing);
	CGFloat y = kTileSpacing + row * (kTileSide + kTileSpacing);
	return CGRectMake((CGFloat)(int)x, (CGFloat)(int)y, kTileSide, kTileSide);
}

- (void)dropAllTiles {
	for (NSNumber *key in [_visibleTiles allKeys])
		[_recycler recycleView:[_visibleTiles objectForKey:key]];
	[_visibleTiles removeAllObjects];
}

- (void)updateVisibleTiles {
	NSInteger count = (NSInteger)_assets.count;
	if (count == 0)
		return;

	CGFloat top = _grid.contentOffset.y - kTileSide;
	CGFloat bottom = _grid.contentOffset.y + _grid.bounds.size.height + kTileSide;
	NSInteger firstRow = (NSInteger)floorf((top - kTileSpacing) / (kTileSide + kTileSpacing));
	if (firstRow < 0)
		firstRow = 0;
	NSInteger lastRow = (NSInteger)ceilf((bottom - kTileSpacing) / (kTileSide + kTileSpacing));

	NSInteger first = firstRow * _columns;
	NSInteger last = MIN(count - 1, (lastRow + 1) * _columns - 1);

	NSMutableSet *wanted = [[NSMutableSet alloc] init];
	for (NSInteger i = first; i <= last; i++) {
		if (i < 0)
			continue;
		NSNumber *key = [NSNumber numberWithInteger:i];
		[wanted addObject:key];

		TGAssetTile *tile = [_visibleTiles objectForKey:key];
		if (!tile) {
			tile = (TGAssetTile *)[_recycler dequeueReusableViewWithIdentifier:@"assetTile"];
			if (!tile) {
				tile = [[TGAssetTile alloc] initWithFrame:[self frameForIndex:i]];
				[tile addTarget:self action:@selector(tileTapped:)
					forControlEvents:UIControlEventTouchUpInside];
			}
			[_grid addSubview:tile];
			[_visibleTiles setObject:tile forKey:key];
		}
		tile.frame = [self frameForIndex:i];
		tile.itemIndex = i;
		[self configureTile:tile atIndex:i];
	}

	for (NSNumber *key in [_visibleTiles allKeys]) {
		if ([wanted containsObject:key])
			continue;
		[_recycler recycleView:[_visibleTiles objectForKey:key]];
		[_visibleTiles removeObjectForKey:key];
	}
}

- (void)configureTile:(TGAssetTile *)tile atIndex:(NSInteger)index {
	NSNumber *key = [NSNumber numberWithInteger:index];
	UIImage *cached = [_thumbnails objectForKey:key];
	tile.thumb.image = cached;
	tile.thumb.alpha = 1.0f;
	[tile showCheckImage:[self checkImageForNumber:[self numberForIndex:index]]
				  number:[self numberForIndex:index]
				animated:NO];
	if (!cached)
		[self requestThumbnailAtIndex:index];
}

- (void)requestThumbnailAtIndex:(NSInteger)index {
	NSNumber *key = [NSNumber numberWithInteger:index];
	if ([_loadingIndexes containsObject:key])
		return;
	if (index < 0 || index >= (NSInteger)_assets.count)
		return;
	[_loadingIndexes addObject:key];

	ALAsset *asset = [_assets objectAtIndex:index];
	__weak TGAssetPicker *weakSelf = self;
	dispatch_async(TGAssetPickerQueue(), ^{
		UIImage *image = nil;
		@autoreleasepool {
			CGImageRef thumbnail = [asset thumbnail];
			if (thumbnail)
				image = [[UIImage alloc] initWithCGImage:thumbnail];
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			TGAssetPicker *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf.loadingIndexes removeObject:key];
			if (!image)
				return;
			[strongSelf.thumbnails setObject:image forKey:key];
			TGAssetTile *tile = [strongSelf.visibleTiles objectForKey:key];
			if (!tile || tile.itemIndex != index)
				return;
			tile.thumb.image = image;
			tile.thumb.alpha = 0.0f;
			[UIView animateWithDuration:0.16 animations:^{
				tile.thumb.alpha = 1.0f;
			}];
		});
	});
}

#pragma mark - selection

- (NSInteger)numberForIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)_assets.count)
		return 0;
	NSInteger found = [_selection indexOfObjectIdenticalTo:[_assets objectAtIndex:index]];
	return (found == NSNotFound) ? 0 : (NSInteger)found + 1;
}

- (UIImage *)checkImageForNumber:(NSInteger)number {
	NSNumber *key = [NSNumber numberWithInteger:number];
	UIImage *image = [_checkImages objectForKey:key];
	if (image)
		return image;
	image = TGAssetPickerCheckImage(number, [[TGTheme shared] accentColour]);
	if (image)
		[_checkImages setObject:image forKey:key];
	return image;
}

- (void)tileTapped:(TGAssetTile *)tile {
	if (_staging)
		return;
	NSInteger index = tile.itemIndex;
	if (index < 0 || index >= (NSInteger)_assets.count)
		return;

	ALAsset *asset = [_assets objectAtIndex:index];
	NSInteger existing = [_selection indexOfObjectIdenticalTo:asset];
	if (existing != NSNotFound) {
		[_selection removeObjectAtIndex:existing];
	} else {
		if (_selection.count >= _selectionLimit) {
			[self flashLimit];
			return;
		}
		[_selection addObject:asset];
	}

	[self refreshChecksAnimatingIndex:index];
	[self updatePanel];
}

- (void)refreshChecksAnimatingIndex:(NSInteger)animatedIndex {
	for (NSNumber *key in [_visibleTiles allKeys]) {
		TGAssetTile *tile = [_visibleTiles objectForKey:key];
		NSInteger number = [self numberForIndex:tile.itemIndex];
		if (number == tile.number && tile.itemIndex != animatedIndex)
			continue;
		[tile showCheckImage:[self checkImageForNumber:number]
					  number:number
					animated:(tile.itemIndex == animatedIndex)];
	}
}

- (void)flashLimit {
	_groupLabel.text = TGL(@"Chat.AttachmentLimitReached", @"You can't select more items.");
	__weak TGAssetPicker *weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGAssetPicker *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			NSString *name = [strongSelf.group valueForProperty:TGALString(ALAssetsGroupPropertyName)];
			strongSelf.groupLabel.text = name.length ? name : TGL(@"MediaPicker.CameraRoll", @"Camera Roll");
		});
}

- (void)updatePanel {
	NSInteger count = _selection.count;
	_sendButton.enabled = (count > 0) && !_staging;

	if (!count) {
		_countBadge.alpha = 0.0f;
		return;
	}

	_countLabel.text = [NSString stringWithFormat:@"%d", (int)count];
	CGSize textSize = [_countLabel.text sizeWithFont:_countLabel.font];
	CGFloat badgeHeight = 20.0f;
	CGFloat badgeWidth = MAX(badgeHeight, textSize.width + 12.0f);
	_countBadge.frame = CGRectMake(_sendButton.bounds.size.width - badgeWidth + 6.0f,
		-7.0f, badgeWidth, badgeHeight);
	_countLabel.frame = CGRectMake(0, 0, badgeWidth, badgeHeight);
	_countBadge.alpha = 1.0f;
}

- (void)updateSpoilerButtonAppearance {
	_spoilerButton.backgroundColor = _spoiler
		? [[TGTheme shared] accentColour]
		: [UIColor clearColor];
}

- (void)toggleSpoiler {
	_spoiler = !_spoiler;
	[self updateSpoilerButtonAppearance];
}

#pragma mark - actions

- (void)cancelTapped {
	if (_staging)
		return;
	void (^cancelled)(void) = self.onCancelled;
	if (cancelled)
		cancelled();
}

- (void)sendTapped {
	if (_staging || !_selection.count)
		return;

	_staging = YES;
	[self updatePanel];
	[self showBusy:YES];

	NSArray *chosen = [_selection copy];
	BOOL spoiler = _spoiler;
	double stamp = [[NSDate date] timeIntervalSince1970] * 1000.0;
	__weak TGAssetPicker *weakSelf = self;
	dispatch_async(TGAssetPickerQueue(), ^{
		NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity:chosen.count];
		NSInteger serial = 0;
		for (ALAsset *asset in chosen) {
			@autoreleasepool {
				NSString *path = TGAssetPickerStage(asset, stamp, serial);
				if (path.length)
					[paths addObject:path];
			}
			serial++;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			TGAssetPicker *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			strongSelf.staging = NO;
			[strongSelf showBusy:NO];
			[strongSelf updatePanel];
			void (^picked)(NSArray *, BOOL) = strongSelf.onPicked;
			if (picked)
				picked(paths, spoiler);
		});
	});
}

- (void)showBusy:(BOOL)busy {
	if (!busy) {
		[_busyView removeFromSuperview];
		_busyView = nil;
		return;
	}
	if (_busyView)
		return;

	_busyView = [[UIView alloc] initWithFrame:self.view.bounds];
	_busyView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
	_busyView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	spinner.center = CGPointMake((CGFloat)(int)(_busyView.bounds.size.width / 2.0f),
		(CGFloat)(int)(_busyView.bounds.size.height / 2.0f) - 12.0f);
	spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	[spinner startAnimating];
	[_busyView addSubview:spinner];

	UILabel *label = [[UILabel alloc] initWithFrame:
			CGRectMake(0, spinner.center.y + 22.0f, _busyView.bounds.size.width, 20)];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor whiteColor];
	label.font = [UIFont boldSystemFontOfSize:14];
	label.textAlignment = NSTextAlignmentCenter;
	label.text = TGL(@"AssetPicker.Preparing", @"Preparing");
	[_busyView addSubview:label];

	[self.view addSubview:_busyView];
}

#pragma mark - scrolling

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self updateVisibleTiles];
}

#pragma mark - lifecycle

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[_thumbnails removeAllObjects];
	[_recycler removeAllViews];
	for (NSNumber *key in [_visibleTiles allKeys]) {
		TGAssetTile *tile = [_visibleTiles objectForKey:key];
		[self configureTile:tile atIndex:tile.itemIndex];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	return YES;
}

- (BOOL)shouldAutorotate {
	return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskAll;
}

@end
