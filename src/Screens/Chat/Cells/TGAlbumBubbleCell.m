#import "TGAlbumBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGTheme.h"
#import "TGLocalization.h"

extern UIColor *TGMessageBodyColour(void);
extern CGFloat TGMessageBaseFontSize(void);

@interface TGAlbumBubbleCell ()

@property (nonatomic, strong, readwrite) UIView *album;
@property (nonatomic, strong, readwrite) TGEmojiLabel *body;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *tiles;
@property (nonatomic, strong) NSMutableArray<UIControl *> *tileHitAreas;

@end

@implementation TGAlbumBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.album = [[UIView alloc] init];
	self.album.clipsToBounds = YES;
	self.album.layer.cornerRadius = [[TGTheme shared] mediaCornerRadius];
	[self.bubble addSubview:self.album];

	self.body = [[TGEmojiLabel alloc] init];
	self.body.numberOfLines = 0;
	self.body.lineBreakMode = NSLineBreakByWordWrapping;
	self.body.backgroundColor = [UIColor clearColor];
	self.body.hidden = YES;
	[self.bubble addSubview:self.body];

	self.tiles = [NSMutableArray array];
	self.tileHitAreas = [NSMutableArray array];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.body.richLayout = nil;
	for (UIImageView *tile in self.tiles)
		tile.image = nil;
}

- (TGEmojiLabel *)tg_richTextLabel {
	return self.body;
}

- (NSUInteger)tileCount {
	return self.tiles.count;
}

- (UIImageView *)tileAtIndex:(NSUInteger)index {
	while (self.tiles.count <= index) {
		UIImageView *tile = [[UIImageView alloc] init];
		tile.contentMode = UIViewContentModeScaleAspectFill;
		tile.clipsToBounds = YES;
		[self.album addSubview:tile];
		[self.tiles addObject:tile];
	}
	return self.tiles[index];
}

- (UIControl *)hitAreaAtIndex:(NSUInteger)index {
	while (self.tileHitAreas.count <= index) {
		UIControl *hitArea = [[UIControl alloc] init];
		hitArea.tag = (NSInteger)self.tileHitAreas.count;
		[hitArea addTarget:self action:@selector(tg_tileTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[self.album addSubview:hitArea];
		[self.tileHitAreas addObject:hitArea];
	}
	return self.tileHitAreas[index];
}

- (void)tg_tileTapped:(UIControl *)hitArea {
	if (![self.delegate respondsToSelector:@selector(bubbleCell:didTapAlbumTileAtIndex:atRow:)])
		return;
	[self.delegate bubbleCell:self
		didTapAlbumTileAtIndex:(NSUInteger)hitArea.tag
						 atRow:self.appliedRow];
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	self.album.frame = layout.bubble.album;

	NSInteger count = layout.repeatedRowCount;
	for (NSInteger i = 0; i < count; i++) {
		TGMessageLayoutRepeatedRow row = [layout repeatedRowAtIndex:i];
		if (row.kind != TGMessageLayoutRowAlbumTile)
			continue;
		UIImageView *tile = [self tileAtIndex:row.index];
		tile.frame = row.frame;
		tile.hidden = NO;
		UIControl *hitArea = [self hitAreaAtIndex:row.index];
		hitArea.frame = row.frame;
		hitArea.hidden = NO;
	}
	for (NSInteger i = count; i < self.tiles.count; i++)
		self.tiles[i].hidden = YES;
	for (NSInteger i = count; i < self.tileHitAreas.count; i++)
		self.tileHitAreas[i].hidden = YES;

	self.body.hidden = !(layout.parts & TGMessageLayoutPartBody);
	if (layout.parts & TGMessageLayoutPartBody) {
		self.body.frame = layout.bubble.body;
		self.body.font = [UIFont systemFontOfSize:TGMessageBaseFontSize()];
		self.body.textColor = TGMessageBodyColour();
		self.body.text = item.bodyText;
		self.body.richLayout = item.bodyRichLayout;
	}

	NSUInteger albumItemCount = (NSUInteger)count;
	NSString *albumItemCountText = albumItemCount > 0
		? TGLPlural(@"VoiceOver.Chat.AlbumItemCount", (NSInteger)albumItemCount, @"%ld item", @"%ld items")
		: nil;

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		TGL(@"Attachment.PhotoAlbum", @"Photo Album"),
		albumItemCountText ?: @"",
		item.bodyText ?: @"",
		item.stampText ?: @"",
	]];
}

@end
