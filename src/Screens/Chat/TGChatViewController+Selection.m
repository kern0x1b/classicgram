#import "TGClient+UpdateHandling.h"
#import "TGClient+ChatState.h"
#import "TGSelectionActionAvailability.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGFileDownloadService.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "TGSnackbar.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "TGClient+SecretChats.h"
#import "TGMessageInfoViewController.h"
#import "UIImage+WebP.h"
#import "TGClient+Messages.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Storage.h"
#import "TGMessageRowCell.h"
#import "TGAutosaveDecision.h"

@implementation TGChatViewController (Selection)

#pragma mark - selection

- (void)configureSelectionForCell:(TGMessageRowCell *)cell atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	BOOL nonForwardable = [m[@"id"] isKindOfClass:NSNumber.class] &&
		[self.nonForwardableMessageIds containsObject:m[@"id"]];
	BOOL hidden = !self.selecting || [m[@"service"] boolValue] || nonForwardable;
	BOOL checked = !hidden && [m[@"id"] isKindOfClass:NSNumber.class] &&
		[self.selectedIds containsObject:m[@"id"]];
	[cell setSelectionChecked:checked
						image:(hidden ? nil : [self selectionGlyphChecked:checked])
		hidden:hidden
					 animated:NO];
	[self refreshPeerGesturesInCell:cell];
}

- (void)beginSelectionWithMessage:(int64_t)messageId {
	if (!self.selecting) {
		self.selecting = YES;
		self.rightItemBeforeSelection = self.navigationItem.rightBarButtonItem;
		self.titleViewBeforeSelection = self.navigationItem.titleView;
		self.navigationItem.titleView = nil;
		self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
									   target:self
									   action:@selector(endSelection)];
		[self buildSelectionPanel];
		[self selectionForwardButton].enabled = NO;
		[self refreshSelectionButtonAvailability];
		[self fetchMissingSelectionPermissions];
	}
	if (messageId != 0 && ![self.selectedIds containsObject:@(messageId)])
		[self.selectedIds addObject:@(messageId)];
	[self updateSelectionChrome];
	[self updateSelectionForwardAvailability];
	[self.table reloadData];
}

- (void)endSelection {
	self.selecting = NO;
	self.reportSelectionOptionId = nil;
	[self.selectedIds removeAllObjects];
	self.navigationItem.rightBarButtonItem = self.rightItemBeforeSelection;
	self.rightItemBeforeSelection = nil;
	UIView *panel = self.selectionPanel;
	self.selectionPanel = nil;
	[UIView animateWithDuration:0.2 delay:0.0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{ panel.alpha = 0.0f; }
		completion:^(BOOL finished) { [panel removeFromSuperview]; }];
	self.navigationItem.title = nil;
	if (self.titleViewBeforeSelection) {
		self.navigationItem.titleView = self.titleViewBeforeSelection;
		self.titleViewBeforeSelection = nil;
	}
	[self.table reloadData];
}

- (void)toggleSelectionOfRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	if (!m || [m[@"service"] boolValue] || ![m[@"id"] isKindOfClass:NSNumber.class])
		return;
	if ([self.nonForwardableMessageIds containsObject:m[@"id"]])
		return;
	BOOL picked = [self.selectedIds containsObject:m[@"id"]];
	for (NSDictionary *member in [self messagesAtRow:row]) {
		NSNumber *messageId = member[@"id"];
		if (![messageId isKindOfClass:NSNumber.class])
			continue;
		if (picked)
			[self.selectedIds removeObject:messageId];
		else if (![self.selectedIds containsObject:messageId])
			[self.selectedIds addObject:messageId];
	}

	if (!self.selectedIds.count) {
		[self endSelection];
		return;
	}
	[self updateSelectionChrome];
	[self updateSelectionSaveAvailability];
	[self updateSelectionCopyAvailability];
	[self updateSelectionForwardAvailability];
	[self.table reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:row inSection:0] ]
					  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)updateSelectionChrome {
	self.navigationItem.title = self.selecting
		? [NSString stringWithFormat:TGL(@"Conversation.SelectedMessagesFormat", @"%lu Selected"),
			  (unsigned long)self.selectedIds.count]
		: nil;
}

