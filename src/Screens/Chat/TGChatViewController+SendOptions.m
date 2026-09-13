#import "TGChatViewController.h"
#import "TGDateUtils.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGClient+MessageContent.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSnackbar.h"
#import "TGClient+Channels.h"
#import "TGClient+Premium.h"
#import "TGClient+Reactions.h"
#import "TGClient+SecretChats.h"
#import "TGScheduledMessagesViewController.h"
#import "TGActionSheet.h"

@implementation TGChatViewController (SendOptions)

- (BOOL)allowsMessageEffects {
	return !self.group && self.chatId > 0 && ![self isRemindersChat] &&
		![[TGClient shared] isSecretChat:self.chatId];
}

- (void)showEffectPicker {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] availableMessageEffectsWithCompletion:^(NSArray *effects) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!effects.count) {
			[TGSnackbar showInView:strongSelf.view text:TGL(@"Chat.NoMessageEffectsAvailable", @"No message effects available")
						   seconds:2
						  onCommit:nil];
			return;
		}
		strongSelf.effectChoices = effects;
		UIActionSheet *sheet = [UIActionSheet alloc];
		sheet = [sheet initWithTitle:TGL(@"Chat.MessageEffectMenu.TitleAddEffect", @"Add an animated effect")
							delegate:strongSelf
				   cancelButtonTitle:nil
			  destructiveButtonTitle:nil
				   otherButtonTitles:nil];
		for (NSDictionary *effect in effects)
			[sheet addButtonWithTitle:(effect[@"emoji"] ?: @"?")];
		if (strongSelf.pendingEffectId)
			[sheet addButtonWithTitle:TGL(@"Stickers.SuggestNone", @"None")];
		sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
		sheet.tag = kEffectPickerSheetTag;
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(strongSelf.view.bounds), CGRectGetMidY(strongSelf.view.bounds), 1, 1) inView:strongSelf.view];
	}];
}

- (void)runEffectPickerIndex:(NSInteger)index {
	if (index < 0)
		return;
	if (index >= (NSInteger)self.effectChoices.count) {
		self.pendingEffectId = 0;
		self.pendingEffectEmoji = nil;
		return;
	}
	NSDictionary *effect = self.effectChoices[index];
	if ([effect[@"isPremium"] boolValue] && ![[TGClient shared] isPremiumAccount]) {
		[self showAlertTitle:@"" message:TGL(@"Chat.MessageEffectRequiresPremium", @"Subscribe to Telegram Premium to use this effect.")];
		return;
	}
	self.pendingEffectId = [effect[@"id"] longLongValue];
	self.pendingEffectEmoji = effect[@"emoji"];
}

- (void)playEffectBurstWithEmoji:(NSString *)emoji {
	if (!emoji.length)
		return;

	UILabel *burst = [[UILabel alloc] initWithFrame:CGRectZero];
	burst.text = emoji;
	burst.font = [UIFont systemFontOfSize:96];
	burst.textAlignment = NSTextAlignmentCenter;
	burst.userInteractionEnabled = NO;
	[burst sizeToFit];
	burst.center = CGPointMake(self.view.bounds.size.width / 2,
		self.view.bounds.size.height / 2 - 40);
	burst.alpha = 0.0f;
	burst.transform = CGAffineTransformMakeScale(0.3f, 0.3f);
	[self.view addSubview:burst];

	[UIView animateWithDuration:0.28 delay:0.0
		options:UIViewAnimationOptionCurveEaseOut
		animations:^{
			burst.alpha = 1.0f;
			burst.transform = CGAffineTransformMakeScale(1.15f, 1.15f);
		} completion:^(BOOL finished) {
			[UIView animateWithDuration:0.15 delay:0.0
				options:UIViewAnimationOptionCurveEaseInOut
				animations:^{
					burst.transform = CGAffineTransformIdentity;
				} completion:^(BOOL innerFinished) {
					[UIView animateWithDuration:0.4 delay:0.5
						options:UIViewAnimationOptionCurveEaseIn
						animations:^{
							burst.alpha = 0.0f;
						} completion:^(BOOL doneFinished) {
							[burst removeFromSuperview];
						}];
				}];
		}];
}

