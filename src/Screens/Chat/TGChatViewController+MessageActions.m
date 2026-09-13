#import "TGChatViewController.h"
#import "TGDurationText.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGActionSheet.h"
#import "TGPopupMenu.h"
#import "TGReactionPickerView.h"
#import "TGRichText.h"
#import "TGClient+Contacts.h"
#import "TGClient+Messages.h"
#import "TGCallViewController.h"
#import "TGNewContactViewController.h"
#import "TGSearchViewController.h"
#import "TGSnackbar.h"
#import "TGLazyFramework.h"

@implementation TGChatViewController (MessageActions)

#pragma mark - message actions

- (void)messageHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;

	CGPoint point = [hold locationInView:self.table];
	for (UIView *view = [self.table hitTest:point withEvent:nil]; view; view = view.superview)
		if ([view isKindOfClass:TGReactionChipsView.class])
			return;

	NSIndexPath *path = [self.table indexPathForRowAtPoint:point];
	if (!path)
		return;

	[self.table deselectRowAtIndexPath:path animated:NO];

	UITableViewCell *cell = [self.table cellForRowAtIndexPath:path];
	TGEmojiLabel *body = [self richBodyLabelForCell:cell];
	if (body && !self.selecting) {
		CGPoint inBody = [hold locationInView:body];
		NSString *held = nil;
		TGRichTextLayout *layout = body.richLayout;
		if (layout && !body.hidden) {
			NSDictionary *link = [layout linkAtPoint:inBody
											  inRect:body.bounds];
			if ([self presentEntityMenuForLink:link inRow:path.row atTablePoint:point])
				return;
			NSString *kind = link[TGRichLinkKindKey];
			if ([kind isEqualToString:@"bankcard"]) {
				NSString *cardNumber = link[TGRichLinkValueKey];
				if (cardNumber.length) {
					[self followBankCardNumber:cardNumber];
					return;
				}
			} else if ([kind isEqualToString:@"url"]) {
				held = link[TGRichLinkValueKey];
			}
		} else {
			held = [self urlInLabel:body atPoint:inBody];
		}
		if (held.length) {
			[self showHeldLinkSheetFor:held];
			return;
		}
	}

	[self showActionsForRow:path.row];
}

#pragma mark - entity long-press menus

- (BOOL)presentEntityMenuForLink:(NSDictionary *)link
						   inRow:(NSInteger)row
					atTablePoint:(CGPoint)tablePoint {
	NSString *kind = link[TGRichLinkKindKey];
	NSString *value = link[TGRichLinkValueKey];
	if (![kind isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class])
		return NO;

	CGPoint where = [self.table convertPoint:tablePoint toView:self.view];

	if ([kind isEqualToString:@"hashtag"]) {
		[self showHashtagMenuFor:value atPoint:where];
		return YES;
	}
	if ([kind isEqualToString:@"mention"]) {
		[self showMentionMenuFor:value atPoint:where];
		return YES;
	}
	if ([kind isEqualToString:@"phone"]) {
		[self showPhoneMenuFor:value atPoint:where];
		return YES;
	}
	if ([kind isEqualToString:@"date"]) {
		[self showDateMenuFor:link atPoint:where];
		return YES;
	}
	if ([kind isEqualToString:@"timestamp"]) {
		[self showTimecodeMenuFor:value atPoint:where];
		return YES;
	}
	return NO;
}

- (void)showHashtagMenuFor:(NSString *)hashtag atPoint:(CGPoint)where {
	NSArray *items = @[
		@{@"title" : TGL(@"Chat.Context.Hashtag.Search", @"Search")},
		@{@"title" : TGL(@"HashtagSearch.AllChats", @"All Chats")},
		@{@"title" : TGL(@"Chat.Context.Hashtag.Copy", @"Copy Hashtag")},
	];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.view
				  onChoice:^(NSInteger index, __unused NSString *title) {
					  TGChatViewController *strongSelf = weakSelf;
					  if (!strongSelf)
						  return;
					  if (index == 0)
						  [strongSelf searchChatForTag:hashtag];
					  else if (index == 1)
						  [strongSelf searchEverywhereForTag:hashtag];
					  else if (index == 2)
						  [UIPasteboard generalPasteboard].string = hashtag;
				  }];
}

- (void)searchEverywhereForTag:(NSString *)hashtag {
	if (!hashtag.length)
		return;
	TGSearchViewController *search = [[TGSearchViewController alloc] init];
	search.presetQuery = hashtag;
	[self.navigationController pushViewController:search animated:YES];
}

