#import "TGAnimatedStickerBubbleCell.h"
#import "TGPreferenceFlags.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGLocalization.h"
#import "TGAnimatedStickerFormat.h"
#import "TGVideoStickerView.h"

@interface TGAnimatedStickerBubbleCell ()

@property (nonatomic, strong, readwrite) TGLottieView *lottie;
@property (nonatomic, copy) NSString *loadedLottiePath;
@property (nonatomic, strong) TGVideoStickerView *videoSticker;
@property (nonatomic, copy) NSString *loadedVideoStickerPath;

@end

@implementation TGAnimatedStickerBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.lottie = [[TGLottieView alloc] init];
	[self.bubble addSubview:self.lottie];

	self.videoSticker = [[TGVideoStickerView alloc] init];
	self.videoSticker.hidden = YES;
	[self.bubble addSubview:self.videoSticker];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	[self.lottie stop];
	self.loadedLottiePath = nil;
	[self.videoSticker stop];
	self.loadedVideoStickerPath = nil;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	BOOL showsSticker = (layout.parts & TGMessageLayoutPartLottie) != 0;
	BOOL isVideo = showsSticker && [self stickerAtPathIsVideo:item.lottiePath];
	[self showLottieForItem:item layout:layout visible:showsSticker && !isVideo];
	[self showVideoStickerForItem:item layout:layout visible:isVideo];
	if (!showsSticker)
		return;

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

- (BOOL)stickerAtPathIsVideo:(NSString *)path {
	if (path.length && [path isEqualToString:self.loadedVideoStickerPath])
		return YES;
	if (path.length && [path isEqualToString:self.loadedLottiePath])
		return NO;
	return TGAnimatedStickerFormatOfFile(path) == TGAnimatedStickerFormatWebM;
}

- (void)showLottieForItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout visible:(BOOL)visible {
	self.lottie.hidden = !visible;
	if (!visible) {
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
}

- (void)showVideoStickerForItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout visible:(BOOL)visible {
	self.videoSticker.hidden = !visible;
	if (!visible) {
		[self.videoSticker stop];
		self.loadedVideoStickerPath = nil;
		return;
	}
	self.videoSticker.frame = layout.bubble.lottie;
	if (![self.loadedVideoStickerPath isEqualToString:item.lottiePath]) {
		[self.videoSticker stop];
		if ([self.videoSticker loadWebMFile:item.lottiePath])
			self.loadedVideoStickerPath = item.lottiePath;
		else
			self.loadedVideoStickerPath = nil;
	}
	self.videoSticker.loopEnabled = [TGPreferenceFlags stickersLoopAnimatedEnabled];
	[self.videoSticker play];
}

@end
