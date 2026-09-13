#import "TGClient+ChatState.h"
#import "TGSharedMediaVisibility.h"
#import "TGDateUtils.h"
#import "TGMediaViewControllerInternal.h"
#import "TGClient+Files.h"
#import "TGClient+Notifications.h"
#import "TGFlattenFiles.h"
#import "TGByteFormat.h"
#import "TGLocalization.h"

const CGFloat kMediaRowHeight = 79.0f;
const CGFloat kMediaBannerHeight = 45.0f;
const NSInteger kMediaPageSize = 50;
const CGFloat kMediaPageGap = 40.0f;
const CGFloat kMediaScopeHeight = 44.0f;
const CGFloat kMediaScopeButtonHeight = 30.0f;
const CGFloat kMediaSearchBarHeight = 44.0f;
const CGFloat kMediaListRowHeight = 56.0f;
const CGFloat kMediaTopBarFallbackHeight = 44.0f;

CGFloat TGMediaTopBarHeight(void) {
	UIImage *panel = [UIImage imageNamed:@"GalleryTopPanel.png"];
	return panel ? panel.size.height : kMediaTopBarFallbackHeight;
}

CGFloat TGMediaStatusBarInset(void) {
	CGRect frame = [UIApplication sharedApplication].statusBarFrame;
	CGFloat inset = MIN(frame.size.width, frame.size.height);
	if (inset < 1.0f)
		inset = 20.0f;
	return inset;
}

UIImage *TGMediaPauseGlyph(CGSize size) {
	if (size.width < 8 || size.height < 8)
		size = CGSizeMake(44, 44);

	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 0.35f);
	CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, size.width, size.height));

	CGFloat barWidth = size.width * 0.12f;
	CGFloat barHeight = size.height * 0.36f;
	CGFloat gap = size.width * 0.10f;
	CGFloat top = (size.height - barHeight) / 2.0f;
	CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 0.92f);
	CGContextFillRect(ctx, CGRectMake(size.width / 2.0f - gap / 2.0f - barWidth, top, barWidth, barHeight));
	CGContextFillRect(ctx, CGRectMake(size.width / 2.0f + gap / 2.0f, top, barWidth, barHeight));

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

CGFloat TGMediaFullScreenWidth(void) {
	CGSize screen = [UIScreen mainScreen].bounds.size;
	return MAX(screen.width, screen.height);
}

NSMutableDictionary *TGMediaPhotoFields(NSDictionary *content, TGClient *client,
	CGFloat scale) {
	NSArray *sizes = content[@"photo"][@"sizes"];
	if (![sizes isKindOfClass:NSArray.class] || sizes.count == 0)
		return nil;
	NSDictionary *small = TGBestPhotoSizeInSizesForWidthScale(sizes, kMediaTileSide, scale);
	NSDictionary *large = TGBestPhotoSizeInSizesForWidthScale(sizes, TGMediaFullScreenWidth(), scale);

	NSMutableDictionary *fields = [NSMutableDictionary dictionary];
	id thumbId = small[@"fileId"];
	if (thumbId)
		fields[@"thumbId"] = thumbId;
	NSString *thumbUnique = small[@"uniqueId"];
	if ([thumbUnique isKindOfClass:NSString.class] && thumbUnique.length)
		fields[@"thumbUniqueId"] = thumbUnique;
	id fullId = large[@"fileId"] ?: [sizes lastObject][@"photo"][@"id"];
	if (fullId)
		fields[@"fullId"] = fullId;
	fields[@"sizes"] = sizes;
	id minithumb = content[@"photo"][@"minithumbnail"];
	if (minithumb)
		fields[@"minithumb"] = minithumb;
	fields[@"fileType"] = TGFileTypePhoto;
	return fields;
}

NSMutableDictionary *TGMediaMovingImageFields(NSDictionary *content, TGClient *client,
	NSString *key, NSString *fileType) {
	NSDictionary *media = content[key];
	NSDictionary *thumb = TGDecodableThumbnail(media[@"thumbnail"]);

	NSMutableDictionary *fields = [NSMutableDictionary dictionary];
	id thumbId = thumb[@"fileId"];
	if (thumbId)
		fields[@"thumbId"] = thumbId;
	NSString *thumbUnique = thumb[@"uniqueId"];
	if ([thumbUnique isKindOfClass:NSString.class] && thumbUnique.length)
		fields[@"thumbUniqueId"] = thumbUnique;
	id fullId = media[key][@"id"];
	if (fullId)
		fields[@"fullId"] = fullId;
	fields[@"duration"] = @([media[@"duration"] integerValue]);
	id minithumb = media[@"minithumbnail"];
	if (minithumb)
		fields[@"minithumb"] = minithumb;
	fields[@"fileType"] = fileType;
	fields[@"isVideo"] = @(YES);
	return fields;
}

