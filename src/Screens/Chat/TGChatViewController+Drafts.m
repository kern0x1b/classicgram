#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGPopupMenu.h"
#import "TGClient+SecretChats.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+MessageContent.h"
#import "TGClient+Premium.h"
#import "TGSendAsPremiumGuard.h"

@implementation TGChatViewController (Drafts)

#pragma mark - drafts

- (void)restoreDraft {
	if (self.draftRestored)
		return;
	self.draftRestored = YES;
	[self fetchAndApplyDraftIfComposerEmpty];
}

- (void)chatDraftChanged:(NSNotification *)note {
	if (note.object && ![note.object isEqual:@(self.chatId)])
		return;
	[self fetchAndApplyDraftIfComposerEmpty];
}

- (void)fetchAndApplyDraftIfComposerEmpty {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] draftForChat:self.chatId
							  thread:self.threadId
				 directMessagesTopic:self.directMessagesTopicId
						  savedTopic:self.savedTopicId
						 completion:^(NSString *text, int64_t replyToId, NSArray *customEmojiRuns,
							 NSArray *mentionRuns, NSString *quoteText, NSArray *quoteEntities,
							 NSInteger quotePosition) {
							 TGChatViewController *strongSelf = weakSelf;
							 if (!strongSelf || (!text.length && replyToId == 0))
								 return;

							 BOOL composerWasEmpty = !strongSelf.input.text.length;

							 if (text.length && composerWasEmpty) {
								 strongSelf.input.text = text;
								 [strongSelf inputChanged];

								 strongSelf.pendingCustomEmojiRuns = [customEmojiRuns mutableCopy] ?: [NSMutableArray array];
								 strongSelf.pendingMentionRuns = [mentionRuns mutableCopy] ?: [NSMutableArray array];
								 [strongSelf refreshComposerCustomEmojiOverlay];
							 }

							 if (replyToId != 0 && strongSelf.replyToId == 0 && composerWasEmpty) {
								 strongSelf.replyToId = replyToId;
								 strongSelf.replyQuoteText = quoteText;
								 strongSelf.replyQuoteEntities = quoteEntities;
								 strongSelf.replyQuotePosition = quotePosition;
								 [strongSelf showComposeBanner:(quoteText.length
									 ? [NSString stringWithFormat:TGL(@"Chat.ReplyPanel.ReplyTo", @"Reply to: %@"), quoteText]
									 : TGL(@"Chat.ReplyPanel.ReplyToMessage", @"Reply to message"))];
							 }
						 }];
}

- (void)flushDraftOnAppState:(NSNotification *)note {
	[self saveDraft];
}

- (void)saveDraft {
	if (self.editingId != 0)
		return;
	NSString *text = self.input.text ?: @"";
	NSArray *customEmojiEntities = [self customEmojiEntitiesForOriginalText:text sentAsText:text];
	NSArray *mentionEntities = [self mentionNameEntitiesForOriginalText:text sentAsText:text];
	NSMutableArray *entities = [NSMutableArray array];
	if (customEmojiEntities.count > 0)
		[entities addObjectsFromArray:customEmojiEntities];
	if (mentionEntities.count > 0)
		[entities addObjectsFromArray:mentionEntities];
	[[TGClient shared] setDraftText:text
						   entities:entities
							replyTo:self.replyToId
						  quoteText:self.replyQuoteText
					  quoteEntities:self.replyQuoteEntities
					  quotePosition:self.replyQuotePosition
							 inChat:self.chatId
							 thread:self.threadId
				directMessagesTopic:self.directMessagesTopicId
						 savedTopic:self.savedTopicId];
}

#pragma mark - send options

