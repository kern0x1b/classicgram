#import "TGChatViewController.h"
#import "TGFailedMessageTitle.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "UIImage+WebP.h"
#import "TGLazyFramework.h"
#import "TGLottieView.h"
#import "TGClient+Messages.h"
#import "TGClient+MessageContent.h"
#import "TGClient+Premium.h"
#import "TGClient+Notifications.h"
#import "TGFlattenMessage.h"
#import "TGFileDownloadService.h"
#import "TGUserDisplayNameStore.h"
#import "TGLocalization.h"
#import "TGMessageRowCell.h"
#import "TGChatMessageLayout.h"
#import "TGImageDecode.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGMosaicLayout.h"
#import "TGCallViewController.h"
#import "TGActionSheet.h"
#import "TGMediaFullscreenController.h"
#import "TGMusicPlayer.h"
#import "TGStarsViewController.h"
#import "TGPremiumViewController.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGTheme.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation TGChatViewController (Taps)

- (void)simulateTapOnRow:(NSInteger)row {
	NSDictionary *tapped = [self messageAtRow:row];
	if (!tapped) {
		NSLog(@"tap: row %ld out of range (%ld)",
			(long)row, (long)[self displayRowCount]);
		return;
	}
	NSLog(@"tap: row %ld, kind %@", (long)row, tapped[@"kind"]);
	[self tableView:self.table
		didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
}

- (void)simulateTapOnDayPlate {
	for (UITableViewCell *visible in [self.table visibleCells]) {
		if (![visible isKindOfClass:TGMessageRowCell.class])
			continue;
		TGMessageRowCell *cell = (TGMessageRowCell *)visible;
		if (cell.dayHit.hidden)
			continue;
		NSLog(@"dayplate: tapping %@", cell.dayLabel.text);
		[cell.dayHit sendActionsForControlEvents:UIControlEventTouchUpInside];
		return;
	}
	NSLog(@"dayplate: no day header on screen");
}

- (void)openPhotoMessage:(NSDictionary *)m {
	NSNumber *fileId = [m[@"photoId"] isKindOfClass:NSNumber.class] ? m[@"photoId"] : nil;
	if (!fileId)
		return;
	[self.photoFilesFailed removeObject:fileId];
	[self.photoFilesCancelled removeObject:fileId];
	[self showGalleryForMessage:m];
}

- (void)playMovieMessage:(NSDictionary *)m {
	NSNumber *docId = m[@"docId"];
	if (![docId isKindOfClass:NSNumber.class])
		return;
	[self beginDownloadHUDForFile:[docId longLongValue]];
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:[docId longLongValue] completion:^(NSString *path) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf endDownloadHUDForFile:[docId longLongValue]];
		if (!path)
			return;
		[strongSelf autosaveMessageIfNeeded:m];
		MPMoviePlayerViewController *player = [[TGMPClass(MPMoviePlayerViewController) alloc]
			initWithContentURL:[NSURL fileURLWithPath:path]];
		[strongSelf presentMoviePlayerViewControllerAnimated:player];
	}];
}

