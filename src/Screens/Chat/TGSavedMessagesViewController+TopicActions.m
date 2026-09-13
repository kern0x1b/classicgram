#import "TGClient+ChatManagement.h"
#import "TGSavedMessagesViewControllerInternal.h"
#import "RootViewController.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+SavedMessages.h"
#import "TGClient+Messages.h"
#import "TGPopupMenu.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGPreferenceFlags.h"
#import "TGSnackbar.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGActionSheet.h"
#import "TGSavedMessagesTagsViewController.h"
#import "TGSavedModeSheetAction.h"

@implementation TGSavedMessagesViewController (TopicActions)

- (void)showError:(NSString *)message {
	[[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
					  otherButtonTitles:nil] show];
}

- (void)topicHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan || self.reordering)
		return;

	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:
			[hold locationInView:self.tableView]];
	if (!path || ![self sectionHoldsTopics:path.section])
		return;

	NSArray *rows = [self topicRows];
	if (path.row >= (NSInteger)rows.count)
		return;

	NSDictionary *topic = rows[path.row];
	self.actionTopic = topic;

	BOOL pinned = [topic[@"isPinned"] boolValue];

	NSMutableArray *items = [NSMutableArray array];
	NSMutableArray *keys = [NSMutableArray array];

	[items addObject:@{@"title" : (pinned ? TGL(@"ChatList.Context.Unpin", @"Unpin") : TGL(@"ChatList.Context.Pin", @"Pin")),
		@"icon" : (pinned ? @"unpin" : @"pin")}];
	[keys addObject:@"pin"];

	if (pinned && [self pinnedCount] > 1) {
		[items addObject:@{@"title" : TGL(@"Chat.InlineTopicMenu.Reorder", @"Reorder Pins"), @"icon" : @"pin"}];
		[keys addObject:@"reorder"];
	}

	[items addObject:@{@"title" : TGL(@"Chat.ClearByDate", @"Clear by Date"), @"icon" : @"delete"}];
	[keys addObject:@"range"];

	[items addObject:@{@"title" : TGL(@"Common.Delete", @"Delete"),
		@"icon" : @"delete",
		@"destructive" : @YES}];
	[keys addObject:@"delete"];

	CGRect rect = [self.tableView rectForRowAtIndexPath:path];
	CGPoint where = [self.tableView convertPoint:
			CGPointMake(120, CGRectGetMaxY(rect) - 10)
										  toView:self.navigationController.view];
	self.menuPoint = where;

	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.navigationController.view
				  onChoice:^(NSInteger choice, NSString *title) {
					  if (choice < 0 || choice >= (NSInteger)keys.count)
						  return;
					  [weakSelf runTopicAction:keys[choice]];
				  }];
}

- (void)runTopicAction:(NSString *)key {
	NSDictionary *topic = self.actionTopic;
	if (!topic)
		return;

	int64_t topicId = [topic[@"id"] longLongValue];
	__weak typeof(self) weakSelf = self;

	if ([key isEqualToString:@"pin"]) {
		BOOL pin = ![topic[@"isPinned"] boolValue];
		self.actionTopic = nil;
		[[TGClient shared] setSavedMessagesTopic:topicId pinned:pin completion:^(BOOL ok) {
			if (!ok)
				[weakSelf showError:pin ? TGL(@"Topics.CouldNotPin", @"Could not pin the topic.")
										: TGL(@"Topics.CouldNotUnpin", @"Could not unpin the topic.")];
			[weakSelf applyCachedTopics];
		}];
		return;
	}

	if ([key isEqualToString:@"reorder"]) {
		self.actionTopic = nil;
		[self beginReordering];
		return;
	}

	if ([key isEqualToString:@"range"]) {
		self.actionTopic = nil;
		self.rangeTopicId = topicId;
		self.rangeTopicTitle = TGSavedTopicTitle(topic);
		[self showRangeSheet];
		return;
	}

	if ([key isEqualToString:@"delete"]) {
		NSString *message = [NSString stringWithFormat:TGL(@"ChatList.DeleteSavedPeerConfirmation", @"Delete every saved message from %@?"), TGSavedTopicTitle(topic)];
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"ChatList.DeleteTopicConfirmationAction", @"Delete Topic")
							 message:message
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"Common.Delete", @"Delete"), nil];
		alert.tag = kSavedDeleteAlertTag;
		[alert show];
	}
}

