#import "TGReactionChipView.h"
#import "TGReactionPickerViewInternal.h"
#import "TGTheme.h"

@implementation TGReactionChipView

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		_plateView = [[UIImageView alloc] initWithFrame:CGRectZero];
		_plateView.layer.cornerRadius = kChipRadius;
		_plateView.layer.masksToBounds = YES;
		[self addSubview:_plateView];

		_emojiLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
		_emojiLabel.backgroundColor = [UIColor clearColor];
		_emojiLabel.font = TGEmojiFontOfSize(kChipEmojiFontSize);
		_emojiLabel.textAlignment = NSTextAlignmentCenter;
		[self addSubview:_emojiLabel];

		_countLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_countLabel.backgroundColor = [UIColor clearColor];
		_countLabel.font = [UIFont boldSystemFontOfSize:kChipCountFontSize];
		[self addSubview:_countLabel];

		_tagLabelView = [[UILabel alloc] initWithFrame:CGRectZero];
		_tagLabelView.backgroundColor = [UIColor clearColor];
		_tagLabelView.font = [UIFont systemFontOfSize:kChipCountFontSize];
		_tagLabelView.hidden = YES;
		[self addSubview:_tagLabelView];

		_iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
		_iconView.contentMode = UIViewContentModeScaleAspectFit;
		_iconView.hidden = YES;
		[self addSubview:_iconView];

		self.exclusiveTouch = YES;
	}
	return self;
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	self.alpha = highlighted ? 0.6f : 1.0f;
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
	_plateView.frame = CGRectMake(0, 0, size.width, size.height);

	_emojiLabel.frame = CGRectMake(kChipPadding, 0, kChipGlyphSlot, size.height);
	_iconView.frame = CGRectMake(kChipPadding + floorf((kChipGlyphSlot - kChipGlyphSide) / 2),
		floorf((size.height - kChipGlyphSide) / 2),
		kChipGlyphSide, kChipGlyphSide);

	CGFloat countX = kChipPadding + kChipGlyphSlot + kChipCountGap;
	if (_tagLabel.length) {
		CGFloat countWidth = ceilf([_countLabel.text sizeWithFont:_countLabel.font].width);
		_countLabel.frame = CGRectMake(countX, 0, countWidth, size.height);
		CGFloat labelX = countX + countWidth + kChipCountGap;
		_tagLabelView.frame = CGRectMake(labelX, 0, MAX(0.0f, size.width - labelX - kChipPadding), size.height);
	} else {
		_countLabel.frame = CGRectMake(countX, 0, MAX(0.0f, size.width - countX - kChipPadding), size.height);
		_tagLabelView.frame = CGRectZero;
	}
}

@end
