#import "TGChatViewController.h"
#import "TGFriendlyError.h"
#import "TGChatViewControllerInternal.h"
#import "TGTranslationResponseStaleness.h"
#import "TGTranslationLanguageCode.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGClient+Messages.h"
#import "TGClient+Network.h"
#import "TGLocalization.h"
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
#import "TGClient+Gifs.h"
#import "TGClient+Notifications.h"
#import "TGClient+SecretChats.h"
#import "TGClient+Groups.h"
#import "TGClient+Premium.h"
#import "TGQuotePickerViewController.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <MediaPlayer/MediaPlayer.h>
#import "TGLazyFramework.h"
#import "TGClient+Translation.h"
#import "TGClient+AiWriting.h"
#import "TGAssetPicker.h"
#import "TGSeenByViewController.h"
#import "TGClient+ChatList.h"
#import "TGForwardChunking.h"

@implementation TGChatViewController (ActionHandlers)

- (void)performMessageAction:(NSString *)action {
	NSDictionary *m = self.actionMessage;
	if (![m[@"id"] isKindOfClass:NSNumber.class])
		return;
	int64_t messageId = [m[@"id"] longLongValue];
	NSString *bodyText = [self originalTextOf:m];
	__weak typeof(self) weakSelf = self;

	if ([action isEqualToString:TGMessageActionReact]) {
		[self showReactionPickerForMessage:messageId
								  fromView:[self bubbleViewForMessageId:messageId]];

	} else if ([action isEqualToString:TGMessageActionSeenBy]) {
		if (self.actionsSheet.canGetViewers) {
			TGSeenByViewController *seenBy = [[TGSeenByViewController alloc] initWithMessageId:messageId chatId:self.chatId];
			[self.navigationController pushViewController:seenBy animated:YES];
		} else if (self.actionsSheet.canGetReadDate) {
			[[TGClient shared] readDateOfMessage:messageId
										   inChat:self.chatId
									   completion:^(NSString *status, NSTimeInterval when) {
										   TGChatViewController *strongSelf = weakSelf;
										   if (!strongSelf)
											   return;
										   NSString *detail = TGL(@"Chat.NotReadYet", @"Not read yet");
										   if ([status isEqualToString:@"read"] && when > 0)
											   detail = [NSDateFormatter
												   localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:when]
																 dateStyle:NSDateFormatterShortStyle
																 timeStyle:NSDateFormatterShortStyle];
										   else if ([status isEqualToString:@"tooOld"])
											   detail = TGL(@"Chat.TooOldToTell", @"Too old to tell");
										   else if ([status isEqualToString:@"theirPrivacy"] ||
											   [status isEqualToString:@"myPrivacy"])
											   detail = TGL(@"Chat.HiddenByPrivacy", @"Hidden by privacy");
										   [strongSelf showAlertTitle:TGL(@"DialogList.Read", @"Read") message:detail];
									   }];
		}

	} else if ([action isEqualToString:TGMessageActionViewAuthor]) {
		TGClient *client = [TGClient shared];
		[client actualAuthorOfMessage:messageId
							   inChat:self.chatId
						   completion:^(NSString *name, int64_t userId) {
							   TGChatViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   (void)userId;
							   [strongSelf showAlertTitle:TGL(@"Chat.ViewAuthor", @"View Author") message:name];
						   }];

	} else if ([action isEqualToString:TGMessageActionReply]) {
		[self setComposeMode:TGComposeModeReply messageId:messageId];
		[self.sendButton setTitle:TGL(@"MediaPicker.Send", @"Send") forState:UIControlStateNormal];
		[self showComposeBanner:[NSString stringWithFormat:TGL(@"Conversation.ReplyMessagePanelTitle", @"Reply to: %@"),
									bodyText.length ? bodyText : (m[@"kind"] ?: TGL(@"Call.Message", @"Message"))]];
		[self.input becomeFirstResponder];

	} else if ([action isEqualToString:TGMessageActionEdit] ||
		[action isEqualToString:TGMessageActionSuggestPostEditMessage]) {
		[self setComposeMode:TGComposeModeEdit messageId:messageId];
		self.editingIsCaption = [@[ @"messagePhoto", @"messageVideo", @"messageAnimation",
			@"messageDocument", @"messageAudio", @"messageVoiceNote" ] containsObject:m[@"kind"]];
		self.editingCaptionAboveMedia = [m[@"captionAboveMedia"] boolValue];
		self.editingLinkPreviewOptions = [m[@"linkPreviewOptions"] isKindOfClass:NSDictionary.class]
			? m[@"linkPreviewOptions"] : nil;
		self.preEditDraftText = self.input.text;
		[self seedPendingStyleEntitiesFromMessage:m];
		self.input.text = bodyText ?: @"";
		[self inputChanged];
		[self.sendButton setTitle:TGL(@"Conversation.LinkDialogSave", @"Save") forState:UIControlStateNormal];
		[self showComposeBanner:TGL(@"Chat.SendMessageMenu.EditMessage", @"Edit message")];
		[self.input becomeFirstResponder];

	} else if ([action isEqualToString:TGMessageActionCopy]) {
		if (bodyText.length)
			[UIPasteboard generalPasteboard].string = bodyText;

	} else if ([action isEqualToString:TGMessageActionSelectText]) {
		[self beginTextSelectionForMessage:m];

	} else if ([action isEqualToString:TGMessageActionCopyLink]) {
		[[TGClient shared] linkForMessage:messageId inChat:self.chatId inThread:(self.threadId != 0)
							   completion:^(NSString *link, BOOL isPublic) {
								   TGChatViewController *strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   if (!link.length) {
									   [strongSelf showAlertTitle:@"" message:TGL(@"Conversation.CouldNotGetLink", @"Could not get a link to the message.")];
									   return;
								   }
								   [UIPasteboard generalPasteboard].string = link;
								   [strongSelf showAlertTitle:TGL(@"Story.ToastLinkCopied", @"Link Copied") message:link];
							   }];

	} else if ([action isEqualToString:TGMessageActionForward]) {
		self.forwardMessageId = messageId;
		self.forwardIds = @[ @(messageId) ];
		[self showForwardOptions];

	} else if ([action isEqualToString:TGMessageActionSaveImage] ||
		[action isEqualToString:TGMessageActionSaveVideo]) {
		[self saveMediaMessageToCameraRoll:m];

	} else if ([action isEqualToString:TGMessageActionSaveGif]) {
		NSNumber *fileId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
		if (fileId) {
			[[TGClient shared] saveGifWithFileId:[fileId longLongValue] completion:^(BOOL ok) {
				TGChatViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				if (!ok) {
					[strongSelf showAlertTitle:@"" message:TGL(@"GifPicker.ThisGIFIsHostedOutsideTelegram", @"This GIF is hosted outside Telegram and cannot be saved.")];
					return;
				}
				[TGSnackbar showInView:strongSelf.view text:TGL(@"Gallery.GifSaved", @"Saved GIF") seconds:2 onCommit:nil];
			}];
		}

	} else if ([action isEqualToString:TGMessageActionSetNotificationSound]) {
		TGClient *client = [TGClient shared];
		[client notificationSoundPathForMessage:messageId
										  inChat:self.chatId
									  completion:^(NSString *path, NSString *error) {
										  TGChatViewController *strongSelf = weakSelf;
										  if (!strongSelf)
											  return;
										  (void)error;
										  if (!path.length)
											  return;
										  [client addSavedNotificationSoundAtPath:path completion:^(NSDictionary *sound) {
											  TGChatViewController *innerSelf = weakSelf;
											  if (!innerSelf || !sound)
												  return;
											  [TGSnackbar showInView:innerSelf.view text:TGL(@"Notifications.UploadSuccess.Title", @"Sound Added") seconds:2 onCommit:nil];
										  }];
									  }];

	} else if ([action isEqualToString:TGMessageActionTranslate]) {
		[self translateMessage:messageId];

	} else if ([action isEqualToString:TGMessageActionSummarize]) {
		[self summarizeMessage:messageId];

	} else if ([action isEqualToString:TGMessageActionTranscribe]) {
		[self transcribeMessage:messageId];

	} else if ([action isEqualToString:TGMessageActionQuote]) {
		[self pickQuoteFromMessage:m];

	} else if ([action isEqualToString:TGMessageActionPin]) {
		[self showPinOptionsForMessage:messageId];

	} else if ([action isEqualToString:TGMessageActionUnpin]) {
		[[TGClient shared] unpinMessage:messageId inChat:self.chatId
							 completion:^(BOOL ok) {
								 TGChatViewController *strongSelf = weakSelf;
								 if (!strongSelf)
									 return;
								 if (!ok) {
									 [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotUnpinMessage", @"Could not unpin the message")];
									 return;
								 }
								 [strongSelf loadPinnedMessage];
							 }];

	} else if ([action isEqualToString:TGMessageActionSelect]) {
		[self beginSelectionWithMessage:messageId];

	} else if ([action isEqualToString:TGMessageActionReport]) {
		self.reportMessageIds = @[ @(messageId) ];
		[self reportMessages:@[ @(messageId) ] optionId:nil];

	} else if ([action isEqualToString:TGMessageActionDeleteForMe]) {
		[self deleteMessage:m forEveryone:[[TGClient shared] isSecretChat:self.chatId]];

	} else if ([action isEqualToString:TGMessageActionDeleteForEveryone]) {
		[self deleteMessage:m forEveryone:YES];

	} else if ([action isEqualToString:TGMessageActionFactCheck]) {
		[self showFactCheckPromptForMessage:messageId
								   existing:m[@"factCheckText"]];

	} else if ([action isEqualToString:TGMessageActionApprovePost]) {
		NSString *senderName = [[TGClient shared] nameForUserId:[m[@"senderId"] longLongValue]];
		[self confirmApproveSuggestedPost:messageId price:m[@"suggestedPostPrice"] senderName:senderName];

	} else if ([action isEqualToString:TGMessageActionDeclinePost]) {
		[self showDeclineSuggestedPostPrompt:messageId];

	} else if ([action isEqualToString:TGMessageActionSuggestPost]) {
		[self beginSuggestPostForMessageId:messageId currentPrice:m[@"suggestedPostPrice"]];
	}
	self.actionMessage = nil;
}