NSDictionary *TGMediaItemFromMessage(NSDictionary *message) {
	if (![message isKindOfClass:NSDictionary.class])
		return nil;

	NSDictionary *content = message[@"content"];
	NSString *kind = TGTDLibContentKindOfMessage(message);
	if (!kind.length || !TGSharedMediaShowsMessage(message))
		return nil;

	CGFloat scale = [UIScreen mainScreen].scale;
	TGClient *client = [TGClient shared];

	NSMutableDictionary *fields = nil;
	if ([kind isEqualToString:@"messagePhoto"])
		fields = TGMediaPhotoFields(content, client, scale);
	else if ([kind isEqualToString:@"messageVideo"])
		fields = TGMediaMovingImageFields(content, client, @"video", TGFileTypeVideo);
	else if ([kind isEqualToString:@"messageAnimation"])
		fields = TGMediaMovingImageFields(content, client, @"animation", TGFileTypeAnimation);
	else
		return nil;

	if (!fields)
		return nil;

	NSNumber *thumbId = fields[@"thumbId"];
	NSNumber *fullId = fields[@"fullId"];
	NSInteger duration = [fields[@"duration"] integerValue];
	BOOL isVideo = [fields[@"isVideo"] boolValue];
	NSArray *photoSizes = fields[@"sizes"];
	NSDictionary *minithumb = fields[@"minithumb"];
	NSString *fileType = fields[@"fileType"];
	NSString *thumbUniqueId = fields[@"thumbUniqueId"];

	if (![thumbId isKindOfClass:NSNumber.class] && ![fullId isKindOfClass:NSNumber.class])
		return nil;

	NSString *caption = content[@"caption"][@"text"];
	if (![caption isKindOfClass:NSString.class])
		caption = @"";

	NSDictionary *sender = message[@"sender_id"];
	NSString *senderName = @"";
	if ([TGTDLibTypeOf(sender) isEqualToString:@"messageSenderUser"]) {
		NSNumber *senderUserId = [sender[@"user_id"] isKindOfClass:NSNumber.class] ? sender[@"user_id"] : nil;
		senderName = senderUserId ? ([client nameForUserId:senderUserId.longLongValue] ?: @"") : @"";
	} else if ([TGTDLibTypeOf(sender) isEqualToString:@"messageSenderChat"]) {
		int64_t senderChatId = [sender[@"chat_id"] longLongValue];
		senderName = [client titleForChatId:senderChatId] ?: @"";
	}
	NSString *author = [message[@"is_outgoing"] boolValue] ? @"" : senderName;

	NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{
		@"messageId" : message[@"id"] ?: @(0),
		@"thumbId" : [thumbId isKindOfClass:NSNumber.class] ? thumbId : (fullId ?: @(0)),
		@"fullId" : [fullId isKindOfClass:NSNumber.class] ? fullId : (thumbId ?: @(0)),
		@"duration" : @(duration),
		@"isVideo" : @(isVideo),
		@"caption" : caption,
		@"author" : author,
		@"fileType" : fileType,
		@"date" : message[@"date"] ?: @(0),
	}];
	if ([thumbUniqueId isKindOfClass:NSString.class] && thumbUniqueId.length)
		item[@"thumbUniqueId"] = thumbUniqueId;
	if ([photoSizes isKindOfClass:NSArray.class])
		item[@"sizes"] = photoSizes;
	if ([minithumb isKindOfClass:NSDictionary.class])
		item[@"minithumb"] = minithumb;
	return item;
}

NSArray *TGMediaScopeTitles(void) {
	static NSArray *titles = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		titles = @[ TGL(@"PeerInfo.PaneMedia", @"Media"), TGL(@"PeerInfo.PaneFiles", @"Files"),
			TGL(@"PeerInfo.PaneLinks", @"Links"), TGL(@"Cache.Music", @"Music"),
			TGL(@"PeerInfo.PaneGifs", @"GIFs"), TGL(@"PeerInfo.PaneVoiceAndVideo", @"Voice") ];
	});
	return titles;
}

NSString *TGMediaContentKindName(NSDictionary *content) {
	return TGTDLibContentKindOfMessage(@{@"content" : content ?: @{}});
}

NSString *TGMediaFilterForScope(NSInteger scope) {
	switch (scope) {
		case TGMediaScopeFiles:
			return @"searchMessagesFilterDocument";
		case TGMediaScopeLinks:
			return @"searchMessagesFilterUrl";
		case TGMediaScopeMusic:
			return @"searchMessagesFilterAudio";
		case TGMediaScopeGifs:
			return @"searchMessagesFilterAnimation";
		case TGMediaScopeVoice:
			return @"searchMessagesFilterVoiceAndVideoNote";
		default:
			return @"searchMessagesFilterPhotoAndVideo";
	}
}

