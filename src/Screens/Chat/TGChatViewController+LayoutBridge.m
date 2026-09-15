#import "TGClient+ChatManagement.h"
#import "TGClient+UserStatus.h"
#import "TGSenderNameColour.h"
#import "TGDurationText.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGChatLayoutBridge.h"
#import "TGChatPresenter.h"
#import "TGChatLayoutContext.h"
#import "TGMessageItem.h"
#import "TGMessageItemBuilder.h"
#import "TGMessageItemResolvedInputs.h"
#import "TGMessageLayoutBuilder+Private.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGLocalization.h"
#import "TGIcons.h"
#import "TGChatMessageLayout.h"
#import "TGClient+ChatList.h"
#import "TGMessageRowCell.h"

@implementation TGChatViewController (LayoutBridge)

- (TGChatLayoutContext *)tg_buildLayoutContext {
	CGFloat width = self.table ? self.table.bounds.size.width : self.view.bounds.size.width;
	return [[TGChatLayoutContext alloc]
		initWithTableWidth:width
			  baseFontSize:TGMessageBaseFontSize()
			   screenScale:[UIScreen mainScreen].scale
				   isGroup:self.group
			  isWideLayout:TGChatIsPad()
			   isSelecting:self.selecting
				generation:self.layoutContextGeneration];
}

- (void)tg_captureLayoutContextInputs {
	self.layoutContextWidth = self.table ? self.table.bounds.size.width : self.view.bounds.size.width;
	self.layoutContextFontSize = TGMessageBaseFontSize();
	self.layoutContextIsGroup = self.group;
	self.layoutContextIsWide = TGChatIsPad();
	self.layoutContextIsSelecting = self.selecting;
}

- (void)tg_refreshLayoutContextIfNeeded {
	CGFloat width = self.table ? self.table.bounds.size.width : self.view.bounds.size.width;
	CGFloat fontSize = TGMessageBaseFontSize();
	BOOL isWide = TGChatIsPad();
	BOOL isSelecting = self.selecting;
	BOOL isGroup = self.group;

	BOOL changed = fabsf(width - self.layoutContextWidth) > 0.5f ||
		fabsf(fontSize - self.layoutContextFontSize) > 0.01f ||
		isGroup != self.layoutContextIsGroup ||
		isWide != self.layoutContextIsWide ||
		isSelecting != self.layoutContextIsSelecting;
	if (!changed)
		return;

	self.layoutContextGeneration++;
	self.layoutBridge.context = [self tg_buildLayoutContext];
	[self tg_captureLayoutContextInputs];
}