- (void)confirmApproveSuggestedPost:(int64_t)messageId price:(NSString *)price senderName:(NSString *)senderName {
	NSString *message = price.length
		? [NSString stringWithFormat:TGL(@"Chat.PostApproval.WillPay", @"You will receive %@ once the post is sent."), price]
		: [NSString stringWithFormat:TGL(@"Chat.PostSuggestion.Approve.AdminConfirmationText", @"Do you really want to publish this post from %@?"), senderName.length ? senderName : @""];
	UIAlertView *confirmAlloc = [UIAlertView alloc];
	UIAlertView *confirm = [confirmAlloc initWithTitle:TGL(@"Chat.PostApproval.Message.ActionApprove", @"Approve Post")
											   message:message
											  delegate:self
									 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
									 otherButtonTitles:TGL(@"Chat.PostApproval.Message.ActionApprove", @"Approve Post"), nil];
	confirm.tag = kApprovePostAlertTag;
	self.suggestedPostMessageId = messageId;
	[confirm show];
}

- (void)performApproveSuggestedPost {
	int64_t messageId = self.suggestedPostMessageId;
	if (!messageId)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] approveSuggestedPost:messageId inChat:chatId completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotApproveSuggestedPost", @"Could not approve the suggested post")];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)showDeclineSuggestedPostPrompt:(int64_t)messageId {
	self.suggestedPostMessageId = messageId;
	UIAlertView *askAlloc = [TGAlertView alloc];
	UIAlertView *ask = [askAlloc initWithTitle:TGL(@"Chat.PostApproval.Message.ActionReject", @"Decline Post")
									   message:nil
									  delegate:self
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
							 otherButtonTitles:TGL(@"Call.Decline", @"Decline"), nil];
	if ([ask respondsToSelector:@selector(setAlertViewStyle:)]) {
		ask.alertViewStyle = UIAlertViewStylePlainTextInput;
		[ask textFieldAtIndex:0].placeholder = TGL(@"Chat.PostSuggestion.Reject.Placeholder", @"Optional");
	}
	ask.tag = kDeclinePostAlertTag;
	[ask show];
}

