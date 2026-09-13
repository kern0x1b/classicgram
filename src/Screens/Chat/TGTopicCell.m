#import "TGTopicCell.h"
#import "TGTopicsViewControllerInternal.h"
#import "TGTheme.h"
#import "TGDateLabel.h"
#import "UIView+SafeTint.h"
#import "TGChatListHelpers.h"

@implementation TGTopicCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.avatar = [[UIImageView alloc] initWithFrame:
			CGRectMake(kTopicAvatarLeft, 8, kTopicAvatar, kTopicAvatar)];
	self.avatar.backgroundColor = [UIColor clearColor];
	self.avatar.contentMode = UIViewContentModeScaleAspectFill;
	[self.contentView addSubview:self.avatar];

	self.titleLabel = [[TGEmojiLabel alloc] init];
	self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
	self.titleLabel.textColor = [[TGTheme shared] primaryTextColour];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.titleLabel];

	self.previewLabel = [[TGEmojiLabel alloc] init];
	self.previewLabel.font = [UIFont systemFontOfSize:14];
	self.previewLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.previewLabel.backgroundColor = [UIColor clearColor];
	self.previewLabel.numberOfLines = 2;
	self.previewLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.previewLabel];

	self.dateLabel = [[TGDateLabel alloc] init];
	self.dateLabel.amWidth = 19;
	self.dateLabel.pmWidth = 19;
	self.dateLabel.dstOffset = 2;
	self.dateLabel.dateFont = [UIFont systemFontOfSize:13];
	self.dateLabel.dateTextFont = [UIFont boldSystemFontOfSize:13];
	self.dateLabel.dateLabelFont = [UIFont systemFontOfSize:11];
	self.dateLabel.font = [UIFont systemFontOfSize:13];
	self.dateLabel.textColor = [UIColor colorWithRed:0x33 / 255.0f green:0x7a / 255.0f blue:0xcc / 255.0f alpha:1.0f];
	self.dateLabel.highlightedTextColor = [UIColor whiteColor];
	self.dateLabel.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:self.dateLabel];

	self.badgeBackground = [[UIImageView alloc] initWithImage:TGTopicBadgeImage()
											 highlightedImage:TGTopicBadgeHighlightedImage()];
	self.badgeBackground.hidden = YES;
	[self.contentView addSubview:self.badgeBackground];

	self.badge = [[UILabel alloc] init];
	self.badge.font = [UIFont boldSystemFontOfSize:14];
	self.badge.textColor = [UIColor whiteColor];
	self.badge.highlightedTextColor = [UIColor colorWithRed:0x23 / 255.0f green:0x71 / 255.0f blue:0xc2 / 255.0f alpha:1.0f];
	self.badge.backgroundColor = [UIColor clearColor];
	self.badge.shadowColor = [UIColor colorWithRed:0x80 / 255.0f green:0x91 / 255.0f blue:0xa6 / 255.0f alpha:1.0f];
	self.badge.shadowOffset = CGSizeMake(0, -1);
	self.badge.textAlignment = NSTextAlignmentCenter;
	self.badge.hidden = YES;
	[self.contentView addSubview:self.badge];

	self.arrow = [[UIImageView alloc] initWithImage:TGLocalizedDirectionalImage([UIImage imageNamed:@"DialogListArrow.png"])
								   highlightedImage:TGLocalizedDirectionalImage([UIImage imageNamed:@"DialogListArrow_Highlighted.png"])];
	[self.contentView addSubview:self.arrow];

	self.pinIcon = [[UIImageView alloc] initWithImage:TGDialogListPinBadgeImage(NO)
									  highlightedImage:TGDialogListPinBadgeImage(YES)];
	self.pinIcon.hidden = YES;
	[self.contentView addSubview:self.pinIcon];

	self.muteIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DialogList_Muted.png"]];
	self.muteIcon.hidden = YES;
	[self.contentView addSubview:self.muteIcon];

	UIImage *plate = [[UIImage imageNamed:@"DialogListCell.png"]
		stretchableImageWithLeftCapWidth:1
							topCapHeight:0];
	UIImage *platePressed = [[UIImage imageNamed:@"DialogListCellHighlighted.png"]
		stretchableImageWithLeftCapWidth:1
							topCapHeight:0];
	self.backgroundView = [[UIImageView alloc] initWithImage:plate];
	self.selectedBackgroundView = [[UIImageView alloc] initWithImage:platePressed];

	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleBlue;
	return self;
}

- (void)applyBadgeShadowForHighlight:(BOOL)highlighted {
	self.badge.shadowColor = highlighted
		? [UIColor clearColor]
		: [UIColor colorWithRed:0x80 / 255.0f green:0x91 / 255.0f blue:0xa6 / 255.0f alpha:1.0f];
	self.badgeBackground.highlighted = highlighted;
	self.pinIcon.highlighted = highlighted;
}

- (void)adjustSelectedBackgroundFrame {
	UIView *selected = self.selectedBackgroundView;
	if (selected)
		selected.frame = CGRectMake(0, -1, self.bounds.size.width, self.bounds.size.height + 1);
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
	[super setHighlighted:highlighted animated:animated];
	[self applyBadgeShadowForHighlight:highlighted || self.selected];
	[self adjustSelectedBackgroundFrame];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	[self applyBadgeShadowForHighlight:selected || self.highlighted];
	[self adjustSelectedBackgroundFrame];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	[self adjustSelectedBackgroundFrame];

	CGFloat w = self.contentView.bounds.size.width;
	CGFloat left = kTopicTextLeft;
	CGFloat rightPadding = 16;

	self.avatar.frame = CGRectMake(kTopicAvatarLeft, 8, kTopicAvatar, kTopicAvatar);

	CGFloat countWidth = (int)[self.badge.text sizeWithFont:self.badge.font].width;
	CGFloat badgeWidth = MAX(27, countWidth + 10);
	CGRect badgeFrame = CGRectMake(w - 28 - badgeWidth, 29, badgeWidth, 21);
	self.badgeBackground.frame = badgeFrame;
	self.badge.frame = badgeFrame;
	if (!self.badge.hidden)
		rightPadding += badgeWidth + 7;

	if (!self.pinIcon.hidden) {
		self.pinIcon.frame = CGRectMake(w - 28 - kPinBadgeWidth, 29, kPinBadgeWidth, kPinBadgeHeight);
		rightPadding += kPinBadgeWidth + 7;
	}

	CGFloat dateWidth = (int)[self.dateLabel measureTextSize].width;
	CGFloat dateX = w - dateWidth - 9;
	self.dateLabel.frame = CGRectMake(dateX, 9, 75, 15);

	BOOL muted = (!self.muteIcon.hidden && self.muteIcon.image != nil);

	CGFloat titleWidth = (int)(dateX - 4 - left - 18 - (muted ? 12 : 0));
	titleWidth = MIN(titleWidth, [self.titleLabel.text sizeWithFont:self.titleLabel.font].width);
	if (titleWidth < 0)
		titleWidth = 0;
	self.titleLabel.frame = CGRectMake(left, 6, titleWidth, 20);

	if (muted) {
		CGSize muteSize = self.muteIcon.image.size;
		self.muteIcon.frame = CGRectMake(left + titleWidth + 3, 12,
			muteSize.width, muteSize.height);
	}

	self.previewLabel.frame = CGRectMake(left, 29, w - left - 10 - rightPadding, 40);

	self.arrow.frame = CGRectMake(w - self.arrow.image.size.width - 6, 33,
		self.arrow.image.size.width, self.arrow.image.size.height);
}

@end
