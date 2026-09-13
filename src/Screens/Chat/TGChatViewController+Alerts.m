#import "TGChatViewController.h"
#import "TGFriendlyError.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Bots.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"
#import "TGClient+Translation.h"
#import "TGLocalization.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGOldChannelsViewController.h"

@implementation TGChatViewController (Alerts)

- (NSString *)textInAlert:(UIAlertView *)alertView {
	if (![alertView respondsToSelector:@selector(textFieldAtIndex:)])
		return @"";
	return [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:
				   [NSCharacterSet whitespaceAndNewlineCharacterSet]]
		?: @"";
}

- (void)handlePastePhotoAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex) {
		self.pendingPastedImage = nil;
		return;
	}
	[self sendPendingPastedImage];
}

- (void)handleBotPasswordAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSDictionary *button = self.pendingCallbackButton;
	self.pendingCallbackButton = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !button)
		return;
	NSString *password = [alertView respondsToSelector:@selector(textFieldAtIndex:)]
		? [alertView textFieldAtIndex:0].text
		: @"";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] pressCallbackButton:button
									inChat:self.chatId
								   message:self.botButtonsMessageId
								  password:(password ?: @"")
		completion:^(NSDictionary *answer, NSString *errorMessage) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!answer) {
				[strongSelf showAlertTitle:@"" message:TGFriendlyErrorText(errorMessage, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))];
				return;
			}
			[strongSelf showCallbackAnswer:answer];
		}];
}

- (void)handleAllowBotAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client allowBotToSendMessages:[self botChatUserId] completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showAlertTitle:@"" message:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")];
			return;
		}
		[strongSelf showAlertTitle:@"" message:TGL(@"Notification.BotWriteAllowedRequest", @"You allowed this bot to message you in the app.")];
	}];
}

- (void)handleBotRequestPhoneAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	TGClient *client = [TGClient shared];
	[client sendContactFirstName:client.me[@"first_name"]
						 lastName:client.me[@"last_name"]
							phone:client.me[@"phone"]
							vcard:@""
						   userId:[client.me[@"id"] longLongValue]
						   toChat:self.chatId
						  options:[self sendOptionsDictionary]];
}

- (void)handleBotRequestLocationAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	self.locationMode = @"point";
	[self sendCurrentLocation];
}

- (void)startPendingBotLink:(NSString *)link {
	if (!link.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] openBotStartLink:link completion:^(int64_t openedChatId, NSString *errorCode) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (openedChatId) {
			[strongSelf openChatId:openedChatId title:@"Bot" isGroup:NO];
			return;
		}
		if ([errorCode isEqualToString:@"unsupported"]) {
			[TGSnackbar showInView:strongSelf.view text:TGL(@"Toast.CouldNotOpenLink", @"Could not open this link") seconds:2 onCommit:nil];
			return;
		}
		if ([errorCode isEqualToString:@"notFound"]) {
			[strongSelf showAlertTitle:@"" message:TGL(@"Resolve.ErrorNotFound", @"Sorry, this user doesn't seem to exist.")];
			return;
		}
		[strongSelf showAlertTitle:@"" message:TGFriendlyErrorText(errorCode, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))];
	}];
}

- (void)handleBotStartAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSString *link = self.pendingBotStartLink;
	self.pendingBotStartLink = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !link.length)
		return;
	[self startPendingBotLink:link];
}

- (void)handleJoinLinkAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSString *invite = self.pendingInviteLink;
	self.pendingInviteLink = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !invite.length)
		return;
	[self joinChatByInviteLinkRetrying:invite];
}

