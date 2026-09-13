#import "TGStickerSuggestionStrip.h"

#import "TGStickerCatalogService.h"
#import "TGStickerThumbnailCache.h"
#import "TGTheme.h"

static const CGFloat kStickerSuggestionHeight = 78.0f;
static const CGFloat kStickerSuggestionTileSide = 62.0f;
static const CGFloat kStickerSuggestionSpacing = 6.0f;
static const NSInteger kStickerSuggestionLimit = 20;
static const NSUInteger kStickerSuggestionMaxLength = 24;

static BOOL TGStickerSuggestionScalarIsEmoji(UTF32Char code) {
	if (code >= 0x1F000 && code <= 0x1FAFF)
		return YES;
	if (code >= 0x2600 && code <= 0x27BF)
		return YES;
	if (code >= 0x2190 && code <= 0x21FF)
		return YES;
	if (code >= 0x2300 && code <= 0x23FF)
		return YES;
	if (code == 0x24C2)
		return YES;
	if (code >= 0x25AA && code <= 0x25FE)
		return YES;
	if (code >= 0x2B00 && code <= 0x2BFF)
		return YES;
	if (code == 0x00A9 || code == 0x00AE || code == 0x203C || code == 0x2049)
		return YES;
	if (code >= 0x2122 && code <= 0x2199)
		return YES;
	if (code >= 0xFE00 && code <= 0xFE0F)
		return YES;
	if (code == 0x200D || code == 0x20E3)
		return YES;
	if (code >= 0x1F1E6 && code <= 0x1F1FF)
		return YES;
	return NO;
}

static BOOL TGStickerSuggestionScalarIsFitzpatrickModifier(UTF32Char code) {
	return code >= 0x1F3FB && code <= 0x1F3FF;
}

static BOOL TGStickerSuggestionScalarIsJoinerOrSelector(UTF32Char code) {
	if (code == 0x200D)
		return YES;
	return code >= 0xFE00 && code <= 0xFE0F;
}

static NSUInteger TGStickerSuggestionNextScalar(NSString *text, NSUInteger index, UTF32Char *outCode) {
	unichar unit = [text characterAtIndex:index];
	UTF32Char code = unit;
	NSUInteger step = 1;
	if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
		unichar low = [text characterAtIndex:index + 1];
		if (low >= 0xDC00 && low <= 0xDFFF) {
			code = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
			step = 2;
		}
	}
	*outCode = code;
	return step;
}

static void TGStickerSuggestionAppendScalar(NSMutableString *out, UTF32Char code) {
	if (code > 0xFFFF) {
		UTF32Char shifted = code - 0x10000;
		unichar high = (unichar)(0xD800 + (shifted >> 10));
		unichar low = (unichar)(0xDC00 + (shifted & 0x3FF));
		[out appendFormat:@"%C%C", high, low];
	} else {
		[out appendFormat:@"%C", (unichar)code];
	}
}

static BOOL TGStickerSuggestionConsumeEmojiCluster(NSString *text, NSUInteger length,
		NSUInteger *ioIndex, NSMutableString *outQuery) {
	NSUInteger index = *ioIndex;
	UTF32Char code = 0;
	NSUInteger step = TGStickerSuggestionNextScalar(text, index, &code);
	if (!TGStickerSuggestionScalarIsEmoji(code) ||
			TGStickerSuggestionScalarIsJoinerOrSelector(code) ||
			TGStickerSuggestionScalarIsFitzpatrickModifier(code))
		return NO;

	TGStickerSuggestionAppendScalar(outQuery, code);
	index += step;

	if (code >= 0x1F1E6 && code <= 0x1F1FF && index < length) {
		UTF32Char next = 0;
		NSUInteger nextStep = TGStickerSuggestionNextScalar(text, index, &next);
		if (next >= 0x1F1E6 && next <= 0x1F1FF) {
			TGStickerSuggestionAppendScalar(outQuery, next);
			index += nextStep;
		}
	}

	while (index < length) {
		UTF32Char modifier = 0;
		NSUInteger modifierStep = TGStickerSuggestionNextScalar(text, index, &modifier);
		if (TGStickerSuggestionScalarIsFitzpatrickModifier(modifier)) {
			index += modifierStep;
			continue;
		}
		if (modifier >= 0xFE00 && modifier <= 0xFE0F) {
			TGStickerSuggestionAppendScalar(outQuery, modifier);
			index += modifierStep;
			continue;
		}
		if (modifier == 0x200D && index + modifierStep < length) {
			NSUInteger afterJoiner = index + modifierStep;
			UTF32Char joined = 0;
			NSUInteger joinedStep = TGStickerSuggestionNextScalar(text, afterJoiner, &joined);
			if (TGStickerSuggestionScalarIsEmoji(joined) &&
					!TGStickerSuggestionScalarIsJoinerOrSelector(joined) &&
					!TGStickerSuggestionScalarIsFitzpatrickModifier(joined)) {
				TGStickerSuggestionAppendScalar(outQuery, modifier);
				TGStickerSuggestionAppendScalar(outQuery, joined);
				index = afterJoiner + joinedStep;
				continue;
			}
		}
		break;
	}

	*ioIndex = index;
	return YES;
}

