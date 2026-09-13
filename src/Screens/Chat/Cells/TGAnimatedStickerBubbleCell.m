#import "TGAnimatedStickerBubbleCell.h"
#import "TGPreferenceFlags.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGLocalization.h"

@interface TGAnimatedStickerBubbleCell ()

@property (nonatomic, strong, readwrite) TGLottieView *lottie;
@property (nonatomic, copy) NSString *loadedLottiePath;

@end

@implementation TGAnimatedStickerBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.lottie = [[TGLottieView alloc] init];
	[self.bubble addSubview:self.lottie];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	[self.lottie stop];
	self.loadedLottiePath = nil;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	self.lottie.hidden = !(layout.parts & TGMessageLayoutPartLottie);
	if (!(layout.parts & TGMessageLayoutPartLottie)) {
		[self.lottie stop];
		self.loadedLottiePath = nil;
		return;
	}

	self.lottie.frame = layout.bubble.lottie;
	if (![self.loadedLottiePath isEqualToString:item.lottiePath]) {
		[self.lottie stop];
		if ([self.lottie loadTGSFile:item.lottiePath])
			self.loadedLottiePath = item.lottiePath;
		else
			self.loadedLottiePath = nil;
	}
	self.lottie.loopEnabled = [TGPreferenceFlags stickersLoopAnimatedEnabled];
	[self.lottie play];

	NSString *emoji = item.message.text;
	NSString *stickerDescription = emoji.length
		? [NSString stringWithFormat:@"%@, %@", TGL(@"Message.Sticker", @"Sticker"), emoji]
		: TGL(@"Message.Sticker", @"Sticker");

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		stickerDescription,
		item.stampText ?: @"",
	]];
}

@end
