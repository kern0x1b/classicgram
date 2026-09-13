#import "TGSearchMessageCell.h"
#import "TGEmoji.h"
#import "TGSearchRowMetrics.h"
#import "TGSearchResultItem.h"
#import "TGTheme.h"
#import "TGIcons.h"

static const CGFloat kSearchMessageTextLeft = 73.0f;

@implementation TGSearchMessageCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		UIImage *plate = [[UIImage imageNamed:@"DialogListCell.png"]
			stretchableImageWithLeftCapWidth:1
								topCapHeight:0];
		UIImage *plateHighlighted = [[UIImage imageNamed:@"DialogListCellHighlighted.png"]
			stretchableImageWithLeftCapWidth:1
								topCapHeight:0];
		if (plate)
			self.backgroundView = [[UIImageView alloc] initWithImage:plate];
		if (plateHighlighted)
			self.selectedBackgroundView = [[UIImageView alloc] initWithImage:plateHighlighted];

		_titleLabel = [[TGEmojiLabel alloc] init];
		_titleLabel.backgroundColor = [UIColor clearColor];
		_titleLabel.font = [UIFont boldSystemFontOfSize:16];
		_titleLabel.textColor = [[TGTheme shared] primaryTextColour];
		_titleLabel.highlightedTextColor = [UIColor whiteColor];
		[self.contentView addSubview:_titleLabel];

		_authorLabel = [[TGEmojiLabel alloc] init];
		_authorLabel.backgroundColor = [UIColor clearColor];
		_authorLabel.font = [UIFont boldSystemFontOfSize:14];
		UIColor *authorBlue = [UIColor colorWithRed:0x34 / 255.0f green:0x5f / 255.0f
											   blue:0x8f / 255.0f
											  alpha:1.0f];
		_authorLabel.textColor = authorBlue;
		_authorLabel.highlightedTextColor = [UIColor whiteColor];
		_authorLabel.hidden = YES;
		[self.contentView addSubview:_authorLabel];

		_textLabel_ = [[TGEmojiLabel alloc] init];
		_textLabel_.backgroundColor = [UIColor clearColor];
		_textLabel_.font = [UIFont systemFontOfSize:14];
		_textLabel_.numberOfLines = 2;
		_textLabel_.textColor = [[TGTheme shared] secondaryTextColour];
		_textLabel_.highlightedTextColor = [UIColor whiteColor];
		[self.contentView addSubview:_textLabel_];

		_dateLabel = [[UILabel alloc] init];
		_dateLabel.backgroundColor = [UIColor clearColor];
		_dateLabel.font = [UIFont systemFontOfSize:13];
		_dateLabel.textAlignment = NSTextAlignmentRight;
		_dateLabel.textColor = [UIColor colorWithRed:0x33 / 255.0f green:0x7a / 255.0f
												blue:0xcc / 255.0f
											   alpha:1.0f];
		_dateLabel.highlightedTextColor = [UIColor whiteColor];
		[self.contentView addSubview:_dateLabel];

		_avatarView = [[UIImageView alloc] initWithFrame:
				CGRectMake(8, 8, kSearchMessageAvatar, kSearchMessageAvatar)];
		_avatarView.layer.cornerRadius = 5;
		_avatarView.clipsToBounds = YES;
		[self.contentView addSubview:_avatarView];
	}
	return self;
}

- (void)applyItem:(TGSearchResultItem *)item avatar:(UIImage *)avatar {
	_titleLabel.text = item.titleFirst;
	_authorLabel.text = item.authorText;
	_textLabel_.text = item.subtitleText;
	_dateLabel.text = item.dateText;
	_avatarView.image = avatar;
	[self setNeedsLayout];
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
	_avatarView.frame = CGRectMake(8, 8, kSearchMessageAvatar, kSearchMessageAvatar);

	CGFloat dateWidth = 0;
	if (_dateLabel.text.length) {
		CGSize dateSize = [_dateLabel.text sizeWithFont:_dateLabel.font];
		dateWidth = (CGFloat)(int)dateSize.width;
	}
	_dateLabel.hidden = dateWidth == 0;
	CGFloat dateX = viewSize.width - dateWidth - 9;
	if (dateWidth > 0)
		_dateLabel.frame = CGRectMake(dateX, 9, dateWidth, 15);

	CGFloat titleWidth = viewSize.width - kSearchMessageTextLeft - 10;
	if (dateWidth > 0)
		titleWidth = (CGFloat)(int)(dateX - 4 - kSearchMessageTextLeft - 18);
	if (titleWidth < 0)
		titleWidth = 0;
	_titleLabel.frame = CGRectMake(kSearchMessageTextLeft, 6, titleWidth, 20);

	CGFloat textWidth = viewSize.width - kSearchMessageTextLeft - 10;
	if (textWidth < 0)
		textWidth = 0;
	CGRect messageFrame = CGRectMake(kSearchMessageTextLeft, 29, textWidth, 40);

	BOOL hasAuthor = _authorLabel.text.length != 0;
	_authorLabel.hidden = !hasAuthor;
	if (hasAuthor) {
		_authorLabel.frame = CGRectMake(kSearchMessageTextLeft, 29, textWidth, 20);
		messageFrame.origin.y += 9;
		messageFrame.size.height -= 12;
		CGSize fitted = [_textLabel_.text sizeWithFont:_textLabel_.font
									 constrainedToSize:messageFrame.size
										 lineBreakMode:NSLineBreakByTruncatingTail];
		if (fitted.height < 20)
			messageFrame.origin.y += 9;
	}
	_textLabel_.frame = messageFrame;
}

@end