static BOOL TGStickerSuggestionExtractQuery(NSString *text, NSString **outQuery) {
	NSString *trimmed = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSUInteger length = trimmed.length;
	if (length == 0 || length > kStickerSuggestionMaxLength)
		return NO;

	NSMutableString *stripped = [NSMutableString stringWithCapacity:length];
	NSUInteger index = 0;
	if (!TGStickerSuggestionConsumeEmojiCluster(trimmed, length, &index, stripped))
		return NO;
	if (index != length || stripped.length == 0)
		return NO;

	if (outQuery != NULL)
		*outQuery = stripped;
	return YES;
}

@interface TGStickerSuggestionTile : UIControl

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) NSDictionary *sticker;
@property (nonatomic, strong) id imageToken;

@end

@implementation TGStickerSuggestionTile

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.backgroundColor = [UIColor clearColor];
		self.exclusiveTouch = YES;
		_imageView = [[UIImageView alloc] initWithFrame:self.bounds];
		_imageView.contentMode = UIViewContentModeScaleAspectFit;
		_imageView.userInteractionEnabled = NO;
		[self addSubview:_imageView];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	_imageView.frame = self.bounds;
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	_imageView.transform = highlighted ? CGAffineTransformMakeScale(0.86f, 0.86f)
									   : CGAffineTransformIdentity;
}

@end

@interface TGStickerSuggestionStrip () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scroller;
@property (nonatomic, strong) UIView *topRule;
@property (nonatomic, strong) NSMutableArray *stickers;
@property (nonatomic, strong) NSMutableArray *tiles;
@property (nonatomic, copy) NSString *shownQuery;
@property (nonatomic, assign) NSInteger generation;

@end

@implementation TGStickerSuggestionStrip

+ (CGFloat)preferredHeight {
	return kStickerSuggestionHeight;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		_stickers = [[NSMutableArray alloc] init];
		_tiles = [[NSMutableArray alloc] init];
		_shownQuery = @"";
		self.hidden = YES;
		self.backgroundColor = [UIColor colorWithRed:0.98f green:0.98f blue:0.98f alpha:1.0f];

		_topRule = [[UIView alloc] initWithFrame:CGRectZero];
		_topRule.backgroundColor = [[TGTheme shared] separatorColour];
		[self addSubview:_topRule];

		_scroller = [[UIScrollView alloc] initWithFrame:self.bounds];
		_scroller.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
		_scroller.showsHorizontalScrollIndicator = NO;
		_scroller.alwaysBounceHorizontal = YES;
		_scroller.backgroundColor = [UIColor clearColor];
		_scroller.delegate = self;
		[self addSubview:_scroller];

	}
	return self;
}

- (void)dealloc {
	for (TGStickerSuggestionTile *tile in self.tiles)
		[TGStickerThumbnailCache cancelRequest:tile.imageToken];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat pixel = 1.0f / [UIScreen mainScreen].scale;
	self.topRule.frame = CGRectMake(0, 0, self.bounds.size.width, pixel);
	self.scroller.frame = self.bounds;
	[self layoutTiles];
}

- (void)layoutTiles {
	CGFloat y = floorf((self.bounds.size.height - kStickerSuggestionTileSide) / 2.0f);
	CGFloat x = kStickerSuggestionSpacing * 2.0f;
	for (TGStickerSuggestionTile *tile in self.tiles) {
		tile.frame = CGRectMake(x, y, kStickerSuggestionTileSide,
			kStickerSuggestionTileSide);
		x += kStickerSuggestionTileSide + kStickerSuggestionSpacing;
	}
	self.scroller.contentSize = CGSizeMake(x + kStickerSuggestionSpacing,
		self.bounds.size.height);
	[self loadVisibleThumbnails];
}

- (void)loadVisibleThumbnails {
	CGRect visible = CGRectMake(self.scroller.contentOffset.x, 0,
		self.scroller.bounds.size.width + kStickerSuggestionTileSide,
		self.scroller.bounds.size.height);
	for (TGStickerSuggestionTile *tile in self.tiles) {
		if (tile.imageView.image != nil || tile.imageToken != nil)
			continue;
		if (CGRectIntersectsRect(tile.frame, visible))
			[self loadThumbnailForTile:tile];
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView == self.scroller)
		[self loadVisibleThumbnails];
}

#pragma mark - content

