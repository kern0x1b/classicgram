#import "TGBareEmojiBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"

static const CGFloat kBareEmojiGlyphFontSize = 94.0f;

@interface TGBareEmojiBubbleCell ()

@property (nonatomic, strong, readwrite) TGEmojiLabel *glyph;

@end

@implementation TGBareEmojiBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.glyph = [[TGEmojiLabel alloc] init];
	self.glyph.numberOfLines = 1;
	self.glyph.textAlignment = NSTextAlignmentCenter;
	self.glyph.backgroundColor = [UIColor clearColor];
	self.glyph.font = [UIFont systemFontOfSize:kBareEmojiGlyphFontSize];
	[self.bubble addSubview:self.glyph];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.glyph.richLayout = nil;
	self.glyph.text = nil;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	self.glyph.hidden = !(layout.parts & TGMessageLayoutPartBody);
	if (layout.parts & TGMessageLayoutPartBody) {
		self.glyph.frame = layout.bubble.body;
		self.glyph.text = item.bodyText;
	}
}

@end
