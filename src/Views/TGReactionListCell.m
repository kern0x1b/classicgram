#import "TGReactionListCell.h"
#import "TGReactionPickerViewInternal.h"
#import "TGTheme.h"

@implementation TGReactionListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (self == nil)
		return nil;

	UIImage *plate = TGReactionStretch(@"Cell102.png", 1);
	UIImage *platePressed = TGReactionStretch(@"CellHighlighted102.png", 1);
	if (plate != nil)
		self.backgroundView = [[UIImageView alloc] initWithImage:plate];
	if (platePressed != nil)
		self.selectedBackgroundView = [[UIImageView alloc] initWithImage:platePressed];
	self.backgroundColor = [[TGTheme shared] listBackgroundColour];

	_avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, kListAvatarSide, kListAvatarSide)];
	_avatarView.contentMode = UIViewContentModeScaleAspectFill;
	_avatarView.clipsToBounds = YES;
	_avatarView.layer.cornerRadius = 4.0f;
	[self.contentView addSubview:_avatarView];

	_nameLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
	_nameLabel.backgroundColor = [UIColor clearColor];
	_nameLabel.font = [UIFont systemFontOfSize:19];
	_nameLabel.textColor = [UIColor blackColor];
	_nameLabel.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:_nameLabel];

	_emojiLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
	_emojiLabel.backgroundColor = [UIColor clearColor];
	_emojiLabel.font = TGEmojiFontOfSize(20);
	_emojiLabel.textAlignment = NSTextAlignmentRight;
	[self.contentView addSubview:_emojiLabel];

	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGSize size = self.contentView.bounds.size;
	_avatarView.frame = CGRectMake(5, floorf((size.height - kListAvatarSide) / 2),
		kListAvatarSide, kListAvatarSide);
	_emojiLabel.frame = CGRectMake(size.width - 40, 0, 30, size.height);

	CGFloat nameWidth = MAX(10.0f, size.width - 54 - 46);
	CGFloat nameHeight = _nameLabel.font.lineHeight;
	_nameLabel.frame = CGRectMake(54, floorf((size.height - nameHeight) / 2) - 1, nameWidth, nameHeight);
}

@end