- (void)showRangeSheet {
	if (!self.rangeTopicId || self.rangeDayPanel)
		return;

	CGRect b = self.view.bounds;
	CGFloat panelHeight = 260;
	UIView *panel = [[UIView alloc] initWithFrame:
			CGRectMake(0, b.size.height, b.size.width, panelHeight)];
	panel.backgroundColor = [UIColor whiteColor];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:
			CGRectMake(0, 0, b.size.width, 44)];
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIBarButtonItem *cancel = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
							 target:self
							 action:@selector(dismissRangeDayPicker)];
	UIBarButtonItem *space = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
							 target:nil
							 action:nil];
	UIBarButtonItem *done = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemDone
							 target:self
							 action:@selector(commitRangeDayPicker)];
	bar.items = @[ cancel, space, done ];
	[panel addSubview:bar];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, 44, b.size.width, panelHeight - 44)];
	picker.datePickerMode = UIDatePickerModeDate;
	picker.maximumDate = [NSDate date];
	picker.date = [NSDate date];
	picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[panel addSubview:picker];

	self.rangeDayPicker = picker;
	self.rangeDayPanel = panel;
	[self.view addSubview:panel];
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = CGRectMake(0, b.size.height - panelHeight,
			b.size.width, panelHeight);
	}];
}

- (void)dismissRangeDayPicker {
	UIView *panel = self.rangeDayPanel;
	self.rangeDayPanel = nil;
	self.rangeDayPicker = nil;
	self.rangeTopicId = 0;
	if (!panel)
		return;
	CGRect b = self.view.bounds;
	[UIView animateWithDuration:0.25
		animations:^{
			panel.frame = CGRectMake(0, b.size.height, b.size.width, panel.frame.size.height);
		}
		completion:^(BOOL finished) {
			[panel removeFromSuperview];
		}];
}

- (void)commitRangeDayPicker {
	NSDate *chosen = self.rangeDayPicker.date;
	UIView *panel = self.rangeDayPanel;
	self.rangeDayPanel = nil;
	self.rangeDayPicker = nil;
	[panel removeFromSuperview];
	if (!chosen || !self.rangeTopicId)
		return;

	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *parts = [calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
										  fromDate:chosen];
	NSTimeInterval start = [[calendar dateFromComponents:parts] timeIntervalSince1970];
	self.rangeMinDate = (NSInteger)start;
	self.rangeMaxDate = (NSInteger)start + 86399;

	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:TGL(@"MessageCalendar.Title", @"Calendar")
						 message:TGLPlural(@"MessageCalendar.DeleteAlertText", 1,
							@"Are you sure you want to delete all messages for the selected day?",
							@"Are you sure you want to delete all messages for the selected %@ days?")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"MessageCalendar.ClearHistoryForThisDay", @"Clear History For This Day"), nil];
	alert.tag = kSavedRangeAlertTag;
	[alert show];
}

- (void)clearConfirmedRange {
	int64_t topicId = self.rangeTopicId;
	self.rangeTopicId = 0;
	if (!topicId)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteSavedMessagesTopic:topicId
								   messagesFrom:self.rangeMinDate
											 to:self.rangeMaxDate
									 completion:^(BOOL ok) {
										 if (!ok)
											 [weakSelf showError:TGL(@"Topics.CouldNotClearMessages", @"Could not clear the messages.")];
										 [weakSelf applyCachedTopics];
									 }];
}

