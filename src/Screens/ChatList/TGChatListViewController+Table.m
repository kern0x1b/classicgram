#import "TGClient+ChatManagement.h"
#import "TGChatListViewControllerInternal.h"
#import "RootViewController.h"
#import "TGLocalization.h"
#import "TGClient+ChatList.h"
#import "TGClient+Notifications.h"
#import "TGClient+Messages.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGSwipeGestureRecognizer.h"
#import "TGEmoji.h"
#import "TGActionsMenu.h"
#import "TGChatListHelpers.h"
#import "TGChatCell.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"

@implementation TGChatListViewController (Table)

#pragma mark - table

- (void)rowHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;

	[self closeOpenSwipeCellAnimated:YES];
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:[hold locationInView:self.tableView]];
	if (!path)
		return;

	[self showActionsForRow:path.row];
}

- (void)showActionsForRow:(NSInteger)row {
	if (self.searchResults || self.tableView.editing || self.multiSelecting)
		return;

	NSDictionary *chat = [self chatForRow:row];
	if (!chat)
		return;
	int64_t chatId = [chat[@"id"] longLongValue];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatMarkedAsUnread:chatId completion:^(BOOL marked) {
		[weakSelf presentActionsForRow:row chat:chatId markedUnread:marked];
	}];
}

- (void)presentActionsForRow:(NSInteger)row chat:(int64_t)expected markedUnread:(BOOL)markedUnread {
	NSDictionary *held = [self chatForRow:row];
	if (!held || [held[@"id"] longLongValue] != expected)
		return;
	self.actionChat = held;

	BOOL pinned = self.showsArchive
		? [self.actionChat[@"isPinnedInArchive"] boolValue]
		: [self.actionChat[@"isPinned"] boolValue];
	BOOL muted = [self.actionChat[@"isMuted"] boolValue];
	BOOL unread = markedUnread || [self chatIsUnread:self.actionChat];
	self.actionChatUnread = unread;
	int64_t heldChatId = [self.actionChat[@"id"] longLongValue];
	if (muted)
		[self refreshMuteRemainingForChat:heldChatId];

	BOOL hasFolders = ([self folderList].count > 0);
	BOOL isGroup = [self.actionChat[@"isGroup"] boolValue];
	NSArray *items = [self rowActionItemsForChat:heldChatId
										  pinned:pinned
										   muted:muted
										  unread:unread
									  hasFolders:hasFolders
										   group:isGroup];
	self.rowActionKinds = [self rowActionKindsWithFolders:hasFolders];

	CGRect rect = [self.tableView rectForRowAtIndexPath:
			[NSIndexPath indexPathForRow:row inSection:0]];
	CGPoint where = [self.tableView convertPoint:
			CGPointMake(120, CGRectGetMaxY(rect) - 10)
										  toView:self.navigationController.view];

	self.menuPoint = where;
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.navigationController.view
				  onChoice:^(NSInteger choice, NSString *title) {
					  [weakSelf runChatAction:choice];
				  }];
}

- (NSArray *)rowActionItemsForChat:(int64_t)chatId
							pinned:(BOOL)pinned
							 muted:(BOOL)muted
							unread:(BOOL)unread
						hasFolders:(BOOL)hasFolders
							 group:(BOOL)isGroup {
	NSMutableArray *items = [NSMutableArray array];
	[items addObject:@{@"title" : (pinned ? TGL(@"ChatList.Context.Unpin", @"Unpin") : TGL(@"ChatList.Context.Pin", @"Pin")),
		@"icon" : (pinned ? @"unpin" : @"pin")}];
	[items addObject:@{@"title" : (unread ? TGL(@"ChatList.Context.MarkAsRead", @"Mark as Read") : TGL(@"ChatList.Context.MarkAsUnread", @"Mark as Unread")),
		@"icon" : @"chat"}];
	[items addObject:@{@"title" : (muted ? [self unmuteTitleForChat:chatId] : TGL(@"ChatList.Context.Mute", @"Mute")),
		@"icon" : (muted ? @"unmute" : @"mute")}];
	[items addObject:@{@"title" : TGL(@"GroupInfo.Notifications", @"Notifications…"), @"icon" : @"mute"}];
	[items addObject:@{@"title" : (self.showsArchive ? TGL(@"ChatList.Context.Unarchive", @"Unarchive") : TGL(@"ChatList.Context.Archive", @"Archive")),
		@"icon" : (self.showsArchive ? @"unarchive" : @"archive")}];
	if (hasFolders)
		[items addObject:@{@"title" : TGL(@"ChatList.Context.AddToFolder", @"Add to Folder"), @"icon" : @"folder"}];
	[items addObject:@{@"title" : (isGroup ? TGL(@"PeerInfo.AlertLeaveAction", @"Leave") : TGL(@"Common.Delete", @"Delete")), @"icon" : @"delete", @"destructive" : @YES}];
	[items addObject:@{@"title" : TGL(@"ChatList.Context.Select", @"Select"), @"icon" : @"select"}];
	return items;
}

