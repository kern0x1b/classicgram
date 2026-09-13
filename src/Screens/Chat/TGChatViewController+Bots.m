#import "TGClient+Contacts.h"
#import "TGFriendlyError.h"
#import "TGClient+ChatManagement.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGClient+Bots.h"
#import "TGClient+Search.h"
#import "TGClient+WebLinks.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGAlertView.h"
#import "TGForwardPicker.h"
#import "TGBotCommandsViewController.h"
#import "TGSimilarBotsViewController.h"
#import "TGStarsViewController.h"

@implementation TGChatViewController (Bots)

#pragma mark - bots

- (int64_t)botChatUserId {
	return (!self.group && self.chatId > 0 &&
			   self.chatId != [[TGClient shared] savedMessagesChatId])
		? self.chatId
		: 0;
}

- (void)detectBotChat {
	int64_t botId = [self botChatUserId];
	if (!botId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] botInfoForUser:botId completion:^(NSDictionary *info) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.chatIsWithBot = (info != nil);
		strongSelf.chatCanReceiveGift = (info == nil);
	}];
}

- (void)detectGiftEligibility {
	if (!self.group)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] canSendInChat:self.chatId completion:^(BOOL canSend, BOOL isChannel, NSDictionary *permissions) {
		TGChatViewController *strongSelf = weakSelf;
		if (strongSelf)
			strongSelf.chatCanReceiveGift = isChannel;
	}];
}

- (void)detectGroupBotCommands {
	if (!self.group)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] botCommandsInGroup:chatId completion:^(NSArray *bots) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.groupBotCommandGroups = bots ?: @[];
	}];
}

- (void)prefetchRecentInlineBots {
	if (self.recentInlineBotList)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recentInlineBotsWithCompletion:^(NSArray *bots, BOOL failed) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.recentInlineBotList || failed)
			return;
		strongSelf.recentInlineBotList = bots ?: @[];
	}];
}

- (void)showBotMenu {
	int64_t botId = [self botChatUserId];
	if (!botId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] canBotSendMessages:botId completion:^(BOOL allowed) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		UIActionSheet *sheet = [UIActionSheet alloc];
		sheet = [sheet initWithTitle:TGL(@"Attachment.Bot", @"Bot")
							delegate:strongSelf
				   cancelButtonTitle:nil
			  destructiveButtonTitle:nil
				   otherButtonTitles:TGL(@"Chat.Commands", @"Commands"),
			TGL(@"Bot.DescriptionTitle", @"What can this bot do?"),
			TGL(@"Chat.BotMenuButton", @"Menu Button"),
			TGL(@"Chat.StartBot", @"Start Bot"),
			TGL(@"PeerInfo.PaneRecommendedBots", @"Similar Bots"), nil];
		if (!allowed)
			[sheet addButtonWithTitle:TGL(@"Chat.AllowMessagesFromThisBot", @"Allow Messages From This Bot")];
		sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
		sheet.tag = kBotMenuSheetTag;
		[sheet tg_showFromRect:CGRectMake(0, 0, 41, kInputHeight) inView:strongSelf.inputBar];
	}];
}

