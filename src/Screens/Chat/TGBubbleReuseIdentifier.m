#import "TGBubbleReuseIdentifier.h"

NSString *TGBubbleReuseIdentifierForKind(NSString *kind,
	BOOL isAlbum,
	BOOL isService,
	BOOL isAnimatedSticker,
	BOOL rendersAsSticker,
	BOOL burnsOnOpening) {
	NSString *name = [kind isKindOfClass:NSString.class] ? kind : @"";

	if (isAlbum)
		return @"TGBubbleCell.Album";
	if (isService)
		return @"TGBubbleCell.Service";
	if ([name isEqualToString:@"messageRichMessage"])
		return @"TGBubbleCell.RichMessage";
	if ([name isEqualToString:@"messagePoll"])
		return @"TGBubbleCell.Poll";
	if ([name isEqualToString:@"messageChecklist"])
		return @"TGBubbleCell.Checklist";
	if ([name isEqualToString:@"messageCall"] || [name isEqualToString:@"messageGroupCall"])
		return @"TGBubbleCell.Call";
	if ([name isEqualToString:@"messageDocument"] || [name isEqualToString:@"messageAudio"] ||
		[name isEqualToString:@"messageContact"])
		return @"TGBubbleCell.File";
	if ([name isEqualToString:@"messageVideoNote"])
		return burnsOnOpening ? @"TGBubbleCell.Text" : @"TGBubbleCell.VideoNote";
	if (isAnimatedSticker)
		return @"TGBubbleCell.AnimatedSticker";
	if ([name isEqualToString:@"messageSticker"])
		return @"TGBubbleCell.Sticker";
	if ([name isEqualToString:@"messageAnimatedEmoji"] || [name isEqualToString:@"messageDice"])
		return rendersAsSticker ? @"TGBubbleCell.Sticker" : @"TGBubbleCell.BareEmoji";
	if ([name isEqualToString:@"messageVoiceNote"])
		return @"TGBubbleCell.Voice";
	if ([name isEqualToString:@"messageText"])
		return @"TGBubbleCell.Text";
	if ([name isEqualToString:@"messagePhoto"] || [name isEqualToString:@"messageVideo"] ||
		[name isEqualToString:@"messageAnimation"])
		return burnsOnOpening ? @"TGBubbleCell.Text" : @"TGBubbleCell.Photo";
	if ([name isEqualToString:@"messageLocation"] || [name isEqualToString:@"messageVenue"] ||
		[name isEqualToString:@"messageLiveLocation"])
		return @"TGBubbleCell.Location";
	return @"TGBubbleCell.Text";
}
