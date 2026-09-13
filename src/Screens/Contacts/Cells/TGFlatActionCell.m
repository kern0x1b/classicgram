#import "TGFlatActionCell.h"
#import "TGContactRowMetrics.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGHexColour.h"

@implementation TGFlatActionCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	UIImage *background = [UIImage imageNamed:@"Cell88"] ?: [UIImage imageNamed:@"Cell102"];
	UIImage *highlighted = [UIImage imageNamed:@"CellHighlighted88"]
		?: [UIImage imageNamed:@"CellHighlighted102"];
	if (background)
		self.backgroundView = [[UIImageView alloc] initWithImage:background];
	if (highlighted)
		self.selectedBackgroundView = [[UIImageView alloc] initWithImage:highlighted];
	self.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(53, 12, 200, 20)];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	self.titleLabel.contentMode = UIViewContentModeLeft;
	self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
	self.titleLabel.textColor = TGColourFromHex(0x0779d0);
	self.titleLabel.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:self.titleLabel];

	self.iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
	[self.contentView addSubview:self.iconView];

	UIImage *disclosureImage = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator"]);
	UIImage *disclosureHighlightedImage = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator_Highlighted"]);
	self.disclosureIndicator = [[UIImageView alloc] initWithImage:disclosureImage highlightedImage:disclosureHighlightedImage];
	self.disclosureIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self.contentView addSubview:self.disclosureIndicator];

	return self;
}

- (void)setIconNamed:(NSString *)name at:(CGPoint)origin {
	UIImage *image = name.length ? [UIImage imageNamed:name] : nil;
	self.iconView.image = image;
	self.iconView.highlightedImage = image
		? [UIImage imageNamed:[name stringByAppendingString:@"_Highlighted"]]
		: nil;
	if (!image) {
		self.iconView.frame = CGRectZero;
		return;
	}
	self.iconView.frame = CGRectMake(origin.x, origin.y, image.size.width, image.size.height);
}

- (void)layoutSubviews {
	[super layoutSubviews];
	if (self.selectedBackgroundView) {
		CGRect selectedFrame = self.selectedBackgroundView.frame;
		selectedFrame.origin.y = -1;
		selectedFrame.size.height = self.frame.size.height + 1;
		self.selectedBackgroundView.frame = selectedFrame;
	}
	CGFloat width = self.contentView.bounds.size.width;
	CGSize arrow = self.disclosureIndicator.image.size;
	if (arrow.width > 0)
		self.disclosureIndicator.frame = CGRectMake(width - arrow.width - 12, 14,
			arrow.width, arrow.height);
	CGFloat right = self.disclosureIndicator.hidden ? 12 : (arrow.width + 18);
	self.titleLabel.frame = CGRectMake(53, 12, MAX(20.0f, width - 53 - right), 20);
}

@end