- (void)runBotMenu:(NSString *)chosen {
	int64_t botId = [self botChatUserId];
	if (!botId)
		return;
	__weak typeof(self) weakSelf = self;

	if ([chosen isEqualToString:TGL(@"Chat.Commands", @"Commands")]) {
		NSString *typed = [self composerText];
		void (^show)(NSArray *) = ^(NSArray *commands) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf tgb_presentBotCommandsList:commands];
		};
		if ([typed hasPrefix:@"/"] && typed.length > 1)
			[[TGClient shared] botCommandsForUser:botId matchingPrefix:typed
									   completion:show];
		else
			[[TGClient shared] botCommandsForUser:botId completion:show];
		return;
	}

	if ([chosen isEqualToString:TGL(@"Bot.DescriptionTitle", @"What can this bot do?")]) {
		[[TGClient shared] botInfoForUser:botId completion:^(NSDictionary *info) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!info)
				return;
			NSString *description = info[@"description"];
			if (!description.length)
				description = info[@"shortDescription"];
			NSInteger commandCount = [info[@"commands"] count];
			NSMutableString *body = [NSMutableString string];
			[body appendString:(description.length ? description : TGL(@"Chat.NoBotDescription", @"No description."))];
			if (commandCount)
				[body appendFormat:TGL(@"Chat.BotCommandCountSuffix", @"\n\n%ld commands"), (long)commandCount];
			[strongSelf showAlertTitle:(strongSelf.chatTitle ?: TGL(@"Attachment.Bot", @"Bot")) message:body];
		}];
		return;
	}

	if ([chosen isEqualToString:TGL(@"Chat.BotMenuButton", @"Menu Button")]) {
		[[TGClient shared] menuButtonForBot:botId completion:^(NSDictionary *button) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			NSString *url = button[@"url"];
			if (!url.length) {
				[strongSelf runBotMenu:TGL(@"Chat.Commands", @"Commands")];
				return;
			}
			[strongSelf openLink:url];
		}];
		return;
	}

	if ([chosen isEqualToString:TGL(@"Chat.StartBot", @"Start Bot")]) {
		[[TGClient shared] startBot:botId inChat:self.chatId parameter:nil
			completion:^(BOOL ok, NSString *errorMessage) {
				TGChatViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				if (!ok) {
					[strongSelf showAlertTitle:@"" message:TGFriendlyErrorText(errorMessage, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))];
					return;
				}
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
					dispatch_get_main_queue(), ^{ [weakSelf reload]; });
			}];
		return;
	}

	if ([chosen isEqualToString:TGL(@"PeerInfo.PaneRecommendedBots", @"Similar Bots")]) {
		TGSimilarBotsViewController *list = [[TGSimilarBotsViewController alloc] init];
		list.botUserId = botId;
		list.onPick = ^(NSDictionary *entry) {
			[weakSelf openBotFromEntry:entry];
		};
		[self.navigationController pushViewController:list animated:YES];
		return;
	}

	if ([chosen isEqualToString:TGL(@"Chat.AllowMessagesFromThisBot", @"Allow Messages From This Bot")]) {
		NSString *botTitle = self.chatTitle ?: TGL(@"Attachment.Bot", @"Bot");
		UIAlertView *ask = [UIAlertView alloc];
		ask = [ask initWithTitle:botTitle
						 message:[NSString stringWithFormat:
								   TGL(@"WebApp.AllowWriteConfirmation", @"This will allow the bot %@ to message you on Telegram."),
							   botTitle]
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"WebApp.EmojiPermission.Allow", @"Allow"), nil];
		ask.tag = kAllowBotAlertTag;
		[ask show];
	}
}

- (void)openBotFromEntry:(NSDictionary *)entry {
	int64_t userId = [entry[@"id"] longLongValue];
	if (!userId)
		return;
	int64_t sourceBotId = [self botChatUserId];
	if (sourceBotId)
		[[TGClient shared] openSimilarBot:userId fromBot:sourceBotId];
	NSString *name = entry[@"name"] ?: (entry[@"username"] ?: TGL(@"Attachment.Bot", @"Bot"));
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t openedChatId) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!openedChatId) {
			[strongSelf showAlertTitle:@"" message:TGL(@"Resolve.ErrorNotFound", @"Sorry, this user doesn't seem to exist.")];
			return;
		}
		[strongSelf openChatId:openedChatId title:name isGroup:NO];
	}];
}

- (void)tgb_presentBotCommandsList:(NSArray *)commands {
	if (!commands.count)
		return;
	__weak typeof(self) weakSelf = self;
	TGBotCommandsViewController *list = [[TGBotCommandsViewController alloc] init];
	list.commands = commands;
	list.onPick = ^(NSString *command) {
		TGChatViewController *innerSelf = weakSelf;
		if (!innerSelf || !command.length)
			return;
		innerSelf.input.text = [NSString stringWithFormat:@"/%@", command];
		[innerSelf inputChanged];
		[innerSelf sendTapped];
	};
	[self.navigationController pushViewController:list animated:YES];
}

- (void)showGroupBotCommandsMenu {
	NSArray *bots = self.groupBotCommandGroups;
	if (!bots.count)
		return;
	if (bots.count == 1) {
		[self tgb_presentBotCommandsList:bots.firstObject[@"commands"]];
		return;
	}
	UIActionSheet *sheetAlloc = [UIActionSheet alloc];
	UIActionSheet *sheet = [sheetAlloc initWithTitle:TGL(@"Chat.Commands", @"Commands")
											 delegate:self
									cancelButtonTitle:nil
							   destructiveButtonTitle:nil
									otherButtonTitles:nil];
	for (NSDictionary *bot in bots)
		[sheet addButtonWithTitle:(bot[@"name"] ?: TGL(@"Attachment.Bot", @"Bot"))];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kGroupBotCommandsPickSheetTag;
	[sheet tg_showFromRect:CGRectMake(0, 0, 41, kInputHeight) inView:self.inputBar];
}