- (BOOL)revealMediaSpoilerIfActiveForMessage:(NSDictionary *)m row:(NSInteger)row {
	if (![self mediaSpoilerActiveForMessage:m])
		return NO;
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	if (!messageId)
		return NO;
	[self.revealedMediaSpoilers addObject:messageId];
	[self reloadRow:row];
	return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	NSDictionary *m = [self messageAtRow:indexPath.row];
	if (!m)
		return;
	NSString *kind = m[@"kind"];

	if (self.selecting) {
		[self toggleSelectionOfRow:indexPath.row];
		return;
	}

	if ([self handleRichTapInRow:indexPath.row])
		return;

	if ([self revealMediaSpoilerIfActiveForMessage:m row:indexPath.row])
		return;

	if ([m[@"outgoing"] boolValue] &&
		[self canResendMessage:m] &&
		[m[@"id"] isKindOfClass:NSNumber.class]) {
		[self offerResendOfMessage:[m[@"id"] longLongValue]];
		return;
	}

	if ([kind isEqualToString:@"messagePinMessage"]) {
		[self jumpToPinnedMessageBehind:m];
		return;
	}

	if ([kind isEqualToString:@"messageChatSetBackground"] &&
			[self wallpaperRevertTargetFor:m]) {
		[self offerWallpaperRevertForMessage:m];
		return;
	}

	if ([kind isEqualToString:@"messagePremiumGiftCode"] &&
			[m[@"giftCode"] isKindOfClass:NSString.class] && [m[@"giftCode"] length]) {
		TGPremiumViewController *premium = [[TGPremiumViewController alloc] init];
		[self.navigationController pushViewController:premium animated:YES];
		[premium checkCode:m[@"giftCode"]];
		return;
	}

	if (([kind isEqualToString:@"messageGiveaway"] || [kind isEqualToString:@"messageGiveawayWinners"]) &&
			[m[@"id"] isKindOfClass:NSNumber.class]) {
		[self showGiveawayStatusForMessage:m];
		return;
	}

	NSTimeInterval offset = [self mediaTimestampInMessage:m];
	if (offset >= 0 && [self openMediaTimestamp:offset forRow:indexPath.row])
		return;

	if ([kind isEqualToString:@"messageCall"] && !self.group) {
		[self confirmCallBackWithVideo:[m[@"isVideoCall"] boolValue]];
		return;
	}

	if ([kind isEqualToString:@"messagePoll"] || [kind isEqualToString:@"messageChecklist"])
		return;

	if ([kind isEqualToString:@"messageRichMessage"]) {
		[self openRichMessage:m];
		return;
	}

	if ([kind isEqualToString:@"messageSticker"] &&
		[m[@"stickerSetId"] longLongValue] != 0) {
		[self openStickerSetWithId:[m[@"stickerSetId"] longLongValue]];
		return;
	}

	if ([kind isEqualToString:@"messageInvoice"] && [m[@"id"] isKindOfClass:NSNumber.class]) {
		int64_t messageId = [m[@"id"] longLongValue];
		if ([m[@"invoicePaid"] boolValue])
			[TGStarsViewController presentReceiptForMessage:messageId chat:self.chatId fromViewController:self];
		else
			[TGStarsViewController presentInvoiceForMessage:messageId chat:self.chatId fromViewController:self];
		return;
	}

	if ([kind isEqualToString:@"messagePaidMedia"] && [m[@"id"] isKindOfClass:NSNumber.class] && ![m[@"paidMediaUnlocked"] boolValue]) {
		int64_t paidMessageId = [m[@"id"] longLongValue];
		int64_t stars = [m[@"paidMediaStarCount"] longLongValue];
		[TGStarsViewController
			presentPaidMediaUnlockForMessage:paidMessageId
										chat:self.chatId
								   starCount:stars
						  fromViewController:self];
		return;
	}

	if ([kind isEqualToString:@"messageVoiceNote"] || [kind isEqualToString:@"messageAudio"] ||
		[kind isEqualToString:@"messageVideoNote"] || [kind isEqualToString:@"messageVideo"] ||
		[kind isEqualToString:@"messagePhoto"]) {
		if ([m[@"id"] isKindOfClass:NSNumber.class])
			[[TGClient shared] openContentOfMessage:[m[@"id"] longLongValue]
											 inChat:self.chatId];
	}

	if ([m[@"id"] isKindOfClass:NSNumber.class] && [self largeEmojiCountFor:m] > 0) {
		[self playAnimatedEmojiEffectFor:[m[@"id"] longLongValue]];
		return;
	}

	if ([kind isEqualToString:@"messageDocument"]) {
		NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
		if (!docId)
			return;
		NSNumber *documentMessageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (!documentMessageId)
			return;
		NSString *name = [m[@"docName"] length] ? m[@"docName"] : @"file";
		NSDictionary *state = [self fileStateFor:m];

		if ([state[@"active"] boolValue] && ![state[@"local"] boolValue]) {
			[self.filesBeingFetched removeObject:docId];
			[TGFileDownloadService cancelDownloadOfFile:[docId longLongValue]
										  onlyIfPending:NO];
			[self refreshFileStatusForFile:docId];
			return;
		}

		[self.filesBeingFetched addObject:docId];
		[self refreshFileStatusForFile:docId];
		__weak typeof(self) weakSelf = self;
		[TGFileDownloadService downloadFile:[docId longLongValue] completion:^(NSString *path) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf.filesBeingFetched removeObject:docId];
			[strongSelf refreshFileStatusForFile:docId];
			if (!path)
				return;
			[[TGClient shared] propertiesOfMessage:documentMessageId.longLongValue
											 inChat:strongSelf.chatId
										 completion:^(NSDictionary *properties) {
				TGChatViewController *innerSelf = weakSelf;
				if (!innerSelf)
					return;
				if (![properties[@"canSave"] boolValue]) {
					[TGSnackbar showInView:innerSelf.view
									   text:TGL(@"Toast.SavingContentRestricted", @"Saving content restricted")
									seconds:3 onCommit:nil];
					return;
				}
				NSString *documents = [NSSearchPathForDirectoriesInDomains(
					NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
				NSString *savedName = name.lastPathComponent;
				NSString *docExtension = [m[@"docExtension"] isKindOfClass:NSString.class] ? m[@"docExtension"] : nil;
				if (docExtension.length && [[savedName pathExtension] length] == 0)
					savedName = [savedName stringByAppendingPathExtension:docExtension];
				NSString *saved = [documents stringByAppendingPathComponent:savedName];
				NSFileManager *files = [NSFileManager defaultManager];
				[files removeItemAtPath:saved error:nil];
				NSError *copyError = nil;
				[files copyItemAtPath:path toPath:saved error:&copyError];
				if (copyError)
					return;
				if ([innerSelf offerOpenInForFileAtPath:saved fromRow:indexPath.row])
					return;
				[innerSelf showAlertTitle:name message:TGL(@"WebApp.Download.SavedToFiles", @"Saved to Files.")];
			}];
		}];
		return;
	}

	if ([kind isEqualToString:@"messageVideoNote"]) {
		NSNumber *docId = m[@"docId"];
		if (![docId isKindOfClass:NSNumber.class])
			return;
		[self beginDownloadHUDForFile:[docId longLongValue]];
		NSInteger videoNoteRow = indexPath.row;
		__weak typeof(self) weakSelf = self;
		[TGFileDownloadService downloadFile:[docId longLongValue] completion:^(NSString *path) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf endDownloadHUDForFile:[docId longLongValue]];
			if (path)
				[strongSelf playVideoNoteAtPath:path row:videoNoteRow];
		}];
		return;
	}

	if ([kind isEqualToString:@"messageVideo"] ||
		[kind isEqualToString:@"messageAnimation"]) {
		[self playMovieMessage:m];
		return;
	}

	if ([kind isEqualToString:@"messageVoiceNote"] ||
		[kind isEqualToString:@"messageAudio"]) {
		[self playAudioMessage:m fromSeconds:0];
		return;
	}

	if ([kind isEqualToString:@"messageContact"]) {
		int64_t contactId = [m[@"contactUserId"] longLongValue];
		if (contactId != 0) {
			[self openProfileForUserId:contactId];
			return;
		}
		NSString *phone = [self contactPhoneFor:m];
		if (!phone.length)
			return;
		CGRect rowRect = [self.table rectForRowAtIndexPath:indexPath];
		CGPoint where = [self.table convertPoint:CGPointMake(CGRectGetMidX(rowRect), CGRectGetMidY(rowRect))
										   toView:self.view];
		[self showPhoneMenuFor:phone atPoint:where
					  firstName:m[@"contactFirstName"]
					   lastName:m[@"contactLastName"]];
		return;
	}

	if ([kind isEqualToString:@"messageText"]) {
		[self openLinkInMessage:m];
		return;
	}

	if ([kind isEqualToString:@"messagePhoto"]) {
		[self openPhotoMessage:m];
		return;
	}

	[self tapFellThroughOnMessage:m];
}