- (void)presentSheet:(UIActionSheet *)sheet fromBarButtonItem:(UIBarButtonItem *)item {
	if (item && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[sheet showFromBarButtonItem:item animated:YES];
		return;
	}
	[sheet showInView:self.navigationController.view ?: self.view];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index < 0 || index == sheet.cancelButtonIndex)
		return;

	if (sheet.tag == kSavedModeSheetTag) {
		TGSavedModeSheetAction action = TGSavedModeSheetActionForIndex(index, sheet.cancelButtonIndex);
		if (action == TGSavedModeSheetActionViewAsMessages)
			[self openPlainChat];
		else if (action == TGSavedModeSheetActionMessageTags)
			[self openMessageTags];
		return;
	}

	if (sheet.tag == kSavedReminderSheetTag) {
		if (index < 0 || index >= (NSInteger)self.reminders.count)
			return;
		[self presentReminderMenu:self.reminders[index]];
		return;
	}

	if (sheet.tag == kSavedReminderMenuSheetTag) {
		NSDictionary *reminder = self.actionReminder;
		self.actionReminder = nil;
		if (!reminder)
			return;
		int64_t messageId = [reminder[@"id"] longLongValue];
		int64_t chatId = [[TGClient shared] savedMessagesChatId];
		if (!messageId || !chatId)
			return;

		BOOL canEdit = [self reminderSupportsTextEdit:reminder];
		NSInteger editIndex = canEdit ? 1 : -1;
		NSInteger rescheduleIndex = canEdit ? 2 : 1;
		NSInteger deleteIndex = rescheduleIndex + 1;

		if (canEdit && index == editIndex) {
			[self openRemindersChatForEditingMessageId:messageId];
			return;
		}
		if (index == rescheduleIndex) {
			NSTimeInterval sendDate = [reminder[@"sendDate"] isKindOfClass:[NSNumber class]]
				? [reminder[@"sendDate"] doubleValue] : 0;
			[self openRemindersChatForReschedulingMessageId:messageId sendDate:sendDate];
			return;
		}
		if (index == deleteIndex) {
			[self deleteReminder:reminder];
			return;
		}

		__weak typeof(self) weakSelf = self;
		[[TGClient shared] sendScheduledMessageNow:messageId inChat:chatId
								completion:^(BOOL ok) {
									[weakSelf reloadReminders];
								}];
	}
}

- (BOOL)reminderSupportsTextEdit:(NSDictionary *)reminder {
	NSString *kind = [reminder[@"kind"] isKindOfClass:[NSString class]] ? reminder[@"kind"] : nil;
	if (!kind.length)
		return NO;
	if ([kind isEqualToString:@"messageText"])
		return YES;
	return [@[ @"messagePhoto", @"messageVideo", @"messageAnimation",
		@"messageDocument", @"messageAudio", @"messageVoiceNote" ] containsObject:kind];
}

- (void)presentReminderMenu:(NSDictionary *)reminder {
	if (!reminder)
		return;
	self.actionReminder = reminder;

	BOOL canEdit = [self reminderSupportsTextEdit:reminder];
	NSMutableArray *titles = [NSMutableArray arrayWithObject:
		TGL(@"ScheduledMessages.SendNow", @"Remind Me Now")];
	if (canEdit)
		[titles addObject:TGL(@"Conversation.MessageDialogEdit", @"Edit")];
	[titles addObject:TGL(@"ScheduledMessages.EditTime", @"Reschedule")];
	[titles addObject:TGL(@"Common.Delete", @"Delete")];

	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:[self titleForReminder:reminder]
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:(NSInteger)titles.count - 1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = kSavedReminderMenuSheetTag;
	[sheet tg_showFromRect:self.reminderBanner.bounds inView:self.reminderBanner];
}