- (void)runGroupBotCommandsPick:(NSInteger)index {
	NSArray *bots = self.groupBotCommandGroups;
	if (index < 0 || index >= (NSInteger)bots.count)
		return;
	[self tgb_presentBotCommandsList:bots[index][@"commands"]];
}

#pragma mark - bot keyboards

- (NSArray *)botButtonsForMessage:(NSDictionary *)m {
	NSMutableArray *flat = [NSMutableArray array];
	for (NSArray *row in [[TGClient shared] inlineKeyboardRowsForMessage:m])
		for (NSDictionary *button in row)
			if ([button isKindOfClass:NSDictionary.class])
				[flat addObject:button];

	NSDictionary *replyKeyboard = [[TGClient shared] replyKeyboardForMessage:m];
	for (NSArray *row in replyKeyboard[@"rows"]) {
		for (NSDictionary *button in row) {
			if (![button isKindOfClass:NSDictionary.class])
				continue;
			NSMutableDictionary *copy = [button mutableCopy];
			copy[@"replyKeyboard"] = @YES;
			[flat addObject:copy];
		}
	}
	return flat;
}

- (BOOL)tgb_beginForceReplyToMessage:(NSDictionary *)m {
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return NO;
	[self setComposeMode:TGComposeModeReply messageId:messageId];
	[self.sendButton setTitle:TGL(@"MediaPicker.Send", @"Send") forState:UIControlStateNormal];
	NSString *bodyText = [self textOf:m];
	[self showComposeBanner:[NSString stringWithFormat:TGL(@"Chat.ReplyPanel.ReplyTo", @"Reply to: %@"),
								bodyText.length ? bodyText : (m[@"kind"] ?: @"message")]];
	NSString *placeholder = [[TGClient shared] replyKeyboardForMessage:m][@"placeholder"];
	if (placeholder.length)
		self.inputPlaceholder.text = placeholder;
	[self.input becomeFirstResponder];
	return YES;
}