- (BOOL)offerOpenInForFileAtPath:(NSString *)path fromRow:(NSInteger)row {
	if (!path.length || !self.view.window)
		return NO;
	UIDocumentInteractionController *interaction = [UIDocumentInteractionController
		interactionControllerWithURL:[NSURL fileURLWithPath:path]];
	if (!interaction)
		return NO;
	interaction.delegate = self;

	CGRect rect = self.view.bounds;
	if (row >= 0 && row < [self displayRowCount])
		rect = [self.table convertRect:[self.table rectForRowAtIndexPath:
											   [NSIndexPath indexPathForRow:row inSection:0]]
								toView:self.view];

	self.documentInteraction = interaction;
	if ([interaction presentOpenInMenuFromRect:rect inView:self.view animated:YES])
		return YES;
	self.documentInteraction = nil;
	return NO;
}

- (void)documentInteractionControllerDidDismissOpenInMenu:
	(UIDocumentInteractionController *)controller {
	if (self.documentInteraction == controller)
		self.documentInteraction = nil;
}

- (void)tapFellThroughOnMessage:(NSDictionary *)m {
	NSNumber *replyTo = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	int64_t replyChatId = [m[@"replyChatId"] longLongValue];
	if (replyTo && (!replyChatId || replyChatId == self.chatId) &&
		[self scrollToMessageId:replyTo.longLongValue])
		return;
	[self touchedMessageBackground];
}