- (void)buildSelectionPanel {
	CGRect b = self.view.bounds;
	const CGFloat height = kInputHeight;
	UIView *panel = [[UIView alloc] initWithFrame:
			CGRectMake(0, CGRectGetMaxY(self.inputBar.frame) - height,
				b.size.width, height)];
	panel.backgroundColor = [[TGTheme shared] inputBarColour];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleTopMargin;

	UIImage *bar = [UIImage imageNamed:@"ConversationActionBar"];
	if (bar) {
		UIImageView *plate = [[UIImageView alloc] initWithFrame:
				CGRectMake(0, 0, b.size.width, height)];
		plate.image = [bar stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		plate.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
		[panel addSubview:plate];
	}

	NSArray *titles;
	if (self.reportSelectionOptionId.length)
		titles = @[ TGL(@"ReportPeer.Report", @"Report") ];
	else if ([[TGClient shared] isSecretChat:self.chatId])
		titles = @[ TGL(@"Common.More", @"More"), TGL(@"Common.Delete", @"Delete") ];
	else
		titles = @[ TGL(@"Conversation.ContextMenuForward", @"Forward"),
			TGL(@"Conversation.ContextMenuCopy", @"Copy"),
			TGL(@"Conversation.LinkDialogSave", @"Save"),
			TGL(@"Common.More", @"More"),
			TGL(@"Common.Delete", @"Delete") ];
	CGFloat slice = b.size.width / titles.count;
	for (NSInteger i = 0; i < titles.count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(floorf(slice * i), 0,
			floorf(slice * (i + 1)) - floorf(slice * i), height);
		button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		button.tag = (NSInteger)i;
		[button setTitle:titles[i] forState:UIControlStateNormal];
		UIColor *ink = [titles[i] isEqualToString:TGL(@"Common.Delete", @"Delete")]
			? [UIColor colorWithRed:0.78f green:0.16f blue:0.13f alpha:1.0f]
			: [[TGTheme shared] accentColour];
		[button setTitleColor:ink forState:UIControlStateNormal];
		[button setTitleColor:[ink colorWithAlphaComponent:0.4f]
					 forState:UIControlStateHighlighted];
		[button setTitleColor:[ink colorWithAlphaComponent:0.3f]
					 forState:UIControlStateDisabled];
		[button addTarget:self action:@selector(selectionButtonTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[panel addSubview:button];

		if (i > 0) {
			UIView *rule = [[UIView alloc] initWithFrame:
					CGRectMake(floorf(slice * i), 7, kRetinaPixel, height - 14)];
			rule.backgroundColor = [[TGTheme shared] separatorColour];
			[panel addSubview:rule];
		}
	}

	panel.alpha = 0.0f;
	[self.view addSubview:panel];
	self.selectionPanel = panel;
	[UIView animateWithDuration:0.2 delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{ panel.alpha = 1.0f; }
					 completion:nil];
}

- (UIButton *)selectionButtonWithTitle:(NSString *)title {
	for (UIView *view in self.selectionPanel.subviews) {
		if ([view isKindOfClass:UIButton.class] &&
			[[(UIButton *)view currentTitle] isEqualToString:title])
			return (UIButton *)view;
	}
	return nil;
}

- (UIButton *)selectionForwardButton {
	return [self selectionButtonWithTitle:TGL(@"Conversation.ContextMenuForward", @"Forward")];
}

- (UIButton *)selectionSaveButton {
	return [self selectionButtonWithTitle:TGL(@"Conversation.LinkDialogSave", @"Save")];
}

- (UIButton *)selectionCopyButton {
	return [self selectionButtonWithTitle:TGL(@"Conversation.ContextMenuCopy", @"Copy")];
}

- (void)updateSelectionSaveAvailability {
	BOOL anySelectedNonSaveable = NO;
	for (NSNumber *messageId in self.selectedIds) {
		if ([self.nonSaveableMessageIds containsObject:messageId]) {
			anySelectedNonSaveable = YES;
			break;
		}
	}
	[self selectionSaveButton].enabled = TGSelectionActionIsAvailable(
		self.chatHasProtectedContentKnown, self.chatHasProtectedContent,
		self.selectedIds.count > 0, anySelectedNonSaveable);
}

- (void)updateSelectionCopyAvailability {
	BOOL anySelectedNonCopyable = NO;
	for (NSNumber *messageId in self.selectedIds) {
		if ([self.nonCopyableMessageIds containsObject:messageId]) {
			anySelectedNonCopyable = YES;
			break;
		}
	}
	[self selectionCopyButton].enabled = TGSelectionActionIsAvailable(
		self.chatHasProtectedContentKnown, self.chatHasProtectedContent,
		self.selectedIds.count > 0, anySelectedNonCopyable);
}

- (void)installProtectedContentObserver {
	if (self.protectedContentObserver)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	self.protectedContentObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatProtectedContentDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGChatViewController *strongSelf = weakSelf;
					if (!strongSelf || strongSelf.chatId != chatId)
						return;
					if ([note.userInfo[@"chatId"] longLongValue] != chatId)
						return;
					[strongSelf adoptProtectedContentFlag:
							[note.userInfo[@"hasProtectedContent"] boolValue]];
				}];
}

- (void)adoptProtectedContentFlag:(BOOL)hasProtectedContent {
	self.chatHasProtectedContentKnown = YES;
	self.chatHasProtectedContent = hasProtectedContent;
	[self updateSelectionForwardAvailability];
	[self updateSelectionSaveAvailability];
	[self updateSelectionCopyAvailability];
}

- (void)refreshSelectionButtonAvailability {
	[self updateSelectionForwardAvailability];
	if (self.chatHasProtectedContentKnown) {
		[self updateSelectionSaveAvailability];
		[self updateSelectionCopyAvailability];
		return;
	}
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[self installProtectedContentObserver];
	[[TGClient shared] managementInfoForChat:chatId completion:^(NSDictionary *info) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.chatId != chatId)
			return;
		[strongSelf adoptProtectedContentFlag:[info[@"hasProtectedContent"] boolValue]];
	}];
}

