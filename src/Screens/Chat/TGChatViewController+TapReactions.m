#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGLocalization.h"
#import "TGBubbleCellBase.h"
#import "TGEmoji.h"
#import "TGRichText.h"
#import "TGTheme.h"
#import "TGSnackbar.h"
#import "TGActionSheet.h"
#import "TGPopupMenu.h"
#import "TGForwardPicker.h"
#import "TGClient+MessageContent.h"
#import "TGReactionPickerView.h"
#import "TGMessageActionsSheet.h"
#import "TGTextSelectionOverlay.h"
#import "TGClient+Reactions.h"
#import "TGQuotePickerViewController.h"
#import "TGAlertView.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <MediaPlayer/MediaPlayer.h>
#import "TGLazyFramework.h"
#import "TGAssetPicker.h"

@implementation TGChatViewController (TapReactions)

- (void)showReactionPickerForMessage:(int64_t)messageId fromView:(UIView *)source {
	CGRect rect = [source convertRect:source.bounds toView:self.view];
	__weak typeof(self) weakSelf = self;
	[TGReactionPickerView showForMessage:messageId
								  inChat:self.chatId
								fromRect:rect
								  inView:self.view
								  picked:^(NSString *emoji, BOOL nowChosen) {
									  TGChatViewController *strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  [strongSelf.reactionChipsRequested removeObject:@(messageId)];
									  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
										  dispatch_get_main_queue(), ^{ [strongSelf reload]; });
								  }];
}

- (NSString *)textOf:(NSDictionary *)m {
	if ([m[@"id"] isKindOfClass:NSNumber.class]) {
		NSString *summary = self.aiSummaries[m[@"id"]];
		if ([summary isKindOfClass:NSString.class] && summary.length)
			return [NSString stringWithFormat:@"%@\n%@",
				TGL(@"Conversation.Summary.Title", @"AI summary (machine-generated)"), summary];
		NSString *translated = self.translations[m[@"id"]];
		if ([translated isKindOfClass:NSString.class] && translated.length)
			return translated;
	}
	return [self originalTextOf:m];
}

- (NSString *)originalTextOf:(NSDictionary *)m {
	NSString *text = m[@"text"];
	if ([text isKindOfClass:NSString.class] && text.length)
		return text;
	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : nil;
	NSString *placeholder = kind.length
		? [[TGClient shared] placeholderTextForContentKind:kind]
		: nil;
	if (placeholder.length)
		return placeholder;
	return [text isKindOfClass:NSString.class] ? text : nil;
}

- (NSArray *)originalEntitiesOf:(NSDictionary *)m {
	NSArray *entities = m[@"entities"];
	return [entities isKindOfClass:NSArray.class] ? entities : @[];
}

- (BOOL)messageHasQuotableText:(NSDictionary *)m {
	NSString *text = m[@"text"];
	return [text isKindOfClass:NSString.class] && text.length > 0;
}

- (void)showActionsForRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	if (!m)
		return;
	if ([m[@"service"] boolValue])
		return;
	if (![m[@"id"] isKindOfClass:NSNumber.class])
		return;
	self.actionMessage = m;

	if ([self offerBotButtonsForRow:row message:m])
		return;
	[self showActionsSheetForRow:row];
}

- (void)showActionsSheetForRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	if (![m[@"id"] isKindOfClass:NSNumber.class])
		return;
	self.actionMessage = m;

	BOOL mine = [m[@"outgoing"] boolValue];
	int64_t messageId = [m[@"id"] longLongValue];

	CGRect rect = [self.table rectForRowAtIndexPath:
			[NSIndexPath indexPathForRow:row inSection:0]];
	CGPoint where = [self.table convertPoint:
			CGPointMake(mine ? CGRectGetMaxX(rect) - 60 : 60, CGRectGetMaxY(rect) - 8)
									  toView:self.view];

	[self.actionsSheet dismiss];
	TGMessageActionsSheet *sheet = [TGMessageActionsSheet sheetForMessage:messageId inChat:self.chatId];
	sheet.messageText = [self textOf:m];
	sheet.canQuoteText = [self messageHasQuotableText:m];
	sheet.mediaKind = [self savableMediaKindFor:m];
	sheet.pinned = [self isMessagePinnedLocally:messageId];
	sheet.allowsSelection = YES;
	sheet.canTranscribe = [self messageCanBeTranscribed:m];
	sheet.transcriptShown = (self.transcripts[@(messageId)] != nil);
	sheet.summaryShown = (self.aiSummaries[@(messageId)] != nil);
	sheet.translationShown = (self.translations[@(messageId)] != nil);
	sheet.factCheckText = [m[@"factCheckText"] isKindOfClass:NSString.class]
		? m[@"factCheckText"]
		: nil;
	self.actionsSheet = sheet;
	[self setPressedRow:row];

	__weak typeof(self) weakSelf = self;
	[sheet presentAtPoint:where inView:self.view completion:^(NSString *action) {
		[weakSelf setPressedRow:-1];
		if (action)
			[weakSelf performMessageAction:action];
	}];
}

