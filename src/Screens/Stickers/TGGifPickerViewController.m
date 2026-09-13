#import "TGGifPickerViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"

#import <AVFoundation/AVFoundation.h>

#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGClient+Files.h"
#import "TGClient+Gifs.h"
#import "TGLazyFramework.h"
#import "TGStickerThumbnailCache.h"
#import "TGTheme.h"

static const CGFloat kGifCategoryStripHeight = 38.0f;
static const CGFloat kGifGridSpacing = 3.0f;
static const CGFloat kGifColumnWidthTarget = 150.0f;
static const NSTimeInterval kGifSearchDelay = 0.4;
static const CGFloat kGifWindowMargin = 220.0f;

@interface TGGifTile : UIControl

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *badge;
@property (nonatomic, strong) NSDictionary *gif;
@property (nonatomic, strong) id imageToken;

@end

@implementation TGGifTile

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.06f];
		self.clipsToBounds = YES;
		self.exclusiveTouch = YES;
		self.layer.cornerRadius = 3.0f;

		_imageView = [[UIImageView alloc] initWithFrame:self.bounds];
		_imageView.contentMode = UIViewContentModeScaleAspectFill;
		_imageView.clipsToBounds = YES;
		_imageView.userInteractionEnabled = NO;
		[self addSubview:_imageView];

		_badge = [[UILabel alloc] initWithFrame:CGRectZero];
		_badge.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.45f];
		_badge.textColor = [UIColor whiteColor];
		_badge.font = [UIFont boldSystemFontOfSize:9];
		_badge.textAlignment = NSTextAlignmentCenter;
		_badge.text = TGL(@"Message.Animation", @"GIF");
		_badge.layer.cornerRadius = 2.0f;
		_badge.clipsToBounds = YES;
		_badge.userInteractionEnabled = NO;
		[self addSubview:_badge];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	_imageView.frame = self.bounds;
	_badge.frame = CGRectMake(4, self.bounds.size.height - 17, 26, 13);
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	_imageView.alpha = highlighted ? 0.55f : 1.0f;
}

@end

@interface TGGifPickerViewController () <UIScrollViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIScrollView *categoryStrip;
@property (nonatomic, strong) UISegmentedControl *scopeControl;
@property (nonatomic, strong) UIScrollView *grid;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) NSMutableArray *gifs;
@property (nonatomic, strong) NSMutableArray *frames;
@property (nonatomic, strong) NSMutableDictionary *tiles;
@property (nonatomic, strong) NSArray *categories;
@property (nonatomic, strong) NSMutableSet *savedFileIds;

@property (nonatomic, copy) NSString *query;
@property (nonatomic, copy) NSString *nextOffset;
@property (nonatomic, assign) NSInteger generation;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) CGFloat laidOutWidth;
@property (nonatomic, strong) NSDictionary *menuGif;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, strong) id keyboardWillShowObserverToken;
@property (nonatomic, strong) id keyboardWillHideObserverToken;
@property (nonatomic, strong) id savedAnimationsObserverToken;
@property (nonatomic, assign) BOOL finishing;

@end

@implementation TGGifPickerViewController

