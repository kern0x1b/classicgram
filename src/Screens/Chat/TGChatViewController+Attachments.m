#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGClient+MessageContent.h"
#import "TGClient+Premium.h"
#import "TGClient+SecretChats.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGAssetPicker.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGVideoCaptureViewController.h"
#import "TGStarsViewController.h"
#import "AppDelegate.h"

@implementation TGChatViewController (Attachments)

#pragma mark - attachments

const NSInteger kAttachSheetTag = 41;
const NSInteger kForwardSheetTag = 43;
const NSInteger kReportSheetTag = 44;
const NSInteger kSelectionDeleteSheetTag = 48;
const NSInteger kLinkSheetTag = 49;
const NSInteger kReportTextAlertTag = 61;
const NSInteger kPastePhotoAlertTag = 62;
const NSInteger kJoinLinkAlertTag = 63;
const NSInteger kModerationSheetTag = 50;
const NSInteger kAttachMoreSheetTag = 51;
const NSInteger kLocationSheetTag = 52;
const NSInteger kTextToolsSheetTag = 54;
const NSInteger kPinnedSheetTag = 55;
const NSInteger kSelectionMoreSheetTag = 57;
const NSInteger kVenueTitleAlertTag = 64;
const NSInteger kVenueAddressAlertTag = 65;
const NSInteger kChecklistAddAlertTag = 69;
const NSInteger kAddLanguagePackAlertTag = 116;
const NSInteger kPollAddOptionAlertTag = 70;
const NSInteger kAiSuggestionAlertTag = 122;
const NSInteger kAiRewriteStyleSheetTag = 123;
const NSInteger kAlbumSelectionLimit = 30;
const NSInteger kAlbumBatchLimit = 10;
const NSInteger kBotMenuSheetTag = 90;
const NSInteger kBotButtonsSheetTag = 91;
const NSInteger kBotPasswordAlertTag = 97;
const NSInteger kBotStartAlertTag = 99;
const NSInteger kAllowBotAlertTag = 100;
const NSInteger kTextLinksSheetTag = 101;
const NSInteger kPeerMenuSheetTag = 103;
const NSInteger kHeldLinkSheetTag = 104;
const NSInteger kFailedMessageSheetTag = 105;
const NSInteger kPinOptionsSheetTag = 106;
const NSInteger kActionBarBlockSheetTag = 107;
const NSInteger kActionBarReportAlertTag = 108;
const NSInteger kActionBarSharePhoneAlertTag = 109;
const NSInteger kEffectPickerSheetTag = 110;
const NSInteger kFactCheckAlertTag = 111;
const NSInteger kSendAsSheetTag = 112;
const NSInteger kApprovePostAlertTag = 114;
const NSInteger kDeclinePostAlertTag = 115;
const NSInteger kSuggestPostPriceAlertTag = 117;
const NSInteger kSuggestPostTimingSheetTag = 118;
const NSInteger kChecklistEditAlertTag = 119;
const NSInteger kChecklistDeleteTaskSheetTag = 120;
const NSInteger kChecklistTaskMenuSheetTag = 124;
const NSInteger kBankCardSheetTag = 121;
const NSInteger kGroupBotCommandsPickSheetTag = 125;
const NSInteger kQuoteOutdatedAlertTag = 126;
const NSInteger kWallpaperRevertAlertTag = 127;
const NSInteger kSuggestedPostDeleteWarningAlertTag = 128;
const NSInteger kBotRequestPhoneAlertTag = 129;
const NSInteger kBotRequestLocationAlertTag = 130;
const NSInteger kModerationConfirmSheetTag = 131;

- (Class)videoCaptureClass {
	if (![UIImagePickerController isSourceTypeAvailable:
				UIImagePickerControllerSourceTypeCamera])
		return Nil;
	return NSClassFromString(@"TGVideoCaptureViewController");
}

- (BOOL)cameraAvailable {
	return [UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypeCamera];
}