- (void)showMentionMenuFor:(NSString *)mention atPoint:(CGPoint)where {
	NSString *username = mention.length > 1 ? [mention substringFromIndex:1] : mention;
	NSArray *items = @[
		@{@"title" : TGL(@"Chat.Context.Username.SendMessage", @"Send Message")},
		@{@"title" : TGL(@"Conversation.LinkDialogCopy", @"Copy")},
		@{@"title" : TGL(@"Conversation.OpenProfile", @"Open Profile")},
	];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.view
				  onChoice:^(NSInteger index, __unused NSString *title) {
					  TGChatViewController *strongSelf = weakSelf;
					  if (!strongSelf)
						  return;
					  if (index == 0) {
						  [strongSelf followTextTarget:@{@"mention" : username}];
					  } else if (index == 1) {
						  [UIPasteboard generalPasteboard].string = mention;
					  } else if (index == 2) {
						  [[TGClient shared] userIdForUsername:username completion:^(int64_t userId, BOOL failed) {
							  TGChatViewController *innerSelf = weakSelf;
							  if (!innerSelf)
								  return;
							  if (userId > 0) {
								  [innerSelf openProfileForUserId:userId];
							  } else {
								  [innerSelf showAlertTitle:@"" message:TGL(@"Resolve.ErrorNotFound", @"Sorry, this user doesn't seem to exist.")];
							  }
						  }];
					  }
				  }];
}

- (void)showPhoneMenuFor:(NSString *)number atPoint:(CGPoint)where {
	[self showPhoneMenuFor:number atPoint:where firstName:nil lastName:nil];
}

- (void)showPhoneMenuFor:(NSString *)number atPoint:(CGPoint)where
				firstName:(NSString *)firstName
				 lastName:(NSString *)lastName {
	NSMutableString *digits = [NSMutableString string];
	for (NSInteger i = 0; i < number.length; i++) {
		unichar c = [number characterAtIndex:i];
		if ((c >= '0' && c <= '9') || (c == '+' && digits.length == 0))
			[digits appendFormat:@"%C", c];
	}
	NSArray *items = @[
		@{@"title" : TGL(@"Chat.Context.Phone.AddToContacts", @"Add to Contacts")},
		@{@"title" : TGL(@"Chat.Context.Phone.TelegramVoiceCall", @"Telegram Voice Call")},
		@{@"title" : TGL(@"Chat.Context.Phone.TelegramVideoCall", @"Telegram Video Call")},
		@{@"title" : TGL(@"Chat.Context.Phone.CallViaCarrier", @"Call via Carrier")},
		@{@"title" : TGL(@"Conversation.LinkDialogCopy", @"Copy")},
	];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.view
				  onChoice:^(NSInteger index, __unused NSString *title) {
					  TGChatViewController *strongSelf = weakSelf;
					  if (!strongSelf)
						  return;
					  if (index == 0) {
						  [strongSelf presentAddToContactsForPhone:number
														  firstName:firstName
														   lastName:lastName];
					  } else if (index == 1 || index == 2) {
						  BOOL video = (index == 2);
						  [[TGClient shared]
							  userForPhoneNumber:digits
									   onlyLocal:NO
									  completion:^(NSDictionary *user) {
										  TGChatViewController *innerSelf = weakSelf;
										  if (!innerSelf)
											  return;
										  int64_t userId = [user[@"id"] longLongValue];
										  if (!userId) {
											  NSString *absent = TGL(@"Chat.Context.Phone.NotOnTelegram", @"This number is not on Telegram.");
											  [innerSelf showAlertTitle:@"" message:absent];
											  return;
										  }
										  NSString *first = user[@"first_name"] ?: @"";
										  NSString *last = user[@"last_name"] ?: @"";
										  NSString *raw = [NSString stringWithFormat:@"%@ %@", first, last];
										  NSCharacterSet *blanks = [NSCharacterSet whitespaceCharacterSet];
										  NSString *name = [raw stringByTrimmingCharactersInSet:blanks];
										  [TGCallViewController presentForUserId:userId name:name outgoing:YES video:video];
									  }];
					  } else if (index == 3) {
						  [strongSelf openLink:[@"tel:" stringByAppendingString:digits]];
					  } else if (index == 4) {
						  [UIPasteboard generalPasteboard].string = number;
					  }
				  }];
}

- (void)presentAddToContactsForPhone:(NSString *)number {
	[self presentAddToContactsForPhone:number firstName:nil lastName:nil];
}

- (void)presentAddToContactsForPhone:(NSString *)number
							firstName:(NSString *)firstName
							 lastName:(NSString *)lastName {
	TGNewContactViewController *form = [[TGNewContactViewController alloc] init];
	form.prefillPhone = number;
	form.prefillFirstName = firstName;
	form.prefillLastName = lastName;
	form.offersShareException = YES;
	__weak typeof(self) weakSelf = self;
	form.onDone = ^(BOOL saved, int64_t resolvedUserId) {
		(void)resolvedUserId;
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[TGSnackbar showInView:strongSelf.view
						   text:(saved
							   ? TGL(@"Toast.ContactAdded", @"Added to contacts")
							   : TGL(@"Toast.CouldNotSaveContact", @"Could not save the contact"))
						seconds:2
					   onCommit:nil];
	};
	[self.navigationController pushViewController:form animated:YES];
}