- (void)beginSuggestPostForMessageId:(int64_t)messageId currentPrice:(NSString *)priceText {
	self.suggestedPostMessageId = messageId;
	BOOL editing = priceText.length > 0;
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:(editing ? TGL(@"Chat.ContextMenu.SuggestedPost.EditPrice", @"Edit Price")
								   : TGL(@"Chat.ContextMenu.SuggestedPost.Create", @"Suggest as Post"))
				  message:[NSString stringWithFormat:
							  TGL(@"Chat.PostSuggestion.Suggest.OfferDescriptionStars",
								  @"Choose how many Stars you want to offer %@ to publish this message."),
							  self.chatTitle.length ? self.chatTitle : TGL(@"ChatList.UnnamedChat", @"Chat")]
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Next", @"Next"), nil];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;
		[alert textFieldAtIndex:0].text = @"0";
	}
	alert.tag = kSuggestPostPriceAlertTag;
	[alert show];
}

- (void)showSuggestPostTimingSheet {
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
											  cancelButtonTitle:nil
										 destructiveButtonTitle:nil
											  otherButtonTitles:TGL(@"SuggestPost.SetTimeFormat.Any", @"Anytime"),
		TGL(@"SuggestPost.SetTime.Label", @"Time"), nil];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kSuggestPostTimingSheetTag;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)runSuggestPostTimingOption:(NSString *)title {
	if ([title isEqualToString:TGL(@"SuggestPost.SetTimeFormat.Any", @"Anytime")]) {
		[self performAddOfferWithSendDate:0];
		return;
	}
	self.suggestPostMessageIdForSchedule = self.suggestedPostMessageId;
	[self showSchedulePicker];
}

- (void)performAddOfferWithSendDate:(int64_t)sendDate {
	int64_t messageId = self.suggestedPostMessageId;
	int64_t starCount = self.suggestPostStarCount;
	if (!messageId)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client addOfferForMessage:messageId
						inChat:chatId
					 starCount:starCount
					  sendDate:sendDate
					completion:^(BOOL ok) {
						TGChatViewController *strongSelf = weakSelf;
						if (!strongSelf)
							return;
						if (!ok) {
							[strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotSuggestPost", @"Could not suggest the post")];
							return;
						}
						[strongSelf reload];
					}];
}

- (void)performDeclineSuggestedPostWithComment:(NSString *)comment {
	int64_t messageId = self.suggestedPostMessageId;
	if (!messageId)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] declineSuggestedPost:messageId inChat:chatId comment:comment
								 completion:^(BOOL ok) {
									 TGChatViewController *strongSelf = weakSelf;
									 if (!strongSelf)
										 return;
									 if (!ok) {
										 [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotDeclineSuggestedPost", @"Could not decline the suggested post")];
										 return;
									 }
									 [strongSelf reload];
								 }];
}

- (void)showFactCheckPromptForMessage:(int64_t)messageId existing:(NSString *)existing {
	self.factCheckMessageId = messageId;
	BOOL hasExisting = [existing isKindOfClass:NSString.class] && existing.length > 0;
	UIAlertView *ask = hasExisting
		? [[TGAlertView alloc] initWithTitle:TGL(@"Message.FactCheck", @"Fact Check")
									 message:TGL(@"FactCheck.Placeholder", @"Add Fact Check")
									delegate:self
						   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
						   otherButtonTitles:TGL(@"Appearance.RemoveTheme", @"Remove"), TGL(@"Conversation.LinkDialogSave", @"Save"), nil]
		: [[TGAlertView alloc] initWithTitle:TGL(@"Message.FactCheck", @"Fact Check")
									 message:TGL(@"FactCheck.Placeholder", @"Add Fact Check")
									delegate:self
						   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
						   otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
		ask.alertViewStyle = UIAlertViewStylePlainTextInput;
	if (hasExisting && [ask respondsToSelector:@selector(textFieldAtIndex:)])
		[ask textFieldAtIndex:0].text = existing;
	ask.tag = kFactCheckAlertTag;
	[ask show];
}

- (void)handleFactCheckAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	int64_t messageId = self.factCheckMessageId;
	if (!messageId)
		return;

	BOOL isRemove = alertView.numberOfButtons == 3 && buttonIndex == 1;
	NSString *text = isRemove ? @""
							  : ([alertView respondsToSelector:@selector(textFieldAtIndex:)]
										? [alertView textFieldAtIndex:0].text ?: @""
										: @"");
	if (!isRemove && !text.length)
		return;

	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setFactCheck:text forMessage:messageId inChat:chatId
						 completion:^(BOOL ok) {
							 TGChatViewController *strongSelf = weakSelf;
							 if (!strongSelf)
								 return;
							 if (!ok) {
								 [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotSaveFactCheck", @"Could not save the fact check")];
								 return;
							 }
							 [strongSelf reload];
						 }];
}

- (void)deleteMessage:(NSDictionary *)m forEveryone:(BOOL)forEveryone {
	BOOL isPaidSuggestedPost = [m[@"isPaidStarSuggestedPost"] boolValue] || [m[@"isPaidGramSuggestedPost"] boolValue];
	if (!isPaidSuggestedPost) {
		[self performDeleteMessage:m forEveryone:forEveryone];
		return;
	}

	self.pendingDeleteMessage = m;
	self.pendingDeleteForEveryone = forEveryone;
	NSTimeInterval sentAt = [m[@"date"] doubleValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] optionNamed:@"suggested_post_lifetime_min" completion:^(id value) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSTimeInterval lifetimeMin = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : -1;
		NSTimeInterval elapsed = [[NSDate date] timeIntervalSince1970] - sentAt;
		if (lifetimeMin >= 0 && sentAt > 0 && elapsed >= lifetimeMin) {
			NSDictionary *readyMessage = strongSelf.pendingDeleteMessage;
			BOOL readyForEveryone = strongSelf.pendingDeleteForEveryone;
			strongSelf.pendingDeleteMessage = nil;
			[strongSelf performDeleteMessage:readyMessage forEveryone:readyForEveryone];
			return;
		}
		UIAlertView *warn = [UIAlertView alloc];
		warn = [warn initWithTitle:TGL(@"Chat.PostApproval.DeleteWarning.Title", @"Delete Post")
							message:TGL(@"Chat.PostApproval.DeleteWarning.Text",
								@"The payment for this post will be refunded if you delete it now. Are you sure you want to delete it?")
						   delegate:strongSelf
				  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				  otherButtonTitles:TGL(@"Common.Delete", @"Delete"), nil];
		warn.tag = kSuggestedPostDeleteWarningAlertTag;
		[warn show];
	}];
}

