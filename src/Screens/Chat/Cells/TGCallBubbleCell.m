#import "TGCallBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGEmoji.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGMessage.h"
#import "TGCallContent.h"

extern UIColor *TGMessageBodyColour(void);

@interface TGCallBubbleCell ()

@property (nonatomic, strong, readwrite) UIImageView *glyph;
@property (nonatomic, strong, readwrite) UILabel *title;
@property (nonatomic, strong, readwrite) UILabel *detail;

@end

@implementation TGCallBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.glyph = [[UIImageView alloc] init];
	self.glyph.contentMode = UIViewContentModeCenter;
	self.glyph.hidden = YES;
	[self.bubble addSubview:self.glyph];

	self.title = [[TGEmojiLabel alloc] init];
	self.title.font = [UIFont boldSystemFontOfSize:15];
	self.title.backgroundColor = [UIColor clearColor];
	self.title.hidden = YES;
	[self.bubble addSubview:self.title];

	self.detail = [[TGEmojiLabel alloc] init];
	self.detail.font = [UIFont systemFontOfSize:13];
	self.detail.backgroundColor = [UIColor clearColor];
	self.detail.hidden = YES;
	[self.bubble addSubview:self.detail];

	return self;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	TGMessageLayoutParts parts = layout.parts;
	TGCallContent *callContent = [item.message.content isKindOfClass:[TGCallContent class]]
		? (TGCallContent *)item.message.content
		: nil;
	BOOL missed = callContent.state == TGCallContentStateMissed && !layout.outgoing;

	self.glyph.hidden = !(parts & TGMessageLayoutPartMediaDisc);
	if (!self.glyph.hidden) {
		self.glyph.frame = layout.bubble.disc;
		self.glyph.image = [TGIcons callArrowOutgoing:layout.outgoing missed:missed];
	}

	self.title.hidden = !(parts & TGMessageLayoutPartBody);
	if (!self.title.hidden) {
		self.title.frame = layout.bubble.body;
		self.title.text = item.callTitleText.length ? item.callTitleText : item.bodyText;
		self.title.textColor = TGMessageBodyColour();
	}

	self.detail.hidden = !(parts & TGMessageLayoutPartSubtitle);
	if (!self.detail.hidden) {
		self.detail.frame = layout.bubble.subtitle;
		self.detail.text = item.callDetailText;
		self.detail.textColor = [[TGTheme shared] secondaryTextColour];
	}

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		item.callTitleText.length ? item.callTitleText : (item.bodyText ?: @""),
		item.callDetailText ?: @"",
		item.stampText ?: @"",
	]];
}

@end