- (id)init {
	self = [super init];
	if (self != nil) {
		_gifs = [[NSMutableArray alloc] init];
		_frames = [[NSMutableArray alloc] init];
		_tiles = [[NSMutableDictionary alloc] init];
		_savedFileIds = [[NSMutableSet alloc] init];
		_query = @"";
		_nextOffset = @"";
		self.title = TGL(@"WebSearch.GIFs", @"GIFs");
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.keyboardWillShowObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillShowObserverToken];
	if (self.keyboardWillHideObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillHideObserverToken];
	if (self.savedAnimationsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.savedAnimationsObserverToken];
	for (TGGifTile *tile in self.tiles.allValues)
		[TGStickerThumbnailCache cancelRequest:tile.imageToken];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	CGFloat width = self.view.bounds.size.width;

	self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.placeholder = TGL(@"Gif.Search", @"Search GIFs");
	self.searchBar.delegate = self;
	[self.view addSubview:self.searchBar];

	self.categoryStrip = [[UIScrollView alloc] initWithFrame:
			CGRectMake(0, 44, width, kGifCategoryStripHeight)];
	self.categoryStrip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.categoryStrip.showsHorizontalScrollIndicator = NO;
	self.categoryStrip.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.categoryStrip];

	self.scopeControl = [[UISegmentedControl alloc] initWithItems:
			[NSArray arrayWithObjects:
				TGL(@"PeerInfo.SavedMessagesTabTitle", @"Saved"),
				TGL(@"Stickers.Trending", @"Trending"), nil]];
	self.scopeControl.segmentedControlStyle = UISegmentedControlStyleBar;
	self.scopeControl.selectedSegmentIndex = 0;
	[self.scopeControl addTarget:self action:@selector(scopeChanged)
				forControlEvents:UIControlEventValueChanged];
	self.navigationItem.titleView = self.scopeControl;

	self.grid = [[UIScrollView alloc] initWithFrame:CGRectZero];
	self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleHeight;
	self.grid.delegate = self;
	self.grid.alwaysBounceVertical = YES;
	self.grid.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.grid];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
			UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];

	self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.statusLabel.backgroundColor = [UIColor clearColor];
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.font = [UIFont systemFontOfSize:14];
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.statusLabel.numberOfLines = 2;
	self.statusLabel.hidden = YES;
	[self.view addSubview:self.statusLabel];

	self.navigationItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
									   target:self
									   action:@selector(cancel)];
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Message.Video", @"Video") bold:NO
									   target:self
									   action:@selector(pickFromLibrary)];

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	__weak typeof(self) weakSelf = self;
	self.keyboardWillShowObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillShowNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardChanged:note];
				}];
	self.keyboardWillHideObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillHideNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardChanged:note];
				}];
	self.savedAnimationsObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGSavedAnimationsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (strongSelf.query.length == 0 && strongSelf.scopeControl.selectedSegmentIndex == 0)
						[strongSelf reloadSaved];
				}];
	[self loadCategories];
	[self reloadSaved];
}

- (void)keyboardChanged:(NSNotification *)note {
	CGFloat overlap = 0.0f;
	if ([note.name isEqualToString:UIKeyboardWillShowNotification]) {
		CGRect frame = [[note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey]
			CGRectValue];
		CGFloat side = MIN(frame.size.width, frame.size.height);
		overlap = MAX(0.0f, side - (self.view.bounds.size.height - CGRectGetMaxY(self.grid.frame)));
	}
	UIEdgeInsets insets = self.grid.contentInset;
	insets.bottom = overlap;
	self.grid.contentInset = insets;
	self.grid.scrollIndicatorInsets = insets;
	[self updateVisibleTiles];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	CGRect bounds = self.view.bounds;
	CGFloat top = 44 + (self.categories.count > 0 ? kGifCategoryStripHeight : 0);
	self.categoryStrip.hidden = (self.categories.count == 0);
	self.grid.frame = CGRectMake(0, top, bounds.size.width, bounds.size.height - top);
	self.spinner.center = CGPointMake(CGRectGetMidX(bounds),
		top + (bounds.size.height - top) / 2.0f);
	self.statusLabel.frame = CGRectMake(20, top + 40, bounds.size.width - 40, 40);
	if (fabsf(self.laidOutWidth - bounds.size.width) > 0.5f) {
		self.laidOutWidth = bounds.size.width;
		[self relayout];
	}
}

#pragma mark - the emoji category strip

- (void)loadCategories {
	__weak TGGifPickerViewController *weakSelf = self;
	[[TGClient shared] gifSearchCategoriesWithCompletion:^(NSArray *categories) {
		TGGifPickerViewController *strongSelf = weakSelf;
		if (!strongSelf || categories.count == 0)
			return;
		strongSelf.categories = categories;
		[strongSelf rebuildCategoryStrip];
		[strongSelf.view setNeedsLayout];
	}];
}