- (NSInteger)mediaSelfDestruct {
	if (![self allowsViewOnceMedia])
		return 0;
	if (self.sendMediaOnce)
		return kSelfDestructViewOnce;
	return self.pendingSelfDestructSeconds;
}

- (void)clearMediaSelfDestruct {
	self.sendMediaOnce = NO;
	self.pendingSelfDestructSeconds = 0;
}

- (void)showSchedulePicker {
	if (self.datePickerPanel)
		return;

	CGRect b = self.view.bounds;
	CGFloat panelHeight = 260;
	UIView *panel = [[UIView alloc] initWithFrame:
			CGRectMake(0, b.size.height, b.size.width, panelHeight)];
	panel.backgroundColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleTopMargin;

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:
			CGRectMake(0, 0, b.size.width, 44)];
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIBarButtonItem *cancel = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
							 target:self
							 action:@selector(dismissSchedulePicker)];
	UIBarButtonItem *space = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
							 target:nil
							 action:nil];
	UIBarButtonItem *done = self.suggestPostMessageIdForSchedule
		? [[UIBarButtonItem alloc] initWithTitle:TGL(@"Common.Done", @"Done")
											style:UIBarButtonItemStyleDone
										   target:self
										   action:@selector(commitSchedulePicker)]
		: [[UIBarButtonItem alloc]
			initWithBarButtonSystemItem:UIBarButtonSystemItemDone
								 target:self
								 action:@selector(commitSchedulePicker)];
	self.scheduleDoneButton = done;
	if (!self.group && ![self isRemindersChat] &&
		!self.reschedulingMessageId && !self.suggestPostMessageIdForSchedule &&
		![[TGClient shared] isSecretChat:self.chatId]) {
		UIBarButtonItem *whenOnline = [[UIBarButtonItem alloc]
			initWithTitle:TGL(@"Conversation.SendMessage.SendWhenOnline", @"When Online")
					style:UIBarButtonItemStylePlain
				   target:self
				   action:@selector(commitScheduleWhenOnline)];
		bar.items = @[ cancel, whenOnline, space, done ];
	} else {
		bar.items = @[ cancel, space, done ];
	}
	[panel addSubview:bar];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, 44, b.size.width, panelHeight - 44)];
	picker.datePickerMode = UIDatePickerModeDateAndTime;
	picker.minuteInterval = 5;
	picker.minimumDate = [NSDate dateWithTimeIntervalSinceNow:60];
	picker.maximumDate = [NSDate dateWithTimeIntervalSinceNow:367 * 86400];
	NSDate *seededDate = self.reschedulingMessageId && self.reschedulingSendDate > 0
		? [NSDate dateWithTimeIntervalSince1970:self.reschedulingSendDate]
		: [NSDate dateWithTimeIntervalSinceNow:3600];
	if ([seededDate compare:picker.minimumDate] == NSOrderedAscending)
		seededDate = picker.minimumDate;
	if ([seededDate compare:picker.maximumDate] == NSOrderedDescending)
		seededDate = picker.maximumDate;
	picker.date = seededDate;
	picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[panel addSubview:picker];

	self.schedulePicker = picker;
	self.datePickerPanel = panel;

	if (self.suggestPostMessageIdForSchedule) {
		[picker addTarget:self action:@selector(suggestPostScheduleDateChanged:)
			forControlEvents:UIControlEventValueChanged];
		[self updateSuggestPostDoneButtonTitleForDate:picker.date];
	}

	[self.input resignFirstResponder];
	[self.view addSubview:panel];
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = CGRectMake(0, b.size.height - panelHeight,
			b.size.width, panelHeight);
	}];
}

- (void)suggestPostScheduleDateChanged:(UIDatePicker *)picker {
	[self updateSuggestPostDoneButtonTitleForDate:picker.date];
}