- (void)clear {
	if (self.hidden && self.shownQuery.length == 0 && self.stickers.count == 0)
		return;
	self.generation++;
	self.shownQuery = @"";
	[self.stickers removeAllObjects];
	[self rebuildTiles];
	[self setVisible:NO];
}

- (void)updateForText:(NSString *)text {
	TGStickerSuggestMode mode = TGStickersSuggestMode();
	if (mode == TGStickerSuggestModeNone) {
		[self clear];
		return;
	}

	NSString *query = nil;
	if (!TGStickerSuggestionExtractQuery(text, &query)) {
		[self clear];
		return;
	}

	if ([query isEqualToString:self.shownQuery])
		return;

	self.generation++;
	NSInteger generation = self.generation;
	self.shownQuery = query;

	__weak TGStickerSuggestionStrip *weakSelf = self;
	void (^showRemote)(NSArray *) = ^(NSArray *remote) {
		TGStickerSuggestionStrip *strongSelf = weakSelf;
		if (!strongSelf || generation != strongSelf.generation)
			return;
		[strongSelf showStickers:remote];
	};
	void (^showInstalled)(NSArray *) = ^(NSArray *stickers) {
		TGStickerSuggestionStrip *strongSelf = weakSelf;
		if (!strongSelf || generation != strongSelf.generation)
			return;
		if (stickers.count > 0 || mode == TGStickerSuggestModeInstalled) {
			[strongSelf showStickers:stickers];
			return;
		}
		[TGStickerCatalogService searchStickersByEmoji:query
												 query:nil
												 limit:kStickerSuggestionLimit
											completion:showRemote];
	};
	[TGStickerCatalogService installedStickersMatching:query
												 limit:kStickerSuggestionLimit
											completion:showInstalled];
}

- (void)showStickers:(NSArray *)stickers {
	[self.stickers removeAllObjects];
	for (NSDictionary *sticker in stickers) {
		if (![sticker isKindOfClass:[NSDictionary class]])
			continue;
		if ([sticker[@"isVideo"] boolValue])
			continue;
		[self.stickers addObject:sticker];
	}
	[self rebuildTiles];
	[self setVisible:(self.stickers.count > 0)];
}

- (void)rebuildTiles {
	for (TGStickerSuggestionTile *tile in self.tiles) {
		[TGStickerThumbnailCache cancelRequest:tile.imageToken];
		[tile removeFromSuperview];
	}
	[self.tiles removeAllObjects];

	NSInteger index = 0;
	for (NSDictionary *sticker in self.stickers) {
		TGStickerSuggestionTile *tile = [[TGStickerSuggestionTile alloc]
			initWithFrame:CGRectZero];
		tile.sticker = sticker;
		tile.tag = index++;
		[tile addTarget:self action:@selector(tileTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[self.scroller addSubview:tile];
		[self.tiles addObject:tile];
	}
	self.scroller.contentOffset = CGPointZero;
	[self layoutTiles];
}

- (void)loadThumbnailForTile:(TGStickerSuggestionTile *)tile {
	NSDictionary *sticker = tile.sticker;
	NSNumber *thumbId = sticker[@"thumbId"];
	NSString *uniqueId = sticker[@"thumbUniqueId"];
	long long fileId = [thumbId longLongValue];
	if (fileId <= 0 && ![sticker[@"isAnimated"] boolValue]) {
		fileId = [sticker[@"fileId"] longLongValue];
		uniqueId = sticker[@"uniqueId"];
	}
	if (fileId <= 0)
		return;

	UIImage *cached = [TGStickerThumbnailCache
		cachedThumbnailForUniqueId:uniqueId
							  side:kStickerSuggestionTileSide];
	if (cached != nil) {
		tile.imageView.image = cached;
		return;
	}

	__weak TGStickerSuggestionTile *weakTile = tile;
	tile.imageToken = [TGStickerThumbnailCache
		thumbnailForFileId:fileId
				  uniqueId:uniqueId
					  side:kStickerSuggestionTileSide
				completion:^(UIImage *image) {
					TGStickerSuggestionTile *strongTile = weakTile;
					if (!strongTile || image == nil)
						return;
					strongTile.imageToken = nil;
					strongTile.imageView.image = image;
				}];
}

- (void)setVisible:(BOOL)visible {
	if (self.hidden == !visible)
		return;
	self.hidden = !visible;
	if (self.onVisibilityChanged)
		self.onVisibilityChanged(visible);
}

- (void)tileTapped:(TGStickerSuggestionTile *)tile {
	NSDictionary *sticker = tile.sticker;
	if (sticker == nil)
		return;
	long long fileId = [sticker[@"fileId"] longLongValue];
	if (fileId != 0)
		[TGStickerCatalogService addRecentStickerWithFileId:fileId];
	[self clear];
	if (self.onStickerPicked)
		self.onStickerPicked(sticker);
}

@end