- (TGMessageItemResolvedInputs *)tg_resolvedInputsForMessage:(NSDictionary *)m
													   atRow:(NSInteger)row
												sideRevision:(uint32_t)sideRevision {
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];

	BOOL mine = [m[@"outgoing"] boolValue];
	int64_t senderId = [m[@"senderId"] longLongValue];
	int64_t senderChatId = [m[@"senderChatId"] longLongValue];
	BOOL isChannelPost = [m[@"channelPost"] boolValue];
	resolved.senderChatId = senderChatId;

	if (self.group && !mine) {
		resolved.senderDisplayName = (senderChatId != 0 && !isChannelPost)
			? [[TGClient shared] cachedTitleForChatId:senderChatId]
			: [[TGClient shared] nameForUserId:senderId];
	} else {
		resolved.senderDisplayName = nil;
	}

	NSString *forwardFrom = m[@"forward"];
	if (forwardFrom.length) {
		int64_t originChat = [m[@"forwardChatId"] longLongValue];
		NSString *originTitle = originChat ? [[TGClient shared] cachedTitleForChatId:originChat] : nil;
		NSString *from = originTitle.length ? originTitle : forwardFrom;
		resolved.forwardDisplayName = from;

		if (self.chatId == [[TGClient shared] savedMessagesChatId]) {
			resolved.forwardAvatarUserId = [m[@"forwardUserId"] longLongValue];
			resolved.forwardAvatarChatId = [m[@"forwardChatId"] longLongValue];
		}
	}
	resolved.forwardOriginIsReachable = [self forwardOriginIsReachable:m];

	int64_t viaBotId = [m[@"viaBotId"] longLongValue];
	if (viaBotId != 0) {
		NSString *viaBotUsername = [[TGClient shared] usernameForUserId:viaBotId];
		resolved.viaBotDisplayName = viaBotUsername.length
			? [@"@" stringByAppendingString:viaBotUsername]
			: nil;
	}

	resolved.bodyText = [self bubbleTextFor:m];
	resolved.bodyRichLayout = [self bodyLayoutFor:m];
	resolved.stampText = [self stampFor:m];
	resolved.viewCountText = [self viewCountTextFor:m];

	NSString *quoted = [self quoteTextFor:m];
	if (quoted) {
		NSString *quoteBody = [self quoteDisplayTextFor:m];
		if ([m[@"replyIsFragment"] boolValue] && quoteBody.length)
			quoteBody = [NSString stringWithFormat:@"“%@”", quoteBody];
		resolved.quoteBodyText = quoteBody;
		resolved.quoteAuthorText = [self quoteAuthorFor:m] ?: TGL(@"Notification.Reply", @"Reply");
		resolved.quoteThumbnailSize = [self quoteThumbnailFor:m] ? CGSizeMake(32, 32) : CGSizeZero;

		CGFloat quoteTextX = kPadH + (resolved.quoteThumbnailSize.width > 0 ? 45 : 8);
		CGFloat quoteW = MAX([self maxBubbleWidthFor:m] - quoteTextX - kPadH, 40);
		resolved.quoteRichLayout = [self quoteLayoutFor:m text:quoteBody width:quoteW];
	}

	resolved.serviceLineText = [m[@"service"] boolValue] ? [self serviceLineFor:m] : nil;

	NSNumber *messageIdNumber = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	NSArray *fresherChips = messageIdNumber ? self.reactionChips[messageIdNumber] : nil;
	NSArray *ownChips = [m[@"reactionChips"] isKindOfClass:NSArray.class] ? m[@"reactionChips"] : nil;
	resolved.reactionChips = fresherChips ?: ownChips;
	resolved.reactionRowSize = [self chipsRowSizeFor:m];

	resolved.linkPreview = [self previewFor:m];
	if (resolved.linkPreview) {
		NSNumber *photoFileId = [resolved.linkPreview[@"photoFileId"] isKindOfClass:NSNumber.class]
			? resolved.linkPreview[@"photoFileId"]
			: nil;
		UIImage *shown = photoFileId ? self.images[photoFileId] : nil;
		resolved.linkPreviewImageSize = shown ? shown.size : CGSizeZero;
	}

	resolved.pictureSize = [self imageSizeForRow:row];
	resolved.pictureLoadFailed = [self pictureFailedFor:m] && ![self imageFor:m];
	resolved.mediaBadgeText = [self mediaBadgeTextFor:m];

	NSNumber *lottieDocId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
	if (lottieDocId && [m[@"docName"] isEqualToString:@"tgs"])
		resolved.lottiePath = self.lottiePaths[lottieDocId];

	NSString *rowKind = m[@"kind"];
	BOOL isContactRow = [rowKind isEqualToString:@"messageContact"];
	BOOL isAudioRow = [rowKind isEqualToString:@"messageAudio"];
	if (isContactRow || isAudioRow || [rowKind isEqualToString:@"messageDocument"]) {
		NSDictionary *state = [self fileStateFor:m];
		resolved.fileShowsThumbnail = [self fileCellShowsThumbnailFor:m];
		resolved.fileTileSide = [self fileCellTileSideFor:m];
		resolved.fileCaptionText = [self fileCaptionFor:m];
		if (isContactRow) {
			resolved.fileTitleText = [self contactNameFor:m];
			resolved.fileMetaText = [self contactPhoneFor:m];
		} else if (isAudioRow) {
			TGAudioMetadata *tags = [self audioTagsFor:m];
			resolved.fileTitleText = [self audioTitleFor:m tags:tags];
			resolved.fileMetaText = [self audioArtistFor:m tags:tags state:state];
			resolved.audioClockTemplate = [self audioClockTemplateFor:m];
			CGFloat tileSide = resolved.fileTileSide;
			UIImage *cover = [TGAudioMetadata artworkTileOfSide:tileSide cornerRadius:4 scrim:NO forMetadata:tags];
			resolved.fileHasCoverArt = (cover != nil);
		} else {
			resolved.fileTitleText = [self fileTitleFor:m];
			resolved.fileMetaText = [self fileSubtitleFor:m state:state];
		}
	}

	if ([rowKind isEqualToString:@"messageVoiceNote"]) {
		resolved.voiceDurationText = [self clockTextForSeconds:[m[@"duration"] integerValue]];
		resolved.transcriptText = [self transcriptFor:m];
	}

	if ([rowKind isEqualToString:@"messageVideoNote"])
		resolved.roundNoteDurationText = [self clockTextForSeconds:[m[@"duration"] integerValue]];

	NSArray *album = [self albumAtRow:row];
	if (album.count > 1) {
		NSDictionary *mosaic = [self mosaicForRow:row];
		NSArray *frames = mosaic[@"frames"];
		resolved.mosaicSize = mosaic ? [mosaic[@"size"] CGSizeValue] : CGSizeZero;
		resolved.mosaicTileFrames = frames ?: @[];
		NSMutableArray *positions = [NSMutableArray arrayWithCapacity:frames.count];
		for (NSInteger i = 0; i < frames.count; i++)
			[positions addObject:@(i)];
		resolved.mosaicTilePositions = positions;

		NSDictionary *caption = [self albumCaptionMessageAtRow:row];
		resolved.bodyText = caption ? [self bubbleTextFor:caption] : nil;
		resolved.bodyRichLayout = caption ? [self bodyLayoutFor:caption] : nil;
	}

	if ([m[@"kind"] isEqualToString:@"messageCall"] || [m[@"kind"] isEqualToString:@"messageGroupCall"]) {
		NSString *title = [m[@"callTitle"] isKindOfClass:NSString.class] && [m[@"callTitle"] length]
			? m[@"callTitle"]
			: ([self textOf:m] ?: @"");
		NSInteger seconds = [m[@"callDuration"] integerValue];
		NSString *length = seconds > 0 ? TGDurationText(seconds) : nil;
		NSString *stamp = [self stampFor:m];
		resolved.callTitleText = title;
		resolved.callDetailText = length.length
			? [NSString stringWithFormat:@"%@, %@", stamp, length]
			: stamp;
	}

	if ([m[@"kind"] isEqualToString:@"messagePoll"]) {
		resolved.pollQuestionText = m[@"pollQuestion"] ?: TGL(@"Watch.Message.Poll", @"Poll");
		resolved.pollSubtitleText = [self pollSubtitleFor:m];
	}

	if ([m[@"kind"] isEqualToString:@"messageChecklist"])
		resolved.checklistTitleText = m[@"checklistTitle"]
			?: TGL(@"Attachment.Todo", @"Checklist");

	NSString *sendState = [self sendStateForMessage:m];
	if ([sendState isEqualToString:@"pending"])
		resolved.sendState = TGMessageSendStatePending;
	else if ([sendState isEqualToString:@"failed"])
		resolved.sendState = TGMessageSendStateFailed;
	else
		resolved.sendState = TGMessageSendStateSent;

	resolved.opensNewDay = [self rowOpensNewDay:row];
	resolved.carriesUnreadBand = (row == [self unreadDividerRow]);
	long long readTo = [[TGClient shared] lastReadOutgoingMessageInChat:self.chatId];
	long long thisId = [m[@"id"] longLongValue];
	resolved.deliveryWasRead = thisId != 0 && readTo >= thisId;
	resolved.dayText = resolved.opensNewDay ? [self dayStringForMessage:m] : nil;

	resolved.sideRevision = sideRevision;

	return resolved;
}