- (void)updateSelectionForwardAvailability {
	UIButton *button = [self selectionForwardButton];
	if (!TGSelectionActionIsAvailable(self.chatHasProtectedContentKnown,
			self.chatHasProtectedContent, self.selectedIds.count > 0, NO)) {
		button.enabled = NO;
		return;
	}
	for (NSNumber *messageId in self.selectedIds) {
		if ([self.nonForwardableMessageIds containsObject:messageId] ||
			![self.forwardPermissionKnownMessageIds containsObject:messageId]) {
			button.enabled = NO;
			return;
		}
	}
	button.enabled = YES;
}

- (void)fetchMissingSelectionPermissions {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *m in self.messages) {
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (!messageId || [m[@"service"] boolValue] || [self.selectionPermissionsRequested containsObject:messageId])
			continue;
		[self.selectionPermissionsRequested addObject:messageId];

		int64_t chatId = self.chatId;
		[[TGClient shared] propertiesOfMessage:messageId.longLongValue inChat:chatId
									 completion:^(NSDictionary *properties) {
										 TGChatViewController *strongSelf = weakSelf;
										 if (!strongSelf || strongSelf.chatId != chatId)
											 return;
										 [strongSelf.forwardPermissionKnownMessageIds addObject:messageId];
										 if (![properties[@"canSave"] boolValue]) {
											 [strongSelf.nonSaveableMessageIds addObject:messageId];
											 [strongSelf updateSelectionSaveAvailability];
										 }
										 if (![properties[@"canCopy"] boolValue]) {
											 [strongSelf.nonCopyableMessageIds addObject:messageId];
											 [strongSelf updateSelectionCopyAvailability];
										 }
										 if (![properties[@"canDeleteForEveryone"] boolValue])
											 [strongSelf.nonDeletableForEveryoneMessageIds addObject:messageId];
										 if (![properties[@"canForward"] boolValue]) {
											 [strongSelf.nonForwardableMessageIds addObject:messageId];
											 if ([strongSelf.selectedIds containsObject:messageId]) {
												 [strongSelf.selectedIds removeObject:messageId];
												 if (!strongSelf.selectedIds.count)
													 [strongSelf endSelection];
												 else
													 [strongSelf updateSelectionChrome];
											 }
											 [strongSelf.table reloadData];
										 }
										 [strongSelf updateSelectionForwardAvailability];
									 }];
	}
}

- (void)selectionButtonTapped:(UIButton *)button {
	if (!self.selectedIds.count)
		return;
	NSString *title = button.currentTitle ?: @"";
	if (self.reportSelectionOptionId.length) {
		[self submitReportSelection];
		return;
	}
	if ([title isEqualToString:TGL(@"Conversation.ContextMenuForward", @"Forward")])
		[self forwardSelected];
	else if ([title isEqualToString:TGL(@"Conversation.ContextMenuCopy", @"Copy")])
		[self copySelected];
	else if ([title isEqualToString:TGL(@"Conversation.LinkDialogSave", @"Save")])
		[self saveSelectedToCameraRoll];
	else if ([title isEqualToString:TGL(@"Common.More", @"More")])
		[self showSelectionMore];
	else
		[self confirmDeleteSelected];
}