- (void)sendHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan || self.postingBlocked)
		return;

	BOOL hasText = [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
	BOOL reminders = [self isRemindersChat];

	NSMutableArray *titles = [NSMutableArray array];
	if (hasText)
		[titles addObject:TGL(@"Conversation.SendMessage.SendSilently", @"Send Without Sound")];
	if ([self allowsViewOnceMedia]) {
		NSString *viewOnce = self.sendMediaOnce ? TGL(@"Chat.KeepMediaInTheChat", @"Keep Media in the Chat")
												: TGL(@"MediaPicker.Timer.ViewOnce", @"Send Media Once");
		[titles addObject:viewOnce];
		NSString *timer = self.pendingSelfDestructSeconds > 0
			? [NSString stringWithFormat:TGL(@"Chat.SelfDestructTimer", @"Self-Destruct Timer: %@"),
				[TGClient autoDeleteTitleForSeconds:self.pendingSelfDestructSeconds]]
			: TGL(@"Chat.SelfDestructTimerPlaceholder", @"Self-Destruct Timer");
		[titles addObject:timer];
	}
	if ([self allowsMessageEffects])
		[titles addObject:(self.pendingEffectId
								  ? [NSString stringWithFormat:TGL(@"Chat.MessageEffect", @"Message Effect: %@"),
										self.pendingEffectEmoji ?: @""]
								  : TGL(@"Chat.MessageEffectPlaceholder", @"Message Effect"))];
	if (self.availableSenders.count > 1)
		[titles addObject:TGL(@"Conversation.SendMessageAs", @"Send Message As...")];
	if (![[TGClient shared] isSecretChat:self.chatId])
		[titles addObject:TGL(@"Chat.TextTools", @"Text Tools")];
	if (hasText && self.directMessagesTopicId == 0 && ![[TGClient shared] isSecretChat:self.chatId]) {
		[titles addObject:(reminders ? TGL(@"Conversation.SetReminder.Title", @"Remind me") : TGL(@"Conversation.SendMessage.ScheduleMessage", @"Schedule Message"))];
		if (!self.group && !reminders && !self.chatIsWithBot)
			[titles addObject:TGL(@"Conversation.SendMessage.SendWhenOnline", @"When Online")];
	}
	if (self.scheduledMessages.count)
		[titles addObject:(reminders ? TGL(@"ScheduledMessages.RemindersTitle", @"Reminders") : TGL(@"VoiceOver.ScheduledMessages", @"Scheduled Messages"))];

	if (!titles.count)
		return;

	NSMutableArray *items = [NSMutableArray array];
	for (NSString *title in titles)
		[items addObject:@{ @"title" : title }];

	CGRect anchor = [self.view convertRect:self.sendButton.bounds fromView:self.sendButton];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items
					atPoint:CGPointMake(CGRectGetMidX(anchor), CGRectGetMinY(anchor))
					 inView:self.view
				   onChoice:^(NSInteger index, NSString *title) {
					   [weakSelf runSendOption:title];
				   }];
}

- (void)runSendOption:(NSString *)title {
	if ([title isEqualToString:TGL(@"Conversation.SendMessage.SendSilently", @"Send Without Sound")]) {
		self.sendSilently = YES;
		[self sendTapped];
		self.sendSilently = NO;
		return;
	}
	if ([title isEqualToString:TGL(@"Conversation.SendMessage.SendWhenOnline", @"When Online")]) {
		self.scheduleWhenOnline = YES;
		[self sendTapped];
		return;
	}
	if ([title isEqualToString:TGL(@"MediaPicker.Timer.ViewOnce", @"Send Media Once")] ||
		[title isEqualToString:TGL(@"Chat.KeepMediaInTheChat", @"Keep Media in the Chat")]) {
		self.sendMediaOnce = !self.sendMediaOnce;
		if (self.sendMediaOnce)
			self.pendingSelfDestructSeconds = 0;
		[TGSnackbar showInView:self.view
						  text:(self.sendMediaOnce
									   ? TGL(@"Chat.TheNextPhotoOrVideoCan", @"The next photo or video can be opened once")
									   : TGL(@"Chat.PhotosAndVideosStayInTheChat", @"Photos and videos stay in the chat"))
			seconds:3
					  onCommit:nil];
		return;
	}
	if ([title hasPrefix:TGL(@"Chat.SelfDestructTimerPlaceholder", @"Self-Destruct Timer")]) {
		[self showSelfDestructTimerPicker];
		return;
	}
	if ([title isEqualToString:TGL(@"Chat.TextTools", @"Text Tools")]) {
		[self showTextTools];
		return;
	}
	if ([title hasPrefix:TGL(@"Chat.MessageEffectPlaceholder", @"Message Effect")]) {
		[self showEffectPicker];
		return;
	}
	if ([title isEqualToString:TGL(@"Conversation.SendMessageAs", @"Send Message As...")]) {
		[self showSendAsPicker];
		return;
	}
	if ([title isEqualToString:TGL(@"Conversation.SendMessage.ScheduleMessage", @"Schedule Message")] ||
		[title isEqualToString:TGL(@"Conversation.SetReminder.Title", @"Remind me")]) {
		[self showSchedulePicker];
		return;
	}
	if ([title isEqualToString:TGL(@"VoiceOver.ScheduledMessages", @"Scheduled Messages")] ||
		[title isEqualToString:TGL(@"ScheduledMessages.RemindersTitle", @"Reminders")])
		[self showScheduledMessages];
}

