#import "TGInstantViewCellBase.h"
#import "TGInstantViewItem.h"
#import "TGEmoji.h"
#import "TGTheme.h"
#import "TGHexColour.h"

@implementation TGInstantViewCellBase

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	_body = [[TGEmojiLabel alloc] init];
	_body.numberOfLines = 0;
	_body.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_body];

	_bar = [[UIView alloc] init];
	_bar.hidden = YES;
	[self.contentView addSubview:_bar];

	_picture = [[UIImageView alloc] init];
	_picture.contentMode = UIViewContentModeScaleAspectFill;
	_picture.clipsToBounds = YES;
	[self.contentView addSubview:_picture];

	_caption = [[UILabel alloc] init];
	_caption.numberOfLines = 0;
	_caption.font = [UIFont systemFontOfSize:13];
	_caption.textColor = TGColourFromHex(0x697487);
	[self.contentView addSubview:_caption];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	_body.hidden = YES;
	_body.richLayout = nil;
	_bar.hidden = YES;
	_picture.hidden = YES;
	_picture.image = nil;
	_caption.hidden = YES;
	self.lastTouchKnown = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	if (touch) {
		self.lastTouchInCell = [touch locationInView:self.contentView];
		self.lastTouchKnown = YES;
	}
	[super touchesBegan:touches withEvent:event];
}

- (void)applyItem:(TGInstantViewItem *)item image:(UIImage *)image {
	self.backgroundColor = item.cellBackgroundColour;

	_body.hidden = item.bodyHidden;
	_body.richLayout = item.bodyHidden ? nil : item.bodyRichLayout;
	if (!item.bodyHidden) {
		_body.font = item.bodyFont;
		_body.textColor = item.bodyTextColour;
		_body.backgroundColor = item.bodyBackgroundColour;
		_body.text = item.bodyText;
		_body.frame = item.bodyFrame;
	}

	_bar.hidden = item.barHidden;
	if (!item.barHidden) {
		_bar.backgroundColor = item.barColour;
		_bar.frame = item.barFrame;
	}

	_picture.hidden = (item.kind != TGInstantViewRowKindMedia);
	if (item.kind == TGInstantViewRowKindMedia) {
		_picture.image = image;
		_picture.backgroundColor = image ? [UIColor clearColor] : item.pictureEmptyColour;
		_picture.frame = item.pictureFrame;
	}

	_caption.hidden = item.captionHidden;
	if (!item.captionHidden) {
		_caption.text = item.captionText;
		_caption.frame = item.captionFrame;
	}
}

@end
