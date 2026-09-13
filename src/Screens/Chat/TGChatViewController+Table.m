#import "TGClient+UpdateHandling.h"
#import "TGBubbleReuseIdentifier.h"
#import "TGDurationText.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGRichText.h"
#import "TGMusicPlayer.h"
#import "TGAudioMetadata.h"
#import "TGMessageLayoutBuilder+Private.h"
#import "TGStringTruncation.h"
#import "TGFlattenMessage.h"
#import "TGWallpaperRevertEligibility.h"
#import "TGChatRowText.h"

extern UIColor *TGActiveChatThemeAccentColour(int64_t chatId);

@implementation TGChatViewController (Table)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self displayRowCount];
}

- (NSDictionary *)pinnedTargetFor:(NSDictionary *)m {
	NSNumber *targetId = [m[@"pinnedId"] isKindOfClass:NSNumber.class]
		? m[@"pinnedId"]
		: nil;
	if (!targetId)
		targetId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	if (!targetId || ![targetId longLongValue])
		return nil;
	NSDictionary *fetched = self.quotes[targetId];
	if (fetched)
		return fetched;
	if ([self.quotesMissing containsObject:targetId])
		return nil;
	NSInteger loadedRow = [self rowForMessageId:[targetId longLongValue]];
	if (loadedRow == NSNotFound)
		return nil;
	for (NSDictionary *candidate in [self messagesAtRow:loadedRow])
		if ([candidate[@"id"] isKindOfClass:NSNumber.class] &&
			[candidate[@"id"] longLongValue] == [targetId longLongValue])
			return candidate;
	return nil;
}

- (NSNumber *)wallpaperRevertTargetFor:(NSDictionary *)m {
	return TGWallpaperRevertTarget(m, self.chatBackgroundId);
}

- (NSString *)pinnedDescriptorFor:(NSDictionary *)target {
	return TGPinnedDescriptor(target);
}

- (NSString *)pinnedNoticeFor:(NSDictionary *)m {
	if (![m[@"kind"] isEqualToString:@"messagePinMessage"])
		return nil;
	NSDictionary *target = [self pinnedTargetFor:m];
	if (!target)
		return nil;
	NSString *who = [m[@"serviceActor"] isKindOfClass:NSString.class] &&
			[m[@"serviceActor"] length]
		? m[@"serviceActor"]
		: TGL(@"Community.Request.UnknownRequester", @"Someone");
	return TGComposePinnedNotice(who, [self pinnedDescriptorFor:target]);
}

- (NSString *)serviceLineFor:(NSDictionary *)m {
	NSString *pinned = [self pinnedNoticeFor:m];
	if (pinned.length)
		return pinned;

	NSString *who = [m[@"serviceActor"] isKindOfClass:NSString.class] ? m[@"serviceActor"] : nil;
	NSString *body = [self textOf:m] ?: @"";
	BOOL alreadyNamed = [m[@"serviceNamesAuthor"] boolValue];
	return (who.length && !alreadyNamed)
		? [NSString stringWithFormat:@"%@ %@", who, body]
		: body;
}

- (NSDictionary *)fileStateFor:(NSDictionary *)m {
	NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
	long long size = [m[@"docSize"] longLongValue];
	long long got = [m[@"docDownloadedSize"] longLongValue];
	BOOL local = [m[@"docLocal"] boolValue];
	BOOL active = [m[@"docDownloading"] boolValue];
	NSString *path = [m[@"docPath"] isKindOfClass:NSString.class] ? m[@"docPath"] : @"";

	NSDictionary *live = docId ? [[TGClient shared] knownStateOfFile:[docId longLongValue]]
							   : nil;
	if (live) {
		if ([live[@"size"] longLongValue] > 0)
			size = [live[@"size"] longLongValue];
		got = [live[@"downloaded"] longLongValue];
		local = [live[@"complete"] boolValue];
		active = [live[@"active"] boolValue];
		if ([live[@"path"] length])
			path = live[@"path"];
	}
	if (docId && [self.filesBeingFetched containsObject:docId])
		active = active || !local;

	CGFloat progress = (size > 0 && got > 0) ? MIN(1.0f, (CGFloat)got / (CGFloat)size) : 0.0f;
	return @{@"size" : @(size), @"downloaded" : @(got), @"local" : @(local), @"active" : @(active), @"path" : path, @"progress" : @(progress)};
}

- (TGFileStatusKind)statusKindForFileState:(NSDictionary *)state
								  playable:(BOOL)playable
								   playing:(BOOL)playing {
	return TGFileStatusKindForState(state, playable, playing);
}