- (void)updateSuggestPostDoneButtonTitleForDate:(NSDate *)date {
	if (!date || !self.scheduleDoneButton)
		return;

	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSUInteger dayUnits = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
	NSDate *dateOnly = [calendar dateFromComponents:[calendar components:dayUnits fromDate:date]];
	NSDate *todayOnly = [calendar dateFromComponents:[calendar components:dayUnits fromDate:[NSDate date]]];
	NSInteger dayDelta = [calendar components:NSCalendarUnitDay
									 fromDate:todayOnly
									   toDate:dateOnly
									  options:0]
							 .day;

	int when = (int)[date timeIntervalSince1970];
	NSString *time = [TGDateUtils stringForShortTime:when];

	NSString *title;
	if (dayDelta == 0)
		title = [NSString stringWithFormat:TGL(@"SuggestPost.Time.ProposeToday", @"Post today at %@"), time];
	else if (dayDelta == 1)
		title = [NSString stringWithFormat:TGL(@"SuggestPost.Time.ProposeTomorrow", @"Post tomorrow at %@"), time];
	else
		title = [NSString stringWithFormat:TGL(@"SuggestPost.Time.ProposeOn", @"Post on %@ at %@"),
					[TGDateUtils stringForFullDate:when], time];
	self.scheduleDoneButton.title = title;
}

- (void)dismissSchedulePicker {
	UIView *panel = self.datePickerPanel;
	self.reschedulingMessageId = 0;
	self.reschedulingSendDate = 0;
	self.suggestPostMessageIdForSchedule = 0;
	if (!panel) {
		self.scheduleDoneButton = nil;
		return;
	}
	self.datePickerPanel = nil;
	self.schedulePicker = nil;
	self.scheduleDoneButton = nil;
	CGRect gone = panel.frame;
	gone.origin.y = self.view.bounds.size.height;
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = gone;
	} completion:^(BOOL finished) {
		[panel removeFromSuperview];
	}];
}

- (void)commitSchedulePicker {
	NSDate *when = self.schedulePicker.date;
	int64_t moving = self.reschedulingMessageId;
	int64_t suggestingPost = self.suggestPostMessageIdForSchedule;
	[self dismissSchedulePicker];
	if (!when)
		return;
	NSTimeInterval stamp = [when timeIntervalSince1970];
	if (stamp <= [[NSDate date] timeIntervalSince1970]) {
		[TGSnackbar showInView:self.view
						  text:TGL(@"ScheduledMessages.TimeHasPassed", @"That time has already passed. Please pick another time.")
					   seconds:3
					  onCommit:nil];
		return;
	}
	if (suggestingPost) {
		self.suggestedPostMessageId = suggestingPost;
		[self performAddOfferWithSendDate:(int64_t)stamp];
		return;
	}
	if (moving) {
		self.reschedulingMessageId = moving;
		[self rescheduleTo:stamp];
		return;
	}
	self.scheduleWhenOnline = NO;
	self.scheduledSendDate = stamp;
	NSString *whenText =
		[NSDateFormatter localizedStringFromDate:when
									   dateStyle:NSDateFormatterShortStyle
									   timeStyle:NSDateFormatterShortStyle];
	NSString *bannerFormat = [self isRemindersChat]
		? TGL(@"Chat.ReminderForFormat", @"Reminder for %@")
		: TGL(@"ScheduledMessages.ScheduledDate", @"Scheduled for %@");
	[self showComposeBanner:[NSString stringWithFormat:bannerFormat, whenText]];
	[self.input becomeFirstResponder];
}

- (void)commitScheduleWhenOnline {
	[self dismissSchedulePicker];
	self.scheduledSendDate = 0;
	self.scheduleWhenOnline = YES;
	[self showComposeBanner:TGL(@"Conversation.SendMessage.SendWhenOnline", @"When Online")];
	[self.input becomeFirstResponder];
}