- (BOOL)offerBotButtonsForRow:(NSInteger)row message:(NSDictionary *)m {
	NSArray *buttons = [self botButtonsForMessage:m];
	if (!buttons.count) {
		NSDictionary *replyKeyboard = [[TGClient shared] replyKeyboardForMessage:m];
		if ([replyKeyboard[@"mode"] isEqualToString:@"forceReply"])
			return [self tgb_beginForceReplyToMessage:m];
		return NO;
	}

	self.botButtons = buttons;
	self.botButtonsMessageId = [m[@"id"] longLongValue];
	self.botButtonsMessageInvoicePaid = [m[@"invoicePaid"] boolValue];
	self.botButtonsRow = row;

	UIActionSheet *sheet = [UIActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Chat.BotButtons", @"Bot Buttons")
						delegate:self
			   cancelButtonTitle:nil
		  destructiveButtonTitle:nil
			   otherButtonTitles:nil];
	NSInteger shown = MIN((NSUInteger)8, buttons.count);
	for (NSInteger i = 0; i < shown; i++) {
		NSString *text = buttons[i][@"text"];
		[sheet addButtonWithTitle:(text.length ? text : TGL(@"Chat.Button", @"Button"))];
	}
	[sheet addButtonWithTitle:TGL(@"Chat.MessageActions", @"Message Actions")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kBotButtonsSheetTag;
	NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
	UITableViewCell *cell = [self.table cellForRowAtIndexPath:path];
	[sheet tg_showFromRect:cell.frame inView:self.table];
	return YES;
}

- (void)runBotButtonAtIndex:(NSInteger)index {
	NSInteger shown = MIN((NSUInteger)8, self.botButtons.count);
	if (index < 0 || index >= (NSInteger)shown) {
		[self showActionsSheetForRow:self.botButtonsRow];
		return;
	}
	NSDictionary *button = self.botButtons[index];
	NSString *kind = button[@"kind"];
	int64_t messageId = self.botButtonsMessageId;
	__weak typeof(self) weakSelf = self;

	if ([button[@"replyKeyboard"] boolValue]) {
		[self runReplyKeyboardButton:button messageId:messageId];
		return;
	}

	if ([kind isEqualToString:@"url"] || [kind isEqualToString:@"webApp"]) {
		[self openLink:button[@"url"]];
		return;
	}

	if ([kind isEqualToString:@"loginUrl"]) {
		[self tgb_runLoginUrlButton:button];
		return;
	}

	if ([kind isEqualToString:@"buy"]) {
		if (self.botButtonsMessageInvoicePaid)
			[TGStarsViewController presentReceiptForMessage:messageId chat:self.chatId fromViewController:self];
		else
			[TGStarsViewController presentInvoiceForMessage:messageId chat:self.chatId fromViewController:self];
		return;
	}

	if ([kind isEqualToString:@"copyText"]) {
		NSString *text = button[@"copyText"] ?: button[@"text"];
		if (!text.length)
			return;
		[UIPasteboard generalPasteboard].string = text;
		[TGSnackbar showInView:self.view text:TGL(@"Conversation.TextCopied", @"Text copied to clipboard") seconds:3 onCommit:nil];
		return;
	}

	if ([kind isEqualToString:@"switchInline"]) {
		NSString *query = button[@"query"] ?: @"";
		NSString *target = button[@"target"];
		NSDictionary *sourceMessage = [self messageAtRow:self.botButtonsRow];
		int64_t botUserId = [self tgb_botUserIdForMessage:sourceMessage];
		NSString *botUsername = botUserId ? [[TGClient shared] usernameForUserId:botUserId] : nil;
		NSString *composedText = botUsername.length
			? [NSString stringWithFormat:@"@%@ %@", botUsername, query]
			: query;
		if (![target isEqualToString:@"chosen"] && ![target isEqualToString:@"link"]) {
			self.input.text = composedText;
			[self inputChanged];
			[self.input becomeFirstResponder];
			return;
		}
		[self tgb_pickChatForSwitchInlineQuery:composedText];
		return;
	}

	if ([kind isEqualToString:@"user"]) {
		int64_t userId = [button[@"userId"] longLongValue];
		[self openProfileForUserId:userId];
		return;
	}

	if ([kind isEqualToString:@"callbackWithPassword"]) {
		self.pendingCallbackButton = button;
		UIAlertView *ask = [TGAlertView alloc];
		ask = [ask initWithTitle:(button[@"text"] ?: TGL(@"LoginPassword.PasswordPlaceholder", @"Password"))
						 message:TGL(@"OwnershipTransfer.EnterPasswordText", @"Please enter your 2-Step Verification password to confirm the action.")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"MediaPicker.Send", @"Send"), nil];
		if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
			ask.alertViewStyle = UIAlertViewStyleSecureTextInput;
		ask.tag = kBotPasswordAlertTag;
		[ask show];
		return;
	}

	if ([kind isEqualToString:@"callbackGame"]) {
		[TGSnackbar showInView:self.view text:TGL(@"Chat.GameButtonUnsupported", @"Games aren't supported in this app.") seconds:3 onCommit:nil];
		return;
	}

	if ([kind isEqualToString:@"callback"]) {
		[[TGClient shared] pressCallbackButton:button
										inChat:self.chatId
									   message:messageId
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
		return;
	}
}

- (int64_t)tgb_botUserIdForMessage:(NSDictionary *)m {
	int64_t viaBotId = [m[@"viaBotId"] longLongValue];
	if (viaBotId != 0)
		return viaBotId;
	return [m[@"senderId"] longLongValue];
}

- (void)tgb_runLoginUrlButton:(NSDictionary *)button {
	int64_t buttonId = [button[@"buttonId"] longLongValue];
	int64_t messageId = self.botButtonsMessageId;
	int64_t chatId = self.chatId;
	NSString *fallbackUrl = button[@"url"];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] loginUrlInfoForButton:buttonId
									inMessage:messageId
									   inChat:chatId
								   completion:^(NSDictionary *info) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!info) {
			[strongSelf openLink:fallbackUrl];
			return;
		}
		if (![info[@"needsConfirmation"] boolValue]) {
			[strongSelf openLink:info[@"url"]];
			return;
		}
		[strongSelf tgb_confirmLoginUrl:info
							   buttonId:buttonId
							  messageId:messageId
								 chatId:chatId
							fallbackUrl:fallbackUrl];
	}];
}

