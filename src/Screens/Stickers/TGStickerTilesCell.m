#import "TGStickerTilesCell.h"
#import "TGTheme.h"

@implementation TGStickerTilesCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.tiles = [NSMutableArray array];

	self.backgroundColor = [UIColor whiteColor];
	return self;
}

- (UIButton *)tileAtIndex:(NSInteger)index {
	while ((NSInteger)self.tiles.count <= index) {
		UIButton *tile = [UIButton buttonWithType:UIButtonTypeCustom];
		tile.backgroundColor = [UIColor clearColor];
		tile.titleLabel.font = [UIFont systemFontOfSize:34];
		tile.imageView.contentMode = UIViewContentModeScaleAspectFit;
		[self.contentView addSubview:tile];
		[self.tiles addObject:tile];
	}
	UIButton *tile = self.tiles[index];
	tile.hidden = NO;
	return tile;
}

- (void)hideTilesFromIndex:(NSInteger)index {
	for (NSInteger i = index; i < (NSInteger)self.tiles.count; i++) {
		UIButton *tile = self.tiles[i];
		tile.hidden = YES;
		[tile setImage:nil forState:UIControlStateNormal];
		[tile setTitle:@"" forState:UIControlStateNormal];
	}
}

@end