- (void)jumpToPinnedMessageBehind:(NSDictionary *)m {
	NSNumber *replyTo = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	int64_t replyChatId = [m[@"replyChatId"] longLongValue];
	if (replyTo && (!replyChatId || replyChatId == self.chatId) &&
		[self scrollToMessageId:replyTo.longLongValue])
		return;
	if (![m[@"id"] isKindOfClass:NSNumber.class]) {
		[self touchedMessageBackground];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] repliedMessageOf:[m[@"id"] longLongValue]
								 inChat:self.chatId
							 completion:^(int64_t pinned) {
								 TGChatViewController *strongSelf = weakSelf;
								 if (!strongSelf)
									 return;
								 if (!pinned || ![strongSelf scrollToMessageId:pinned])
									 [strongSelf showAlertTitle:@"" message:TGL(@"Conversation.MessageDoesntExist", @"Message doesn't exist")];
							 }];
}

- (void)offerResendOfMessage:(int64_t)messageId {
	self.failedMessageId = messageId;
	NSInteger row = [self rowForMessageId:messageId];
	NSDictionary *found = (row != NSNotFound) ? [self messageAtRow:row] : nil;
	NSString *title = TGFailedMessageTitle(found[@"sendErrorMessage"]);
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:title
					  delegate:self
				   otherTitles:@[ TGL(@"Conversation.MessageDialogRetry", @"Resend"), TGL(@"Common.Delete", @"Delete") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = kFailedMessageSheetTag;
	CGRect anchorRect = (row != NSNotFound)
		? [self.table rectForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]]
		: self.table.bounds;
	[sheet tg_showFromRect:anchorRect inView:self.table];
}