- (NSString *)savableMediaKindFor:(NSDictionary *)m {
	if ([self messageBurnsOnOpening:m])
		return nil;
	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	if ([kind isEqualToString:@"messagePhoto"])
		return @"photo";
	if ([kind isEqualToString:@"messageVideo"] || [kind isEqualToString:@"messageVideoNote"])
		return @"video";
	if ([kind isEqualToString:@"messageAnimation"])
		return @"gif";
	return nil;
}

- (TGRichTextLayout *)textSelectionLayoutFor:(NSDictionary *)m text:(NSString *)text {
	if (!text.length)
		return nil;
	NSArray *entities = [self entitiesOf:m] ?: @[];
	CGFloat maxW = floorf([self maxBubbleWidthFor:m] - 2 * kPadH);
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	BOOL revealed = messageId && [self.revealedSpoilers containsObject:messageId];
	NSSet *expanded = messageId ? self.expandedQuotes[messageId] : nil;
	NSAttributedString *styled = TGRichTextBuild(text, entities, [self bodyPaletteFor:m],
		revealed);
	NSTextAlignment alignment = TGTextIsRightToLeft(text) ? NSTextAlignmentRight : NSTextAlignmentLeft;
	return [TGRichTextLayout layoutWithText:styled width:maxW maxLines:0 alignment:alignment expandedBlocks:expanded];
}

- (void)beginTextSelectionForMessage:(NSDictionary *)m {
	if (![m[@"id"] isKindOfClass:NSNumber.class])
		return;
	int64_t messageId = [m[@"id"] longLongValue];

	NSNumber *rowNumber = self.rowByMessageId[@(messageId)];
	if (![rowNumber isKindOfClass:NSNumber.class])
		return;
	NSIndexPath *path = [NSIndexPath indexPathForRow:rowNumber.integerValue inSection:0];
	UITableViewCell *cell = [self.table cellForRowAtIndexPath:path];
	TGEmojiLabel *body = [self richBodyLabelForCell:cell];
	if (!body || body.hidden)
		return;

	NSString *bodyText = body.text;
	if (!bodyText.length)
		return;
	TGRichTextLayout *layout = body.richLayout
		?: [self textSelectionLayoutFor:m text:bodyText];
	if (!layout)
		return;

	[self.textSelectionOverlay dismiss];

	TGTextSelectionOverlay *overlay = [[TGTextSelectionOverlay alloc]
		initWithFrame:self.view.bounds];
	overlay.text = bodyText;
	overlay.layout = layout;
	overlay.bodyFrame = [body convertRect:body.bounds toView:self.view];

	__weak typeof(self) weakSelf = self;
	overlay.onCopy = ^(NSString *selected) {
		if (selected.length)
			[UIPasteboard generalPasteboard].string = selected;
		[weakSelf endTextSelection];
	};
	overlay.onDismiss = ^{
		[weakSelf endTextSelection];
	};

	self.textSelectionOverlay = overlay;
	self.table.scrollEnabled = NO;
	[overlay presentInView:self.view];
}

- (void)endTextSelection {
	[self.textSelectionOverlay dismiss];
	self.textSelectionOverlay = nil;
	self.table.scrollEnabled = YES;
}

- (NSInteger)pressedRow {
	return _pressedRow;
}

- (void)setPressedRow:(NSInteger)row {
	if (_pressedRow == row)
		return;
	NSInteger before = _pressedRow;
	_pressedRow = row;
	if (before >= 0)
		[self repaintBubbleArtworkOnRow:before];
	if (row >= 0)
		[self repaintBubbleArtworkOnRow:row];
}

