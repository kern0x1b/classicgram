#import "TGMediaGridCell.h"
#import "TGMediaTileView.h"
#import "TGViewRecycler.h"
#import "TGLocalization.h"

@implementation TGMediaGridCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.backgroundColor = [UIColor clearColor];
		self.contentView.backgroundColor = [UIColor clearColor];
		_tiles = [[NSMutableArray alloc] init];

		UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
			initWithTarget:self
					action:@selector(handleTap:)];
		[self.contentView addGestureRecognizer:tap];
	}
	return self;
}

- (TGMediaTileView *)takeTile {
	TGMediaTileView *tile = nil;
	TGViewRecycler *recycler = self.recycler;
	if (recycler) {
		UIView<TGReusableView> *view = [recycler dequeueReusableViewWithIdentifier:TGMediaTileIdentifier];
		if ([view isKindOfClass:[TGMediaTileView class]])
			tile = (TGMediaTileView *)view;
	}
	if (!tile) {
		tile = [[TGMediaTileView alloc] initWithFrame:CGRectZero];
		tile.image = TGMediaTilePlaceholder();
	}
	return tile;
}

- (void)releaseTiles {
	TGViewRecycler *recycler = self.recycler;
	for (TGMediaTileView *tile in _tiles) {
		if (recycler)
			[recycler recycleView:tile];
		else {
			[tile cancelLoading];
			[tile removeFromSuperview];
		}
	}
	[_tiles removeAllObjects];
	self.items = nil;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	[self releaseTiles];
}

- (void)configureWithItems:(NSArray *)items baseIndex:(NSInteger)baseIndex {
	self.baseIndex = baseIndex;
	self.items = items;

	while (_tiles.count > items.count) {
		TGMediaTileView *tile = [_tiles lastObject];
		[_tiles removeLastObject];
		TGViewRecycler *recycler = self.recycler;
		if (recycler)
			[recycler recycleView:tile];
		else {
			[tile cancelLoading];
			[tile removeFromSuperview];
		}
	}

	while (_tiles.count < items.count) {
		TGMediaTileView *tile = [self takeTile];
		[self.contentView addSubview:tile];
		[_tiles addObject:tile];
	}

	for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
		TGMediaTileView *tile = _tiles[i];
		NSDictionary *item = items[i];

		if (tile.superview != self.contentView)
			[self.contentView addSubview:tile];

		NSNumber *thumbId = item[@"thumbId"];
		if (![thumbId isKindOfClass:NSNumber.class])
			thumbId = nil;

		UIImage *instant = self.instantThumbnailProvider
			? self.instantThumbnailProvider(item)
			: nil;
		NSString *stableKey = item[@"thumbUniqueId"];
		if (![stableKey isKindOfClass:NSString.class])
			stableKey = nil;
		[tile loadWithFileId:thumbId
				   stableKey:stableKey
					  square:kMediaTileSide
				 placeholder:instant ?: TGMediaTilePlaceholder()
				   forceFade:false];

		if ([item[@"isVideo"] boolValue]) {
			NSString *duration = TGMediaFormatDuration([item[@"duration"] integerValue]);
			[tile showVideoBadge:duration];
			tile.accessibilityLabel = [NSString stringWithFormat:@"%@, %@",
				TGL(@"Message.Video", @"Video"), duration];
		} else {
			[tile hideVideoBadge];
			tile.accessibilityLabel = TGL(@"Message.Photo", @"Photo");
		}
		tile.isAccessibilityElement = YES;
	}

	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	NSInteger count = (NSInteger)_tiles.count;
	if (count == 0)
		return;

	CGFloat width = self.contentView.bounds.size.width;
	NSInteger perRow = (NSInteger)(width / (kMediaTileSide + kMediaTileSpacing));
	if (perRow < 1)
		perRow = 1;
	CGFloat used = perRow * kMediaTileSide + (perRow - 1) * kMediaTileSpacing;
	CGFloat x = (CGFloat)(int)((width - used) / 2.0f);

	for (NSInteger i = 0; i < count; i++) {
		TGMediaTileView *tile = _tiles[i];
		tile.frame = CGRectMake(x, kMediaTileSpacing, kMediaTileSide, kMediaTileSide);
		if (tile.badgeBar && !tile.badgeBar.hidden)
			tile.badgeBar.frame = CGRectMake(0, kMediaTileSide - 19, kMediaTileSide, 19);
		x += kMediaTileSide + kMediaTileSpacing;
	}
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateRecognized)
		return;

	CGPoint point = [recognizer locationInView:self.contentView];
	for (NSInteger i = 0; i < (NSInteger)_tiles.count; i++) {
		TGMediaTileView *tile = _tiles[i];
		if (CGRectContainsPoint(CGRectInset(tile.frame, -2, -2), point)) {
			[self.gridDelegate gridCell:self tappedItemAtIndex:self.baseIndex + i];
			return;
		}
	}
}

@end