- (void)runFailedMessageOption:(NSString *)chosen {
	int64_t messageId = self.failedMessageId;
	self.failedMessageId = 0;
	if (!messageId)
		return;

	if ([chosen isEqualToString:TGL(@"Common.Delete", @"Delete")]) {
		NSInteger row = [self rowForMessageId:messageId];
		NSDictionary *found = (row != NSNotFound) ? [self messageAtRow:row] : nil;
		if (found)
			[self deleteMessage:found forEveryone:NO];
		return;
	}
	if (![chosen isEqualToString:TGL(@"Conversation.MessageDialogRetry", @"Resend")])
		return;

	NSInteger row = [self rowForMessageId:messageId];
	NSDictionary *found = (row != NSNotFound) ? [self messageAtRow:row] : nil;
	if ([found[@"needAnotherReplyQuote"] boolValue]) {
		[self presentQuoteOutdatedAlertForMessageIds:@[ @(messageId) ]];
		return;
	}
	BOOL dropQuote = [found[@"needDropReply"] boolValue];
	int64_t paidStarCount = [found[@"requiredPaidMessageStarCount"] longLongValue];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resendMessages:@[ @(messageId) ] inChat:self.chatId dropQuote:dropQuote
						 paidStarCount:paidStarCount
						completion:^(NSArray *messages) {
							   TGChatViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   [strongSelf.sendStates removeObjectForKey:@(messageId)];
							   [strongSelf.sendStatesRequested removeObject:@(messageId)];
							   [strongSelf reload];
						   }];
}

- (void)presentAnimatedEmojiLottieEffectAtPath:(NSString *)path {
	TGLottieView *effect = [[TGLottieView alloc] initWithFrame:CGRectMake(0, 0, 220, 220)];
	effect.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
	effect.userInteractionEnabled = NO;
	effect.loopEnabled = NO;
	if (![effect loadTGSFile:path])
		return;
	[self.view addSubview:effect];
	[effect play];
	[UIView animateWithDuration:0.3 delay:2.3 options:0 animations:^{
		effect.alpha = 0.0f;
	} completion:^(BOOL finished) {
		[effect stop];
		[effect removeFromSuperview];
	}];
}

- (void)presentAnimatedEmojiStaticEffectAtPath:(NSString *)path {
	dispatch_async(TGImageDecodeQueue(), ^{
		UIImage *sticker = [UIImage imageWithContentsOfFile:path];
		if (!sticker && [path.pathExtension.lowercaseString isEqualToString:@"webp"])
			sticker = [UIImage convertFromWebP:path compressedData:nil error:nil];
		if (!sticker)
			return;
		UIImage *resized = TGImageDrawnAtPointSize(sticker, CGSizeMake(140, 140));
		dispatch_async(dispatch_get_main_queue(), ^{
			UIImageView *effect = [[UIImageView alloc] initWithImage:resized];
			effect.frame = CGRectMake(0, 0, 140, 140);
			effect.center = CGPointMake(CGRectGetMidX(self.view.bounds),
				CGRectGetMidY(self.view.bounds));
			effect.userInteractionEnabled = NO;
			[self.view addSubview:effect];
			[UIView animateWithDuration:0.9 animations:^{
				effect.alpha = 0.0f;
			} completion:^(BOOL finished) {
				[effect removeFromSuperview];
			}];
		});
	});
}

- (void)playAnimatedEmojiSticker:(long long)stickerFileId animated:(BOOL)isAnimated {
	if (stickerFileId <= 0)
		return;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:stickerFileId completion:^(NSString *path) {
		TGChatViewController *innerSelf = weakSelf;
		if (!innerSelf || !path.length)
			return;
		if (isAnimated) {
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *host = weakSelf;
				[host presentAnimatedEmojiLottieEffectAtPath:path];
			});
			return;
		}
		[innerSelf presentAnimatedEmojiStaticEffectAtPath:path];
	}];
}

- (void)installAnimatedEmojiHandler {
	if (self.animatedEmojiObserverToken)
		return;
	__weak typeof(self) weakSelf = self;
	self.animatedEmojiObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGAnimatedEmojiClickedNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if ([note.userInfo[TGAnimatedEmojiClickedChatIdKey] longLongValue] != strongSelf.chatId)
			return;
		[strongSelf playAnimatedEmojiSticker:
				[note.userInfo[TGAnimatedEmojiClickedStickerFileIdKey] longLongValue]
								   animated:[note.userInfo[TGAnimatedEmojiClickedIsAnimatedKey] boolValue]];
	}];
}

