#import "TGStickerBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGMessage.h"
#import "TGLocalization.h"

@interface TGStickerBubbleCell ()

@property (nonatomic, strong, readwrite) UIImageView *picture;

@end

@implementation TGStickerBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.picture = [[UIImageView alloc] init];
	self.picture.contentMode = UIViewContentModeScaleAspectFit;
	[self.bubble addSubview:self.picture];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.picture.image = nil;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	self.picture.hidden = !(layout.parts & TGMessageLayoutPartPicture);
	if (layout.parts & TGMessageLayoutPartPicture)
		self.picture.frame = layout.bubble.picture;

	NSString *emoji = item.message.text;
	NSString *stickerDescription = emoji.length
		? [NSString stringWithFormat:TGL(@"Message.StickerText", @"Sticker %@"), emoji]
		: TGL(@"Message.Sticker", @"Sticker");

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		stickerDescription,
		item.stampText ?: @"",
	]];
}

@end