- (void)performDeleteMessage:(NSDictionary *)m forEveryone:(BOOL)forEveryone {
	int64_t messageId = [m[@"id"] longLongValue];
	int64_t chatId = self.chatId;

	NSMutableArray *without = [self.messages mutableCopy];
	[without removeObject:m];
	self.messages = without;
	[self.table reloadData];
	[self updateEmptyState];

	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.view
					  text:(forEveryone ? TGL(@"Chat.DeletedForEveryone", @"Deleted for everyone") : TGL(@"Chat.DeletedForYou", @"Deleted for you"))
				   seconds:5
					  kind:TGSnackbarKindDestructiveUndo
				  onCommit:^{
					  [[TGClient shared] deleteMessages:@[ @(messageId) ] inChat:chatId
											forEveryone:forEveryone
											 completion:^(BOOL ok) {
												 TGChatViewController *strongSelf = weakSelf;
												 if (!strongSelf)
													 return;
												 if (!ok) {
													 [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotDeleteMessages", @"Could not delete these messages")];
													 [strongSelf reload];
												 }
											 }];
				  }];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{ [weakSelf reload]; });

	[self offerModerationForMessage:m];
}

- (void)offerModerationForMessage:(NSDictionary *)m {
	if (!self.group || [m[@"outgoing"] boolValue])
		return;
	int64_t senderId = [m[@"senderId"] longLongValue];
	if (senderId <= 0)
		return;
	if (!self.view.window)
		return;

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client myAdministratorRightsInGroup:self.chatId
							  completion:^(NSDictionary *rights, NSString *status) {
								  TGChatViewController *strongSelf = weakSelf;
								  if (!strongSelf || !rights || !strongSelf.view.window)
									  return;
								  BOOL isCreator = [status isEqualToString:@"creator"];
								  BOOL canRestrict = [rights[@"can_restrict_members"] boolValue] || isCreator;
								  BOOL canDeleteMessages = [rights[@"can_delete_messages"] boolValue] || isCreator;
								  if (!canRestrict && !canDeleteMessages)
									  return;

								  [client groupInfoForChat:strongSelf.chatId
												 completion:^(NSDictionary *info) {
													 TGChatViewController *innerSelf = weakSelf;
													 if (!innerSelf || !innerSelf.view.window)
														 return;
													 BOOL canDeleteAllFromUser = canDeleteMessages && [info[@"isSupergroup"] boolValue];
													 if (!canRestrict && !canDeleteAllFromUser)
														 return;

													 NSString *name = [client nameForUserId:senderId];
													 if (!name.length)
														 name = TGL(@"Notification.ForwardFromUnknownUser", @"a user");
													 innerSelf.moderationUserId = senderId;
													 innerSelf.moderationName = name;
													 innerSelf.moderationMessageIds = ([m[@"id"] isKindOfClass:NSNumber.class]
															 ? @[ m[@"id"] ]
															 : @[]);

													 NSMutableArray *titles = [NSMutableArray array];
													 if (canDeleteAllFromUser)
														 [titles addObject:TGL(@"Chat.AdminActionSheet.DeleteAllMessages", @"Delete All Messages")];
													 if (canRestrict) {
														 [titles addObject:TGL(@"Conversation.ContextMenuBanFull", @"Ban")];
														 [titles addObject:TGL(@"Conversation.ReportSpam", @"Report as Spam")];
													 }

													 UIActionSheet *sheetAlloc = [UIActionSheet alloc];
													 UIActionSheet *sheet =
														 [sheetAlloc initWithTitle:name
																	   delegate:innerSelf
															  cancelButtonTitle:nil
														 destructiveButtonTitle:nil
															  otherButtonTitles:nil];
													 for (NSString *title in titles)
														 [sheet addButtonWithTitle:title];
													 sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Done", @"Done")];
													 sheet.tag = kModerationSheetTag;
													 [sheet tg_showFromRect:CGRectMake(CGRectGetMidX(innerSelf.view.bounds), CGRectGetMidY(innerSelf.view.bounds), 1, 1) inView:innerSelf.view];
												 }];
							  }];
}

- (void)runModerationAction:(NSString *)action {
	if (!self.moderationUserId || !action.length)
		return;
	if (![action isEqualToString:TGL(@"Chat.AdminActionSheet.DeleteAllMessages", @"Delete All Messages")] &&
		![action isEqualToString:TGL(@"Conversation.ContextMenuBanFull", @"Ban")] &&
		![action isEqualToString:TGL(@"Conversation.ReportSpam", @"Report as Spam")])
		return;

	self.pendingModerationAction = action;
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:self.moderationName
					  delegate:self
				   otherTitles:@[ action ]
			  destructiveIndex:0
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = kModerationConfirmSheetTag;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)performModerationAction:(NSString *)action {
	int64_t userId = self.moderationUserId;
	if (!userId)
		return;

	if ([action isEqualToString:TGL(@"Chat.AdminActionSheet.DeleteAllMessages", @"Delete All Messages")]) {
		__weak typeof(self) weakSelf = self;
		TGClient *client = [TGClient shared];
		[client deleteMessagesFromUser:userId
								inChat:self.chatId
							completion:^(BOOL ok) {
								TGChatViewController *strongSelf = weakSelf;
								if (!strongSelf)
									return;
								if (!ok) {
									[strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotDeleteMessages", @"Could not delete these messages")];
									return;
								}
								[strongSelf reload];
							}];
		return;
	}
	if ([action isEqualToString:TGL(@"Conversation.ContextMenuBanFull", @"Ban")]) {
		__weak typeof(self) weakSelf = self;
		TGClient *client = [TGClient shared];
		[client banMember:userId
				   inGroup:self.chatId
				 untilDate:0
			revokeMessages:NO
				completion:^(BOOL ok) {
					TGChatViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (!ok)
						[strongSelf showAlertTitle:@"" message:TGL(@"Chat.CouldNotBanMember", @"Could not ban this member from the group.")];
				}];
		return;
	}
	if ([action isEqualToString:TGL(@"Conversation.ReportSpam", @"Report as Spam")] && self.moderationMessageIds.count) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] reportSpamMessages:self.moderationMessageIds inGroup:self.chatId
									completion:^(BOOL ok) {
										TGChatViewController *strongSelf = weakSelf;
										if (!strongSelf)
											return;
										[strongSelf showAlertTitle:@"" message:(ok
												? TGL(@"Report.Succeed", @"Telegram moderators will study your report. Thank you!")
												: TGL(@"Report.Failed", @"This message could not be reported."))];
									}];
	}
}