- (TGMessageItem *)tg_itemForRow:(NSInteger)row reuseIdentifier:(NSString *)reuseIdentifier {
	NSDictionary *m = [self messageAtRow:row];
	if (!m)
		return nil;

	int64_t messageId = [m[@"id"] longLongValue];
	uint32_t sideRevision = [self.presenter sideRevisionForMessageId:messageId];

	NSArray *cached = self.stableMessageEntries[@(messageId)];
	if (cached && cached[0] == m && [cached[1] unsignedIntValue] == sideRevision &&
		[cached[3] isEqualToString:reuseIdentifier])
		return cached[2];

	TGMessageItemResolvedInputs *resolved = [self tg_resolvedInputsForMessage:m atRow:row sideRevision:sideRevision];

	NSNumber *fresherCommentCount = self.commentCounts[@(messageId)];
	NSDictionary *effectiveMessage = m;
	if (fresherCommentCount) {
		NSMutableDictionary *patched = [m mutableCopy];
		patched[@"commentCount"] = fresherCommentCount;
		effectiveMessage = patched;
	}

	TGMessageItem *item = [TGMessageItemBuilder
		itemFromFlatMessage:effectiveMessage
					 chatId:self.chatId
			reuseIdentifier:reuseIdentifier
			   albumMembers:@[]
				   resolved:resolved];
	self.stableMessageEntries[@(messageId)] = @[ m, @(sideRevision), item, reuseIdentifier ];
	return item;
}