- (UIImage *)pasteboardImage {
	UIPasteboard *board = [UIPasteboard generalPasteboard];
	UIImage *image = board.image;
	if (image)
		return image;
	id first = [board.images firstObject];
	return [first isKindOfClass:UIImage.class] ? first : nil;
}

- (BOOL)pasteboardHoldsImage {
	return [[UIPasteboard generalPasteboard]
		containsPasteboardTypes:UIPasteboardTypeListImage];
}

- (void)attachTapped {
	if (self.composeMode == TGComposeModeEdit) {
		[TGSnackbar showInView:self.view
						   text:TGL(@"Toast.CantAttachWhileEditing", @"Finish or cancel your edit before attaching media")
						seconds:3
					   onCommit:nil];
		return;
	}

	NSTimeInterval startedAt = TGPerfLogging()
		? [NSDate timeIntervalSinceReferenceDate]
		: 0;
	BOOL canSendPhotos = !self.composerState || self.composerState.canSendPhotos;
	BOOL canSendVideos = !self.composerState || self.composerState.canSendVideos;
	BOOL canSendVideoNotes = !self.composerState || self.composerState.canSendVideoNotes;
	BOOL canSendAudios = !self.composerState || self.composerState.canSendAudios;

	NSMutableArray *titles = [NSMutableArray array];
	if ([self cameraAvailable] && canSendPhotos)
		[titles addObject:TGL(@"Common.TakePhoto", @"Take Photo")];
	if (canSendPhotos || canSendVideos)
		[titles addObject:TGL(@"AttachmentMenu.PhotoOrVideo", @"Photo or Video")];
	if ([TGAssetPicker available] && (canSendPhotos || canSendVideos))
		[titles addObject:TGL(@"Attachment.PhotoAlbum", @"Photo Album")];
	if ([self videoCaptureClass]) {
		if (canSendVideos)
			[titles addObject:TGL(@"Message.Video", @"Video")];
		if (canSendVideoNotes)
			[titles addObject:TGL(@"Message.VideoMessage", @"Video Message")];
	}
	if ([self pasteboardHoldsImage] && canSendPhotos)
		[titles addObject:TGL(@"Attachment.Pasteboard", @"Paste Photo")];
	if (canSendAudios)
		[titles addObject:TGL(@"Cache.Music", @"Music")];
	[titles addObject:TGL(@"Attachment.Location", @"Location")];
	[titles addObject:TGL(@"Attachment.Contact", @"Contact")];
	if (self.chatCanReceiveGift)
		[titles addObject:TGL(@"Attachment.Gift", @"Gift")];
	[titles addObject:TGL(@"Common.More", @"More")];

	UIActionSheet *bareSheet = [UIActionSheet alloc];
	UIActionSheet *sheet = [bareSheet initWithTitle:nil
										   delegate:self
								  cancelButtonTitle:nil
							 destructiveButtonTitle:nil
								  otherButtonTitles:nil];
	for (NSString *title in titles)
		[sheet addButtonWithTitle:title];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kAttachSheetTag;
	[sheet tg_showFromRect:CGRectMake(0, 0, 41, kInputHeight) inView:self.inputBar];
	if (startedAt > 0)
		NSLog(@"PERF attach sheet up in %.0f ms",
			([NSDate timeIntervalSinceReferenceDate] - startedAt) * 1000.0);
}

- (void)captureVideoRound:(BOOL)round {
	Class shooterClass = [self videoCaptureClass];
	if (!shooterClass)
		return;

	if (round) {
		self.sendMediaOnce = NO;
		self.pendingSelfDestructSeconds = 0;
	}

	TGVideoCaptureViewController *shooter =
		[[shooterClass alloc] initWithRoundVideoNote:round];
	if (!shooter)
		return;

	__weak typeof(self) weakSelf = self;
	shooter.onFinish = ^(NSString *path, NSTimeInterval duration, CGSize dimensions) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.videoNoteShooter = nil;
		[strongSelf sendCapturedVideoAtPath:path duration:duration
							   size:dimensions
							  round:round];
	};
	shooter.onCancel = ^{
		TGChatViewController *strongSelf = weakSelf;
		strongSelf.videoNoteShooter = nil;
	};

	if (!round) {
		[self presentViewController:shooter animated:YES completion:nil];
		return;
	}

	[self stopVideoNote];
	[self.input resignFirstResponder];
	self.videoNoteShooter = shooter;
	CGRect strip = CGRectMake(0, self.view.bounds.size.height - kInputHeight,
		self.view.bounds.size.width, kInputHeight);
	[shooter presentOverParent:self controlsFrame:strip];
}

