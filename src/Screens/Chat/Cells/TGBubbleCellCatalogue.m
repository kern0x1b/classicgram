#import "TGBubbleCellCatalogue.h"
#import "TGServiceRowCell.h"
#import "TGTextBubbleCell.h"
#import "TGPhotoBubbleCell.h"
#import "TGFileBubbleCell.h"
#import "TGVoiceBubbleCell.h"
#import "TGStickerBubbleCell.h"
#import "TGAnimatedStickerBubbleCell.h"
#import "TGBareEmojiBubbleCell.h"
#import "TGVideoNoteBubbleCell.h"
#import "TGAlbumBubbleCell.h"
#import "TGPollBubbleCell.h"
#import "TGChecklistBubbleCell.h"
#import "TGCallBubbleCell.h"
#import "TGRichMessageBubbleCell.h"
#import "TGMapBubbleCell.h"

static NSString *const TGBubbleCellIdentifierService = @"TGBubbleCell.Service";
static NSString *const TGBubbleCellIdentifierText = @"TGBubbleCell.Text";
static NSString *const TGBubbleCellIdentifierPhoto = @"TGBubbleCell.Photo";
static NSString *const TGBubbleCellIdentifierFile = @"TGBubbleCell.File";
static NSString *const TGBubbleCellIdentifierVoice = @"TGBubbleCell.Voice";
static NSString *const TGBubbleCellIdentifierSticker = @"TGBubbleCell.Sticker";
static NSString *const TGBubbleCellIdentifierAnimatedSticker = @"TGBubbleCell.AnimatedSticker";
static NSString *const TGBubbleCellIdentifierBareEmoji = @"TGBubbleCell.BareEmoji";
static NSString *const TGBubbleCellIdentifierVideoNote = @"TGBubbleCell.VideoNote";
static NSString *const TGBubbleCellIdentifierAlbum = @"TGBubbleCell.Album";
static NSString *const TGBubbleCellIdentifierPoll = @"TGBubbleCell.Poll";
static NSString *const TGBubbleCellIdentifierChecklist = @"TGBubbleCell.Checklist";
static NSString *const TGBubbleCellIdentifierCall = @"TGBubbleCell.Call";
static NSString *const TGBubbleCellIdentifierRichMessage = @"TGBubbleCell.RichMessage";
static NSString *const TGBubbleCellIdentifierLocation = @"TGBubbleCell.Location";

@implementation TGBubbleCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGChatRowKind)kind {
	switch (kind) {
		case TGChatRowKindService:
			return TGBubbleCellIdentifierService;
		case TGChatRowKindText:
			return TGBubbleCellIdentifierText;
		case TGChatRowKindPhoto:
			return TGBubbleCellIdentifierPhoto;
		case TGChatRowKindFile:
			return TGBubbleCellIdentifierFile;
		case TGChatRowKindVoice:
			return TGBubbleCellIdentifierVoice;
		case TGChatRowKindSticker:
			return TGBubbleCellIdentifierSticker;
		case TGChatRowKindAnimatedSticker:
			return TGBubbleCellIdentifierAnimatedSticker;
		case TGChatRowKindBareEmoji:
			return TGBubbleCellIdentifierBareEmoji;
		case TGChatRowKindVideoNote:
			return TGBubbleCellIdentifierVideoNote;
		case TGChatRowKindAlbum:
			return TGBubbleCellIdentifierAlbum;
		case TGChatRowKindPoll:
			return TGBubbleCellIdentifierPoll;
		case TGChatRowKindChecklist:
			return TGBubbleCellIdentifierChecklist;
		case TGChatRowKindCall:
			return TGBubbleCellIdentifierCall;
		case TGChatRowKindRichMessage:
			return TGBubbleCellIdentifierRichMessage;
		case TGChatRowKindLocation:
			return TGBubbleCellIdentifierLocation;
		default:
			return nil;
	}
}

+ (Class)cellClassForReuseIdentifier:(NSString *)identifier {
	if ([identifier isEqualToString:TGBubbleCellIdentifierService])
		return [TGServiceRowCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierText])
		return [TGTextBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierPhoto])
		return [TGPhotoBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierFile])
		return [TGFileBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierVoice])
		return [TGVoiceBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierSticker])
		return [TGStickerBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierAnimatedSticker])
		return [TGAnimatedStickerBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierBareEmoji])
		return [TGBareEmojiBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierVideoNote])
		return [TGVideoNoteBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierAlbum])
		return [TGAlbumBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierPoll])
		return [TGPollBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierChecklist])
		return [TGChecklistBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierCall])
		return [TGCallBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierRichMessage])
		return [TGRichMessageBubbleCell class];
	if ([identifier isEqualToString:TGBubbleCellIdentifierLocation])
		return [TGMapBubbleCell class];
	return nil;
}

@end