- (void)playAnimatedEmojiEffectFor:(int64_t)messageId {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client clickAnimatedEmojiInMessage:messageId inChat:self.chatId completion:^(long long stickerFileId, BOOL isAnimated) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf playAnimatedEmojiSticker:stickerFileId animated:isAnimated];
	}];
}

- (void)playAudioMessage:(NSDictionary *)m fromSeconds:(NSTimeInterval)seconds {
	[[TGMusicPlayer shared] playMessage:m
								 inChat:self.chatId
							  chatTitle:self.chatTitle
							fromSeconds:seconds];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error
				 contextInfo:(void *)contextInfo {
	if (error) {
		[self showAlertTitle:@"" message:TGL(@"Toast.CouldNotSaveMedia", @"Could not save")];
		return;
	}
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:@""
						 message:TGL(@"WebApp.Download.SavedToPhotos", @"Saved to Camera Roll")
		delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:(title ?: @"")
						 message:(message ?: @"")
		delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (void)showGiveawayStatusForMessage:(NSDictionary *)m {
	int64_t messageId = [m[@"id"] longLongValue];
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] giveawayInfoForMessage:messageId
										inChat:chatId
									completion:^(NSDictionary *info) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *status = [info[@"statusText"] isKindOfClass:NSString.class] ? info[@"statusText"] : nil;
		[strongSelf showAlertTitle:(strongSelf.chatTitle.length ? strongSelf.chatTitle : TGL(@"Message.Giveaway", @"Giveaway"))
							message:(status.length ? status : TGL(@"Premium.NoDetailsForThisGiveaway", @"No details for this giveaway."))];
	}];
}

- (void)showRecordingFailure {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:@""
						 message:TGL(@"Chat.CouldNotStartRecording", @"Could not start recording")
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (NSDictionary *)galleryItemForMessage:(NSDictionary *)m {
	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	BOOL isVideo = [kind isEqualToString:@"messageVideo"];
	if (!isVideo && ![kind isEqualToString:@"messagePhoto"])
		return nil;

	NSNumber *pictureId = [m[@"photoId"] isKindOfClass:NSNumber.class] ? m[@"photoId"] : nil;
	NSNumber *movieId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
	NSNumber *fullId = isVideo ? movieId : pictureId;
	if (!fullId || [fullId longLongValue] <= 0)
		return nil;

	NSNumber *thumbId = [self pictureFileIdFor:m] ?: (pictureId ?: fullId);
	NSString *caption = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : @"";
	int64_t senderUserId = [m[@"senderId"] longLongValue];
	int64_t senderChatId = [m[@"senderChatId"] longLongValue];
	NSString *author = [m[@"outgoing"] boolValue]
		? @""
		: (senderUserId != 0
			? ([TGUserDisplayNameStore nameForUserId:senderUserId] ?: @"")
			: ([[TGClient shared] titleForChatId:senderChatId] ?: @""));

	NSTimeInterval destructAt = [m[@"destructAt"] doubleValue];
	NSTimeInterval remainingDestructSeconds = TGRemainingSecondsUntilDestruct(destructAt,
		[NSDate timeIntervalSinceReferenceDate]);

	NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{
		@"fullId" : fullId,
		@"thumbId" : thumbId,
		@"caption" : caption,
		@"author" : author,
		@"date" : m[@"date"] ?: @(0),
		@"messageId" : m[@"id"] ?: @(0),
		@"duration" : m[@"duration"] ?: @(0),
		@"isVideo" : @(isVideo),
		@"burns" : @([self messageBurnsOnOpening:m]),
		@"destructTimer" : m[@"destructTimer"] ?: @0,
		@"destructIn" : @(remainingDestructSeconds),
	}];
	NSDictionary *minithumb = m[@"minithumbnail"];
	if ([minithumb isKindOfClass:NSDictionary.class])
		item[@"minithumb"] = minithumb;
	return item;
}