- (void)deleteReminder:(NSDictionary *)reminder {
	int64_t messageId = [reminder[@"id"] longLongValue];
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!messageId || !chatId)
		return;

	NSMutableArray *without = [self.reminders mutableCopy];
	[without removeObject:reminder];
	self.reminders = without;
	[self updateReminderBanner];

	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.view
					  text:TGL(@"Chat.DeletedForYou", @"Deleted for you")
				   seconds:5
					  kind:TGSnackbarKindDestructiveUndo
				  onCommit:^{
					  [[TGClient shared] deleteMessages:@[ @(messageId) ] inChat:chatId
											forEveryone:NO
											 completion:^(BOOL ok) {
												 if (!ok)
													 [weakSelf reloadReminders];
											 }];
				  }];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{ [weakSelf reloadReminders]; });
}

- (void)openRemindersChatForEditingMessageId:(int64_t)messageId {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId)
		return;

	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = TGL(@"Settings.SavedMessages", @"Saved Messages");
	[self presentSavedChat:vc];

	[[TGClient shared] messageWithId:messageId inChat:chatId completion:^(NSDictionary *full) {
		if (!full)
			return;
		[vc beginEditingScheduledMessage:full messageId:messageId];
	}];
}

- (void)openRemindersChatForReschedulingMessageId:(int64_t)messageId sendDate:(NSTimeInterval)sendDate {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId)
		return;

	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = TGL(@"Settings.SavedMessages", @"Saved Messages");
	[self presentSavedChat:vc];

	dispatch_async(dispatch_get_main_queue(), ^{
		vc.reschedulingMessageId = messageId;
		vc.reschedulingSendDate = sendDate;
		[vc showSchedulePicker];
	});
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kSavedRangeAlertTag) {
		if (buttonIndex != alertView.cancelButtonIndex)
			[self clearConfirmedRange];
		else
			self.rangeTopicId = 0;
		return;
	}

	NSDictionary *topic = self.actionTopic;
	self.actionTopic = nil;

	if (alertView.tag != kSavedDeleteAlertTag || buttonIndex == alertView.cancelButtonIndex)
		return;

	int64_t topicId = [topic[@"id"] longLongValue];
	if (!topicId)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteSavedMessagesTopic:topicId completion:^(BOOL ok) {
		if (!ok)
			[weakSelf showError:TGL(@"Topics.CouldNotDelete", @"Could not delete the topic.")];
		[weakSelf applyCachedTopics];
	}];
}

- (void)showListButtons {
	UIButton *more = [TGIcons headerButtonWithTitle:TGL(@"Common.More", @"More") bold:NO
											 target:self
											 action:@selector(showModeMenu)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:more];
}

- (void)showModeMenu {
	UIActionSheet *sheet = [UIActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Settings.SavedMessages", @"Saved Messages")
						delegate:self
			   cancelButtonTitle:nil
		  destructiveButtonTitle:nil
			   otherButtonTitles:nil];
	[sheet addButtonWithTitle:[@"✓ " stringByAppendingString:
									  TGL(@"Chat.SavedMessagesModeMenu.ViewAsChats", @"View as Chats")]];
	[sheet addButtonWithTitle:TGL(@"Chat.SavedMessagesModeMenu.ViewAsMessages", @"View as Messages")];
	[sheet addButtonWithTitle:TGL(@"Premium.MessageTags", @"Saved Message Tags")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kSavedModeSheetTag;
	[self presentSheet:sheet fromBarButtonItem:self.navigationItem.rightBarButtonItem];
}

- (void)presentSavedChat:(UIViewController *)controller {
	if (![RootViewController isSplitLayoutActive] ||
		![RootViewController presentInDetail:controller])
		[self.navigationController pushViewController:controller animated:YES];
}

- (void)openMessageTags {
	[self presentSavedChat:[[TGSavedMessagesTagsViewController alloc] initWithTopicId:0]];
}

- (void)openPlainChat {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId)
		return;

	[TGPreferenceFlags setSavedMessagesShowsTopics:NO];

	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = TGL(@"Settings.SavedMessages", @"Saved Messages");
	[self presentSavedChat:vc];
}

@end