- (void)sendCapturedVideoAtPath:(NSString *)path
					   duration:(NSTimeInterval)duration
						   size:(CGSize)dimensions
						  round:(BOOL)round {
	if (!path.length)
		return;

	if (self.postingBlocked) {
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		return;
	}

	if ([self blockSendForSlowMode]) {
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		return;
	}

	if (!round) {
		[self clearComposeState];
		[self presentSendPreviewForImage:nil videoPath:path videoDuration:duration videoSize:dimensions];
		return;
	}

	NSInteger side = (NSInteger)MIN(dimensions.width, dimensions.height);
	if (side <= 0)
		side = 240;

	NSDictionary *sendOptions = [self sendOptionsDictionary];
	[[TGClient shared] sendChatAction:@"uploadingVideoNote" toChat:self.chatId thread:self.threadId];
	[[TGClient shared] sendVideoNoteAtPath:path
									toChat:self.chatId
									thread:self.threadId
					   directMessagesTopic:self.directMessagesTopicId
								savedTopic:self.savedTopicId
								   replyTo:self.replyToId
								  duration:(NSInteger)duration
									  side:side
								   options:sendOptions];

	[self clearComposeState];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[[TGClient shared] sendChatAction:@"cancel" toChat:self.chatId thread:self.threadId];
			[self reload];
		});
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex) {
		if (sheet.tag == kPeerMenuSheetTag) {
			self.peerMenuUserId = 0;
			self.peerMenuName = nil;
		} else if (sheet.tag == kHeldLinkSheetTag) {
			self.heldLinkURL = nil;
		} else if (sheet.tag == kFailedMessageSheetTag) {
			self.failedMessageId = 0;
		} else if (sheet.tag == kPinOptionsSheetTag) {
			self.pinMessageId = 0;
		} else if (sheet.tag == kChecklistDeleteTaskSheetTag) {
			self.checklistDeleteMessageId = 0;
			self.checklistDeleteTaskId = 0;
		} else if (sheet.tag == kChecklistTaskMenuSheetTag) {
			self.checklistMenuMessageId = 0;
			self.checklistMenuTaskId = 0;
			self.checklistMenuTaskText = nil;
		} else if (sheet.tag == kBankCardSheetTag) {
			self.bankCardNumber = nil;
			self.bankCardActions = nil;
		}
		return;
	}

	if (sheet.tag == kTextLinksSheetTag) {
		if (index >= 0 && index < (NSInteger)self.tappedLinkTargets.count)
			[self followTextTarget:[self.tappedLinkTargets objectAtIndex:index]];
		self.tappedLinkTargets = nil;
		return;
	}
	if (sheet.tag == kPeerMenuSheetTag) {
		[self runPeerMenuOption:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kHeldLinkSheetTag) {
		[self runHeldLinkOption:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kFailedMessageSheetTag) {
		[self runFailedMessageOption:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kForwardSheetTag) {
		[self forwardWithCopy:(index >= 1) removeCaptions:(index == 2)];
		return;
	}
	if (sheet.tag == kPinOptionsSheetTag) {
		[self runPinOption:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kChecklistDeleteTaskSheetTag) {
		[self performDeleteChecklistTask];
		return;
	}
	if (sheet.tag == kChecklistTaskMenuSheetTag) {
		[self runChecklistTaskMenuOption:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kActionBarBlockSheetTag) {
		if (index != sheet.cancelButtonIndex)
			[self runActionBarBlockOption:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kEffectPickerSheetTag) {
		if (index != sheet.cancelButtonIndex)
			[self runEffectPickerIndex:index];
		return;
	}
	if (sheet.tag == kSendAsSheetTag) {
		[self runSendAsPickerIndex:index];
		return;
	}
	if (sheet.tag == kBankCardSheetTag) {
		[self runBankCardOptionIndex:index];
		return;
	}
	if (sheet.tag == kSuggestPostTimingSheetTag) {
		if (index != sheet.cancelButtonIndex)
			[self runSuggestPostTimingOption:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kReportSheetTag) {
		if (index < (NSInteger)self.reportOptions.count)
			[self reportMessages:self.reportMessageIds
						 optionId:self.reportOptions[index][@"id"]];
		return;
	}
	if (sheet.tag == kAttachMoreSheetTag) {
		[self runAttachMore:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kBotMenuSheetTag) {
		[self runBotMenu:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kBotButtonsSheetTag) {
		[self runBotButtonAtIndex:index];
		return;
	}
	if (sheet.tag == kGroupBotCommandsPickSheetTag) {
		if (index != sheet.cancelButtonIndex)
			[self runGroupBotCommandsPick:index];
		return;
	}
	if (sheet.tag == kLocationSheetTag) {
		[self runLocationOption:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kTextToolsSheetTag) {
		[self runTextToolAtIndex:index];
		return;
	}
	if (sheet.tag == kAiRewriteStyleSheetTag) {
		[self runAiRewriteStyleAtIndex:index];
		return;
	}
	if (sheet.tag == kPinnedSheetTag) {
		if (index != sheet.cancelButtonIndex) {
			NSString *chosen = [sheet buttonTitleAtIndex:index] ?: @"";
			if ([chosen isEqualToString:TGL(@"Chat.PinnedListPreview.ShowAllMessages", @"Show All Messages")])
				[self showAllPinnedMessages];
			else
				[self unpinEverything];
		}
		return;
	}
	if (sheet.tag == kSelectionMoreSheetTag) {
		[self runSelectionMore:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kLinkSheetTag) {
		NSString *link = self.pendingLinkURL;
		self.pendingLinkURL = nil;
		if (!link.length)
			return;
		if (index == 0)
			[self openExternalLink:link];
		else
			[UIPasteboard generalPasteboard].string = link;
		return;
	}
	if (sheet.tag == kModerationSheetTag) {
		[self runModerationAction:([sheet buttonTitleAtIndex:index] ?: @"")];
		return;
	}
	if (sheet.tag == kModerationConfirmSheetTag) {
		NSString *pending = self.pendingModerationAction;
		self.pendingModerationAction = nil;
		if (index != sheet.cancelButtonIndex && pending.length)
			[self performModerationAction:pending];
		return;
	}
	if (sheet.tag == kSelectionDeleteSheetTag) {
		if (index == sheet.cancelButtonIndex)
			return;
		NSString *chosen = [sheet buttonTitleAtIndex:index] ?: @"";
		[self deleteSelectedForEveryone:[chosen isEqualToString:TGL(@"Stickers.Delete.ForEveryone", @"Delete for Everyone")]];
		return;
	}
	if (sheet.tag != kAttachSheetTag)
		return;

	NSString *chosen = [sheet buttonTitleAtIndex:index] ?: @"";
	if ([chosen isEqualToString:TGL(@"Common.TakePhoto", @"Take Photo")])
		[self takePhoto];
	else if ([chosen isEqualToString:TGL(@"Attachment.Pasteboard", @"Paste Photo")])
		[self pastePhoto];
	else if ([chosen isEqualToString:TGL(@"Cache.Music", @"Music")])
		[self pickMusic];
	else if ([chosen isEqualToString:TGL(@"AttachmentMenu.PhotoOrVideo", @"Photo or Video")])
		[self pickMedia];
	else if ([chosen isEqualToString:TGL(@"Attachment.PhotoAlbum", @"Photo Album")])
		[self pickPhotoAlbum];
	else if ([chosen isEqualToString:TGL(@"Message.Video", @"Video")])
		[self captureVideoRound:NO];
	else if ([chosen isEqualToString:TGL(@"Message.VideoMessage", @"Video Message")]) {
		[self captureVideoRound:YES];
		[self.videoNoteShooter beginLockedRecording];
	} else if ([chosen isEqualToString:TGL(@"Attachment.Location", @"Location")])
		[self showLocationOptions];
	else if ([chosen isEqualToString:TGL(@"Attachment.Contact", @"Contact")])
		[self pickContact];
	else if ([chosen isEqualToString:TGL(@"Attachment.Gift", @"Gift")])
		[self attachGiftTapped];
	else if ([chosen isEqualToString:TGL(@"Common.More", @"More")])
		[self showAttachMore];
}

- (void)attachGiftTapped {
	if (!self.chatCanReceiveGift)
		return;
	TGStarsViewController *stars = [[TGStarsViewController alloc] init];
	stars.opensGiftCatalogue = YES;
	stars.giftPresetName = self.chatTitle;
	if (self.group)
		stars.giftPresetChatId = self.chatId;
	else {
		int64_t userId = self.chatId;
		int64_t secretUserId = [[TGClient shared] secretChatUserIdForChat:self.chatId];
		if (secretUserId != 0)
			userId = secretUserId;
		stars.giftPresetUserId = userId;
	}
	[self.navigationController pushViewController:stars animated:YES];
}

- (void)showAttachMore {
	BOOL canSendDocuments = !self.composerState || self.composerState.canSendDocuments;
	BOOL canSendOtherMessages = !self.composerState || self.composerState.canSendOtherMessages;
	BOOL canSendPolls = !self.composerState || self.composerState.canSendPolls;

	NSMutableArray *titles = [NSMutableArray array];
	if (canSendDocuments)
		[titles addObject:TGL(@"AttachmentMenu.SendAsFiles", @"Send as File")];
	if (canSendOtherMessages)
		[titles addObject:TGL(@"Message.Animation", @"GIF")];
	if (canSendPolls)
		[titles addObject:TGL(@"AttachmentMenu.Poll", @"Poll")];
	BOOL canUseQuickReplies = [[TGClient shared] isPremiumAccount]
		&& !self.group
		&& !self.chatIsWithBot
		&& ![self isRemindersChat]
		&& ![[TGClient shared] isSecretChat:self.chatId];
	if (canUseQuickReplies)
		[titles addObject:TGL(@"Premium.Business.Replies.Title", @"Quick Replies")];
	if (self.chatIsWithBot || self.groupBotCommandGroups.count)
		[titles addObject:TGL(@"Attachment.Bot", @"Bot")];

	UIActionSheet *bareSheet = [UIActionSheet alloc];
	UIActionSheet *sheet = [bareSheet initWithTitle:nil
										   delegate:self
								  cancelButtonTitle:nil
							 destructiveButtonTitle:nil
								  otherButtonTitles:nil];
	for (NSString *title in titles)
		[sheet addButtonWithTitle:title];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kAttachMoreSheetTag;
	[sheet tg_showFromRect:CGRectMake(0, 0, 41, kInputHeight) inView:self.inputBar];
}

- (void)runAttachMore:(NSString *)chosen {
	if (self.postingBlocked)
		return;
	if ([chosen isEqualToString:TGL(@"Attachment.Bot", @"Bot")]) {
		if (self.group)
			[self showGroupBotCommandsMenu];
		else
			[self showBotMenu];
		return;
	}
	if ([chosen isEqualToString:TGL(@"AttachmentMenu.SendAsFiles", @"Send as File")]) {
		self.attachMode = @"document";
		[self pickMedia];
		return;
	}
	if ([chosen isEqualToString:TGL(@"Message.Animation", @"GIF")]) {
		[self showGifPicker];
		return;
	}
	if ([chosen isEqualToString:TGL(@"Premium.Business.Replies.Title", @"Quick Replies")]) {
		[self showQuickReplies];
		return;
	}
	if ([chosen isEqualToString:TGL(@"AttachmentMenu.Poll", @"Poll")]) {
		[self showPollComposer];
		return;
	}
}

@end
