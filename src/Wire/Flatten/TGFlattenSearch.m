#import "TGFlattenSearch.h"
#import "TGDisappearingMedia.h"
#import "TGFlattenMessage.h"
#import "TGLocalization.h"

NSString *TGSearchTextForContent(NSDictionary *content) {
	if (![content isKindOfClass:NSDictionary.class])
		return @"";
	NSString *type = [content[@"@type"] isKindOfClass:NSString.class] ? content[@"@type"] : @"";
	if (TGMediaContentDisappears(content)) {
		NSString *disappearing = TGDisappearingMediaLabel(type);
		if (disappearing)
			return disappearing;
	}
	NSDictionary *text = content[@"text"];
	if ([text isKindOfClass:NSDictionary.class] && [text[@"text"] isKindOfClass:NSString.class])
		return text[@"text"];
	NSDictionary *caption = content[@"caption"];
	if ([caption isKindOfClass:NSDictionary.class] &&
		[caption[@"text"] isKindOfClass:NSString.class] &&
		[caption[@"text"] length])
		return caption[@"text"];

	if ([type isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([type isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([type isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([type isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([type isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([type isEqualToString:@"messageSticker"])
		return TGL(@"Message.Sticker", @"Sticker");
	if ([type isEqualToString:@"messageLocation"])
		return TGL(@"Message.Location", @"Location");
	if ([type isEqualToString:@"messageLiveLocation"])
		return TGL(@"Message.LiveLocation", @"Live location");
	if ([type isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([type isEqualToString:@"messagePoll"])
		return TGL(@"Watch.Message.Poll", @"Poll");
	if ([type isEqualToString:@"messageCall"])
		return TGL(@"Conversation.Call", @"Call");
	if ([type isEqualToString:@"messageDocument"]) {
		NSDictionary *doc = content[@"document"];
		NSString *name = [doc isKindOfClass:NSDictionary.class] ? doc[@"file_name"] : nil;
		return [name isKindOfClass:NSString.class] && name.length
			? name
			: TGL(@"Message.File", @"File");
	}
	if ([type isEqualToString:@"messageAudio"]) {
		NSDictionary *audio = content[@"audio"];
		NSString *title = [audio isKindOfClass:NSDictionary.class] ? audio[@"title"] : nil;
		return [title isKindOfClass:NSString.class] && title.length
			? title
			: TGL(@"SharedMedia.CategoryOther", @"Audio");
	}
	return TGMessageContentKindLabel(content) ?: @"";
}

NSNumber *TGSearchPhotoIdForContent(NSDictionary *content) {
	if (![content isKindOfClass:NSDictionary.class])
		return nil;
	NSString *type = [content[@"@type"] isKindOfClass:NSString.class] ? content[@"@type"] : @"";
	if ([type isEqualToString:@"messagePhoto"]) {
		NSArray *sizes = content[@"photo"][@"sizes"];
		if ([sizes isKindOfClass:NSArray.class] && sizes.count) {
			NSDictionary *largest = [sizes lastObject];
			if ([largest isKindOfClass:NSDictionary.class])
				return largest[@"photo"][@"id"];
		}
		return nil;
	}
	NSString *key = nil;
	if ([type isEqualToString:@"messageVideo"])
		key = @"video";
	else if ([type isEqualToString:@"messageVideoNote"])
		key = @"video_note";
	else if ([type isEqualToString:@"messageAnimation"])
		key = @"animation";
	else if ([type isEqualToString:@"messageDocument"])
		key = @"document";
	else if ([type isEqualToString:@"messageSticker"])
		key = @"sticker";
	if (!key)
		return nil;
	NSDictionary *media = content[key];
	if (![media isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *thumb = media[@"thumbnail"];
	if (![thumb isKindOfClass:NSDictionary.class])
		return nil;
	return thumb[@"file"][@"id"];
}
