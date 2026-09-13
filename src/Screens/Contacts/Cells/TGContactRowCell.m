#import "TGContactRowCell.h"
#import "TGContactRowMetrics.h"
#import "TGContactRowMeasurement.h"
#import "TGTheme.h"
#import "TGEmoji.h"
#import "TGHexColour.h"

@implementation TGContactRowCell {
	NSString *_titleMeasuredText;
	CGFloat _titleMeasuredFontSize;
	CGFloat _titleMeasuredHeight;
	CGFloat _titleMeasuredWidth;
	NSString *_secondMeasuredText;
	CGFloat _secondMeasuredFontSize;
	CGFloat _secondMeasuredHeight;
	CGFloat _secondMeasuredWidth;
	NSString *_fittedText;
	CGFloat _fittedFontSize;
	CGFloat _fittedHeight;
	CGFloat _fittedLimit;
	CGFloat _fittedWidth;
}

- (CGFloat)measuredTitleWidthForHeight:(CGFloat)height {
	NSString *text = self.titleLabel.text;
	CGFloat fontSize = self.titleLabel.font.pointSize;
	if (TGContactRowMeasurementIsFresh(_titleMeasuredText, _titleMeasuredFontSize,
			_titleMeasuredHeight, 0, text, fontSize, height, 0))
		return _titleMeasuredWidth;
	CGSize size = TGEmojiTextSize(text, self.titleLabel.font, CGSizeMake(10000, height),
		NSLineBreakByWordWrapping, 1);
	_titleMeasuredText = [text copy];
	_titleMeasuredFontSize = fontSize;
	_titleMeasuredHeight = height;
	_titleMeasuredWidth = size.width;
	return size.width;
}

- (CGFloat)measuredSecondTitleWidthForHeight:(CGFloat)height {
	NSString *text = self.secondTitleLabel.text;
	CGFloat fontSize = self.secondTitleLabel.font.pointSize;
	if (TGContactRowMeasurementIsFresh(_secondMeasuredText, _secondMeasuredFontSize,
			_secondMeasuredHeight, 0, text, fontSize, height, 0))
		return _secondMeasuredWidth;
	CGSize size = TGEmojiTextSize(text, self.secondTitleLabel.font, CGSizeMake(10000, height),
		NSLineBreakByWordWrapping, 1);
	_secondMeasuredText = [text copy];
	_secondMeasuredFontSize = fontSize;
	_secondMeasuredHeight = height;
	_secondMeasuredWidth = size.width;
	return size.width;
}

- (CGFloat)fittedTitleWidthForLimit:(CGFloat)limit height:(CGFloat)height {
	NSString *text = self.titleLabel.text;
	CGFloat fontSize = self.titleLabel.font.pointSize;
	if (TGContactRowMeasurementIsFresh(_fittedText, _fittedFontSize, _fittedHeight, _fittedLimit,
			text, fontSize, height, limit))
		return _fittedWidth;
	CGSize fit = [self.titleLabel sizeThatFits:CGSizeMake(limit, height)];
	_fittedText = [text copy];
	_fittedFontSize = fontSize;
	_fittedHeight = height;
	_fittedLimit = limit;
	_fittedWidth = fit.width;
	return fit.width;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	UIImage *background = [UIImage imageNamed:@"Cell102"];
	UIImage *highlighted = [UIImage imageNamed:@"CellHighlighted102"];
	if (background)
		self.backgroundView = [[UIImageView alloc] initWithImage:background];
	if (highlighted)
		self.selectedBackgroundView = [[UIImageView alloc] initWithImage:highlighted];
	self.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.avatarView = [[UIImageView alloc] initWithFrame:
			CGRectMake(kContactAvatarLeft, kContactAvatarTop, kContactAvatar, kContactAvatar)];
	self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
	self.avatarView.clipsToBounds = YES;
	[self.contentView addSubview:self.avatarView];

	self.titleLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	self.titleLabel.font = [UIFont systemFontOfSize:19];
	self.titleLabel.textColor = [UIColor blackColor];
	self.titleLabel.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:self.titleLabel];

	self.secondTitleLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
	self.secondTitleLabel.backgroundColor = [UIColor clearColor];
	self.secondTitleLabel.font = [UIFont boldSystemFontOfSize:19];
	self.secondTitleLabel.textColor = [UIColor blackColor];
	self.secondTitleLabel.highlightedTextColor = [UIColor whiteColor];
	self.secondTitleLabel.hidden = YES;
	[self.contentView addSubview:self.secondTitleLabel];

	self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.subtitleLabel.backgroundColor = [UIColor clearColor];
	self.subtitleLabel.font = [UIFont systemFontOfSize:13.0f + TGContactsRetinaPixel()];
	self.subtitleLabel.textColor = TGColourFromHex(0x888888);
	self.subtitleLabel.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:self.subtitleLabel];

	[self buildBadgeViews];

	return self;
}

- (void)buildBadgeViews {
	self.premiumView = [[UIImageView alloc] initWithFrame:CGRectZero];
	self.premiumView.contentMode = UIViewContentModeScaleAspectFit;
	self.premiumView.hidden = YES;
	[self.contentView addSubview:self.premiumView];

	self.verifiedLabel = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ListCheck"]
										   highlightedImage:[UIImage imageNamed:@"ListCheck_Highlighted"]];
	self.verifiedLabel.backgroundColor = [UIColor clearColor];
	self.verifiedLabel.contentMode = UIViewContentModeCenter;
	self.verifiedLabel.hidden = YES;
	[self.contentView addSubview:self.verifiedLabel];

	self.closeFriendLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.closeFriendLabel.backgroundColor = [UIColor clearColor];
	self.closeFriendLabel.font = [UIFont systemFontOfSize:13];
	self.closeFriendLabel.textColor = TGColourFromHex(0x3ac13a);
	self.closeFriendLabel.highlightedTextColor = [UIColor whiteColor];
	self.closeFriendLabel.textAlignment = NSTextAlignmentCenter;
	self.closeFriendLabel.text = @"★";
	self.closeFriendLabel.hidden = YES;
	[self.contentView addSubview:self.closeFriendLabel];
}