static NSString *TGFormattedTimecode(NSTimeInterval seconds) {
	NSInteger total = (NSInteger)llround(seconds);
	if (total < 0)
		total = 0;
	return TGDurationText(total);
}

- (void)showTimecodeMenuFor:(NSString *)secondsText atPoint:(CGPoint)where {
	NSString *display = TGFormattedTimecode([secondsText doubleValue]);
	NSArray *items = @[ @{@"title" : TGL(@"Conversation.LinkDialogCopy", @"Copy")} ];
	[TGPopupMenu showItems:items atPoint:where inView:self.view
				  onChoice:^(NSInteger index, __unused NSString *title) {
					  if (index == 0)
						  [UIPasteboard generalPasteboard].string = display;
				  }];
}

- (void)showDateMenuFor:(NSDictionary *)link atPoint:(CGPoint)where {
	NSString *unixTimeText = link[TGRichLinkValueKey];
	NSString *displayText = [link[@"text"] isKindOfClass:NSString.class] ? link[@"text"] : unixTimeText;
	NSTimeInterval unixTime = [unixTimeText doubleValue];

	NSArray *items = @[
		@{@"title" : TGL(@"Conversation.LinkDialogCopy", @"Copy")},
		@{@"title" : TGL(@"Chat.Context.Date.AddToCalendar", @"Add to Calendar")},
		@{@"title" : TGL(@"Chat.Context.Date.SetReminder", @"Set a Reminder")},
	];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.view
				  onChoice:^(NSInteger index, __unused NSString *title) {
					  TGChatViewController *strongSelf = weakSelf;
					  if (!strongSelf)
						  return;
					  if (index == 0)
						  [UIPasteboard generalPasteboard].string = displayText;
					  else if (index == 1)
						  [strongSelf addToCalendarAtUnixTime:unixTime];
					  else if (index == 2)
						  [strongSelf setReminderAtUnixTime:unixTime title:displayText];
				  }];
}

- (EKEventStore *)sharedEventStore {
	if (!self.eventStore) {
		Class storeClass = TGFrameworkClass(@"EventKit", @"EKEventStore");
		if (!storeClass)
			return nil;
		self.eventStore = [[storeClass alloc] init];
	}
	return self.eventStore;
}

- (void)addToCalendarAtUnixTime:(NSTimeInterval)unixTime {
	EKEventStore *store = [self sharedEventStore];
	if (!store)
		return;
	__weak typeof(self) weakSelf = self;
	void (^presentEditor)(void) = ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		Class eventClass = TGFrameworkClass(@"EventKit", @"EKEvent");
		Class editorClass = TGFrameworkClass(@"EventKitUI", @"EKEventEditViewController");
		if (!eventClass || !editorClass)
			return;
		EKEvent *event = [eventClass eventWithEventStore:strongSelf.eventStore];
		event.startDate = [NSDate dateWithTimeIntervalSince1970:unixTime];
		event.endDate = [NSDate dateWithTimeIntervalSince1970:unixTime + 3600];

		EKEventEditViewController *editor = [[editorClass alloc] init];
		editor.eventStore = strongSelf.eventStore;
		editor.event = event;
		editor.editViewDelegate = strongSelf;
		[strongSelf presentViewController:editor animated:YES completion:nil];
	};
	if ([store respondsToSelector:@selector(requestAccessToEntityType:completion:)]) {
		[store requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *strongSelf = weakSelf;
				if (!strongSelf || !granted)
					return;
				presentEditor();
			});
		}];
	} else {
		presentEditor();
	}
}

- (void)eventEditViewController:(EKEventEditViewController *)controller
		  didCompleteWithAction:(EKEventEditViewAction)action {
	[controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)setReminderAtUnixTime:(NSTimeInterval)unixTime title:(NSString *)title {
	NSDictionary *me = [[TGClient shared] me];
	int64_t savedMessagesChatId = [me[@"id"] longLongValue];
	if (!savedMessagesChatId) {
		[self showAlertTitle:@"" message:TGL(@"Chat.RemindersAreNotAvailable", @"Reminders are not available.")];
		return;
	}
	NSString *text = title.length ? title : TGL(@"ScheduledMessages.ReminderNotification", @"Reminder");
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sendText:text
						  toChat:savedMessagesChatId
						  thread:0
					  savedTopic:0
						 replyTo:0
						 options:@{@"sendDate" : @(unixTime)}
					  completion:^(NSDictionary *result) {
						  TGChatViewController *strongSelf = weakSelf;
						  if (!strongSelf)
							  return;
						  [strongSelf showAlertTitle:@""
											  message:(result ? TGL(@"Conversation.DateReminderSet", @"Reminder set")
															   : TGL(@"Chat.RemindersAreNotAvailable", @"Reminders are not available."))];
					  }];
}

@end