- (void)submitReportSelection {
	NSArray *messageIds = [self.selectedIds copy];
	NSString *optionId = self.reportSelectionOptionId;
	self.reportSelectionOptionId = nil;
	[self endSelection];
	if (!messageIds.count)
		return;
	[self reportMessages:messageIds optionId:optionId text:@""];
}

- (void)showSelectionMore {
	if (self.selectedIds.count == 1) {
		[self openInfoForMessageId:[[self.selectedIds firstObject] longLongValue]];
		return;
	}
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
											  cancelButtonTitle:nil
										 destructiveButtonTitle:nil
											  otherButtonTitles:TGL(@"Conversation.MessageDialogRetry", @"Resend"), nil];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kSelectionMoreSheetTag;
	UIButton *anchorButton = [self selectionButtonWithTitle:TGL(@"Common.More", @"More")];
	[sheet tg_showFromRect:anchorButton.bounds inView:(anchorButton ?: self.view)];
}

- (void)runSelectionMore:(NSString *)chosen {
	if (![chosen isEqualToString:TGL(@"Conversation.MessageDialogRetry", @"Resend")] || !self.selectedIds.count)
		return;
	NSArray *messageIds = [self.selectedIds copy];
	BOOL needAnotherReplyQuote = NO;
	BOOL needDropReply = NO;
	int64_t paidStarCount = 0;
	for (NSNumber *messageId in messageIds) {
		NSInteger row = [self rowForMessageId:messageId.longLongValue];
		NSDictionary *found = (row != NSNotFound) ? [self messageAtRow:row] : nil;
		needAnotherReplyQuote = needAnotherReplyQuote || [found[@"needAnotherReplyQuote"] boolValue];
		needDropReply = needDropReply || [found[@"needDropReply"] boolValue];
		paidStarCount += [found[@"requiredPaidMessageStarCount"] longLongValue];
	}
	if (needAnotherReplyQuote) {
		[self presentQuoteOutdatedAlertForMessageIds:messageIds];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resendMessages:messageIds inChat:self.chatId dropQuote:needDropReply
						 paidStarCount:paidStarCount
						completion:^(NSArray *messages) {
							   TGChatViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   [strongSelf endSelection];
							   [strongSelf reload];
						   }];
}

- (void)openInfoForMessageId:(int64_t)messageId {
	[self openInfoForMessageId:messageId section:nil];
}

- (void)openInfoForMessageId:(int64_t)messageId section:(NSString *)section {
	NSDictionary *found = nil;
	for (NSDictionary *m in self.messages) {
		if ([m[@"id"] isKindOfClass:NSNumber.class] &&
			[m[@"id"] longLongValue] == messageId) {
			found = m;
			break;
		}
	}
	if (!found)
		return;

	TGMessageInfoViewController *info = [[TGMessageInfoViewController alloc] init];
	info.chatId = self.chatId;
	info.messageId = messageId;
	info.message = found;
	info.group = self.group;
	info.canResend = [self canResendMessage:found];
	info.focusSection = section;
	__weak typeof(self) weakSelf = self;
	info.onOpenChat = ^(int64_t targetChatId, NSString *title) {
		[weakSelf openChatId:targetChatId title:title isGroup:YES];
	};
	if (self.selecting)
		[self endSelection];
	[self.navigationController pushViewController:info animated:YES];
}

- (void)forwardSelected {
	if (!self.selectedIds.count)
		return;
	NSMutableArray *ids = [self.selectedIds mutableCopy];
	[ids removeObjectsInArray:self.nonForwardableMessageIds.allObjects];
	if (!ids.count)
		return;
	self.forwardMessageId = 0;
	self.forwardIds = [ids copy];
	[self showForwardOptions];
}

- (void)copySelected {
	if (self.chatHasProtectedContent) {
		[self endSelection];
		return;
	}
	NSMutableArray *lines = [NSMutableArray array];
	for (NSDictionary *m in self.messages) {
		if (![m[@"id"] isKindOfClass:NSNumber.class] ||
			![self.selectedIds containsObject:m[@"id"]] ||
			[self.nonCopyableMessageIds containsObject:m[@"id"]])
			continue;
		NSString *body = [self originalTextOf:m];
		if (body.length)
			[lines addObject:body];
	}
	[UIPasteboard generalPasteboard].string = [lines componentsJoinedByString:@"\n"];
	[self endSelection];
}