- (void)showPinOptionsForMessage:(int64_t)messageId {
	self.pinMessageId = messageId;
	UIActionSheet *sheetAlloc = [UIActionSheet alloc];
	UIActionSheet *sheet = [sheetAlloc initWithTitle:TGL(@"Conversation.PinOlderMessageAlertTitle", @"Pin message")
											delegate:self
								   cancelButtonTitle:nil
							  destructiveButtonTitle:nil
								   otherButtonTitles:TGL(@"Conversation.PinMessageAlert.PinAndNotifyMembers", @"Pin and Notify"),
		TGL(@"Conversation.PinMessageAlert.OnlyPin", @"Pin Silently"), nil];
	if (!self.group)
		[sheet addButtonWithTitle:TGL(@"Conversation.PinMessagesForMe", @"Pin only for me")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kPinOptionsSheetTag;
	UIView *anchor = [self bubbleViewForMessageId:messageId];
	[sheet tg_showFromRect:anchor.bounds inView:anchor];
}

- (void)runPinOption:(NSString *)chosen {
	int64_t messageId = self.pinMessageId;
	self.pinMessageId = 0;
	if (!messageId || !chosen.length)
		return;
	BOOL silently = [chosen isEqualToString:TGL(@"Conversation.PinMessageAlert.OnlyPin", @"Pin Silently")] ||
		[chosen isEqualToString:TGL(@"Conversation.PinMessagesForMe", @"Pin only for me")];
	BOOL onlyForMe = [chosen isEqualToString:TGL(@"Conversation.PinMessagesForMe", @"Pin only for me")];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] pinMessage:messageId inChat:self.chatId
						 silently:silently
						onlyForMe:onlyForMe completion:^(BOOL ok) {
							TGChatViewController *strongSelf = weakSelf;
							if (!strongSelf)
								return;
							if (!ok) {
								[strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotPinMessage", @"Could not pin the message")];
								return;
							}
							[strongSelf loadPinnedMessage];
						}];
}

- (void)showForwardOptions {
	NSString *title = (self.forwardIds.count > 1)
		? TGLPlural(@"Conversation.ForwardOptions.ForwardTitle", (NSInteger)self.forwardIds.count,
			  @"Forward %@ Message", @"Forward %@ Messages")
		: TGL(@"Conversation.ForwardOptions.ForwardTitleSingle", @"Forward Message");
	UIActionSheet *sheetAlloc = [UIActionSheet alloc];
	UIActionSheet *sheet = [sheetAlloc initWithTitle:title
											delegate:self
								   cancelButtonTitle:nil
							  destructiveButtonTitle:nil
								   otherButtonTitles:TGL(@"Conversation.ForwardTitle", @"Forward"),
		TGL(@"Conversation.ForwardOptions.HideSendersName", @"Hide sender name"),
		TGL(@"Conversation.ForwardOptions.HideCaption", @"Hide Captions"), nil];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kForwardSheetTag;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)forwardWithCopy:(BOOL)asCopy removeCaptions:(BOOL)removeCaptions {
	NSArray *ids = self.forwardIds.count ? [self.forwardIds copy]
										 : (self.forwardMessageId ? @[ @(self.forwardMessageId) ] : nil);
	if (!ids.count)
		return;
	NSArray *sortedIds = [ids sortedArrayUsingSelector:@selector(compare:)];
	NSArray *idChunks = TGChunkedForwardMessageIds(sortedIds, TGForwardMessagesMaxChunkSize);
	NSUInteger requestedPerTarget = sortedIds.count;
	BOOL silent = self.sendSilently;

	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	picker.allowsMultiplePicks = YES;
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSArray *chatIds) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !chatIds.count)
			return;

		NSMutableArray *problemTargets = [NSMutableArray array];
		__block NSUInteger pendingTargets = chatIds.count;
		void (^reportResults)(void) = ^{
			TGChatViewController *innerSelf = weakSelf;
			if (innerSelf)
				[innerSelf reportForwardProblems:problemTargets requestedPerTarget:requestedPerTarget];
		};

		for (NSNumber *targetChatId in chatIds) {
			int64_t toChatId = [targetChatId longLongValue];
			[strongSelf forwardChunks:idChunks
							  atIndex:0
							   toChat:toChatId
							   asCopy:asCopy
					   removeCaptions:removeCaptions
							   silent:silent
							forwarded:0
						   completion:^(NSUInteger totalForwarded) {
							   if (totalForwarded < requestedPerTarget)
								   [problemTargets addObject:@{
									   @"chatId" : @(toChatId),
									   @"forwarded" : @(totalForwarded),
								   }];
							   if (--pendingTargets == 0)
								   reportResults();
						   }];
		}
		strongSelf.forwardIds = nil;
		strongSelf.forwardMessageId = 0;
		if (strongSelf.selecting)
			[strongSelf endSelection];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)forwardChunks:(NSArray *)idChunks
			  atIndex:(NSUInteger)chunkIndex
			   toChat:(int64_t)toChatId
			   asCopy:(BOOL)asCopy
	   removeCaptions:(BOOL)removeCaptions
			   silent:(BOOL)silent
			forwarded:(NSUInteger)forwardedSoFar
		   completion:(void (^)(NSUInteger))completion {
	if (chunkIndex >= idChunks.count) {
		if (completion)
			completion(forwardedSoFar);
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] forwardMessages:idChunks[chunkIndex]
							  fromChat:self.chatId
								toChat:toChatId
								thread:0
								asCopy:asCopy
						removeCaptions:removeCaptions
								silent:silent
							completion:^(NSArray *forwarded) {
								TGChatViewController *strongSelf = weakSelf;
								if (!strongSelf)
									return;
								[strongSelf forwardChunks:idChunks
												  atIndex:chunkIndex + 1
												   toChat:toChatId
												   asCopy:asCopy
										   removeCaptions:removeCaptions
												   silent:silent
												forwarded:forwardedSoFar + forwarded.count
											   completion:completion];
							}];
}