- (void)confirmJoinChatByInviteLink:(NSString *)invite info:(NSDictionary *)info {
	self.pendingInviteLink = invite;
	NSString *chatTitle = info[@"title"];
	if (!chatTitle.length)
		chatTitle = TGL(@"InviteLink.InviteLink", @"Invite Link");
	BOOL requiresApproval = [info[@"requiresApproval"] boolValue];
	NSInteger memberCount = [info[@"memberCount"] integerValue];
	NSString *membersLine = memberCount > 0
		? TGLPlural(@"Conversation.StatusMembers", memberCount, @"1 member", @"%@ members")
		: nil;
	NSString *action = requiresApproval
		? TGL(@"Chat.RequestToJoinPrompt", @"Do you want to request to join this chat?")
		: TGL(@"Chat.JoinPrompt", @"Do you want to join this chat?");
	NSString *message = membersLine.length
		? [NSString stringWithFormat:@"%@\n%@", membersLine, action]
		: action;
	NSString *confirmTitle = requiresApproval
		? TGL(@"MemberRequests.RequestToJoin", @"Request to Join")
		: TGL(@"Channel.JoinChannel", @"Join");
	UIAlertView *ask = [UIAlertView alloc];
	ask = [ask initWithTitle:chatTitle
					 message:message
					delegate:self
		   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		   otherButtonTitles:confirmTitle, nil];
	ask.tag = kJoinLinkAlertTag;
	[ask show];
}

- (void)handleAddLanguagePackAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSString *packId = self.pendingLanguagePackId;
	self.pendingLanguagePackId = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !packId.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] applyLanguagePack:packId completion:^(BOOL success, BOOL packNotFound) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!success) {
			if (packNotFound) {
				[strongSelf showAlertTitle:@"" message:TGL(@"ApplyLanguage.LanguageNotSupportedError", @"This language pack does not exist.")];
			} else {
				[TGSnackbar showInView:strongSelf.view text:TGL(@"Login.UnknownError", @"An error occurred, please try again later.") seconds:3 onCommit:nil];
			}
			return;
		}
		[TGSnackbar showInView:strongSelf.view text:TGL(@"ApplyLanguage.ApplySuccess", @"Language changed") seconds:3 onCommit:nil];
	}];
}

- (void)joinChatByInviteLinkRetrying:(NSString *)invite {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client joinChatByInviteLink:invite completion:^(int64_t joinedChatId, BOOL requestSent, NSString *errorCode) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (joinedChatId) {
			[strongSelf openChatId:joinedChatId title:@"Chat" isGroup:YES];
			return;
		}
		if (requestSent) {
			[strongSelf showAlertTitle:@"" message:TGL(@"Group.RequestToJoinSent", @"Your request to join has been sent.")];
			return;
		}
		if ([errorCode isEqualToString:@"CHANNELS_TOO_MUCH"]) {
			strongSelf.pendingInviteLink = invite;
			[strongSelf offerToLeaveAnInactiveChannel];
			return;
		}
		if ([errorCode isEqualToString:@"GUARD_BOT_REQUIRED"]) {
			[strongSelf showAlertTitle:TGL(@"Login.Fee.Verification.Title", @"Verification Required")
					   message:TGL(@"Chat.VerificationRequiredMessage", @"This chat is protected by a verification bot. Complete the verification in the Telegram app, then use the invite link again.")];
			return;
		}
		if ([errorCode isEqualToString:@"GUARD_BOT_DECLINED"]) {
			[strongSelf showAlertTitle:TGL(@"Chat.VerificationDeclined", @"Verification Declined")
					   message:TGL(@"Chat.VerificationDeclinedMessage", @"The verification bot declined this join request.")];
			return;
		}
	}];
}

- (void)offerToLeaveAnInactiveChannel {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] inactiveSupergroupChatsWithCompletion:^(NSArray *chats) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!chats.count) {
			strongSelf.pendingInviteLink = nil;
			[strongSelf showAlertTitle:@""
					   message:TGL(@"Join.ChannelsTooMuch", @"Sorry, you are a member of too many groups and channels. Please leave some before joining one.")];
			return;
		}
		strongSelf.inactiveChannelsList = chats;
		NSString *invite = strongSelf.pendingInviteLink;
		TGOldChannelsViewController *screen = [[TGOldChannelsViewController alloc] init];
		screen.chats = chats;
		__weak typeof(strongSelf) weakMe = strongSelf;
		screen.onLeft = ^{
			TGChatViewController *inner = weakMe;
			if (!inner)
				return;
			inner.pendingInviteLink = nil;
			[inner joinChatByInviteLinkRetrying:invite];
		};
		[strongSelf.navigationController pushViewController:screen animated:YES];
	}];
}