- (NSArray *)rowActionKindsWithFolders:(BOOL)hasFolders {
	NSMutableArray *kinds = [NSMutableArray arrayWithObjects:
			@"pin", @"read", @"mute", @"notify", @"archive", nil];
	if (hasFolders)
		[kinds addObject:@"folder"];
	[kinds addObject:@"delete"];
	[kinds addObject:@"select"];
	return kinds;
}

- (void)runChatAction:(NSInteger)choice {
	NSDictionary *chat = self.actionChat;
	int64_t chatId = [chat[@"id"] longLongValue];
	BOOL unread = self.actionChatUnread;
	if (choice < 0 || choice >= (NSInteger)self.rowActionKinds.count)
		return;
	NSString *kind = self.rowActionKinds[choice];

	if ([kind isEqualToString:@"pin"]) {
		BOOL currentlyPinned = self.showsArchive
			? [chat[@"isPinnedInArchive"] boolValue]
			: [chat[@"isPinned"] boolValue];
		[self pinChat:chatId pinned:!currentlyPinned];
	} else if ([kind isEqualToString:@"read"]) {
		[self setChat:chatId read:unread];
	} else if ([kind isEqualToString:@"mute"]) {
		if ([chat[@"isMuted"] boolValue]) {
			[self setChat:chatId muteForSeconds:0];
		} else {
			[self showMuteDurationsForChat:chatId];
			return;
		}
	} else if ([kind isEqualToString:@"notify"]) {
		[self showNotificationOptionsForChat:chatId];
		return;
	} else if ([kind isEqualToString:@"archive"]) {
		[self setChat:chatId archived:!self.showsArchive];
	} else if ([kind isEqualToString:@"folder"]) {
		[self showFoldersForChat:chatId];
		return;
	} else if ([kind isEqualToString:@"select"]) {
		[self beginMultiSelectWithChat:chatId];
		return;
	} else {
		[self confirmDeleteChat:chat];
	}
	self.actionChat = nil;
}

- (void)showFoldersForChat:(int64_t)chatId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] listsToAddChat:chatId completion:^(NSArray *reply) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSMutableArray *items = [NSMutableArray array];
		NSMutableArray *ids = [NSMutableArray array];
		for (id entry in (TGReplyArray(reply) ?: @[])) {
			NSDictionary *list = TGReplyDictionary(entry);
			if (![list[@"list"] isKindOfClass:[NSNumber class]])
				continue;
			NSInteger listId = [list[@"list"] integerValue];
			if (listId == TGChatListMain || listId == TGChatListArchive)
				continue;
			[items addObject:@{@"title" : (TGReplyString(list[@"title"])
								?: TGL(@"ChatListFolder.DefaultTitle", @"Folder")),
				@"icon" : @"folder"}];
			[ids addObject:@(listId)];
		}
		if (!items.count) {
			[strongSelf showAllFoldersForChat:chatId];
			return;
		}
		strongSelf.listsToAddIds = ids;

		[TGPopupMenu showItems:items atPoint:strongSelf.menuPoint inView:strongSelf.navigationController.view
					  onChoice:^(NSInteger choice, NSString *title) {
						  TGChatListViewController *innerSelf = weakSelf;
						  if (!innerSelf || choice < 0 || choice >= (NSInteger)innerSelf.listsToAddIds.count)
							  return;
						  NSInteger listId = [innerSelf.listsToAddIds[choice] integerValue];
						  [[TGClient shared] addChat:chatId toList:(TGChatListId)listId completion:^(BOOL ok) {
							  TGChatListViewController *tail = weakSelf;
							  if (!tail)
								  return;
							  tail.actionChat = nil;
							  if (!ok) {
								  [TGSnackbar showInView:tail.navigationController.view
													text:TGL(@"ChatList.Context.AddToFolderFailed", @"Telegram could not add the chat to the folder.")
												 seconds:2
												onCommit:nil];
								  return;
							  }
							  [tail reload];
						  }];
					  }];
	}];
}