- (void)reportForwardProblems:(NSArray *)problemTargets requestedPerTarget:(NSUInteger)requestedPerTarget {
	if (!problemTargets.count)
		return;

	if (problemTargets.count == 1) {
		NSDictionary *info = problemTargets.firstObject;
		int64_t chatId = [info[@"chatId"] longLongValue];
		NSUInteger forwarded = [info[@"forwarded"] unsignedIntegerValue];
		NSString *name = [[TGClient shared] cachedTitleForChatId:chatId];
		if (!forwarded) {
			NSString *message = name.length
				? [NSString stringWithFormat:TGL(@"Toast.CouldNotForwardToChatFormat", @"Could not forward to %@"), name]
				: TGL(@"Toast.CouldNotForwardMessages", @"Could not forward these messages");
			[self showAlertTitle:@"" message:message];
			return;
		}
		NSString *message = name.length
			? [NSString stringWithFormat:TGL(@"Toast.SomeMessagesForwardedToChatFormat", @"%lu of %lu messages forwarded to %@"),
				(unsigned long)forwarded, (unsigned long)requestedPerTarget, name]
			: TGL(@"Toast.SomeMessagesNotForwarded", @"Some messages could not be forwarded");
		[TGSnackbar showInView:self.view text:message seconds:2 onCommit:nil];
		return;
	}

	NSMutableArray *failedNames = [NSMutableArray array];
	BOOL anyPartial = NO;
	BOOL anyUnnamed = NO;
	NSUInteger totalForwarded = 0;
	for (NSDictionary *info in problemTargets) {
		NSUInteger forwarded = [info[@"forwarded"] unsignedIntegerValue];
		totalForwarded += forwarded;
		if (forwarded > 0)
			anyPartial = YES;
		NSString *name = [[TGClient shared] cachedTitleForChatId:[info[@"chatId"] longLongValue]];
		if (name.length)
			[failedNames addObject:name];
		else
			anyUnnamed = YES;
	}

	if (!anyPartial && !anyUnnamed) {
		NSString *message = [NSString stringWithFormat:TGL(@"Toast.CouldNotForwardToChatFormat", @"Could not forward to %@"),
			[failedNames componentsJoinedByString:@", "]];
		[self showAlertTitle:@"" message:message];
		return;
	}

	if (!totalForwarded) {
		[self showAlertTitle:@"" message:TGL(@"Toast.CouldNotForwardMessages", @"Could not forward these messages")];
		return;
	}

	[TGSnackbar showInView:self.view
						text:TGL(@"Toast.SomeMessagesNotForwarded", @"Some messages could not be forwarded")
					 seconds:2
					onCommit:nil];
}

- (void)pickQuoteFromMessage:(NSDictionary *)m {
	if (![m[@"id"] isKindOfClass:NSNumber.class])
		return;
	if (![self messageHasQuotableText:m])
		return;
	NSString *whole = [self originalTextOf:m];
	if (!whole.length)
		return;

	NSArray *entities = [self originalEntitiesOf:m];
	int64_t messageId = [m[@"id"] longLongValue];
	NSString *author = [m[@"outgoing"] boolValue]
		? TGL(@"DialogList.You", @"You")
		: [[TGClient shared] nameForUserId:[m[@"senderId"] longLongValue]];

	TGQuotePickerViewController *picker =
		[[TGQuotePickerViewController alloc] initWithText:whole entities:entities author:author];
	__weak typeof(self) weakSelf = self;
	picker.onQuote = ^(NSString *fragment, NSArray *quoteEntities, NSInteger position) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !fragment.length)
			return;
		[strongSelf setComposeMode:TGComposeModeReply messageId:messageId];
		strongSelf.replyQuoteText = fragment;
		strongSelf.replyQuoteEntities = quoteEntities;
		strongSelf.replyQuotePosition = position;
		[strongSelf.sendButton setTitle:TGL(@"MediaPicker.Send", @"Send") forState:UIControlStateNormal];
		[strongSelf showComposeBanner:[NSString stringWithFormat:TGL(@"Chat.ReplyPanel.ReplyTo", @"Reply to: %@"), strongSelf.replyQuoteText]];
		[strongSelf.input becomeFirstResponder];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (BOOL)messageCanBeTranscribed:(NSDictionary *)m {
	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	if (![kind isEqualToString:@"messageVoiceNote"] && ![kind isEqualToString:@"messageVideoNote"])
		return NO;
	return ![self messageBurnsOnOpening:m];
}

- (NSString *)transcriptFor:(NSDictionary *)m {
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	if (!messageId)
		return nil;
	NSString *text = self.transcripts[messageId];
	return [text isKindOfClass:NSString.class] && text.length ? text : nil;
}