- (NSString *)fileSubtitleFor:(NSDictionary *)m state:(NSDictionary *)state {
	NSString *kind = m[@"kind"];
	long long size = [state[@"size"] longLongValue];
	if ([state[@"active"] boolValue] && ![state[@"local"] boolValue] && size > 0)
		return [NSString stringWithFormat:@"%@ / %@",
			TGFormatByteCount([state[@"downloaded"] longLongValue]),
			TGFormatByteCount(size)];

	if ([kind isEqualToString:@"messageAudio"]) {
		NSString *performer = [m[@"audioPerformer"] isKindOfClass:NSString.class]
			? m[@"audioPerformer"]
			: @"";
		NSInteger seconds = [m[@"duration"] integerValue];
		NSString *length = seconds > 0 ? TGDurationText(seconds) : @"";
		if (performer.length && length.length)
			return [NSString stringWithFormat:@"%@ • %@", performer, length];
		if (performer.length)
			return performer;
		return length.length ? length : TGFormatByteCount(size);
	}

	return TGFormatByteCount(size);
}

- (NSString *)fileTitleFor:(NSDictionary *)m {
	NSString *kind = m[@"kind"];
	if ([kind isEqualToString:@"messageAudio"]) {
		NSString *title = [m[@"audioTitle"] isKindOfClass:NSString.class]
			? m[@"audioTitle"]
			: @"";
		if (title.length)
			return title;
	}
	NSString *name = [m[@"docName"] isKindOfClass:NSString.class] ? m[@"docName"] : @"";
	if (name.length)
		return name;
	return [kind isEqualToString:@"messageAudio"]
		? TGL(@"SharedMedia.CategoryOther", @"Audio")
		: TGL(@"Message.File", @"File");
}

- (NSString *)contactNameFor:(NSDictionary *)m {
	NSString *first = [m[@"contactFirstName"] isKindOfClass:NSString.class]
		? m[@"contactFirstName"]
		: @"";
	NSString *last = [m[@"contactLastName"] isKindOfClass:NSString.class]
		? m[@"contactLastName"]
		: @"";
	NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (name.length)
		return name;
	NSArray *lines = [([self textOf:m] ?: @"") componentsSeparatedByString:@"\n"];
	return lines.count ? lines[0] : @"";
}

- (NSString *)contactPhoneFor:(NSDictionary *)m {
	NSString *phone = [m[@"contactPhone"] isKindOfClass:NSString.class]
		? m[@"contactPhone"]
		: @"";
	if (phone.length)
		return [phone hasPrefix:@"+"] ? phone
									  : [@"+" stringByAppendingString:phone];
	NSArray *lines = [([self textOf:m] ?: @"") componentsSeparatedByString:@"\n"];
	return lines.count > 1 ? lines[1] : @"";
}

- (BOOL)fileCellShowsThumbnailFor:(NSDictionary *)m {
	if (![m[@"kind"] isEqualToString:@"messageDocument"])
		return NO;
	NSNumber *thumbId = [m[@"photoId"] isKindOfClass:NSNumber.class] ? m[@"photoId"] : nil;
	if (thumbId && [thumbId longLongValue] != 0)
		return YES;
	return [m[@"minithumbnail"] isKindOfClass:NSDictionary.class];
}

- (NSString *)fileCaptionFor:(NSDictionary *)m {
	if ([m[@"kind"] isEqualToString:@"messageContact"])
		return nil;
	if (![m[@"caption"] isKindOfClass:NSString.class] || ![m[@"caption"] length])
		return nil;
	NSString *text = [self textOf:m];
	return text.length ? text : nil;
}

- (CGFloat)fileCellTileSideFor:(NSDictionary *)m {
	if ([m[@"kind"] isEqualToString:@"messageContact"])
		return 44.0f;
	return [self fileCellShowsThumbnailFor:m] ? 60.0f : 44.0f;
}

- (NSString *)clockTextForSeconds:(NSInteger)seconds {
	return TGClockText(seconds);
}

- (TGAudioMetadata *)audioTagsFor:(NSDictionary *)m {
	int64_t fileId = [m[@"docId"] longLongValue];
	if (!fileId)
		return nil;
	TGAudioMetadata *cached = [TGAudioMetadata cachedForFileId:fileId];
	if (cached)
		return cached;
	if ([m[@"audioIsLocal"] boolValue] ||
		[[TGMusicPlayer shared] isCurrentMessage:[m[@"id"] longLongValue] inChat:self.chatId])
		[TGAudioMetadata requestForFileId:fileId];
	return nil;
}

- (NSString *)audioTitleFor:(NSDictionary *)m tags:(TGAudioMetadata *)tags {
	NSString *name = m[@"docName"];
	NSString *bare = name.length
		? [name.lastPathComponent stringByDeletingPathExtension]
		: nil;

	NSString *tagged = [m[@"audioTitle"] length] ? m[@"audioTitle"] : tags.title;
	if (tagged.length) {
		if (name.length && ([tagged isEqualToString:name] || [tagged isEqualToString:name.lastPathComponent]))
			return bare.length ? bare : tagged;
		return tagged;
	}
	return bare.length ? bare : TGL(@"MediaPlayer.UnknownTrack", @"Unknown Track");
}