- (void)showAllFoldersForChat:(int64_t)chatId {
	NSArray *folders = [self folderList];
	if (!folders.count) {
		[self openFolderManagement];
		return;
	}

	NSMutableArray *items = [NSMutableArray array];
	NSMutableArray *ids = [NSMutableArray array];
	for (id entry in folders) {
		NSDictionary *folder = TGReplyDictionary(entry);
		NSInteger listId = [folder[@"id"] integerValue];
		if (!listId)
			continue;
		[items addObject:@{@"title" : (TGReplyString(folder[@"title"])
							  ?: TGL(@"ChatListFolder.DefaultTitle", @"Folder")),
			@"icon" : @"folder"}];
		[ids addObject:@(listId)];
	}
	if (!items.count) {
		[self openFolderManagement];
		return;
	}
	self.folderSheetItems = ids;

	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:self.menuPoint inView:self.navigationController.view
				  onChoice:^(NSInteger choice, NSString *title) {
					  TGChatListViewController *strongSelf = weakSelf;
					  if (!strongSelf || choice < 0 || choice >= (NSInteger)strongSelf.folderSheetItems.count)
						  return;
					  [strongSelf toggleChat:chatId inFolder:[strongSelf.folderSheetItems[choice] integerValue]];
				  }];
}

- (void)toggleChat:(int64_t)chatId inFolder:(NSInteger)folderId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] folderWithId:folderId completion:^(NSDictionary *reply) {
		TGChatListViewController *strongSelf = weakSelf;
		NSDictionary *folder = TGReplyDictionary(reply);
		if (!strongSelf || !folder)
			return;

		NSMutableDictionary *edited = [folder mutableCopy];
		NSMutableArray *included = [(TGReplyArray(folder[@"includedChatIds"]) ?: @[]) mutableCopy];
		NSMutableArray *excluded = [(TGReplyArray(folder[@"excludedChatIds"]) ?: @[]) mutableCopy];
		NSNumber *key = @(chatId);

		BOOL wasIn = NO;
		for (NSNumber *entry in [included copy]) {
			if ([entry longLongValue] == chatId) {
				wasIn = YES;
				[included removeObject:entry];
			}
		}
		for (NSNumber *entry in [excluded copy]) {
			if ([entry longLongValue] == chatId)
				[excluded removeObject:entry];
		}
		if (!wasIn)
			[included addObject:key];

		edited[@"includedChatIds"] = included;
		edited[@"excludedChatIds"] = excluded;
		[[TGClient shared] saveFolder:edited completion:^(NSInteger saved, NSString *errorMessage) {
			TGChatListViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (!saved)
				return;
			[innerSelf reload];
		}];
	}];
	self.actionChat = nil;
}