- (void)tgb_confirmLoginUrl:(NSDictionary *)info
					buttonId:(int64_t)buttonId
				   messageId:(int64_t)messageId
					  chatId:(int64_t)chatId
				 fallbackUrl:(NSString *)fallbackUrl {
	NSString *domain = [info[@"domain"] length] ? info[@"domain"] : fallbackUrl;
	int64_t botUserId = [info[@"botUserId"] longLongValue];
	NSString *botName = [[TGClient shared] nameForUserId:botUserId] ?: TGL(@"Attachment.Bot", @"Bot");
	BOOL allowWrite = [info[@"requestWriteAccess"] boolValue];
	NSMutableString *message = [NSMutableString stringWithFormat:
		TGL(@"Conversation.OpenBotLinkLogin", @"Log in to %@ as %@?"), domain, botName];
	if (allowWrite)
		[message appendFormat:@"\n\n%@", [NSString stringWithFormat:
			TGL(@"WebApp.AllowWriteConfirmation", @"This will allow the bot %@ to message you on Telegram."), botName]];

	__weak typeof(self) weakSelf = self;
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"AuthConfirmation.LogIn", @"Log in")
				  message:message
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			okButtonTitle:TGL(@"AuthConfirmation.LogIn", @"Log in")
		  completionBlock:^(bool okButtonPressed) {
			  TGChatViewController *strongSelf = weakSelf;
			  if (!strongSelf || !okButtonPressed)
				  return;
			  [[TGClient shared] loginUrlForButton:buttonId
										  inMessage:messageId
											 inChat:chatId
								   allowWriteAccess:allowWrite
										 completion:^(NSString *url) {
				  TGChatViewController *innerSelf = weakSelf;
				  if (!innerSelf)
					  return;
				  [innerSelf openLink:url.length ? url : fallbackUrl];
			  }];
		  }];
	[alert show];
}

- (void)tgb_pickChatForSwitchInlineQuery:(NSString *)query {
	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSArray *chatIds) {
		int64_t pickedChatId = [[chatIds firstObject] longLongValue];
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !pickedChatId)
			return;
		NSDictionary *chat = nil;
		for (NSDictionary *candidate in [TGClient shared].chats) {
			if ([candidate isKindOfClass:NSDictionary.class] &&
				[candidate[@"id"] longLongValue] == pickedChatId) {
				chat = candidate;
				break;
			}
		}
		NSString *title = [chat[@"title"] isKindOfClass:NSString.class]
			? chat[@"title"]
			: TGL(@"ChatList.UnnamedChat", @"Chat");
		BOOL isGroup = [chat[@"isGroup"] boolValue];
		[strongSelf openChatId:pickedChatId
						  title:title
						isGroup:isGroup
				   focusMessage:0
					 completion:^(TGChatViewController *target) {
						 target.input.text = query;
						 [target inputChanged];
						 [target.input becomeFirstResponder];
					 }];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)showCallbackAnswer:(NSDictionary *)answer {
	if (!answer)
		return;
	NSString *url = answer[@"url"];
	if (url.length) {
		[self openLink:url];
		return;
	}
	NSString *text = answer[@"text"];
	if (!text.length) {
		[TGSnackbar showInView:self.view text:TGL(@"Common.Done", @"Done") seconds:2 onCommit:nil];
		return;
	}
	if ([answer[@"showAlert"] boolValue])
		[self showAlertTitle:@"" message:text];
	else
		[TGSnackbar showInView:self.view text:text seconds:3 onCommit:nil];
}