- (void)tg_rebuildLayoutBridgeItems {
	[self.layoutBridge removeAllItems];
	NSInteger count = [self displayRowCount];
	for (NSInteger row = 0; row < count; row++) {
		NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
		NSString *reuse = [self bubbleReuseIdentifierAtIndexPath:path];
		TGMessageItem *item = [self tg_itemForRow:row reuseIdentifier:reuse];
		if (item)
			[self.layoutBridge setItem:item forRow:row];
	}
}

- (void)tg_invalidateLayoutForMessageId:(int64_t)messageId {
	NSNumber *key = @(messageId);
	[self.stableMessageEntries removeObjectForKey:key];
	[self.layoutBridge invalidateMessageId:messageId];

	NSNumber *row = self.rowByMessageId[key];
	if (!row)
		return;
	NSIndexPath *path = [NSIndexPath indexPathForRow:row.integerValue inSection:0];
	NSString *reuse = [self bubbleReuseIdentifierAtIndexPath:path];
	TGMessageItem *item = [self tg_itemForRow:row.integerValue reuseIdentifier:reuse];
	if (item)
		[self.layoutBridge setItem:item forRow:row.integerValue];
}

- (void)attachInteractionsToRowCell:(TGMessageRowCell *)cell {
	if ([cell conformsToProtocol:@protocol(TGReplySwipeCell)])
		[self attachReplySwipeToRowCell:(UITableViewCell<TGReplySwipeCell> *)cell];
	[self attachPeerGesturesToRowCell:cell];
}

- (void)resetRowCellSwipeIfNeeded:(TGMessageRowCell *)cell {
	if (![cell conformsToProtocol:@protocol(TGReplySwipeCell)])
		return;
	UITableViewCell<TGReplySwipeCell> *swipeCell = (UITableViewCell<TGReplySwipeCell> *)cell;
	if (swipeCell != self.swipingCell)
		[self resetReplySwipeOnCell:swipeCell];
}

