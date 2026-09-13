#import "TGTextBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"

extern UIColor *TGMessageBodyColour(void);
extern CGFloat TGMessageBaseFontSize(void);

@interface TGTextBubbleCell ()

@property (nonatomic, strong, readwrite) TGEmojiLabel *body;

@end

@implementation TGTextBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.body = [[TGEmojiLabel alloc] init];
	self.body.numberOfLines = 0;
	self.body.lineBreakMode = NSLineBreakByWordWrapping;
	self.body.backgroundColor = [UIColor clearColor];
	self.body.textColor = TGMessageBodyColour();
	[self.bubble addSubview:self.body];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.body.richLayout = nil;
}

- (TGEmojiLabel *)tg_richTextLabel {
	return self.body;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	self.body.hidden = !(layout.parts & TGMessageLayoutPartBody);
	if (layout.parts & TGMessageLayoutPartBody) {
		self.body.frame = layout.bubble.body;
		self.body.font = [UIFont systemFontOfSize:TGMessageBaseFontSize()];
		self.body.text = item.bodyText;
		self.body.richLayout = item.bodyRichLayout;
	}

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		item.bodyText ?: @"",
		item.stampText ?: @"",
	]];
}

@end