- (void)runReplyKeyboardButton:(NSDictionary *)button messageId:(int64_t)messageId {
	NSString *kind = button[@"kind"];

	if (!kind.length || [kind isEqualToString:@"text"]) {
		NSString *text = button[@"text"];
		if (!text.length)
			return;
		self.input.text = text;
		[self inputChanged];
		[self sendTapped];
		return;
	}

	if ([kind isEqualToString:@"requestLocation"]) {
		UIAlertView *ask = [UIAlertView alloc];
		ask = [ask initWithTitle:TGL(@"Conversation.ShareBotLocationConfirmationTitle", @"Share Your Location?")
						 message:TGL(@"Conversation.ShareBotLocationConfirmation", @"This will send your current location to the bot.")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.OK", @"OK"), nil];
		ask.tag = kBotRequestLocationAlertTag;
		[ask show];
		return;
	}

	if ([kind isEqualToString:@"requestPhoneNumber"]) {
		UIAlertView *ask = [UIAlertView alloc];
		ask = [ask initWithTitle:TGL(@"Conversation.ShareBotContactConfirmationTitle", @"Share Your Phone Number?")
						 message:TGL(@"Conversation.ShareBotContactConfirmation", @"The bot will know your phone number. This can be useful for integration with other services.")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Conversation.ShareMyPhoneNumber", @"Share My Phone Number"), nil];
		ask.tag = kBotRequestPhoneAlertTag;
		[ask show];
		return;
	}

	if ([kind isEqualToString:@"requestPoll"]) {
		[self showPollComposer];
		return;
	}

	if ([kind isEqualToString:@"webApp"]) {
		[self openLink:button[@"url"]];
		return;
	}

	if ([kind isEqualToString:@"requestUsers"] || [kind isEqualToString:@"requestChat"]) {
		self.sharePickerKind = kind;
		self.sharePickerButtonId = [button[@"buttonId"] integerValue];
		self.sharePickerMessageId = messageId;
		TGForwardPicker *picker = [[TGForwardPicker alloc] init];
		BOOL requestsChannel = [kind isEqualToString:@"requestChat"] && [button[@"chatIsChannel"] boolValue];
		picker.requiredKind = [kind isEqualToString:@"requestUsers"]
			? @"user"
			: (requestsChannel ? @"channel" : @"group");
		__weak typeof(self) weakSelf = self;
		picker.onPicked = ^(NSArray *chatIds) {
			[weakSelf completeShareWithChatId:[[chatIds firstObject] longLongValue]];
		};
		[self.navigationController pushViewController:picker animated:YES];
		return;
	}
}

- (void)completeShareWithChatId:(int64_t)pickedChatId {
	if (!pickedChatId || !self.sharePickerKind.length)
		return;

	NSString *kind = self.sharePickerKind;
	self.sharePickerKind = nil;
	__weak typeof(self) weakSelf = self;
	void (^completion)(BOOL, NSString *) = ^(BOOL ok, NSString *errorMessage) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showAlertTitle:@"" message:TGFriendlyErrorText(errorMessage, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))];
			return;
		}
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{ [weakSelf reload]; });
	};

	if ([kind isEqualToString:@"requestUsers"]) {
		[[TGClient shared] shareUsers:@[ @(pickedChatId) ]
						withBotButton:self.sharePickerButtonId
							   inChat:self.chatId
							  message:self.sharePickerMessageId
							completion:completion];
	} else {
		[[TGClient shared] shareChat:pickedChatId
					   withBotButton:self.sharePickerButtonId
							  inChat:self.chatId
							 message:self.sharePickerMessageId
						   completion:completion];
	}
}

#pragma mark - inline bots

- (void)runInlineQueryForBot:(int64_t)botId query:(NSString *)query offset:(NSString *)offset {
	NSInteger generation = self.inlineQueryGeneration;
	BOOL isLoadMore = offset.length > 0;
	if (isLoadMore)
		self.inlineQueryLoadingMore = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] inlineQueryToBot:botId inChat:self.chatId query:(query ?: @"") offset:offset
		completion:^(NSDictionary *results) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (isLoadMore)
				strongSelf.inlineQueryLoadingMore = NO;
			if (generation != strongSelf.inlineQueryGeneration)
				return;
			if (!results) {
				if (!isLoadMore)
					[strongSelf clearInlineBotQuery];
				return;
			}
			strongSelf.inlineQueryId = results[@"queryId"];
			strongSelf.inlineQueryBotId = botId;
			strongSelf.inlineQueryNextOffset = results[@"nextOffset"];
			NSString *buttonText = results[@"buttonText"];
			strongSelf.inlineQueryButtonParameter = buttonText.length ? results[@"buttonParameter"] : nil;
			if (isLoadMore)
				[strongSelf appendInlineQueryResults:results[@"results"]];
			else
				[strongSelf showInlineQueryResults:results[@"results"] buttonText:buttonText];
		}];
}

@end