- (UIImageView *)tg_pressableBubbleArtworkViewForCell:(UITableViewCell *)cell {
	if ([cell isKindOfClass:TGBubbleCellBase.class]) {
		TGBubbleCellBase *bubbleCell = (TGBubbleCellBase *)cell;
		return bubbleCell.bubbleArtwork.hidden ? nil : bubbleCell.bubbleArtwork;
	}
	return nil;
}

- (void)repaintBubbleArtworkOnRow:(NSInteger)row {
	if (row < 0 || row >= [self displayRowCount])
		return;
	NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
	UITableViewCell *cell = [self.table cellForRowAtIndexPath:path];
	UIImageView *artworkView = [self tg_pressableBubbleArtworkViewForCell:cell];
	if (!artworkView)
		return;
	NSDictionary *m = [self messageAtRow:row];
	if (!m)
		return;

	BOOL mine = [m[@"outgoing"] boolValue];
	BOOL lit = (row == _pressedRow);
	NSString *name = mine ? @"Msg_Out" : @"Msg_In";
	if (lit)
		name = [name stringByAppendingString:@"_Selected"];
	UIImage *art = [UIImage imageNamed:name];
	if (!art)
		art = [UIImage imageNamed:(mine ? @"Msg_Out" : @"Msg_In")];
	if (!art)
		return;
	if (!lit) {
		CATransition *fade = [CATransition animation];
		fade.duration = 0.25;
		fade.type = kCATransitionFade;
		[artworkView.layer addAnimation:fade forKey:@"tgBubbleFade"];
	}
	artworkView.image = [art stretchableImageWithLeftCapWidth:(mine ? 15 : 20)
												 topCapHeight:15];
}

- (void)messageDoubleTapped:(UITapGestureRecognizer *)tap {
	NSIndexPath *path = [self.table indexPathForRowAtPoint:[tap locationInView:self.table]];
	NSDictionary *m = path ? [self messageAtRow:path.row] : nil;
	if (!m)
		return;
	if ([m[@"service"] boolValue] || ![m[@"id"] isKindOfClass:NSNumber.class])
		return;
	[self sendQuickReactionToMessage:[m[@"id"] longLongValue]];
}

- (void)sendQuickReactionToMessage:(int64_t)messageId {
	if (!messageId || self.selecting)
		return;
	TGClient *client = [TGClient shared];
	if ([client isReactionInFlightForMessage:messageId inChat:self.chatId emoji:[client quickReactionEmoji]])
		return;
	NSNumber *requestKey = @(messageId);
	if ([self.quickReactionRequestsInFlight containsObject:requestKey])
		return;
	[self.quickReactionRequestsInFlight addObject:requestKey];
	__weak typeof(self) weakSelf = self;
	[client availableReactionsForMessage:messageId inChat:self.chatId completion:^(NSDictionary *info) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *reason = [info[@"reason"] isKindOfClass:NSString.class]
			? info[@"reason"]
			: @"";
		if (reason.length) {
			[strongSelf.quickReactionRequestsInFlight removeObject:requestKey];
			[strongSelf showAlertTitle:@"" message:reason];
			return;
		}
		NSArray *allowed = [info[@"allEmoji"] isKindOfClass:NSArray.class]
			? info[@"allEmoji"]
			: nil;
		if (allowed.count == 0) {
			[strongSelf.quickReactionRequestsInFlight removeObject:requestKey];
			UIView *host = strongSelf.navigationController.view ?: strongSelf.view;
			if (host)
				[TGSnackbar showInView:host
								   text:TGL(@"Chat.SendReactionRestricted", @"You cannot send reactions in this chat.")
								seconds:2
							   onCommit:nil];
			return;
		}
		NSString *emoji = [[TGClient shared] quickReactionEmoji];
		if (allowed.count && ![allowed containsObject:emoji])
			emoji = [allowed objectAtIndex:0];
		if (!emoji.length) {
			[strongSelf.quickReactionRequestsInFlight removeObject:requestKey];
			return;
		}
		[client toggleReaction:emoji onMessage:messageId inChat:strongSelf.chatId big:NO completion:^(BOOL __unused nowChosen, BOOL succeeded) {
			TGChatViewController *innerSelf = weakSelf;
			[innerSelf.quickReactionRequestsInFlight removeObject:requestKey];
			if (!innerSelf)
				return;
			if (!succeeded) {
				[innerSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotUpdateReaction", @"Could not update the reaction")];
				return;
			}
			[innerSelf.reactionChipsRequested removeObject:@(messageId)];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{ [innerSelf reload]; });
		}];
	}];
}

@end