- (void)rebuildCategoryStrip {
	for (UIView *view in [self.categoryStrip.subviews copy])
		[view removeFromSuperview];

	CGFloat x = 8.0f;
	NSInteger index = 0;
	for (NSDictionary *category in self.categories) {
		NSArray *emojis = category[@"emojis"];
		NSString *glyph = [emojis firstObject];
		if (![glyph isKindOfClass:[NSString class]] || glyph.length == 0)
			continue;
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(x, 3, 32, kGifCategoryStripHeight - 6);
		button.titleLabel.font = [UIFont systemFontOfSize:22];
		[button setTitle:glyph forState:UIControlStateNormal];
		button.tag = index;
		[button addTarget:self action:@selector(categoryTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[self.categoryStrip addSubview:button];
		x += 34.0f;
		index++;
	}
	self.categoryStrip.contentSize = CGSizeMake(x + 8.0f, kGifCategoryStripHeight);
}

- (void)categoryTapped:(UIButton *)button {
	NSInteger index = button.tag;
	if (index < 0 || index >= (NSInteger)self.categories.count)
		return;
	NSArray *emojis = self.categories[index][@"emojis"];
	NSString *joined = [emojis componentsJoinedByString:@""];
	if (joined.length == 0)
		return;
	self.searchBar.text = joined;
	[self.searchBar resignFirstResponder];
	[self runSearch:joined];
}

#pragma mark - loading

- (void)scopeChanged {
	if (self.query.length > 0) {
		self.searchBar.text = @"";
		[self.searchBar resignFirstResponder];
		self.query = @"";
	}
	if (self.scopeControl.selectedSegmentIndex == 0)
		[self reloadSaved];
	else
		[self reloadTrending];
}

- (void)beginLoad {
	self.generation++;
	self.loadingMore = NO;
	self.nextOffset = @"";
	[self.gifs removeAllObjects];
	[self relayout];
	self.grid.contentOffset = CGPointZero;
	self.statusLabel.hidden = YES;
	[self.spinner startAnimating];
}

- (void)finishLoadWithGifs:(NSArray *)gifs
				nextOffset:(NSString *)nextOffset
				generation:(NSInteger)generation
					 empty:(NSString *)emptyText {
	if (generation != self.generation)
		return;
	[self.spinner stopAnimating];
	self.nextOffset = nextOffset ?: @"";
	[self.gifs addObjectsFromArray:(gifs ?: @[])];
	[self relayout];
	self.statusLabel.text = emptyText;
	self.statusLabel.hidden = (self.gifs.count > 0);
}

- (void)reloadSaved {
	[self beginLoad];
	NSInteger generation = self.generation;
	__weak TGGifPickerViewController *weakSelf = self;
	[[TGClient shared] savedGifsWithCompletion:^(NSArray *gifs) {
		TGGifPickerViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.savedFileIds removeAllObjects];
		for (NSDictionary *gif in gifs)
			[strongSelf.savedFileIds addObject:gif[@"fileId"]];
		[strongSelf finishLoadWithGifs:gifs nextOffset:@"" generation:generation
						 empty:TGL(@"GifPicker.NoSavedGifsYet", @"No saved GIFs.\nHold one under Trending to save it.")];
	}];
}

- (void)reloadTrending {
	[self beginLoad];
	NSInteger generation = self.generation;
	__weak TGGifPickerViewController *weakSelf = self;
	[[TGClient shared] trendingGifsWithCompletion:^(NSArray *gifs, NSString *nextOffset) {
		TGGifPickerViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf finishLoadWithGifs:gifs nextOffset:nextOffset generation:generation
						 empty:TGL(@"GifPicker.TrendingGifsNotAvailable", @"Trending GIFs are not available.")];
	}];
}

- (void)runSearch:(NSString *)query {
	self.query = query ?: @"";
	if (self.query.length == 0) {
		[self scopeChanged];
		return;
	}
	[self beginLoad];
	NSInteger generation = self.generation;
	__weak TGGifPickerViewController *weakSelf = self;
	[[TGClient shared] searchGifs:self.query offset:nil
					   completion:^(NSArray *gifs, NSString *nextOffset) {
						   TGGifPickerViewController *strongSelf = weakSelf;
						   if (!strongSelf)
							   return;
						   [strongSelf finishLoadWithGifs:gifs nextOffset:nextOffset generation:generation
											empty:TGL(@"Gif.NoGifsFound", @"No GIFs Found")];
					   }];
}

- (void)loadNextPage {
	if (self.loadingMore || self.nextOffset.length == 0)
		return;
	self.loadingMore = YES;
	NSInteger generation = self.generation;
	NSString *offset = self.nextOffset;
	__weak TGGifPickerViewController *weakSelf = self;
	[[TGClient shared] searchGifs:self.query offset:offset
					   completion:^(NSArray *gifs, NSString *nextOffset) {
						   TGGifPickerViewController *strongSelf = weakSelf;
						   if (!strongSelf || generation != strongSelf.generation)
							   return;
						   strongSelf.loadingMore = NO;
						   strongSelf.nextOffset = [(nextOffset ?: @"") isEqualToString:offset] ? @"" : (nextOffset ?: @"");
						   [strongSelf.gifs addObjectsFromArray:(gifs ?: @[])];
						   [strongSelf relayout];
					   }];
}

