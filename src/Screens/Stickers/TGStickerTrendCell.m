#import "TGStickerTrendCell.h"
#import "TGTheme.h"
#import "TGStickersViewControllerInternal.h"
#import "TGHexColour.h"

static const NSInteger kTrendCoverCount = 5;

@implementation TGStickerTrendCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.packTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.packTitleLabel.backgroundColor = [UIColor clearColor];
	self.packTitleLabel.font = [UIFont boldSystemFontOfSize:15];
	[self.contentView addSubview:self.packTitleLabel];

	self.packCountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.packCountLabel.backgroundColor = [UIColor clearColor];
	self.packCountLabel.font = [UIFont systemFontOfSize:13 + TGStickersRetinaPixel()];
	self.packCountLabel.textColor = TGColourFromHex(0x888888);
	[self.contentView addSubview:self.packCountLabel];

	self.coverViews = [NSMutableArray array];
	for (NSInteger i = 0; i < kTrendCoverCount; i++) {
		UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectZero];
		cover.contentMode = UIViewContentModeScaleAspectFit;
		[self.contentView addSubview:cover];
		[self.coverViews addObject:cover];
	}

	self.addButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.addButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	self.addButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
	[self.addButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.addButton setTitleColor:TGColourFromHex(0x8b97a5) forState:UIControlStateDisabled];
	[self.addButton setTitleShadowColor:TGStickersGreenShadow()
							   forState:UIControlStateNormal];
	[self.addButton setTitleShadowColor:TGStickersGreenShadow()
							   forState:UIControlStateHighlighted];
	[self.addButton setBackgroundImage:TGStickersPlate(@"GroupedActionButtonGreen.png")
							  forState:UIControlStateNormal];
	[self.addButton setBackgroundImage:
			TGStickersPlate(@"GroupedActionButtonGreen_Highlighted.png")
							  forState:UIControlStateHighlighted];
	[self.contentView addSubview:self.addButton];
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat width = self.contentView.bounds.size.width;

	CGFloat plate = TGStickersPlateHeight(@"GroupedActionButtonGreen.png", 43.0f);
	self.addButton.frame = CGRectMake(width - 80, 7, 70, plate);
	self.packTitleLabel.frame = CGRectMake(10, 6, width - 100, 20);
	self.packCountLabel.frame = CGRectMake(10, 24, width - 100, 16);

	NSInteger index = 0;
	for (UIImageView *cover in self.coverViews) {
		cover.frame = CGRectMake(10 + index * (kTrendCoverSide + 14), 40,
			kTrendCoverSide, kTrendCoverSide);
		index++;
	}
}

@end
