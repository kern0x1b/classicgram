#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessage.h"

TGMessageLayoutGenericBucket TGMessageLayoutGenericBucketForContent(TGMessageContentKind kind,
	BOOL isLargeEmojiText) {
	switch (kind) {
		case TGMessageContentKindText:
			return isLargeEmojiText
				? TGMessageLayoutGenericBucketSticker
				: TGMessageLayoutGenericBucketText;

		case TGMessageContentKindPhoto:
		case TGMessageContentKindVideo:
		case TGMessageContentKindAnimation:
		case TGMessageContentKindLocation:
		case TGMessageContentKindLiveLocation:
		case TGMessageContentKindVenue:
			return TGMessageLayoutGenericBucketPhoto;

		case TGMessageContentKindSticker:
		case TGMessageContentKindAnimatedEmoji:
			return TGMessageLayoutGenericBucketSticker;

		case TGMessageContentKindDice:
		case TGMessageContentKindGame:
		case TGMessageContentKindInvoice:
		case TGMessageContentKindStory:
		case TGMessageContentKindPaidMedia:
		case TGMessageContentKindExpiredMedia:
		case TGMessageContentKindUnsupported:
			return TGMessageLayoutGenericBucketText;

		case TGMessageContentKindUnknown:
		case TGMessageContentKindVideoNote:
		case TGMessageContentKindDocument:
		case TGMessageContentKindVoiceNote:
		case TGMessageContentKindAudio:
		case TGMessageContentKindContact:
		case TGMessageContentKindPoll:
		case TGMessageContentKindChecklist:
		case TGMessageContentKindCall:
		case TGMessageContentKindRichMessage:
		case TGMessageContentKindService:
			return TGMessageLayoutGenericBucketNotApplicable;
	}
	return TGMessageLayoutGenericBucketNotApplicable;
}