- (void)transcribeMessage:(int64_t)messageId {
	NSNumber *key = @(messageId);
	if (self.transcripts[key]) {
		[self.transcriptsPending removeObject:key];
		[self.transcripts removeObjectForKey:key];
		[self tg_invalidateLayoutForMessageId:messageId];
		[self.table reloadData];
		return;
	}
	if ([self.transcriptsPending containsObject:key])
		return;

	NSDictionary *syncedTranscript = nil;
	for (NSDictionary *m in self.messages) {
		if ([m[@"id"] longLongValue] != messageId)
			continue;
		NSDictionary *transcript = m[@"transcript"];
		syncedTranscript = [transcript isKindOfClass:NSDictionary.class] ? transcript : nil;
		break;
	}
	if ([syncedTranscript[@"state"] isEqualToString:@"text"]) {
		NSString *text = [syncedTranscript[@"text"] isKindOfClass:NSString.class] ? syncedTranscript[@"text"] : @"";
		self.transcripts[key] = text.length ? text : TGL(@"Message.AudioTranscription.ErrorEmpty", @"No speech was recognised.");
		[self tg_invalidateLayoutForMessageId:messageId];
		[self.table reloadData];
		return;
	}

	[self.transcriptsPending addObject:key];
	self.transcripts[key] = TGL(@"Chat.InProgress", @"In progress");
	[self tg_invalidateLayoutForMessageId:messageId];
	[self.table reloadData];

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client recognizeSpeechInMessage:messageId
							  inChat:self.chatId
						  completion:^(BOOL ok, NSString *problem) {
							  TGChatViewController *strongSelf = weakSelf;
							  if (!strongSelf)
								  return;
							  if (!ok) {
								  [strongSelf.transcriptsPending removeObject:key];
								  [strongSelf.transcripts removeObjectForKey:key];
								  [strongSelf tg_invalidateLayoutForMessageId:messageId];
								  [strongSelf.table reloadData];
								  [strongSelf showTranscriptionFailureAlertFor:problem];
								  return;
							  }
							  [strongSelf scheduleTranscriptFallbackCheckForMessage:messageId];
						  }];
}

- (void)scheduleTranscriptFallbackCheckForMessage:(int64_t)messageId {
	NSNumber *key = @(messageId);
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kTranscriptFallbackDelay * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || ![strongSelf.transcriptsPending containsObject:key])
				return;

			TGClient *client = [TGClient shared];
			[client speechTranscriptForMessage:messageId
										inChat:strongSelf.chatId
									completion:^(NSDictionary *transcript) {
										TGChatViewController *innerSelf = weakSelf;
										if (!innerSelf || ![innerSelf.transcriptsPending containsObject:key])
											return;

										NSString *state = [transcript[@"state"] isKindOfClass:NSString.class]
											? transcript[@"state"]
											: @"none";

										if ([state isEqualToString:@"text"]) {
											NSString *text = [transcript[@"text"] isKindOfClass:NSString.class]
												? transcript[@"text"]
												: @"";
											[innerSelf.transcriptsPending removeObject:key];
											innerSelf.transcripts[key] = text.length ? text : TGL(@"Message.AudioTranscription.ErrorEmpty", @"No speech was recognised.");
											[innerSelf tg_invalidateLayoutForMessageId:messageId];
											[innerSelf.table reloadData];
											return;
										}
										if ([state isEqualToString:@"error"]) {
											NSString *reason = [transcript[@"error"] isKindOfClass:NSString.class]
												? transcript[@"error"]
												: @"";
											[innerSelf.transcriptsPending removeObject:key];
											[innerSelf.transcripts removeObjectForKey:key];
											[innerSelf tg_invalidateLayoutForMessageId:messageId];
											[innerSelf.table reloadData];
											[innerSelf showTranscriptionFailureAlertFor:reason];
											return;
										}
									}];
		});
}