- (void)setChat:(int64_t)chatId read:(BOOL)read {
	[self.rowDetails removeObjectForKey:@(chatId)];
	[self.rowDetailsRequested removeObject:@(chatId)];
	__weak typeof(self) weakSelf = self;
	if (!read) {
		[[TGClient shared] setChat:chatId markedAsUnread:YES completion:^(BOOL success) {
			TGChatListViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!success) {
				[TGSnackbar showInView:strongSelf.navigationController.view
								  text:TGL(@"ChatList.Context.PinFailed", @"Telegram could not update the chat.")
							   seconds:2
							  onCommit:nil];
				return;
			}
			[strongSelf reload];
		}];
		return;
	}
	[[TGClient shared] readAllMentionsInChat:chatId];
	[[TGClient shared] readAllReactionsInChat:chatId];
	[[TGClient shared] readAllPollVotesInChat:chatId];
	[[TGClient shared] markChatAsRead:chatId completion:^(BOOL ok) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"ChatList.Context.MarkAsReadFailed", @"Telegram could not mark the chat as read.")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[strongSelf reload];
		if ([strongSelf.tabBarController isKindOfClass:[RootViewController class]])
			[(RootViewController *)strongSelf.tabBarController updateUnreadBadge];
	}];
}

- (BOOL)chatIsUnread:(NSDictionary *)chat {
	if ([chat[@"unread"] integerValue] > 0)
		return YES;
	if ([chat[@"markedUnread"] boolValue])
		return YES;
	return [[TGClient shared] isChatMarkedAsUnread:[chat[@"id"] longLongValue]];
}

- (void)showNotificationsAlertWithMessage:(NSString *)message {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Notifications.Title", @"Notifications")
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (NSArray *)notificationMenuKindsForChatMuted:(BOOL)muted usesDefault:(BOOL)usesDefault {
	NSMutableArray *kinds = [NSMutableArray array];
	[kinds addObject:(muted ? @"unmute" : @"mute")];
	[kinds addObject:@"preview"];
	if (!usesDefault)
		[kinds addObject:@"default"];
	return kinds;
}

- (NSArray *)notificationMenuItemsForChat:(int64_t)chatId
									muted:(BOOL)muted
								  preview:(BOOL)preview
							  usesDefault:(BOOL)usesDefault {
	NSMutableArray *items = [NSMutableArray array];
	[items addObject:@{@"title" : (muted ? [self unmuteTitleForChat:chatId] : TGL(@"ChatList.Context.Mute", @"Mute")),
		@"icon" : (muted ? @"unmute" : @"mute")}];
	[items addObject:@{@"title" : (preview ? TGL(@"Notification.Exceptions.PreviewAlwaysOff", @"Hide Message Text")
									: TGL(@"Notification.Exceptions.PreviewAlwaysOn", @"Show Message Text")),
		@"icon" : @"chat"}];
	if (!usesDefault)
		[items addObject:@{@"title" : TGL(@"Notifications.ExceptionsResetToDefaults", @"Use Default Settings"), @"icon" : @"chat"}];
	return items;
}

- (void)togglePreviewForChat:(int64_t)chatId currentlyOn:(BOOL)preview {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] updateChat:chatId
						   values:@{@"showPreview" : @(!preview),
							   @"useDefaultShowPreview" : @NO}
					   completion:^(BOOL ok) {
						   TGChatListViewController *strongSelf = weakSelf;
						   if (!strongSelf)
							   return;
						   strongSelf.actionChat = nil;
						   if (!ok) {
							   [strongSelf showNotificationsAlertWithMessage:TGL(@"ChatList.SettingCouldNotBeChangedMessage", @"Telegram would not change that setting.")];
							   return;
						   }
						   [strongSelf reload];
					   }];
}

- (void)applyNotificationMenuKind:(NSString *)kind
						  forChat:(int64_t)chatId
						previewOn:(BOOL)preview {
	if ([kind isEqualToString:@"mute"]) {
		[self showMuteDurationsForChat:chatId];
		return;
	}
	if ([kind isEqualToString:@"unmute"]) {
		self.actionChat = nil;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] setChat:chatId
					muteForSeconds:0
						completion:^(BOOL ok) {
			TGChatListViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[strongSelf showNotificationsAlertWithMessage:TGL(@"ChatList.SettingCouldNotBeChangedMessage", @"Telegram would not change that setting.")];
				return;
			}
			[strongSelf.muteRemaining removeObjectForKey:@(chatId)];
			[strongSelf reload];
		}];
		return;
	}
	if ([kind isEqualToString:@"default"]) {
		self.actionChat = nil;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] resetNotificationSettingsForChat:chatId
												  completion:^(BOOL ok) {
			TGChatListViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[strongSelf showNotificationsAlertWithMessage:TGL(@"ChatList.SettingCouldNotBeChangedMessage", @"Telegram would not change that setting.")];
				return;
			}
			[strongSelf.muteRemaining removeObjectForKey:@(chatId)];
			[strongSelf reload];
		}];
		return;
	}
	[self togglePreviewForChat:chatId currentlyOn:preview];
}