- (BOOL)saveMediaMessageToCameraRoll:(NSDictionary *)m {
	if ([self messageBurnsOnOpening:m])
		return NO;
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	if (self.chatHasProtectedContent || (messageId && [self.nonSaveableMessageIds containsObject:messageId]))
		return NO;
	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	if ([kind isEqualToString:@"messagePhoto"]) {
		NSNumber *fileId = [m[@"photoId"] isKindOfClass:NSNumber.class]
			? m[@"photoId"]
			: nil;
		if (!fileId)
			return NO;
		__weak typeof(self) weakForPhoto = self;
		[TGFileDownloadService downloadFile:[fileId longLongValue]
								 completion:^(NSString *path) {
									 if (!path.length)
										 return;
									 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
										 UIImage *loaded = [UIImage imageWithContentsOfFile:path];
										 if (!loaded && [path.pathExtension.lowercaseString isEqualToString:@"webp"])
											 loaded = [UIImage convertFromWebP:path compressedData:nil error:nil];
										 if (!loaded)
											 return;
										 dispatch_async(dispatch_get_main_queue(), ^{
											 TGChatViewController *me = weakForPhoto;
											 if (!me)
												 return;
											 UIImageWriteToSavedPhotosAlbum(loaded, me,
												 @selector(image:didFinishSavingWithError:contextInfo:), NULL);
										 });
									 });
								 }];
		return YES;
	}
	if ([kind isEqualToString:@"messageVideo"] ||
		[kind isEqualToString:@"messageVideoNote"]) {
		NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
		if (!docId)
			return NO;
		__weak typeof(self) weakSelf = self;
		[TGFileDownloadService downloadFile:[docId longLongValue]
								 completion:^(NSString *path) {
									 TGChatViewController *strongSelf = weakSelf;
									 if (!strongSelf || !path)
										 return;
									 if (!UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
										 [strongSelf showAlertTitle:@"" message:TGL(@"Chat.ThisVideoCannotBeSaved", @"This video cannot be saved.")];
										 return;
									 }
									 UISaveVideoAtPathToSavedPhotosAlbum(path, strongSelf,
										 @selector(video:didFinishSavingWithError:contextInfo:), NULL);
								 }];
		return YES;
	}
	return NO;
}

- (void)autosaveMessageIfNeeded:(NSDictionary *)m {
	if ([m[@"outgoing"] boolValue])
		return;
	NSString *kind = [m[@"kind"] isKindOfClass:[NSString class]] ? m[@"kind"] : @"";
	NSString *category = TGAutosaveCategoryForKind(kind);
	if (!category)
		return;
	NSNumber *fileId = [category isEqualToString:TGAutosaveCategoryPhoto]
		? ([m[@"photoId"] isKindOfClass:[NSNumber class]] ? m[@"photoId"] : nil)
		: ([m[@"docId"] isKindOfClass:[NSNumber class]] ? m[@"docId"] : nil);
	if (!fileId)
		return;

	long long knownSize = [[[TGClient shared] knownStateOfFile:fileId.longLongValue][@"size"] longLongValue];
	NSString *scope = [[TGClient shared] autosaveScopeForChat:self.chatId];
	NSDictionary *scopeSettings = [[TGClient shared] autosaveSettingsForScope:scope];
	NSDictionary *exception = [[TGClient shared] autosaveExceptionForChat:self.chatId];
	if (!TGShouldAutosaveFile(scopeSettings, exception, category, knownSize))
		return;

	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	if (!messageId)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] propertiesOfMessage:messageId.longLongValue inChat:chatId
								 completion:^(NSDictionary *properties) {
									 TGChatViewController *strongSelf = weakSelf;
									 if (!strongSelf || strongSelf.chatId != chatId)
										 return;
									 if (![properties[@"canSave"] boolValue])
										 return;
									 [strongSelf saveMediaMessageToCameraRoll:m];
								 }];
}

- (void)saveSelectedToCameraRoll {
	NSMutableArray *wanted = [NSMutableArray array];
	for (NSDictionary *m in self.messages)
		if ([m[@"id"] isKindOfClass:NSNumber.class] &&
			[self.selectedIds containsObject:m[@"id"]])
			[wanted addObject:m];

	for (NSDictionary *m in wanted)
		[self saveMediaMessageToCameraRoll:m];

	[self endSelection];
}