- (BOOL)transcriptionUpsellRequiredFor:(NSString *)errorMessage {
	if (!errorMessage.length)
		return NO;
	if ([self aiPremiumRequiredFor:errorMessage])
		return YES;
	return [errorMessage rangeOfString:@"Too Many Requests" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (void)showTranscriptionFailureAlertFor:(NSString *)errorMessage {
	if ([self transcriptionUpsellRequiredFor:errorMessage]) {
		[self showAlertTitle:TGL(@"TextProcessing.LimitToast.Title", @"Daily limit reached")
					  message:TGL(@"TextProcessing.LimitToast.Text", @"Get Telegram Premium for 50x more text edits per day.")];
		return;
	}
	NSString *fallback = TGL(@"Message.AudioTranscription.ErrorEmpty", @"No speech was recognised.");
	[self showAlertTitle:@"" message:TGFriendlyErrorText(errorMessage, fallback)];
}

- (void)translateMessage:(int64_t)messageId {
	NSNumber *key = @(messageId);
	if (self.translations[key]) {
		[self.translations removeObjectForKey:key];
		[self.translationEntities removeObjectForKey:key];
		[self tg_invalidateLayoutForMessageId:messageId];
		[self.table reloadData];
		return;
	}
	if (self.translationsPending[key])
		return;

	NSString *preferred = [[NSLocale preferredLanguages] firstObject];
	NSString *language = TGTranslationLanguageCodeForLocaleIdentifier(preferred);
	NSNumber *generation = @(++self.translationRequestGeneration);
	self.translationsPending[key] = generation;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] translateMessage:messageId
								 inChat:self.chatId
							 toLanguage:language
								   tone:nil
							 completion:^(NSString *text, NSArray *entities, NSString *errorMessage) {
								 TGChatViewController *strongSelf = weakSelf;
								 if (!strongSelf || TGTranslationResponseIsStale(strongSelf.translationsPending, key, generation))
									 return;
								 [strongSelf.translationsPending removeObjectForKey:key];
								 if (!text.length) {
									 if ([strongSelf aiPremiumRequiredFor:errorMessage])
										 [strongSelf showAlertTitle:TGL(@"TextProcessing.LimitToast.Title", @"Daily limit reached")
													message:TGL(@"TextProcessing.LimitToast.Text", @"Get Telegram Premium for 50x more text edits per day.")];
									 else
										 [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotTranslateMessage", @"Could not translate this message")];
									 return;
								 }
								 strongSelf.translations[key] = text;
								 if (entities.count)
									 strongSelf.translationEntities[key] = entities;
								 else
									 [strongSelf.translationEntities removeObjectForKey:key];
								 [strongSelf tg_invalidateLayoutForMessageId:messageId];
								 [strongSelf.table reloadData];
							 }];
}

- (void)autoTranslateMessagesIfNeeded:(NSArray *)messages {
	if (!self.chatId || ![[TGClient shared] isChatTranslatable:self.chatId])
		return;

	for (NSDictionary *m in messages) {
		if (![m isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (!messageId || !messageId.longLongValue)
			continue;
		if (self.translations[messageId] || self.translationsPending[messageId])
			continue;
		if (![self originalTextOf:m].length)
			continue;

		if (!self.autoTranslatedMessageIds)
			self.autoTranslatedMessageIds = [NSMutableSet set];
		[self.autoTranslatedMessageIds addObject:messageId];
		[self translateMessage:messageId.longLongValue];
	}
}

- (void)revertAutoTranslatedMessages {
	if (!self.autoTranslatedMessageIds.count)
		return;

	NSSet *reverting = [self.autoTranslatedMessageIds copy];
	[self.autoTranslatedMessageIds removeAllObjects];
	for (NSNumber *messageId in reverting) {
		if (!self.translations[messageId])
			continue;
		[self.translations removeObjectForKey:messageId];
		[self.translationEntities removeObjectForKey:messageId];
		[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	}
	[self.table reloadData];
}

- (void)summarizeMessage:(int64_t)messageId {
	if (self.aiSummaries[@(messageId)]) {
		[self.aiSummaries removeObjectForKey:@(messageId)];
		[self tg_invalidateLayoutForMessageId:messageId];
		[self.table reloadData];
		return;
	}

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client summarizeMessage:messageId
						 inChat:self.chatId
		translateToLanguageCode:@""
						   tone:@""
					 completion:^(NSString *text, NSString *errorMessage) {
						 TGChatViewController *strongSelf = weakSelf;
						 if (!strongSelf)
							 return;
						 if (!text.length) {
							 if ([strongSelf aiPremiumRequiredFor:errorMessage])
								 [strongSelf showAlertTitle:TGL(@"TextProcessing.LimitToast.Title", @"Daily limit reached")
											message:TGL(@"TextProcessing.LimitToast.Text", @"Get Telegram Premium for 50x more text edits per day.")];
							 else
								 [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotSummarizeMessage", @"Could not summarize this message")];
							 return;
						 }
						 strongSelf.aiSummaries[@(messageId)] = text;
						 [strongSelf tg_invalidateLayoutForMessageId:messageId];
						 [strongSelf.table reloadData];
					 }];
}

- (BOOL)aiPremiumRequiredFor:(NSString *)errorMessage {
	return [errorMessage rangeOfString:@"PREMIUM" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (void)reportMessages:(NSArray *)messageIds optionId:(NSString *)optionId {
	[self reportMessages:messageIds optionId:optionId text:@""];
}

- (void)reportMessages:(NSArray *)messageIds optionId:(NSString *)optionId text:(NSString *)text {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client reportMessages:messageIds
					inChat:self.chatId
				  optionId:optionId
					  text:(text ?: @"")
		completion:^(NSDictionary *result) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			NSString *status = result[@"status"];
			if ([status isEqualToString:@"chooseOption"] && [result[@"options"] count]) {
				strongSelf.reportMessageIds = messageIds;
				strongSelf.reportOptions = result[@"options"];
				UIActionSheet *sheetAlloc = [UIActionSheet alloc];
				UIActionSheet *sheet =
					[sheetAlloc initWithTitle:(result[@"title"] ?: TGL(@"ReportPeer.Report", @"Report"))
									  delegate:strongSelf
							 cancelButtonTitle:nil
						destructiveButtonTitle:nil
							 otherButtonTitles:nil];
				for (NSDictionary *option in strongSelf.reportOptions)
					[sheet addButtonWithTitle:(option[@"text"] ?: @"")];
				sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
				sheet.tag = kReportSheetTag;
				UIView *anchor = [strongSelf bubbleViewForMessageId:[messageIds.firstObject longLongValue]];
				[sheet tg_showFromRect:anchor.bounds inView:anchor];
				return;
			}
			if ([status isEqualToString:@"needText"]) {
				strongSelf.reportMessageIds = messageIds;
				strongSelf.reportTextOptionId = result[@"optionId"] ?: optionId;
				strongSelf.reportTextOptional = [result[@"optional"] boolValue];
				UIAlertView *askAlloc = [TGAlertView alloc];
				UIAlertView *ask = strongSelf.reportTextOptional
					? [askAlloc initWithTitle:TGL(@"ReportPeer.Report", @"Report")
									   message:TGL(@"ShareMenu.Comment", @"Add a comment")
									  delegate:strongSelf
							 cancelButtonTitle:nil
							 otherButtonTitles:TGL(@"PhotoEditor.Skip", @"Skip"), TGL(@"MediaPicker.Send", @"Send"), nil]
					: [askAlloc initWithTitle:TGL(@"ReportPeer.Report", @"Report")
									   message:TGL(@"ShareMenu.Comment", @"Add a comment")
									  delegate:strongSelf
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
							 otherButtonTitles:TGL(@"MediaPicker.Send", @"Send"), nil];
				if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
					ask.alertViewStyle = UIAlertViewStylePlainTextInput;
				ask.tag = kReportTextAlertTag;
				[ask show];
				return;
			}
			if ([status isEqualToString:@"messagesRequired"]) {
				strongSelf.reportSelectionOptionId = optionId;
				[TGSnackbar showInView:strongSelf.view
								   text:TGL(@"Report.SelectMessages", @"Select the messages to include as evidence, then tap Report.")
								seconds:3
							   onCommit:nil];
				[strongSelf beginSelectionWithMessage:[messageIds.firstObject longLongValue]];
				return;
			}
			[strongSelf showAlertTitle:@""
					   message:([status isEqualToString:@"ok"]
									   ? TGL(@"Report.Succeed", @"Telegram moderators will study your report. Thank you!")
									   : TGL(@"Report.Failed", @"This message could not be reported."))];
		}];
}

@end