- (void)showNotificationOptionsForChat:(int64_t)chatId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] notificationSettingsForChat:chatId completion:^(NSDictionary *reply) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSDictionary *settings = TGReplyDictionary(reply);
		if (!settings) {
			[strongSelf showNotificationsAlertWithMessage:TGL(@"ChatList.NotificationSettingsCouldNotBeReadMessage", @"Telegram would not answer for this chat.")];
			return;
		}

		BOOL muted = [settings[@"muted"] boolValue];
		BOOL preview = [settings[@"showPreview"] boolValue];
		BOOL usesDefault = [settings[@"useDefaultMuteFor"] boolValue] &&
			[settings[@"useDefaultShowPreview"] boolValue];
		strongSelf.muteRemaining[@(chatId)] = @([settings[@"muteFor"] integerValue]);

		NSArray *items = [strongSelf notificationMenuItemsForChat:chatId muted:muted preview:preview usesDefault:usesDefault];
		NSArray *kinds = [strongSelf notificationMenuKindsForChatMuted:muted usesDefault:usesDefault];

		[TGPopupMenu showItems:items atPoint:strongSelf.menuPoint inView:strongSelf.navigationController.view
					  onChoice:^(NSInteger choice, NSString *title) {
						  TGChatListViewController *innerSelf = weakSelf;
						  if (!innerSelf || choice < 0 || choice >= (NSInteger)kinds.count)
							  return;
						  [innerSelf applyNotificationMenuKind:kinds[choice] forChat:chatId previewOn:preview];
					  }];
	}];
}

- (void)showMuteDurationsForChat:(int64_t)chatId {
	NSArray *items = @[
		@{@"title" : TGL(@"Notification.Mute1h", @"Mute for 1 hour"), @"icon" : @"mute"},
		@{@"title" : TGLPlural(@"MuteFor.Hours", 8, @"Mute for %@ hour", @"Mute for %@ hours"), @"icon" : @"mute"},
		@{@"title" : TGL(@"MuteFor.Days_2", @"Mute for 2 days"), @"icon" : @"mute"},
		@{@"title" : TGLPlural(@"MuteFor.Days", 7, @"Mute for %@ day", @"Mute for %@ days"), @"icon" : @"mute"},
		@{@"title" : TGL(@"PeerInfo.MuteFor", @"Mute for"), @"icon" : @"mute"},
		@{@"title" : TGL(@"PeerInfo.MuteForever", @"Mute forever"), @"icon" : @"mute"},
	];
	NSArray *seconds = @[ @(3600), @(8 * 3600), @(2 * 24 * 3600), @(7 * 24 * 3600),
		@(-1), @(kNotificationMuteForever) ];

	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:self.menuPoint inView:self.navigationController.view
				  onChoice:^(NSInteger choice, NSString *title) {
					  TGChatListViewController *strongSelf = weakSelf;
					  if (!strongSelf || choice < 0 || choice >= (NSInteger)seconds.count)
						  return;
					  NSInteger value = [seconds[choice] integerValue];
					  if (value < 0) {
						  [strongSelf askCustomMuteForChat:chatId];
						  return;
					  }
					  strongSelf.actionChat = nil;
					  [[TGClient shared] setChat:chatId
								  muteForSeconds:value
									  completion:^(BOOL ok) {
						  TGChatListViewController *innerSelf = weakSelf;
						  if (!innerSelf)
							  return;
						  if (!ok) {
							  [innerSelf showNotificationsAlertWithMessage:TGL(@"ChatList.SettingCouldNotBeChangedMessage", @"Telegram would not change that setting.")];
							  return;
						  }
						  innerSelf.muteRemaining[@(chatId)] = @(value);
						  [innerSelf reload];
					  }];
				  }];
}