- (void)video:(NSString *)path didFinishSavingWithError:(NSError *)error
				 contextInfo:(void *)contextInfo {
	if (error) {
		[self showAlertTitle:@"" message:TGL(@"Toast.CouldNotSaveMedia", @"Could not save")];
		return;
	}
	[self showAlertTitle:@"" message:TGL(@"WebApp.Download.SavedToPhotos", @"Saved to Camera Roll")];
}

- (void)confirmDeleteSelected {
	BOOL secret = [[TGClient shared] isSecretChat:self.chatId];
	BOOL allDeletableForEveryone = YES;
	for (NSNumber *messageId in self.selectedIds) {
		if ([self.nonDeletableForEveryoneMessageIds containsObject:messageId]) {
			allDeletableForEveryone = NO;
			break;
		}
	}
	BOOL offerForEveryone = !secret && allDeletableForEveryone;
	NSString *title = TGLPlural(@"Chat.DeleteMessagesConfirmation", (NSInteger)self.selectedIds.count, @"Delete message", @"Delete %lu messages");
	NSString *destructiveTitle = offerForEveryone ? TGL(@"Stickers.Delete.ForEveryone", @"Delete for Everyone") : TGL(@"Common.Delete", @"Delete");
	UIActionSheet *sheetAlloc = [UIActionSheet alloc];
	UIActionSheet *sheet = [sheetAlloc initWithTitle:title
											delegate:self
								   cancelButtonTitle:nil
							  destructiveButtonTitle:destructiveTitle
								   otherButtonTitles:nil];
	if (offerForEveryone)
		[sheet addButtonWithTitle:TGL(@"ChatList.DeleteForMe", @"Delete for Me")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kSelectionDeleteSheetTag;
	UIButton *anchorButton = [self selectionButtonWithTitle:TGL(@"Common.Delete", @"Delete")];
	[sheet tg_showFromRect:anchorButton.bounds inView:(anchorButton ?: self.view)];
}

- (void)deleteSelectedForEveryone:(BOOL)forEveryone {
	NSArray *ids = [self.selectedIds copy];
	if (!ids.count)
		return;
	int64_t chatId = self.chatId;

	NSMutableArray *left = [NSMutableArray array];
	for (NSDictionary *m in self.messages)
		if (![m[@"id"] isKindOfClass:NSNumber.class] || ![ids containsObject:m[@"id"]])
			[left addObject:m];
	self.messages = left;
	[self endSelection];
	[self updateEmptyState];

	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.view
					  text:(forEveryone ? TGL(@"Chat.DeletedForEveryone", @"Deleted for everyone") : TGL(@"Chat.DeletedForYou", @"Deleted for you"))
				   seconds:5
					  kind:TGSnackbarKindDestructiveUndo
				  onCommit:^{
					  [[TGClient shared] deleteMessages:ids inChat:chatId
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
}

- (UIImage *)selectionGlyphChecked:(BOOL)checked {
	CGSize size = CGSizeMake(26, 26);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect ring = CGRectMake(1.5f, 1.5f, size.width - 3, size.height - 3);

	if (checked) {
		CGContextSetFillColorWithColor(ctx, [[TGTheme shared] accentColour].CGColor);
		CGContextFillEllipseInRect(ctx, ring);
		CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
		CGContextSetLineWidth(ctx, 2.0f);
		CGContextSetLineCap(ctx, kCGLineCapRound);
		CGContextMoveToPoint(ctx, 7.5f, 13.5f);
		CGContextAddLineToPoint(ctx, 11.5f, 17.5f);
		CGContextAddLineToPoint(ctx, 18.5f, 9.0f);
		CGContextStrokePath(ctx);
	} else {
		CGContextSetFillColorWithColor(ctx,
			[UIColor colorWithWhite:1.0f alpha:0.85f].CGColor);
		CGContextFillEllipseInRect(ctx, ring);
		CGContextSetStrokeColorWithColor(ctx,
			[UIColor colorWithWhite:0.62f alpha:1.0f].CGColor);
		CGContextSetLineWidth(ctx, 1.0f);
		CGContextStrokeEllipseInRect(ctx, ring);
	}

	UIImage *glyph = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return glyph;
}

@end