- (NSDictionary *)sendOptionsDictionary {
	BOOL hasReplyQuote = self.replyToId != 0 && self.replyQuoteText.length > 0;
	if (!self.sendSilently && !self.pendingEffectId &&
		self.scheduledSendDate == 0 && !self.scheduleWhenOnline &&
		self.paidMessageStarCount == 0 && !hasReplyQuote)
		return nil;
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	if (hasReplyQuote) {
		options[@"quoteText"] = self.replyQuoteText;
		options[@"quotePosition"] = @(self.replyQuotePosition);
		if (self.replyQuoteEntities.count > 0)
			options[@"quoteEntities"] = self.replyQuoteEntities;
	}
	if (self.sendSilently)
		options[@"silent"] = @YES;
	if (self.scheduledSendDate != 0)
		options[@"sendDate"] = @(self.scheduledSendDate);
	if (self.scheduleWhenOnline)
		options[@"whenOnline"] = @YES;
	if (self.pendingEffectId) {
		options[@"effectId"] = @(self.pendingEffectId);
		self.pendingEffectId = 0;
		self.pendingEffectEmoji = nil;
	}
	if (self.paidMessageStarCount > 0)
		options[@"paidStarCount"] = @(self.paidMessageStarCount);
	return options;
}

- (void)loadScheduledMessages {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] scheduledMessagesInChat:self.chatId
									completion:^(NSArray *messages, BOOL failed) {
										if (failed)
											return;
										weakSelf.scheduledMessages = messages ?: @[];
									}];
}

- (void)hasScheduledMessagesChanged:(NSNotification *)note {
	if (note.object && ![note.object isEqual:@(self.chatId)])
		return;
	[self loadScheduledMessages];
}

- (void)showScheduledMessages {
	TGScheduledMessagesViewController *screen =
		[[TGScheduledMessagesViewController alloc] init];
	screen.chatId = self.chatId;
	screen.remindersStyle = [self isRemindersChat];

	__weak typeof(self) weakSelf = self;
	screen.previewOfMessage = ^NSString *(NSDictionary *m) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return nil;
		NSString *body = [strongSelf textOf:m];
		if (body.length)
			return body;
		return [strongSelf quoteKindLabelFor:m];
	};
	screen.onReschedule = ^(int64_t messageId, NSTimeInterval sendDate) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.reschedulingMessageId = messageId;
		strongSelf.reschedulingSendDate = sendDate;
		[strongSelf showSchedulePicker];
	};
	screen.onEdit = ^(NSDictionary *m) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![m[@"id"] isKindOfClass:NSNumber.class])
			return;
		int64_t messageId = [m[@"id"] longLongValue];
		int64_t chatId = strongSelf.chatId;
		[[TGClient shared] messageWithId:messageId inChat:chatId completion:^(NSDictionary *full) {
			TGChatViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			[innerSelf beginEditingScheduledMessage:(full ?: m) messageId:messageId];
		}];
	};
	[self.navigationController pushViewController:screen animated:YES];
}

- (void)beginEditingScheduledMessage:(NSDictionary *)m messageId:(int64_t)messageId {
	[self setComposeMode:TGComposeModeEdit messageId:messageId];
	self.editingIsCaption = [@[ @"messagePhoto", @"messageVideo", @"messageAnimation",
		@"messageDocument", @"messageAudio", @"messageVoiceNote" ] containsObject:m[@"kind"]];
	self.editingCaptionAboveMedia = [m[@"captionAboveMedia"] boolValue];
	self.editingLinkPreviewOptions = [m[@"linkPreviewOptions"] isKindOfClass:NSDictionary.class]
		? m[@"linkPreviewOptions"] : nil;
	self.preEditDraftText = self.input.text;
	[self seedPendingStyleEntitiesFromMessage:m];
	self.input.text = [self originalTextOf:m] ?: @"";
	[self inputChanged];
	[self.sendButton setTitle:TGL(@"Conversation.LinkDialogSave", @"Save") forState:UIControlStateNormal];
	[self showComposeBanner:TGL(@"Chat.SendMessageMenu.EditMessage", @"Edit message")];
	[self.input becomeFirstResponder];
}

- (void)rescheduleTo:(NSTimeInterval)stamp {
	int64_t messageId = self.reschedulingMessageId;
	self.reschedulingMessageId = 0;
	if (!messageId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] rescheduleMessage:messageId
								  inChat:self.chatId
								sendDate:stamp
							  whenOnline:NO
							  completion:^(BOOL ok) {
								  TGChatViewController *strongSelf = weakSelf;
								  if (!strongSelf)
									  return;
								  if (!ok) {
									  [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotRescheduleMessage", @"Could not reschedule the message")];
									  return;
								  }
								  [strongSelf loadScheduledMessages];
							  }];
}

@end