#pragma mark - the masonry

- (void)relayout {
	CGFloat width = self.grid.bounds.size.width;
	if (width < 1.0f)
		width = self.view.bounds.size.width;
	if (width < 1.0f)
		return;

	NSInteger columns = (NSInteger)floorf(width / kGifColumnWidthTarget);
	if (columns < 2)
		columns = 2;
	CGFloat columnWidth = floorf((width - kGifGridSpacing * (columns + 1)) / columns);

	CGFloat *columnY = (CGFloat *)malloc(sizeof(CGFloat) * (size_t)columns);
	for (NSInteger i = 0; i < columns; i++)
		columnY[i] = kGifGridSpacing;

	[self.frames removeAllObjects];
	for (NSDictionary *gif in self.gifs) {
		CGFloat w = [gif[@"width"] floatValue];
		CGFloat h = [gif[@"height"] floatValue];
		CGFloat ratio = (w > 0 && h > 0) ? (h / w) : 0.75f;
		if (ratio < 0.4f)
			ratio = 0.4f;
		if (ratio > 1.6f)
			ratio = 1.6f;
		CGFloat tileHeight = floorf(columnWidth * ratio);

		NSInteger shortest = 0;
		for (NSInteger i = 1; i < columns; i++)
			if (columnY[i] < columnY[shortest])
				shortest = i;

		CGFloat x = kGifGridSpacing + shortest * (columnWidth + kGifGridSpacing);
		CGRect frame = CGRectMake(x, columnY[shortest], columnWidth, tileHeight);
		columnY[shortest] += tileHeight + kGifGridSpacing;
		[self.frames addObject:[NSValue valueWithCGRect:frame]];
	}

	CGFloat tallest = 0;
	for (NSInteger i = 0; i < columns; i++)
		if (columnY[i] > tallest)
			tallest = columnY[i];
	free(columnY);

	self.grid.contentSize = CGSizeMake(width, tallest);
	[self updateVisibleTiles];
}

- (void)updateVisibleTiles {
	CGRect visible = CGRectInset(CGRectMake(0, self.grid.contentOffset.y,
									 self.grid.bounds.size.width, self.grid.bounds.size.height),
		0, -kGifWindowMargin);

	NSMutableSet *wanted = [NSMutableSet set];
	for (NSInteger i = 0; i < self.frames.count; i++) {
		CGRect frame = [self.frames[i] CGRectValue];
		if (CGRectIntersectsRect(frame, visible))
			[wanted addObject:@(i)];
	}

	for (NSNumber *key in [self.tiles.allKeys copy]) {
		if ([wanted containsObject:key])
			continue;
		TGGifTile *tile = self.tiles[key];
		[TGStickerThumbnailCache cancelRequest:tile.imageToken];
		tile.imageToken = nil;
		[tile removeFromSuperview];
		[self.tiles removeObjectForKey:key];
	}

	for (NSNumber *key in wanted) {
		NSInteger index = [key unsignedIntegerValue];
		CGRect frame = [self.frames[index] CGRectValue];
		TGGifTile *tile = self.tiles[key];
		if (tile == nil) {
			tile = [[TGGifTile alloc] initWithFrame:frame];
			tile.gif = self.gifs[index];
			tile.tag = (NSInteger)index;
			[tile addTarget:self action:@selector(tileTapped:)
				forControlEvents:UIControlEventTouchUpInside];
			UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
				initWithTarget:self
						action:@selector(tileHeld:)];
			hold.minimumPressDuration = 0.4;
			[tile addGestureRecognizer:hold];
			[self.grid addSubview:tile];
			self.tiles[key] = tile;
			[self loadThumbnailForTile:tile];
		} else {
			tile.frame = frame;
		}
	}
}

