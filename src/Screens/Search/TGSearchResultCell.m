#import "TGSearchResultCell.h"
#import "TGEmoji.h"
#import "TGSearchRowMetrics.h"
#import "TGSearchResultItem.h"
#import "TGTheme.h"
#import "TGIcons.h"

static const CGFloat kSearchAvatarLeft = 5.0f;
static const CGFloat kSearchAvatarTop = 5.0f;
static const CGFloat kSearchTextLeft = 54.0f;
static const CGFloat kSearchTextRight = 5.0f;

@implementation TGSearchResultCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self){
		UIImage *cellImage = [UIImage imageNamed:@"Cell102.png"];
		UIImage *selectedCellImage = [UIImage imageNamed:@"CellHighlighted102.png"];
		if (cellImage)
			self.backgroundView = [[UIImageView alloc] initWithImage:cellImage];
		if (selectedCellImage)
			self.selectedBackgroundView = [[UIImageView alloc] initWithImage:selectedCellImage];

		_titleLabel = [[TGEmojiLabel alloc] init];
		_titleLabel.backgroundColor = [UIColor clearColor];
		_titleLabel.font = [UIFont systemFontOfSize:19];
		_titleLabel.textColor = [[TGTheme shared] primaryTextColour];
		_titleLabel.highlightedTextColor = [UIColor whiteColor];
		[self.contentView addSubview:_titleLabel];

		_titleLabelSecond = [[TGEmojiLabel alloc] init];
		_titleLabelSecond.backgroundColor = [UIColor clearColor];
		_titleLabelSecond.font = [UIFont boldSystemFontOfSize:19];
		_titleLabelSecond.textColor = _titleLabel.textColor;
		_titleLabelSecond.highlightedTextColor = [UIColor whiteColor];
		_titleLabelSecond.hidden = YES;
		[self.contentView addSubview:_titleLabelSecond];

		_subtitleLabel = [[TGEmojiLabel alloc] init];
		_subtitleLabel.backgroundColor = [UIColor clearColor];
		_subtitleLabel.font = [UIFont systemFontOfSize:13];
		_subtitleLabel.textColor = [UIColor colorWithRed:0x80 / 255.0f green:0x80 / 255.0f blue:0x80 / 255.0f alpha:1.0f];
		_subtitleLabel.highlightedTextColor = [UIColor whiteColor];
		[self.contentView addSubview:_subtitleLabel];

		_dateLabel = [[UILabel alloc] init];
		_dateLabel.backgroundColor = [UIColor clearColor];
		_dateLabel.font = [UIFont systemFontOfSize:13];
		_dateLabel.textAlignment = NSTextAlignmentRight;
		_dateLabel.textColor = [UIColor colorWithRed:0x33 / 255.0f green:0x7a / 255.0f
												 blue:0xcc / 255.0f alpha:1.0f];
		_dateLabel.highlightedTextColor = [UIColor whiteColor];
		[self.contentView addSubview:_dateLabel];

		_avatarView = [[UIImageView alloc] initWithFrame:
				CGRectMake(kSearchAvatarLeft, kSearchAvatarTop, kSearchAvatar, kSearchAvatar)];
		_avatarView.layer.cornerRadius = 4;
		_avatarView.clipsToBounds = YES;
		[self.contentView addSubview:_avatarView];
	}
	return self;
}

- (void)setTitleFirst:(NSString *)first second:(NSString *)second {
	NSString *firstText = first ?: @"";
	NSString *secondText = second ?: @"";

	if (!secondText.length){
		_titleLabel.text = firstText;
		_titleLabel.font = [UIFont boldSystemFontOfSize:19];
		_titleLabelSecond.text = nil;
		_titleLabelSecond.hidden = YES;
		return;
	}

	_titleLabel.text = firstText;
	_titleLabel.font = [UIFont systemFontOfSize:19];
	_titleLabelSecond.text = secondText;
	_titleLabelSecond.font = [UIFont boldSystemFontOfSize:19];
	_titleLabelSecond.hidden = NO;
}

- (void)applyItem:(TGSearchResultItem *)item avatar:(UIImage *)avatar {
	[self setTitleFirst:item.titleFirst second:item.titleSecond];
	_subtitleLabel.text = item.subtitleText;
	_dateLabel.text = item.dateText;
	_avatarView.image = avatar;
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	if (self.selectedBackgroundView){
		CGRect selectedFrame = self.selectedBackgroundView.frame;
		selectedFrame.origin.y = -1;
		selectedFrame.size.height = self.frame.size.height + 1;
		self.selectedBackgroundView.frame = selectedFrame;
	}

	CGSize viewSize = self.contentView.frame.size;
	_avatarView.frame = CGRectMake(kSearchAvatarLeft, kSearchAvatarTop,
								   kSearchAvatar, kSearchAvatar);

	CGFloat textWidth = viewSize.width - kSearchTextLeft - kSearchTextRight;
	CGFloat dateWidth = 0;
	if (_dateLabel.text.length){
		CGSize dateSize = [_dateLabel.text sizeWithFont:_dateLabel.font];
		dateWidth = (CGFloat)(int)dateSize.width + 4;
		textWidth -= dateWidth + 4;
	}
	_dateLabel.hidden = dateWidth == 0;

	CGFloat titleHeight = (CGFloat)(int)(_titleLabel.font.lineHeight);
	CGFloat subtitleHeight = (CGFloat)(int)(_subtitleLabel.font.lineHeight);
	BOOL hasSubtitle = _subtitleLabel.text.length != 0;

	CGFloat y;
	if (!hasSubtitle){
		y = (CGFloat)(int)((viewSize.height - titleHeight) / 2) - 1;
	} else {
		y = (CGFloat)(int)((viewSize.height - titleHeight - subtitleHeight - 1) / 2);
		_subtitleLabel.frame = CGRectMake(kSearchTextLeft + 1, y + titleHeight,
				viewSize.width - kSearchTextLeft - kSearchTextRight, subtitleHeight);
	}
	_subtitleLabel.hidden = !hasSubtitle;
	if (_titleLabelSecond.hidden){
		_titleLabel.frame = CGRectMake(kSearchTextLeft, y, textWidth, titleHeight);
	} else {
		CGFloat firstWidth = (CGFloat)(int)[_titleLabel.text sizeWithFont:_titleLabel.font].width;
		if (firstWidth > textWidth)
			firstWidth = textWidth;
		_titleLabel.frame = CGRectMake(kSearchTextLeft, y, firstWidth, titleHeight);
		CGFloat secondX = kSearchTextLeft + firstWidth + 5;
		CGFloat secondWidth = kSearchTextLeft + textWidth - secondX;
		if (secondWidth < 0)
			secondWidth = 0;
		_titleLabelSecond.frame = CGRectMake(secondX, y, secondWidth, titleHeight);
	}
	if (dateWidth > 0){
		_dateLabel.frame = CGRectMake(viewSize.width - kSearchTextRight - dateWidth,
									  y + 1, dateWidth, titleHeight);
	}
}

@end