- (void)handleVenueTitleAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex) {
		[self cancelLocationFetchTimeout];
		[self.locationManager stopUpdatingLocation];
		self.locationMode = nil;
		self.venuePrefetchedLocation = nil;
		self.venueGeocodedAddress = nil;
		return;
	}
	self.venueTitle = [self textInAlert:alertView];
	if (!self.venueTitle.length) {
		[self showAlertTitle:@"" message:TGL(@"Chat.APlaceNeedsAName", @"A place needs a name.")];
		return;
	}
	UIAlertView *ask = [[TGAlertView alloc]
			initWithTitle:TGL(@"Chat.Place", @"Place")
				  message:TGL(@"Chat.ItsAddress", @"Its address")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"MediaPicker.Send", @"Send"), nil];
	if ([ask respondsToSelector:@selector(setAlertViewStyle:)]) {
		ask.alertViewStyle = UIAlertViewStylePlainTextInput;
		if (self.venueGeocodedAddress.length)
			[ask textFieldAtIndex:0].text = self.venueGeocodedAddress;
	}
	ask.tag = kVenueAddressAlertTag;
	[ask show];
}

- (void)handleVenueAddressAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex) {
		self.venueTitle = nil;
		return;
	}
	self.venueAddress = [self textInAlert:alertView];
	if (self.venuePrefetchedLocation) {
		[self sendVenueWithCachedLocation:self.venuePrefetchedLocation];
		return;
	}
	self.locationMode = @"venue";
	[self sendCurrentLocation];
}

- (void)presentAiSuggestion:(NSString *)suggestion original:(NSString *)original title:(NSString *)title {
	if (!suggestion.length)
		return;
	self.pendingAiSuggestion = suggestion;
	NSString *message = [NSString stringWithFormat:@"%@\n%@\n\n%@\n%@",
			TGL(@"TextProcessing.OriginalBadge", @"Original:"), original ?: @"",
			TGL(@"TextProcessing.ResultBadge", @"Result"), suggestion];
	UIAlertView *ask = [[TGAlertView alloc]
			initWithTitle:title
				  message:message
				 delegate:self
		cancelButtonTitle:TGL(@"TextProcessing.ActionClose", @"Close")
		otherButtonTitles:TGL(@"TextProcessing.ActionApply", @"Apply"), nil];
	ask.tag = kAiSuggestionAlertTag;
	[ask show];
}

- (void)handleAiSuggestionAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSString *suggestion = self.pendingAiSuggestion;
	self.pendingAiSuggestion = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !suggestion.length)
		return;
	self.input.text = suggestion;
	[self inputChanged];
}

- (void)presentQuoteOutdatedAlertForMessageIds:(NSArray *)messageIds {
	if (!messageIds.count)
		return;
	self.pendingQuoteRetryMessageIds = messageIds;
	UIAlertView *ask = [[TGAlertView alloc]
			initWithTitle:TGL(@"Conversation.QuoteOutdatedTitle", @"Quote Outdated")
					message:TGL(@"Conversation.QuoteOutdatedText", @"The quoted text has changed and can no longer be used. You can retry sending this message without the quote.")
				   delegate:self
		  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		  otherButtonTitles:TGL(@"Conversation.RetryWithoutQuote", @"Retry Without Quote"), nil];
	ask.tag = kQuoteOutdatedAlertTag;
	[ask show];
}

- (void)handleQuoteOutdatedAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSArray *messageIds = self.pendingQuoteRetryMessageIds;
	self.pendingQuoteRetryMessageIds = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !messageIds.count)
		return;
	int64_t paidStarCount = 0;
	for (NSNumber *messageId in messageIds) {
		NSInteger row = [self rowForMessageId:messageId.longLongValue];
		NSDictionary *found = (row != NSNotFound) ? [self messageAtRow:row] : nil;
		paidStarCount += [found[@"requiredPaidMessageStarCount"] longLongValue];
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resendMessages:messageIds inChat:self.chatId dropQuote:YES
						 paidStarCount:paidStarCount
						completion:^(NSArray *messages) {
								TGChatViewController *strongSelf = weakSelf;
								if (!strongSelf)
									return;
								if (strongSelf.selecting)
									[strongSelf endSelection];
								for (NSNumber *messageId in messageIds) {
									[strongSelf.sendStates removeObjectForKey:messageId];
									[strongSelf.sendStatesRequested removeObject:messageId];
								}
								[strongSelf reload];
							}];
}