- (void)loadThumbnailForTile:(TGGifTile *)tile {
	NSDictionary *gif = tile.gif;

	NSDictionary *mini = gif[@"minithumbnail"];
	if ([mini isKindOfClass:[NSDictionary class]]) {
		NSData *bytes = [[TGClient shared] minithumbnailData:mini];
		UIImage *blur = bytes.length ? [UIImage imageWithData:bytes] : nil;
		if (blur != nil)
			tile.imageView.image = blur;
	}

	long long thumbId = [gif[@"thumbId"] longLongValue];
	if (thumbId <= 0)
		return;
	NSString *uniqueId = gif[@"thumbUniqueId"];
	CGFloat side = MAX(tile.bounds.size.width, tile.bounds.size.height);

	if ([gif[@"thumbIsVideo"] boolValue]) {
		[self loadVideoStillForTile:tile fileId:thumbId uniqueId:uniqueId side:side];
		return;
	}

	UIImage *cached = [TGStickerThumbnailCache cachedThumbnailForUniqueId:uniqueId side:side];
	if (cached != nil) {
		tile.imageView.image = cached;
		return;
	}

	__weak TGGifTile *weakTile = tile;
	tile.imageToken = [TGStickerThumbnailCache
		thumbnailForFileId:thumbId
				  uniqueId:uniqueId
					  side:side
				completion:^(UIImage *image) {
					TGGifTile *strongTile = weakTile;
					if (!strongTile || image == nil)
						return;
					strongTile.imageToken = nil;
					strongTile.imageView.image = image;
					strongTile.imageView.alpha = 0.0f;
					[UIView animateWithDuration:0.15 animations:^{
						strongTile.imageView.alpha = 1.0f;
					}];
				}];
}

static NSCache *TGGifVideoStillMemory(void) {
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
		cache.countLimit = 40;
		cache.totalCostLimit = 4 * 1024 * 1024;
		[[NSNotificationCenter defaultCenter]
			addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *__unused note) {
						[cache removeAllObjects];
					}];
		[[NSNotificationCenter defaultCenter]
			addObserverForName:UIApplicationDidEnterBackgroundNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *__unused note) {
						[cache removeAllObjects];
					}];
	});
	return cache;
}

+ (void)purgeVideoStillCacheForAccountSwitch {
	[TGGifVideoStillMemory() removeAllObjects];
}

- (void)loadVideoStillForTile:(TGGifTile *)tile
					   fileId:(long long)fileId
					 uniqueId:(NSString *)uniqueId
						 side:(CGFloat)side {
	NSCache *stills = TGGifVideoStillMemory();
	static dispatch_queue_t frames = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		frames = dispatch_queue_create("tg.gif.stillframe", NULL);
	});

	NSString *key = uniqueId.length ? uniqueId
									: [NSString stringWithFormat:@"f%lld", fileId];
	UIImage *hit = [stills objectForKey:key];
	if (hit != nil) {
		tile.imageView.image = hit;
		return;
	}

	CGFloat scale = [UIScreen mainScreen].scale;
	__weak TGGifPickerViewController *weakSelf = self;
	__weak TGGifTile *weakTile = tile;
	[[TGClient shared] downloadFile:fileId completion:^(NSString *path) {
		if (!path.length || weakTile == nil)
			return;
		dispatch_async(frames, ^{
			UIImage *still = nil;
			@autoreleasepool {
				Class generatorClass = TGAVClass(AVAssetImageGenerator);
				AVURLAsset *asset = [TGAVClass(AVURLAsset)
					URLAssetWithURL:[NSURL fileURLWithPath:path]
							options:nil];
				if (asset != nil && generatorClass != Nil) {
					AVAssetImageGenerator *generator =
						[[generatorClass alloc] initWithAsset:asset];
					generator.appliesPreferredTrackTransform = YES;
					generator.maximumSize = CGSizeMake(side * scale, side * scale);
					CMTime start = CMTimeMake(0, 1);
					CGImageRef frame = [generator copyCGImageAtTime:start actualTime:NULL error:NULL];
					if (frame != NULL) {
						still = [UIImage imageWithCGImage:frame scale:scale
											  orientation:UIImageOrientationUp];
						CGImageRelease(frame);
					}
				}
			}
			if (still == nil)
				return;
			NSUInteger cost = (NSUInteger)(still.size.width * still.scale *
				still.size.height * still.scale * 4.0f);
			dispatch_async(dispatch_get_main_queue(), ^{
				[stills setObject:still forKey:key cost:cost];
				TGGifPickerViewController *strongSelf = weakSelf;
				TGGifTile *strongTile = weakTile;
				if (!strongSelf || !strongTile || strongTile.superview == nil)
					return;
				if (![[strongTile.gif[@"thumbUniqueId"] description] isEqualToString:uniqueId])
					return;
				strongTile.imageView.image = still;
			});
		});
	}];
}