- (void)showSelfDestructTimerPicker {
	static const NSInteger kSelfDestructTimerLadder[] = { 3, 10, 30 };
	NSMutableArray *actions = [NSMutableArray array];
	for (NSUInteger i = 0; i < sizeof(kSelfDestructTimerLadder) / sizeof(kSelfDestructTimerLadder[0]); i++) {
		NSInteger seconds = kSelfDestructTimerLadder[i];
		[actions addObject:[[TGActionSheetAction alloc]
			initWithTitle:[TGClient autoDeleteTitleForSeconds:seconds]
				   action:[NSString stringWithFormat:@"%ld", (long)seconds]]];
	}
	[actions addObject:[[TGActionSheetAction alloc]
		initWithTitle:TGL(@"MediaPicker.Timer.DoNotDelete", @"Do Not Delete")
			   action:@"off"]];
	[actions addObject:[[TGActionSheetAction alloc]
		initWithTitle:TGL(@"Common.Cancel", @"Cancel")
			   action:@"cancel"
				 type:TGActionSheetActionTypeCancel]];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:TGL(@"Chat.SelfDestructTimerPlaceholder", @"Self-Destruct Timer")
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGChatViewController *strongSelf = weakSelf;
			  if (!strongSelf || [action isEqualToString:@"cancel"])
				  return;
			  NSInteger seconds = [action isEqualToString:@"off"] ? 0 : [action integerValue];
			  strongSelf.pendingSelfDestructSeconds = seconds;
			  if (seconds > 0)
				  strongSelf.sendMediaOnce = NO;
			  [TGSnackbar showInView:strongSelf.view
								text:(seconds > 0
											 ? [NSString stringWithFormat:
													TGL(@"Chat.TheNextPhotoOrVideoWillSelfDestruct",
														@"The next photo or video will self-destruct %@ after being viewed"),
													[TGClient autoDeleteTitleForSeconds:seconds]]
											 : TGL(@"Chat.PhotosAndVideosStayInTheChat", @"Photos and videos stay in the chat"))
							 seconds:3
							onCommit:nil];
		  }
			   target:self];
	[sheet tg_showFromRect:self.sendButton.bounds inView:self.sendButton];
}

- (BOOL)isRemindersChat {
	return (self.chatId == [[TGClient shared] savedMessagesChatId]);
}

- (BOOL)allowsViewOnceMedia {
	return !self.group && ![self isRemindersChat] &&
		![[TGClient shared] isSecretChat:self.chatId];
}

- (void)loadAvailableSenders {
	if (!self.group || !self.chatId)
		return;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client availableMessageSendersForChat:self.chatId completion:^(NSArray *senders) {
		TGChatViewController *strongSelf = weakSelf;
		if (strongSelf && senders.count > 1)
			strongSelf.availableSenders = senders;
	}];
	[client currentMessageSenderForChat:self.chatId completion:^(int64_t senderId, BOOL isChat) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.currentSenderId = senderId;
		strongSelf.currentSenderIsChat = isChat;
	}];
}