BOOL TGMediaScopeIsGrid(NSInteger scope) {
	return scope == TGMediaScopeMedia || scope == TGMediaScopeGifs;
}

NSString *TGMediaEmptyTextForScope(NSInteger scope) {
	switch (scope) {
		case TGMediaScopeFiles:
			return TGL(@"Media.NoSharedFiles", @"No shared files");
		case TGMediaScopeLinks:
			return TGL(@"Media.NoSharedLinks", @"No shared links");
		case TGMediaScopeMusic:
			return TGL(@"Media.NoSharedMusic", @"No shared music");
		case TGMediaScopeGifs:
			return TGL(@"Media.NoSharedGifs", @"No shared GIFs");
		case TGMediaScopeVoice:
			return TGL(@"Media.NoSharedVoiceMessages", @"No shared voice messages");
		default:
			return TGL(@"Media.NoPhotosInThisConversation", @"No Photos in this Conversation");
	}
}

NSString *TGMediaMonthForDate(NSInteger date) {
	if (date <= 0)
		return @"";
	return [TGDateUtils stringForMonthAndYear:(int)date];
}

NSString *TGMediaDayForDate(NSInteger date) {
	if (date <= 0)
		return @"";
	return [TGDateUtils stringForDateAndTime:(int)date];
}

NSString *TGMediaFirstUrlInText(NSString *text, NSDictionary *content) {
	NSDictionary *webPage = [content[@"link_preview"] isKindOfClass:NSDictionary.class] ? content[@"link_preview"] : nil;
	NSString *pageUrl = webPage[@"url"];
	if ([pageUrl isKindOfClass:NSString.class] && pageUrl.length)
		return pageUrl;

	if (![text isKindOfClass:NSString.class] || text.length == 0)
		return nil;

	static NSDataDetector *detector = nil;
	if (!detector) {
		detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
	}
	NSRange fullRange = NSMakeRange(0, text.length);
	NSTextCheckingResult *match = [detector firstMatchInString:text options:0 range:fullRange];
	if (match && match.URL)
		return [match.URL absoluteString];
	return nil;
}

NSMutableDictionary *TGMediaDocumentFields(NSDictionary *content) {
	NSDictionary *document = content[@"document"];
	NSString *name = document[@"file_name"];
	NSDictionary *file = document[@"document"];
	long long size = [file[@"size"] longLongValue];
	if (size <= 0)
		size = [file[@"expected_size"] longLongValue];

	NSMutableDictionary *fields = [NSMutableDictionary dictionary];
	fields[@"title"] = [name isKindOfClass:NSString.class] && name.length ? name : TGL(@"Message.File", @"File");
	id fileId = file[@"id"];
	if (fileId)
		fields[@"fileId"] = fileId;
	fields[@"size"] = @(size);
	fields[@"detail"] = TGMediaFormatBytes(size);
	NSString *mimeType = document[@"mime_type"];
	if ([mimeType isKindOfClass:NSString.class])
		fields[@"mime"] = mimeType;
	return fields;
}

NSMutableDictionary *TGMediaAudioFields(NSDictionary *content) {
	NSDictionary *audio = content[@"audio"];
	NSString *name = audio[@"title"];
	if (![name isKindOfClass:NSString.class] || name.length == 0)
		name = audio[@"file_name"];
	NSString *performer = audio[@"performer"];
	NSInteger duration = [audio[@"duration"] integerValue];
	NSDictionary *file = audio[@"audio"];
	long long size = [file[@"size"] longLongValue];
	if (size <= 0)
		size = [file[@"expected_size"] longLongValue];

	NSMutableDictionary *fields = [NSMutableDictionary dictionary];
	fields[@"title"] = [name isKindOfClass:NSString.class] && name.length ? name : TGL(@"MediaPlayer.UnknownTrack", @"Unknown Track");
	id fileId = file[@"id"];
	if (fileId)
		fields[@"fileId"] = fileId;
	fields[@"fileType"] = TGFileTypeAudio;
	NSString *mimeType = audio[@"mime_type"];
	if ([mimeType isKindOfClass:NSString.class])
		fields[@"mime"] = mimeType;
	fields[@"size"] = @(size);
	fields[@"duration"] = @(duration);
	fields[@"detail"] = [performer isKindOfClass:NSString.class] && performer.length
		? [NSString stringWithFormat:@"%@ · %@", performer,
			  TGMediaFormatDuration(duration)]
		: TGMediaFormatDuration(duration);
	return fields;
}