#pragma mark - taps

- (void)tileTapped:(TGGifTile *)tile {
	if (self.finishing)
		return;
	NSDictionary *gif = tile.gif;
	if (gif == nil)
		return;
	self.finishing = YES;
	void (^picked)(NSDictionary *) = self.onPicked;
	[self dismissViewControllerAnimated:YES completion:^{
		if (picked)
			picked(gif);
	}];
}

- (void)tileHeld:(UILongPressGestureRecognizer *)recogniser {
	if (recogniser.state != UIGestureRecognizerStateBegan)
		return;
	TGGifTile *tile = (TGGifTile *)recogniser.view;
	if (![tile isKindOfClass:[TGGifTile class]] || tile.gif == nil)
		return;

	self.menuGif = tile.gif;
	NSNumber *fileId = tile.gif[@"fileId"];
	BOOL saved = [self.savedFileIds containsObject:fileId];

	NSMutableArray *actions = [NSMutableArray array];
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:(saved ? TGL(@"Conversation.ContextMenuDelete", @"Delete") : TGL(@"Preview.SaveGif", @"Save GIF"))
								  action:(saved ? @"unsave" : @"save")
						   type:(saved ? TGActionSheetActionTypeDestructive
									   : TGActionSheetActionTypeGeneric)]];
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:TGL(@"Common.Cancel", @"Cancel")
								  action:@"cancel"
									type:TGActionSheetActionTypeCancel]];

	__weak TGGifPickerViewController *weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:nil
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGGifPickerViewController *strongSelf = weakSelf;
			  if (strongSelf == nil)
				  return;
			  strongSelf.currentActionSheet = nil;
			  [strongSelf performMenuAction:action];
		  }
			   target:self];
	[self.currentActionSheet tg_showFromRect:tile.bounds inView:tile];
}

- (void)performMenuAction:(NSString *)action {
	NSDictionary *gif = self.menuGif;
	self.menuGif = nil;
	if (gif == nil)
		return;
	NSNumber *fileId = gif[@"fileId"];
	long long identifier = [fileId longLongValue];

	__weak TGGifPickerViewController *weakSelf = self;
	if ([action isEqualToString:@"save"]) {
		[[TGClient shared] saveGifWithFileId:identifier completion:^(BOOL ok) {
			TGGifPickerViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[strongSelf sayCouldNotSave];
				return;
			}
			[strongSelf.savedFileIds addObject:fileId];
		}];
		return;
	}
	if ([action isEqualToString:@"unsave"]) {
		[[TGClient shared] unsaveGifWithFileId:identifier completion:^(BOOL ok) {
			TGGifPickerViewController *strongSelf = weakSelf;
			if (!strongSelf || !ok)
				return;
			[strongSelf.savedFileIds removeObject:fileId];
			if (strongSelf.query.length == 0 && strongSelf.scopeControl.selectedSegmentIndex == 0)
				[strongSelf reloadSaved];
		}];
	}
}

- (void)sayCouldNotSave {
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"WebSearch.GIFs", @"GIFs")
				  message:TGL(@"GifPicker.ThisGIFIsHostedOutsideTelegram", @"This GIF is hosted outside Telegram and cannot be saved.")
		cancelButtonTitle:TGL(@"Common.OK", @"OK")
			okButtonTitle:nil
		  completionBlock:nil];
	[alert show];
}

- (void)cancel {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pickFromLibrary {
	if (self.finishing)
		return;
	self.finishing = YES;
	void (^fallback)(void) = self.onPickFromLibrary;
	[self dismissViewControllerAnimated:YES completion:^{
		if (fallback)
			fallback();
	}];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != self.grid)
		return;
	[self updateVisibleTiles];
	CGFloat remaining = scrollView.contentSize.height -
		(scrollView.contentOffset.y + scrollView.bounds.size.height);
	if (remaining < scrollView.bounds.size.height)
		[self loadNextPage];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	[self scheduleDelayedSearch];
}

- (void)scheduleDelayedSearch {
	NSInteger generation = ++self.generation;
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kGifSearchDelay * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGGifPickerViewController *strongSelf = weakSelf;
			if (!strongSelf || generation != strongSelf.generation)
				return;
			[strongSelf runSearch:strongSelf.searchBar.text];
		});
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
	[self runSearch:searchBar.text];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	[self runSearch:@""];
}

@end