- (void)handleReportTextAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (!self.reportTextOptional && buttonIndex == alertView.cancelButtonIndex)
		return;
	BOOL wantsText = self.reportTextOptional ? (buttonIndex == 1) : (buttonIndex != alertView.cancelButtonIndex);
	NSString *text = @"";
	if (wantsText && [alertView respondsToSelector:@selector(textFieldAtIndex:)])
		text = [alertView textFieldAtIndex:0].text ?: @"";
	[self reportMessages:self.reportMessageIds
				 optionId:self.reportTextOptionId
					 text:text];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kPastePhotoAlertTag) {
		[self handlePastePhotoAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kBotPasswordAlertTag) {
		[self handleBotPasswordAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kAllowBotAlertTag) {
		[self handleAllowBotAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kBotStartAlertTag) {
		[self handleBotStartAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kBotRequestPhoneAlertTag) {
		[self handleBotRequestPhoneAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kBotRequestLocationAlertTag) {
		[self handleBotRequestLocationAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kJoinLinkAlertTag) {
		[self handleJoinLinkAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kAddLanguagePackAlertTag) {
		[self handleAddLanguagePackAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kVenueTitleAlertTag) {
		[self handleVenueTitleAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kVenueAddressAlertTag) {
		[self handleVenueAddressAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kAiSuggestionAlertTag) {
		[self handleAiSuggestionAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kChecklistAddAlertTag) {
		[self handleChecklistAddAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kPollAddOptionAlertTag) {
		[self handlePollAddOptionAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kChecklistEditAlertTag) {
		[self handleChecklistEditAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kActionBarReportAlertTag) {
		if (buttonIndex != alertView.cancelButtonIndex)
			[self performActionBarReportSpam];
		return;
	}
	if (alertView.tag == kActionBarSharePhoneAlertTag) {
		if (buttonIndex != alertView.cancelButtonIndex)
			[self performActionBarSharePhoneNumber];
		return;
	}
	if (alertView.tag == kFactCheckAlertTag) {
		[self handleFactCheckAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kApprovePostAlertTag) {
		if (buttonIndex != alertView.cancelButtonIndex)
			[self performApproveSuggestedPost];
		return;
	}
	if (alertView.tag == kDeclinePostAlertTag) {
		if (buttonIndex == alertView.cancelButtonIndex)
			return;
		NSString *comment = [alertView respondsToSelector:@selector(textFieldAtIndex:)]
			? [alertView textFieldAtIndex:0].text
			: @"";
		[self performDeclineSuggestedPostWithComment:comment ?: @""];
		return;
	}
	if (alertView.tag == kSuggestPostPriceAlertTag) {
		if (buttonIndex == alertView.cancelButtonIndex)
			return;
		NSString *priceText = [alertView respondsToSelector:@selector(textFieldAtIndex:)]
			? [alertView textFieldAtIndex:0].text
			: @"";
		self.suggestPostStarCount = MAX(0, [priceText longLongValue]);
		[self showSuggestPostTimingSheet];
		return;
	}
	if (alertView.tag == kQuoteOutdatedAlertTag) {
		[self handleQuoteOutdatedAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kSuggestedPostDeleteWarningAlertTag) {
		NSDictionary *pendingMessage = self.pendingDeleteMessage;
		BOOL pendingForEveryone = self.pendingDeleteForEveryone;
		self.pendingDeleteMessage = nil;
		if (buttonIndex != alertView.cancelButtonIndex && pendingMessage)
			[self performDeleteMessage:pendingMessage forEveryone:pendingForEveryone];
		return;
	}
	if (alertView.tag == kWallpaperRevertAlertTag) {
		[self handleWallpaperRevertAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag != kReportTextAlertTag)
		return;
	[self handleReportTextAlert:alertView buttonIndex:buttonIndex];
}

@end