NSMutableDictionary *TGMediaLinkFields(NSDictionary *content) {
	NSString *body = content[@"text"][@"text"];
	if (![body isKindOfClass:NSString.class])
		body = content[@"caption"][@"text"];
	NSString *found = TGMediaFirstUrlInText(body, content);
	if (!found.length)
		return nil;

	NSMutableDictionary *fields = [NSMutableDictionary dictionary];
	fields[@"url"] = found;
	NSDictionary *webPage = [content[@"link_preview"] isKindOfClass:NSDictionary.class] ? content[@"link_preview"] : nil;
	NSString *pageTitle = webPage[@"title"];
	fields[@"title"] = [pageTitle isKindOfClass:NSString.class] && pageTitle.length
		? pageTitle
		: found;
	fields[@"detail"] = found;
	return fields;
}

NSMutableDictionary *TGMediaVoiceFields(NSDictionary *content) {
	NSString *kind = TGMediaContentKindName(content);
	BOOL isVideoNote = [kind isEqualToString:@"messageVideoNote"];
	NSDictionary *media = isVideoNote ? content[@"video_note"] : content[@"voice_note"];
	if (![media isKindOfClass:NSDictionary.class])
		return nil;

	NSDictionary *file = isVideoNote ? media[@"video"] : media[@"voice"];
	NSNumber *fileId = [file isKindOfClass:NSDictionary.class] ? file[@"id"] : nil;
	if (![fileId isKindOfClass:NSNumber.class])
		return nil;

	NSInteger duration = [media[@"duration"] integerValue];
	NSMutableDictionary *fields = [NSMutableDictionary dictionary];
	fields[@"title"] = isVideoNote ? TGL(@"Message.VideoMessage", @"Video Message") : TGL(@"Message.Audio", @"Voice message");
	fields[@"fileId"] = fileId;
	fields[@"fileType"] = TGFileTypeDocument;
	fields[@"duration"] = @(duration);
	fields[@"detail"] = TGMediaFormatDuration(duration);
	fields[@"isVideoNote"] = @(isVideoNote);
	return fields;
}

NSDictionary *TGMediaListItemFromMessage(NSDictionary *message, NSInteger scope) {
	if (![message isKindOfClass:NSDictionary.class])
		return nil;

	NSDictionary *content = message[@"content"];
	NSString *kind = TGTDLibContentKindOfMessage(message);
	if (!kind.length || !TGSharedMediaShowsMessage(message))
		return nil;

	NSMutableDictionary *fields = nil;
	if (scope == TGMediaScopeFiles) {
		if (![kind isEqualToString:@"messageDocument"])
			return nil;
		fields = TGMediaDocumentFields(content);

	} else if (scope == TGMediaScopeMusic) {
		if (![kind isEqualToString:@"messageAudio"])
			return nil;
		fields = TGMediaAudioFields(content);

	} else if (scope == TGMediaScopeVoice) {
		if (![kind isEqualToString:@"messageVoiceNote"] &&
			![kind isEqualToString:@"messageVideoNote"])
			return nil;
		fields = TGMediaVoiceFields(content);

	} else {
		fields = TGMediaLinkFields(content);
	}

	if (!fields)
		return nil;

	NSNumber *fileId = fields[@"fileId"];
	if (scope != TGMediaScopeLinks && ![fileId isKindOfClass:NSNumber.class])
		return nil;

	TGClient *client = [TGClient shared];
	NSDictionary *sender = message[@"sender_id"];
	NSNumber *senderUserId = @0;
	NSString *senderName = @"";
	if ([TGTDLibTypeOf(sender) isEqualToString:@"messageSenderUser"]) {
		senderUserId = [sender[@"user_id"] isKindOfClass:NSNumber.class] ? sender[@"user_id"] : @0;
		senderName = senderUserId.longLongValue ? ([client nameForUserId:senderUserId.longLongValue] ?: @"") : @"";
	} else if ([TGTDLibTypeOf(sender) isEqualToString:@"messageSenderChat"]) {
		int64_t senderChatId = [sender[@"chat_id"] longLongValue];
		senderName = [client titleForChatId:senderChatId] ?: @"";
	}

	NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{
		@"messageId" : message[@"id"] ?: @(0),
		@"chatId" : message[@"chat_id"] ?: @(0),
		@"title" : fields[@"title"] ?: @"",
		@"detail" : fields[@"detail"] ?: @"",
		@"url" : fields[@"url"] ?: @"",
		@"fileId" : [fileId isKindOfClass:NSNumber.class] ? fileId : @(0),
		@"size" : fields[@"size"] ?: @(0),
		@"duration" : fields[@"duration"] ?: @(0),
		@"mime" : fields[@"mime"] ?: @"",
		@"fileType" : fields[@"fileType"] ?: TGFileTypeDocument,
		@"date" : message[@"date"] ?: @(0),
		@"outgoing" : @([message[@"is_outgoing"] boolValue]),
		@"senderId" : senderUserId,
		@"senderName" : senderName,
		@"list" : @(YES),
	}];
	if (scope == TGMediaScopeVoice)
		item[@"isVideoNote"] = fields[@"isVideoNote"] ?: @(NO);
	return item;
}