- (void)resetForConfiguration {
	self.avatarView.image = nil;
	self.avatarView.layer.cornerRadius = kContactAvatarCorner;
	self.titleLabel.font = [UIFont systemFontOfSize:19];
	self.titleLabel.text = @"";
	self.secondTitleLabel.font = [UIFont boldSystemFontOfSize:19];
	self.secondTitleLabel.text = @"";
	self.secondTitleLabel.hidden = YES;
	self.subtitleLabel.text = @"";
	self.subtitleLabel.textColor = TGColourFromHex(0x888888);
	self.premiumView.image = nil;
	self.premiumView.hidden = YES;
	self.verifiedLabel.hidden = YES;
	self.closeFriendLabel.hidden = YES;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.backgroundColor = [[TGTheme shared] listBackgroundColour];
}

- (CGFloat)badgeWidth {
	CGFloat width = 0;
	if (!self.closeFriendLabel.hidden)
		width += kContactBadgeSide + kContactBadgeGap;
	if (!self.premiumView.hidden)
		width += kContactBadgeSide + kContactBadgeGap;
	if (!self.verifiedLabel.hidden)
		width += kContactBadgeSide + kContactBadgeGap;
	return width;
}

- (void)layoutBadgesAfterX:(CGFloat)x titleY:(CGFloat)titleY
			   titleHeight:(CGFloat)titleHeight {
	CGFloat y = (CGFloat)(int)(titleY + (titleHeight - kContactBadgeSide) / 2);
	if (!self.closeFriendLabel.hidden) {
		self.closeFriendLabel.frame = CGRectMake(x, y, kContactBadgeSide, kContactBadgeSide);
		x += kContactBadgeSide + kContactBadgeGap;
	}
	if (!self.premiumView.hidden) {
		self.premiumView.frame = CGRectMake(x, y, kContactBadgeSide, kContactBadgeSide);
		x += kContactBadgeSide + kContactBadgeGap;
	}
	if (!self.verifiedLabel.hidden)
		self.verifiedLabel.frame = CGRectMake(x, y, kContactBadgeSide, kContactBadgeSide);
}

- (void)layoutSubviews {
	[super layoutSubviews];

	if (self.selectedBackgroundView) {
		CGRect selectedFrame = self.selectedBackgroundView.frame;
		selectedFrame.origin.y = -1;
		selectedFrame.size.height = self.frame.size.height + 1;
		self.selectedBackgroundView.frame = selectedFrame;
	}

	CGSize viewSize = self.contentView.frame.size;
	self.avatarView.frame = CGRectMake(kContactAvatarLeft, kContactAvatarTop,
		kContactAvatar, kContactAvatar);

	CGFloat width = viewSize.width - kContactTextLeft - 5;
	CGFloat titleHeight = self.titleLabel.font.lineHeight;
	CGFloat subtitleHeight = self.subtitleLabel.font.lineHeight;
	CGFloat titleWidth = MAX(20.0f, width - [self badgeWidth]);

	CGFloat titleY = self.subtitleLabel.text.length == 0
		? (CGFloat)(int)((viewSize.height - titleHeight) / 2) - 1
		: (CGFloat)(int)((viewSize.height - titleHeight - subtitleHeight - 1) / 2);

	CGFloat firstLimit = viewSize.width - kContactTextLeft - 5 - 14;
	CGFloat firstWidth = MIN(titleWidth, firstLimit);
	if (!self.secondTitleLabel.hidden) {
		firstWidth = MIN([self measuredTitleWidthForHeight:titleHeight], firstLimit);
	}
	self.titleLabel.frame = CGRectMake(kContactTextLeft, titleY, firstWidth, titleHeight);

	CGFloat badgeX = kContactTextLeft + firstWidth + kContactBadgeGap;
	if (!self.secondTitleLabel.hidden) {
		CGFloat secondX = kContactTextLeft + firstWidth + 4;
		CGFloat secondWidth = MAX(0.0f, viewSize.width - 5 - [self badgeWidth] - secondX);
		self.secondTitleLabel.frame = CGRectMake(secondX, titleY, secondWidth, titleHeight);
		badgeX = secondX + MIN([self measuredSecondTitleWidthForHeight:titleHeight], secondWidth) +
			kContactBadgeGap;
	} else {
		badgeX = kContactTextLeft +
			MIN([self fittedTitleWidthForLimit:titleWidth height:titleHeight], titleWidth) +
			kContactBadgeGap;
		self.secondTitleLabel.frame = CGRectZero;
	}
	[self layoutBadgesAfterX:badgeX titleY:titleY titleHeight:titleHeight];

	if (self.subtitleLabel.text.length == 0) {
		self.subtitleLabel.frame = CGRectZero;
		return;
	}
	self.subtitleLabel.frame = CGRectMake(kContactTextLeft + 1,
		titleY + titleHeight + TGContactsRetinaPixel(), width, subtitleHeight);
}

@end