- (void)chatMessageSenderChanged:(NSNotification *)note {
	if (!self.group || !self.chatId)
		return;
	if (![note.object isEqual:@(self.chatId)])
		return;
	self.currentSenderId = [note.userInfo[TGChatMessageSenderIdKey] longLongValue];
	self.currentSenderIsChat = [note.userInfo[TGChatMessageSenderIsChatKey] boolValue];
}

- (NSString *)currentSenderName {
	for (NSDictionary *sender in self.availableSenders)
		if ([sender[@"senderId"] longLongValue] == self.currentSenderId &&
			[sender[@"isChat"] boolValue] == self.currentSenderIsChat)
			return sender[@"name"];
	return nil;
}

- (void)showSendAsPicker {
	if (!self.group || !self.chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] availableMessageSendersForChat:self.chatId completion:^(NSArray *senders) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.availableSenders = senders;
		if (senders.count < 2) {
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"Chat.SendAsNoLongerAvailable", @"You can no longer send messages as someone else in this chat.")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[strongSelf presentSendAsPickerForSenders:senders];
	}];
}

- (void)presentSendAsPickerForSenders:(NSArray *)senders {
	UIActionSheet *sheet = [[UIActionSheet alloc]
				 initWithTitle:TGL(@"Conversation.SendMessageAs", @"Send Message As...")
					  delegate:self
			 cancelButtonTitle:nil
		destructiveButtonTitle:nil
			 otherButtonTitles:nil];
	for (NSDictionary *sender in senders) {
		BOOL current = [sender[@"senderId"] longLongValue] == self.currentSenderId &&
			[sender[@"isChat"] boolValue] == self.currentSenderIsChat;
		NSString *title = sender[@"name"];
		NSString *displayTitle = title;
		if (current)
			displayTitle = [NSString stringWithFormat:TGL(@"Chat.Current", @"%@ (current)"), title];
		else if (TGSendAsSenderRequiresPremiumUpgrade(sender, [[TGClient shared] isPremiumAccount]))
			displayTitle = [NSString stringWithFormat:TGL(@"Chat.RequiresPremiumSuffix", @"%@ (Premium)"), title];
		[sheet addButtonWithTitle:displayTitle];
	}
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kSendAsSheetTag;
	[sheet tg_showFromRect:self.sendButton.bounds inView:self.sendButton];
}

- (void)runSendAsPickerIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.availableSenders.count)
		return;
	NSDictionary *sender = self.availableSenders[index];
	int64_t senderId = [sender[@"senderId"] longLongValue];
	BOOL isChat = [sender[@"isChat"] boolValue];
	if (senderId == self.currentSenderId && isChat == self.currentSenderIsChat)
		return;
	if (TGSendAsSenderRequiresPremiumUpgrade(sender, [[TGClient shared] isPremiumAccount])) {
		[self showAlertTitle:@""
					  message:TGL(@"Chat.SendAsNeedsPremium", @"Telegram Premium is needed to send messages as this channel.")];
		return;
	}
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setMessageSenderId:senderId isChat:isChat forChat:chatId completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"Chat.CouldNotChangeSender", @"Could not change who sends the message.")
						   seconds:2
						  onCommit:nil];
			[[TGClient shared] currentMessageSenderForChat:chatId completion:^(int64_t currentSenderId, BOOL currentIsChat) {
				TGChatViewController *innerSelf = weakSelf;
				if (!innerSelf)
					return;
				innerSelf.currentSenderId = currentSenderId;
				innerSelf.currentSenderIsChat = currentIsChat;
			}];
			return;
		}
		strongSelf.currentSenderId = senderId;
		strongSelf.currentSenderIsChat = isChat;
	}];
}

@end