- (NSArray *)galleryItemsForMessageId:(int64_t)messageId index:(NSInteger *)index {
	NSMutableArray *items = [NSMutableArray array];
	if (index)
		*index = 0;

	for (NSDictionary *m in self.messages) {
		if ([self messageBurnsOnOpening:m] && [m[@"id"] longLongValue] != messageId)
			continue;
		NSDictionary *item = [self galleryItemForMessage:m];
		if (!item)
			continue;
		if (index && messageId != 0 && [m[@"id"] longLongValue] == messageId)
			*index = (NSInteger)items.count;
		[items addObject:item];
	}
	return items;
}

- (void)showGalleryForMessage:(NSDictionary *)m {
	NSInteger index = 0;
	NSArray *items = [self galleryItemsForMessageId:[m[@"id"] longLongValue] index:&index];

	if (items.count == 0) {
		NSDictionary *only = [self galleryItemForMessage:m];
		if (!only)
			return;
		items = @[ only ];
		index = 0;
	}

	TGMediaFullscreenController *viewer = [[TGMediaFullscreenController alloc]
		initWithItems:items
				index:index];
	viewer.chatId = self.chatId;

	__weak typeof(self) weakSelf = self;
	viewer.onMessageDeleted = ^(int64_t deletedId) {
		[weakSelf dropMessageWithId:deletedId];
	};
	viewer.onShowInChat = ^(int64_t shownId) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![strongSelf scrollToMessageId:shownId])
			[strongSelf loadDeeperHistoryAndScrollTo:shownId];
	};
	viewer.onOpenStickerSet = ^(int64_t setId) {
		[weakSelf openStickerSetWithId:setId];
	};

	[self presentViewController:viewer animated:YES completion:nil];
}

- (void)showGalleryForLinkPreview:(NSDictionary *)preview {
	NSNumber *fileId = [preview[@"photoFileId"] isKindOfClass:NSNumber.class]
		? preview[@"photoFileId"]
		: nil;
	if (!fileId || [fileId longLongValue] <= 0)
		return;

	NSDictionary *item = @{
		@"fullId" : fileId,
		@"thumbId" : fileId,
		@"caption" : preview[@"title"] ?: @"",
		@"author" : @"",
		@"date" : @(0),
		@"messageId" : @(0),
		@"duration" : @(0),
		@"isVideo" : @NO,
		@"burns" : @NO,
		@"destructTimer" : @0,
		@"destructIn" : @0,
	};

	TGMediaFullscreenController *viewer = [[TGMediaFullscreenController alloc]
		initWithItems:@[ item ]
				index:0];
	viewer.chatId = self.chatId;
	[self presentViewController:viewer animated:YES completion:nil];
}

- (void)dropMessageWithId:(int64_t)messageId {
	NSMutableArray *left = [NSMutableArray arrayWithCapacity:self.messages.count];
	for (NSDictionary *m in self.messages) {
		if ([m[@"id"] longLongValue] == messageId)
			continue;
		[left addObject:m];
	}
	if (left.count == self.messages.count)
		return;
	self.messages = left;
	[self.table reloadData];
	[self updateEmptyState];
}

- (void)confirmCallBackWithVideo:(BOOL)video {
	if (!self.chatId || self.group)
		return;

	NSString *shown = self.chatTitle.length ? self.chatTitle
											: TGL(@"User.DeletedAccount", @"Deleted Account");
	NSString *callTitle = video ? TGL(@"ContactList.Context.VideoCall", @"Video Call")
								: TGL(@"Conversation.Call", @"Call");
	NSArray *actions = @[ [[TGActionSheetAction alloc] initWithTitle:callTitle action:@"call"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel")
											action:@"cancel"
											  type:TGActionSheetActionTypeCancel] ];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:[NSString stringWithFormat:TGL(@"NewCall.ActionCallSingle", @"Call %@?"), shown]
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGChatViewController *strongSelf = weakSelf;
			  if (!strongSelf || ![action isEqualToString:@"call"])
				  return;
			  [TGCallViewController presentForUserId:strongSelf.chatId
												name:strongSelf.chatTitle
											outgoing:YES
											   video:video];
		  }
			   target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

@end