- (NSString *)audioPerformerFor:(NSDictionary *)m tags:(TGAudioMetadata *)tags {
	if ([m[@"audioPerformer"] length])
		return m[@"audioPerformer"];
	if (tags.performer.length)
		return tags.performer;
	return TGL(@"MediaPlayer.UnknownArtist", @"Unknown Artist");
}

- (NSString *)audioArtistFor:(NSDictionary *)m
						tags:(TGAudioMetadata *)tags
					   state:(NSDictionary *)state {
	long long size = [state[@"size"] longLongValue];
	if ([state[@"active"] boolValue] && ![state[@"local"] boolValue] && size > 0)
		return [NSString stringWithFormat:@"%@ / %@",
			TGFormatByteCount([state[@"downloaded"] longLongValue]),
			TGFormatByteCount(size)];
	return [self audioPerformerFor:m tags:tags];
}

- (NSString *)audioLiveClockTextWithDuration:(NSInteger)fallback {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	NSInteger total = (player.duration > 0.5) ? (NSInteger)player.duration : fallback;
	return [NSString stringWithFormat:@"%@ / %@",
		[self clockTextForSeconds:(NSInteger)player.currentTime],
		[self clockTextForSeconds:total]];
}

- (NSString *)audioClockTextFor:(NSDictionary *)m current:(BOOL)current {
	NSInteger total = [m[@"duration"] integerValue];
	if (!current)
		return [self clockTextForSeconds:total];
	return [self audioLiveClockTextWithDuration:total];
}

- (NSString *)audioClockTemplateFor:(NSDictionary *)m {
	NSString *total = [self clockTextForSeconds:[m[@"duration"] integerValue]];
	NSMutableString *elapsed = [NSMutableString stringWithCapacity:total.length];
	for (NSInteger i = 0; i < total.length; i++) {
		unichar c = [total characterAtIndex:i];
		[elapsed appendFormat:@"%C", (unichar)((c == ':') ? c : '0')];
	}
	return [NSString stringWithFormat:@"%@ / %@", elapsed, total];
}

- (TGRichTextLayout *)quoteLayoutFor:(NSDictionary *)m
								text:(NSString *)text
							   width:(CGFloat)width {
	NSArray *entities = [self quoteEntitiesFor:m];
	if (!entities.count || !text.length || width < 10)
		return nil;

	BOOL isFragment = [m[@"replyIsFragment"] boolValue];
	NSInteger shift = isFragment ? 1 : 0;
	NSInteger surroundingQuoteMarks = isFragment ? 2 : 0;
	NSString *fragment = m[@"replyText"];
	if (text.length != fragment.length + (NSUInteger)surroundingQuoteMarks)
		return nil;
	NSMutableArray *shifted = [NSMutableArray arrayWithCapacity:entities.count];
	for (NSDictionary *entity in entities) {
		if (![entity isKindOfClass:NSDictionary.class])
			continue;
		NSMutableDictionary *moved = [entity mutableCopy];
		moved[@"offset"] = @([entity[@"offset"] integerValue] + shift);
		[shifted addObject:moved];
	}

	TGTheme *theme = [TGTheme shared];
	UIColor *accent = TGActiveChatThemeAccentColour(self.chatId) ?: [theme accentColour];
	TGRichTextPalette *palette =
		[TGRichTextPalette paletteWithFont:[UIFont systemFontOfSize:13]
									colour:[theme primaryTextColour]
								linkColour:TGMessageLinkColour()
							  accentColour:accent];
	palette.underlineLinks = NO;
	NSAttributedString *styled = TGRichTextBuild(text, shifted, palette, YES);
	NSTextAlignment alignment = TGTextIsRightToLeft(text) ? NSTextAlignmentRight : NSTextAlignmentLeft;
	return [TGRichTextLayout layoutWithText:styled width:width maxLines:1
								  alignment:alignment
							 expandedBlocks:nil];
}

- (NSString *)bubbleReuseIdentifierAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *m = [self messageAtRow:indexPath.row];
	if (!m)
		return @"TGBubbleCell.Empty";
	BOOL isAlbum = [self albumAtRow:indexPath.row] != nil &&
		[self mosaicForRow:indexPath.row] != nil;
	NSString *tgsPath = [m[@"docName"] isEqualToString:@"tgs"]
		? self.lottiePaths[m[@"docId"]]
		: nil;
	return TGBubbleReuseIdentifierForKind(m[@"kind"], isAlbum, [m[@"service"] boolValue],
		tgsPath != nil, [self messageIsSticker:m], [self messageBurnsOnOpening:m]);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *reuse = [self bubbleReuseIdentifierAtIndexPath:indexPath];
	if ([reuse isEqualToString:@"TGBubbleCell.Empty"]) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:reuse];
		return cell;
	}
	[self tg_refreshLayoutContextIfNeeded];
	return [self.layoutBridge cellForRow:indexPath.row inTable:tableView];
}

@end
