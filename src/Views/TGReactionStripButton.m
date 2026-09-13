#import "TGReactionStripButton.h"
#import "TGReactionPickerViewInternal.h"

@implementation TGReactionStripButton

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		_leftView = [[UIImageView alloc] init];
		[self addSubview:_leftView];
		_centerView = [[UIImageView alloc] init];
		[self addSubview:_centerView];
		_rightView = [[UIImageView alloc] init];
		[self addSubview:_rightView];

		_emojiLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
		_emojiLabel.backgroundColor = [UIColor clearColor];
		_emojiLabel.textAlignment = NSTextAlignmentCenter;
		_emojiLabel.font = TGEmojiFontOfSize(kStripEmojiFontSize);
		_emojiLabel.textColor = [UIColor whiteColor];
		[self addSubview:_emojiLabel];

		_iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
		_iconView.contentMode = UIViewContentModeScaleAspectFit;
		_iconView.hidden = YES;
		[self addSubview:_iconView];

		_tagLabelView = [[UILabel alloc] initWithFrame:CGRectZero];
		_tagLabelView.backgroundColor = [UIColor clearColor];
		_tagLabelView.font = [UIFont systemFontOfSize:8];
		_tagLabelView.textColor = [UIColor whiteColor];
		_tagLabelView.textAlignment = NSTextAlignmentCenter;
		_tagLabelView.lineBreakMode = NSLineBreakByTruncatingTail;
		_tagLabelView.hidden = YES;
		[self addSubview:_tagLabelView];

		self.exclusiveTouch = YES;
		self.adjustsImageWhenHighlighted = NO;
		self.adjustsImageWhenDisabled = NO;
	}
	return self;
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	_leftView.highlighted = highlighted;
	_centerView.highlighted = highlighted;
	_rightView.highlighted = highlighted;
}

- (void)setTagLabel:(NSString *)tagLabel {
	_tagLabel = [tagLabel copy];
	_tagLabelView.text = _tagLabel;
	_tagLabelView.hidden = _tagLabel.length == 0;
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGSize size = self.bounds.size;
	CGFloat leftWidth = _leftView.image.size.width;
	CGFloat rightWidth = _rightView.image.size.width;

	_leftView.frame = CGRectMake(0, 0, leftWidth, size.height);
	_rightView.frame = CGRectMake(size.width - rightWidth, 0, rightWidth, size.height);
	_centerView.frame = CGRectMake(leftWidth, 0, MAX(0.0f, size.width - leftWidth - rightWidth), size.height);

	CGFloat tagLabelHeight = _tagLabel.length ? 11.0f : 0.0f;
	CGFloat glyphHeight = size.height - tagLabelHeight;

	_emojiLabel.frame = CGRectMake(0, 0, size.width, glyphHeight);
	CGFloat iconSide = MIN(kStripEmojiFontSize, glyphHeight - 14.0f);
	_iconView.frame = CGRectMake(floorf((size.width - iconSide) / 2),
		floorf((glyphHeight - iconSide) / 2), iconSide, iconSide);
	_tagLabelView.frame = CGRectMake(1, size.height - tagLabelHeight, size.width - 2, tagLabelHeight);
	[self bringSubviewToFront:_emojiLabel];
	[self bringSubviewToFront:_iconView];
	[self bringSubviewToFront:_tagLabelView];
}

@end