- (void)tg_invalidateLayoutForRepliesToMessageId:(int64_t)originId {
	for (NSDictionary *m in self.messages) {
		NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
		NSNumber *pinnedId = [m[@"pinnedId"] isKindOfClass:NSNumber.class] ? m[@"pinnedId"] : nil;
		BOOL referencesOrigin = (replyId && replyId.longLongValue == originId) ||
			(pinnedId && pinnedId.longLongValue == originId);
		if (!referencesOrigin)
			continue;
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (messageId)
			[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	}
}

- (void)tg_invalidateLayoutForSenderNameArrived:(int64_t)userId {
	for (NSDictionary *m in self.messages) {
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (!messageId)
			continue;

		BOOL ownSenderMatches = [m[@"senderId"] longLongValue] == userId;
		BOOL viaBotMatches = [m[@"viaBotId"] longLongValue] == userId;

		BOOL quotedSenderMatches = NO;
		NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
		if (replyId) {
			NSDictionary *original = self.quotes[replyId];
			quotedSenderMatches = original &&
				[original[@"senderId"] longLongValue] == userId;
		}

		if (ownSenderMatches || viaBotMatches || quotedSenderMatches)
			[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	}
}

- (void)jumpToQuoteAtRow:(NSInteger)row {
	if (self.selecting)
		return;
	NSDictionary *m = [self messageAtRow:row];
	NSNumber *replyTo = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	if (!replyTo)
		return;

	int64_t replyChatId = [m[@"replyChatId"] longLongValue];
	if (replyChatId && replyChatId != self.chatId) {
		NSString *cachedTitle = [[TGClient shared] cachedTitleForChatId:replyChatId];
		NSString *title = cachedTitle.length ? cachedTitle : m[@"replyAuthor"];
		[self openForwardOriginChat:replyChatId title:title message:replyTo.longLongValue];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[self jumpToMessageId:replyTo.longLongValue inCurrentChatNotFound:^{
		[weakSelf showAlertTitle:@"" message:TGL(@"Conversation.MessageDoesntExist", @"Message doesn't exist")];
	}];
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
		didTapPart:(TGBubbleCellPart)part
			 atRow:(NSInteger)row {
	switch (part) {
		case TGBubbleCellPartQuote:
			[self jumpToQuoteAtRow:row];
			return;
		case TGBubbleCellPartForwardJump:
			[self openForwardOriginForRow:row];
			return;
		case TGBubbleCellPartDayPlate: {
			NSDictionary *m = [self messageAtRow:row];
			[self openDayCalendarAroundDate:[m[@"date"] doubleValue]];
			return;
		}
		case TGBubbleCellPartComments:
			[self openCommentsForRow:row];
			return;
		case TGBubbleCellPartPollRetract:
			[self retractPollVoteForRow:row];
			return;
		case TGBubbleCellPartPollAdd:
			[self promptAddPollOptionForRow:row];
			return;
		case TGBubbleCellPartChecklistAdd:
			[self promptAddChecklistTaskForRow:row];
			return;
		default:
			return;
	}
}

- (NSString *)bubbleCell:(TGMessageRowCell *)__unused cell
	 unreadBandTextAtRow:(NSInteger)__unused row {
	return TGL(@"Conversation.UnreadMessages", @"Unread Messages");
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
	didTapReactionEmoji:(NSString *)__unused emoji
				  atRow:(NSInteger)__unused row {
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
	didTapAlbumTileAtIndex:(NSUInteger)index
					 atRow:(NSInteger)row {
	NSArray *album = [self albumAtRow:row];
	if (index >= album.count)
		return;
	NSDictionary *m = album[index];
	if ([self revealMediaSpoilerIfActiveForMessage:m row:row])
		return;
	[self showGalleryForMessage:m];
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
	didTapChecklistTaskAtIndex:(NSUInteger)index
						 atRow:(NSInteger)row {
	[self toggleChecklistTaskAtIndex:index atRow:row];
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
	didLongPressChecklistTaskAtIndex:(NSUInteger)index
							 atRow:(NSInteger)row {
	[self showChecklistTaskMenuAtIndex:index atRow:row];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	[self tg_refreshLayoutContextIfNeeded];
	return [self.layoutBridge heightForRow:indexPath.row];
}

- (NSDictionary *)albumCaptionMessageAtRow:(NSInteger)row {
	for (NSDictionary *member in [self albumAtRow:row])
		if ([[self textOf:member] length])
			return member;
	return nil;
}

UIColor *TGMessageDateColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0x23 / 255.0f
								 green:0x2d / 255.0f
								  blue:0x37 / 255.0f
								 alpha:1.0f];
	return colour;
}

UIColor *TGSenderColour(int64_t userId) {
	NSInteger rgb = TGSenderNameRgb([[TGClient shared] cachedAccentRgbForSenderId:userId], userId);
	return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f
						   green:((rgb >> 8) & 0xff) / 255.0f
							blue:(rgb & 0xff) / 255.0f
						   alpha:1.0f];
}

@end
