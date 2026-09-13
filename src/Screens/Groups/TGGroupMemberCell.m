#import "TGGroupMemberCell.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGAlertView.h"
#import "TGImageDecode.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGGroupMembersViewControllerInternal.h"
#import "TGGroupMembersItem.h"
#import "TGHexColour.h"

@implementation TGGroupMemberCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	UIImage *plate = TGMembersStretch(@"Cell102.png", 1);
	UIImage *platePressed = TGMembersStretch(@"CellHighlighted102.png", 1);
	if (plate)
		self.backgroundView = [[UIImageView alloc] initWithImage:plate];
	if (platePressed)
		self.selectedBackgroundView = [[UIImageView alloc] initWithImage:platePressed];
	self.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.avatarView = [[UIImageView alloc] initWithFrame:
			CGRectMake(kMemberAvatarLeft, kMemberAvatarTop, kMemberAvatar, kMemberAvatar)];
	self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
	self.avatarView.clipsToBounds = YES;
	self.avatarView.layer.cornerRadius = 4.0f;
	[self.contentView addSubview:self.avatarView];

	UIColor *titleColour = [UIColor blackColor];

	self.titleLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	self.titleLabel.font = [UIFont systemFontOfSize:19];
	self.titleLabel.textColor = titleColour;
	self.titleLabel.highlightedTextColor = [UIColor whiteColor];
	self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.titleLabel];

	self.titleSecondLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
	self.titleSecondLabel.backgroundColor = [UIColor clearColor];
	self.titleSecondLabel.font = [UIFont boldSystemFontOfSize:19];
	self.titleSecondLabel.textColor = titleColour;
	self.titleSecondLabel.highlightedTextColor = [UIColor whiteColor];
	self.titleSecondLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.titleSecondLabel];

	self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.subtitleLabel.backgroundColor = [UIColor clearColor];
	self.subtitleLabel.font = [UIFont systemFontOfSize:13.5f];
	self.subtitleLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.subtitleLabel.highlightedTextColor = [UIColor whiteColor];
	self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.subtitleLabel];

	self.roleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.roleLabel.backgroundColor = [UIColor clearColor];
	self.roleLabel.font = [UIFont systemFontOfSize:13.5f];
	self.roleLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.roleLabel.highlightedTextColor = [UIColor whiteColor];
	self.roleLabel.textAlignment = NSTextAlignmentRight;
	self.roleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.roleLabel];

	return self;
}

- (void)setSubtitleIsOnline:(BOOL)subtitleIsOnline {
	_subtitleIsOnline = subtitleIsOnline;
	self.subtitleLabel.textColor = subtitleIsOnline
		? TGColourFromHex(0x0779d0)
		: [[TGTheme shared] secondaryTextColour];
}

- (void)setName:(NSString *)name {
	NSString *first = name ?: @"";
	NSString *second = nil;
	NSRange space = [first rangeOfString:@" "];
	if (space.location != NSNotFound && space.location + 1 < first.length) {
		second = [first substringFromIndex:space.location + 1];
		first = [first substringToIndex:space.location];
	}
	self.titleLabel.text = first;
	self.titleSecondLabel.text = second;
	[self setNeedsLayout];
}

- (void)applyItem:(TGGroupMembersItem *)item avatar:(UIImage *)avatar {
	[self setName:item.titleText];
	self.subtitleLabel.text = item.subtitleText;
	self.subtitleIsOnline = item.subtitleIsOnline;
	self.roleLabel.text = item.roleText ?: @"";
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
	self.avatarView.frame = CGRectMake(kMemberAvatarLeft, kMemberAvatarTop,
		kMemberAvatar, kMemberAvatar);

	CGFloat fullWidth = viewSize.width - kMemberTextLeft - 5;
	if (fullWidth < 10)
		fullWidth = 10;
	CGFloat titleHeight = self.titleLabel.font.lineHeight;
	CGFloat subtitleHeight = self.subtitleLabel.font.lineHeight;
	BOOL hasSubtitle = self.subtitleLabel.text.length != 0;

	CGFloat titleY = hasSubtitle
		? (CGFloat)(int)((viewSize.height - titleHeight - subtitleHeight - 1) / 2)
		: (CGFloat)(int)((viewSize.height - titleHeight) / 2) - 1;

	CGFloat roleWidth = 0;
	if (self.roleLabel.text.length != 0) {
		roleWidth = [self.roleLabel.text sizeWithFont:self.roleLabel.font].width;
		CGFloat roleCap = fullWidth * 0.5f;
		if (roleWidth > roleCap)
			roleWidth = roleCap;
		self.roleLabel.frame = CGRectMake(viewSize.width - 5 - roleWidth, titleY, roleWidth, titleHeight);
	} else {
		self.roleLabel.frame = CGRectZero;
	}

	CGFloat width = roleWidth > 0 ? fullWidth - roleWidth - 6 : fullWidth;
	if (width < 10)
		width = 10;

	CGFloat firstWidth = width;
	if (self.titleSecondLabel.text.length != 0) {
		firstWidth = [self.titleLabel.text sizeWithFont:self.titleLabel.font].width;
		if (firstWidth > width - 14)
			firstWidth = width - 14;
		CGFloat secondX = kMemberTextLeft + firstWidth + 4;
		CGFloat secondWidth = kMemberTextLeft + width - secondX;
		if (secondWidth < 0)
			secondWidth = 0;
		self.titleSecondLabel.frame = CGRectMake(secondX, titleY, secondWidth, titleHeight);
	} else {
		self.titleSecondLabel.frame = CGRectZero;
	}
	self.titleLabel.frame = CGRectMake(kMemberTextLeft, titleY, firstWidth, titleHeight);

	if (!hasSubtitle) {
		self.subtitleLabel.frame = CGRectZero;
		return;
	}
	self.subtitleLabel.frame = CGRectMake(kMemberTextLeft + 1, titleY + titleHeight + 0.5f,
		width, subtitleHeight);
}

@end