- (void)askCustomMuteForChat:(int64_t)chatId {
	if (self.mutePickerPanel)
		return;
	self.chatPendingCustomMute = chatId;

	UIView *rootView = self.navigationController.view;
	CGRect b = rootView.bounds;
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
							 action:@selector(dismissMutePicker)];
	UIBarButtonItem *space = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
							 target:nil
							 action:nil];
	UIBarButtonItem *done = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemDone
							 target:self
							 action:@selector(commitMutePicker)];
	bar.items = @[ cancel, space, done ];
	[panel addSubview:bar];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, 44, b.size.width, panelHeight - 44)];
	picker.datePickerMode = UIDatePickerModeCountDownTimer;
	picker.minuteInterval = 5;
	picker.countDownDuration = 12 * 3600;
	picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[panel addSubview:picker];

	self.mutePicker = picker;
	self.mutePickerPanel = panel;

	[rootView addSubview:panel];
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = CGRectMake(0, b.size.height - panelHeight,
			b.size.width, panelHeight);
	}];
}

- (void)dismissMutePicker {
	UIView *panel = self.mutePickerPanel;
	self.chatPendingCustomMute = 0;
	if (!panel)
		return;
	self.mutePickerPanel = nil;
	self.mutePicker = nil;
	CGRect gone = panel.frame;
	gone.origin.y = panel.superview.bounds.size.height;
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = gone;
	} completion:^(BOOL finished) {
		[panel removeFromSuperview];
	}];
}

- (void)commitMutePicker {
	int64_t chatId = self.chatPendingCustomMute;
	NSInteger value = (NSInteger)self.mutePicker.countDownDuration;
	[self dismissMutePicker];
	if (!chatId || value <= 0)
		return;
	self.actionChat = nil;
	[self setChat:chatId muteForSeconds:value];
}

- (void)setChat:(int64_t)chatId muteForSeconds:(NSInteger)seconds {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setChat:chatId
				muteForSeconds:seconds
					completion:^(BOOL ok) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showNotificationsAlertWithMessage:TGL(@"ChatList.SettingCouldNotBeChangedMessage", @"Telegram would not change that setting.")];
			return;
		}
		if (seconds > 0)
			strongSelf.muteRemaining[@(chatId)] = @(seconds);
		else
			[strongSelf.muteRemaining removeObjectForKey:@(chatId)];
		[strongSelf reload];
	}];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	if (alertView.tag == 21) {
		NSString *link = [[alertView textFieldAtIndex:0].text
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (link.length)
			[self checkFolderInviteLink:link];
		return;
	}
}

- (void)refreshMuteRemainingForChat:(int64_t)chatId {
	if (!chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] notificationSettingsForChat:chatId completion:^(NSDictionary *settings) {
		TGChatListViewController *strongSelf = weakSelf;
		NSDictionary *values = TGReplyDictionary(settings);
		if (!strongSelf || !values)
			return;
		strongSelf.muteRemaining[@(chatId)] = @([values[@"muteFor"] integerValue]);
	}];
}

- (NSString *)unmuteTitleForChat:(int64_t)chatId {
	return TGL(@"ChatList.Context.Unmute", @"Unmute");
}

- (void)setChat:(int64_t)chatId archived:(BOOL)archived {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] addChat:chatId
						toList:(archived ? TGChatListArchive : TGChatListMain)
		completion:^(BOOL ok) {
			TGChatListViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[TGSnackbar showInView:strongSelf.navigationController.view
								  text:TGL(@"ChatList.Context.ArchiveFailed", @"Telegram could not update the chat.")
							   seconds:2
							  onCommit:nil];
				return;
			}
			[strongSelf reload];
			[strongSelf rebuildTableHeader];
		}];
}

- (NSInteger)pinnedChatCount {
	NSInteger count = 0;
	NSString *pinnedKey = self.showsArchive ? @"isPinnedInArchive" : @"isPinned";
	for (NSDictionary *chat in self.chats) {
		if ([chat[pinnedKey] boolValue])
			count++;
	}
	return count;
}

