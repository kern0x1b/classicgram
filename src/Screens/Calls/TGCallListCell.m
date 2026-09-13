#import "TGCallListCell.h"
#import "TGCallsRowText.h"
#import "TGCallsItem.h"
#import "TGEmoji.h"
#import "TGTheme.h"

static const CGFloat kCallAvatarLeft = 5.0f;
static const CGFloat kCallAvatarTop = 5.0f;
static const CGFloat kCallTextLeft = 54.0f;
static const CGFloat kCallRightPadding = 6.0f;
static const CGFloat kCallArrowSide = 14.0f;

static UIImage *TGCallListCellStretch(NSString *name, int leftCap) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
}

const CGFloat kCallAvatarSide = 40.0f;

@implementation TGCallListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	UIImage *plate = TGCallListCellStretch(@"Cell102.png", 1);
	UIImage *platePressed = TGCallListCellStretch(@"CellHighlighted102.png", 1);
	if (plate)
		self.backgroundView = [[UIImageView alloc] initWithImage:plate];
	if (platePressed)
		self.selectedBackgroundView = [[UIImageView alloc] initWithImage:platePressed];
	self.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

	self.avatarView = [[UIImageView alloc] initWithFrame:
			CGRectMake(kCallAvatarLeft, kCallAvatarTop, kCallAvatarSide, kCallAvatarSide)];
	self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
	self.avatarView.clipsToBounds = YES;
	self.avatarView.layer.cornerRadius = 4.0f;
	[self.contentView addSubview:self.avatarView];

	self.nameLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
	self.nameLabel.backgroundColor = [UIColor clearColor];
	self.nameLabel.font = [UIFont systemFontOfSize:19];
	self.nameLabel.highlightedTextColor = [UIColor whiteColor];
	self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.nameLabel];

	self.countLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.countLabel.backgroundColor = [UIColor clearColor];
	self.countLabel.font = [UIFont systemFontOfSize:19];
	self.countLabel.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:self.countLabel];

	self.dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.dateLabel.backgroundColor = [UIColor clearColor];
	self.dateLabel.font = [UIFont systemFontOfSize:13];
	self.dateLabel.textColor = [[TGTheme shared] accentColour];
	self.dateLabel.highlightedTextColor = [UIColor whiteColor];
	self.dateLabel.textAlignment = NSTextAlignmentRight;
	[self.contentView addSubview:self.dateLabel];

	self.arrowView = [[UIImageView alloc] initWithFrame:CGRectZero];
	[self.contentView addSubview:self.arrowView];

	self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.subtitleLabel.backgroundColor = [UIColor clearColor];
	self.subtitleLabel.font = [UIFont systemFontOfSize:13.5f];
	self.subtitleLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.subtitleLabel.highlightedTextColor = [UIColor whiteColor];
	self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.subtitleLabel];

	return self;
}

- (void)applyItem:(TGCallsItem *)item avatar:(UIImage *)avatar {
	self.nameLabel.text = item.nameText;
	self.nameLabel.textColor = item.nameColour;
	self.countLabel.text = item.countText;
	self.countLabel.textColor = item.nameColour;
	self.dateLabel.text = item.dateText;
	self.subtitleLabel.text = item.subtitleText;
	self.arrowView.image = item.arrowImage;
	self.avatarView.image = avatar ?: item.avatarPlaceholder;
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect selectedFrame = self.selectedBackgroundView.frame;
	if (selectedFrame.size.width > 0) {
		selectedFrame.origin.y = -1;
		selectedFrame.size.height = self.frame.size.height + 1;
		self.selectedBackgroundView.frame = selectedFrame;
	}

	CGSize viewSize = self.contentView.frame.size;
	self.avatarView.frame = CGRectMake(kCallAvatarLeft, kCallAvatarTop,
		kCallAvatarSide, kCallAvatarSide);

	CGFloat nameHeight = self.nameLabel.font.lineHeight;
	CGFloat subtitleHeight = self.subtitleLabel.font.lineHeight;
	CGFloat topY = (CGFloat)(int)((viewSize.height - nameHeight - subtitleHeight - 1) / 2);

	CGFloat rightEdge = viewSize.width - kCallRightPadding;
	CGFloat dateWidth = 0;
	if (self.dateLabel.text.length) {
		dateWidth = [self.dateLabel.text sizeWithFont:self.dateLabel.font].width;
		if (dateWidth > viewSize.width / 3)
			dateWidth = (CGFloat)(int)(viewSize.width / 3);
	}
	CGFloat dateHeight = self.dateLabel.font.lineHeight;
	CGFloat dateY = topY + self.nameLabel.font.ascender - self.dateLabel.font.ascender;
	self.dateLabel.frame = CGRectMake(rightEdge - dateWidth, dateY, dateWidth, dateHeight);

	CGFloat nameRight = rightEdge - (dateWidth > 0 ? dateWidth + 6 : 0);
	CGFloat nameWidth = nameRight - kCallTextLeft;
	if (nameWidth < 10)
		nameWidth = 10;

	CGFloat countWidth = 0;
	if (self.countLabel.text.length) {
		countWidth = [self.countLabel.text sizeWithFont:self.countLabel.font].width + 4;
		if (countWidth > nameWidth - 20)
			countWidth = nameWidth - 20;
		if (countWidth < 0)
			countWidth = 0;
	}

	CGFloat measuredName = TGEmojiTextSize(self.nameLabel.text, self.nameLabel.font,
		CGSizeMake(10000, nameHeight), NSLineBreakByWordWrapping, 1)
							   .width;
	CGFloat shownName = MIN(measuredName, nameWidth - countWidth);
	if (shownName < 0)
		shownName = 0;
	self.nameLabel.frame = CGRectMake(kCallTextLeft, topY, shownName, nameHeight);
	self.countLabel.frame = countWidth > 0
		? CGRectMake(kCallTextLeft + shownName + 4, topY, countWidth, nameHeight)
		: CGRectZero;

	CGFloat subtitleY = topY + nameHeight + 1;
	CGFloat subtitleX = kCallTextLeft;
	if (self.arrowView.image) {
		self.arrowView.frame = CGRectMake(kCallTextLeft,
			(CGFloat)(int)(subtitleY + (subtitleHeight - kCallArrowSide) / 2),
			kCallArrowSide, kCallArrowSide);
		subtitleX = kCallTextLeft + kCallArrowSide + 3;
	} else {
		self.arrowView.frame = CGRectZero;
	}

	CGFloat subtitleWidth = rightEdge - subtitleX;
	if (subtitleWidth < 10)
		subtitleWidth = 10;
	self.subtitleLabel.frame = CGRectMake(subtitleX, subtitleY, subtitleWidth, subtitleHeight);
}

@end
