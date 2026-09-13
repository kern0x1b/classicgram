#import "TGSavedMessagesText.h"
#import "TGFlattenMessage.h"
#import "TGLocalization.h"
#import "TGStringTruncation.h"

NSString *TGSavedFilterForScope(NSInteger scope) {
	switch (scope) {
		case 1:
			return @"searchMessagesFilterPhotoAndVideo";
		case 2:
			return @"searchMessagesFilterDocument";
		case 3:
			return @"searchMessagesFilterAudio";
		case 4:
			return @"searchMessagesFilterUrl";
		default:
			return nil;
	}
}

NSString *TGSavedEmptyTitleForScope(NSInteger scope) {
	switch (scope) {
		case 1:
			return TGL(@"Chat.SavedMessages.NoMedia", @"No Media");
		case 2:
			return TGL(@"Chat.SavedMessages.NoFiles", @"No Files");
		case 3:
			return TGL(@"Chat.SavedMessages.NoMusic", @"No Music");
		case 4:
			return TGL(@"Chat.SavedMessages.NoLinks", @"No Links");
		default:
			return TGL(@"Chat.SavedMessages.NoSavedMessages", @"No Saved Messages");
	}
}

NSString *TGSavedEmptyTextForScope(NSInteger scope) {
	switch (scope) {
		case 1:
			return TGL(@"Chat.SavedMessages.NoMediaText", @"Photos and videos you save end up here.");
		case 2:
			return TGL(@"Chat.SavedMessages.NoFilesText", @"Documents you save end up here.");
		case 3:
			return TGL(@"Chat.SavedMessages.NoMusicText", @"Music and audio files you save end up here.");
		case 4:
			return TGL(@"Chat.SavedMessages.NoLinksText", @"Links you save end up here.");
		default:
			return TGL(@"Chat.SavedMessages.NoSavedMessagesText", @"Forward messages here to keep them. They are grouped by who sent them.");
	}
}

NSString *TGSavedKindLabel(NSString *kind) {
	if (![kind isKindOfClass:NSString.class])
		return @"";
	if ([kind isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([kind isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([kind isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([kind isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([kind isEqualToString:@"messageAudio"])
		return TGL(@"SharedMedia.CategoryOther", @"Audio");
	if ([kind isEqualToString:@"messageDocument"])
		return TGL(@"Message.File", @"File");
	if ([kind isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([kind isEqualToString:@"messageSticker"])
		return TGL(@"Message.Sticker", @"Sticker");
	return TGMessageKindLabel(kind) ?: @"";
}

NSString *TGSavedShortText(NSDictionary *message, NSUInteger limit) {
	NSString *text = message[@"text"];
	if (![text isKindOfClass:NSString.class] || !text.length)
		text = TGL(@"SharedMedia.CategoryMedia", @"Media");
	if (text.length > limit)
		text = [TGSafeSubstringToIndex(text, limit) stringByAppendingString:@"…"];
	return text;
}

NSString *TGSavedTopicKind(NSDictionary *topic) {
	NSString *kind = topic[@"kind"];
	return [kind isKindOfClass:NSString.class] ? kind : @"";
}