- (void)showChatPinLimitReachedAlert:(NSInteger)max {
	NSString *message = [NSString stringWithFormat:
			TGL(@"Premium.MaxPinsFinalText", @"Sorry, you can't pin more than %@ chats to the top. Unpin some that are currently pinned."),
		@(max)];
	TGAlertView *alert = [[TGAlertView alloc]
		initWithTitle:TGL(@"Premium.LimitReached", @"Limit Reached")
			  message:message
	  cancelButtonTitle:TGL(@"Common.OK", @"OK")
			okButtonTitle:nil
		  completionBlock:nil];
	[alert show];
}

- (void)pinChat:(int64_t)chatId pinned:(BOOL)pinned {
	TGChatListId list = [self currentListId];
	if (pinned && (list == TGChatListMain || list == TGChatListArchive)) {
		NSInteger max = list == TGChatListArchive
			? [TGClient shared].pinnedArchivedChatCountMax
			: [TGClient shared].pinnedChatCountMax;
		if (max > 0 && [self pinnedChatCount] + 1 > max) {
			[self showChatPinLimitReachedAlert:max];
			return;
		}
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setChat:chatId pinned:pinned inList:list completion:^(BOOL success) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!success) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"ChatList.Context.PinFailed", @"Telegram could not update the chat.")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)confirmDeleteChat:(NSDictionary *)chat {
	int64_t chatId = [chat[@"id"] longLongValue];
	if (!chatId)
		return;

	if ([chat[@"isPrivate"] boolValue]) {
		self.chatPendingDeleteChoice = chat;
		NSString *name = chat[@"title"] ?: @"";
		NSInteger cancelIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:nil
						  delegate:self
					   otherTitles:@[ TGL(@"ChatList.DeleteForCurrentUser", @"Delete just for me"),
						   [NSString stringWithFormat:TGL(@"ChatList.DeleteForEveryone", @"Delete for me and %@"), name] ]
				  destructiveIndex:1
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:NULL
				 cancelButtonIndex:&cancelIndex];
		sheet.tag = 2;
		[self presentSheet:sheet];
		return;
	}

	[self beginDeletingChat:chatId revoke:NO];
}

- (void)runChatDeleteChoiceAtIndex:(NSInteger)index {
	NSDictionary *chat = self.chatPendingDeleteChoice;
	self.chatPendingDeleteChoice = nil;
	if (index < 0 || index > 1)
		return;
	int64_t chatId = [chat[@"id"] longLongValue];
	if (!chatId)
		return;
	[self beginDeletingChat:chatId revoke:(index == 1)];
}

- (void)beginDeletingChat:(int64_t)chatId revoke:(BOOL)revoke {
	NSNumber *pendingId = @(chatId);
	[self.chatsPendingDeletion addObject:pendingId];
	[self.tableView reloadData];

	BOOL isLeave = NO;
	for (NSDictionary *chat in self.chats) {
		if ([chat[@"id"] longLongValue] == chatId) {
			isLeave = [chat[@"isGroup"] boolValue];
			break;
		}
	}

	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.navigationController.view
					  text:(isLeave
						  ? TGL(@"Undo.ChatLeft", @"Left")
						  : TGL(@"Undo.ChatDeleted", @"Chat deleted"))
				   seconds:5
					  kind:TGSnackbarKindDestructiveUndo
				  onCommit:^{
					  [[TGClient shared] deleteChat:chatId revoke:revoke completion:^(BOOL ok) {
						  TGChatListViewController *innerSelf = weakSelf;
						  if (!innerSelf)
							  return;
						  [innerSelf.chatsPendingDeletion removeObject:pendingId];
						  [innerSelf reload];
						  if (!ok) {
							  [TGSnackbar showInView:innerSelf.navigationController.view
												 text:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
											  seconds:2
											 onCommit:nil];
						  }
					  }];
				  }];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatListViewController *strongSelf = weakSelf;
			if ([strongSelf.chatsPendingDeletion containsObject:pendingId]) {
				[strongSelf.chatsPendingDeletion removeObject:pendingId];
				[strongSelf.tableView reloadData];
			}
		});
}

@end
