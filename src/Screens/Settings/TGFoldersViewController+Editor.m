#import "TGFoldersViewController.h"
#import "TGFriendlyError.h"
#import "TGFoldersInternal.h"
#import "TGLocalization.h"
#import "TGClient+ChatList.h"
#import "TGTheme.h"
#import "TGAlertView.h"

@implementation TGFoldersViewController (Editor)

#pragma mark - editor data

- (void)loadDraft {
	if (!self.folderId) {
		self.draft = [NSMutableDictionary dictionary];
		self.draft[@"title"] = @"";
		self.draft[@"includedChatIds"] = [NSMutableArray array];
		self.draft[@"excludedChatIds"] = [NSMutableArray array];
		self.draftLoaded = YES;
		[self showStatus:nil];
		[self.tableView reloadData];
		[self refreshDefaultIcon];
		[self refreshSaveButtonEnabled];
		return;
	}

	[self showStatus:TGL(@"Channel.NotificationLoading", @"Loading…")];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] folderWithId:self.folderId completion:^(NSDictionary *definition) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![definition isKindOfClass:[NSDictionary class]] || definition.count == 0) {
			strongSelf.draftFailed = YES;
			[strongSelf showStatus:TGL(@"Folders.TheFolderCouldNotBeLoaded", @"This folder could not be loaded.\nGo back and try again.")];
			return;
		}
		strongSelf.draft = [definition mutableCopy];
		strongSelf.draft[@"includedChatIds"] =
			[strongSelf mutableIdsFrom:definition[@"includedChatIds"]];
		strongSelf.draft[@"excludedChatIds"] =
			[strongSelf mutableIdsFrom:definition[@"excludedChatIds"]];
		strongSelf.draftLoaded = YES;
		[strongSelf showStatus:nil];
		[strongSelf.tableView reloadData];
		[strongSelf refreshDefaultIcon];
		[strongSelf refreshSaveButtonEnabled];
	}];
}

- (void)refreshSaveButtonEnabled {
	UIButton *button = (UIButton *)self.navigationItem.rightBarButtonItem.customView;
	if (![button isKindOfClass:[UIButton class]])
		return;
	NSString *title = self.draft[@"title"];
	NSString *trimmed = [title isKindOfClass:[NSString class]]
		? [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
		: @"";
	button.enabled = trimmed.length > 0;
}

- (void)refreshDefaultIcon {
	if (self.page != TGFoldersPageEditor || !self.draftLoaded)
		return;
	NSString *icon = self.draft[@"icon"];
	if ([icon isKindOfClass:[NSString class]] && icon.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] defaultIconNameForFolder:self.draft completion:^(NSString *iconName) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || ![iconName isKindOfClass:[NSString class]])
			return;
		if ([strongSelf.defaultIconName isEqualToString:iconName])
			return;
		strongSelf.defaultIconName = iconName;
		if (strongSelf.tableView.numberOfSections > 0)
			[strongSelf.tableView reloadRowsAtIndexPaths:
					@[ [NSIndexPath indexPathForRow:1 inSection:0] ]
										withRowAnimation:UITableViewRowAnimationNone];
	}];
}

- (NSMutableArray *)mutableIdsFrom:(id)value {
	NSMutableArray *result = [NSMutableArray array];
	if ([value isKindOfClass:[NSArray class]]) {
		for (id entry in value) {
			if ([entry isKindOfClass:[NSNumber class]])
				[result addObject:entry];
		}
	}
	return result;
}

- (void)saveDraft {
	if (!self.draftLoaded || self.savingDraft)
		return;
	NSString *title = self.nameField.text ?: self.draft[@"title"];
	title = [title stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (title.length == 0)
		return;
	self.draft[@"title"] = title;

	NSMutableDictionary *payload = [self.draft mutableCopy];
	if (self.folderId)
		payload[@"id"] = @(self.folderId);
	else
		[payload removeObjectForKey:@"id"];

	self.savingDraft = YES;
	UIButton *saveButton = (UIButton *)self.navigationItem.rightBarButtonItem.customView;
	if ([saveButton isKindOfClass:[UIButton class]])
		saveButton.enabled = NO;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] saveFolder:payload completion:^(NSInteger savedId, NSString *errorMessage) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.savingDraft = NO;
		if (savedId == 0) {
			if (!strongSelf.folderId && [strongSelf folderLimitReached]) {
				[strongSelf showFolderLimitAlert];
				[strongSelf refreshSaveButtonEnabled];
				return;
			}
			TGAlertView *alert = [[TGAlertView alloc]
					initWithTitle:TGL(@"Folders.FolderNotSaved", @"Folder Not Saved")
						  message:TGFriendlyErrorText(errorMessage, TGL(@"Folders.TelegramRefusedThisFolderItMay", @"Telegram refused this folder. It may be full, or the name may be taken."))
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
					okButtonTitle:nil
				  completionBlock:nil];
			[alert show];
			[strongSelf refreshSaveButtonEnabled];
			return;
		}
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

- (NSArray *)includeKeys {
	return @[ @"includeContacts", @"includeNonContacts", @"includeGroups",
		@"includeChannels", @"includeBots" ];
}

- (NSArray *)includeTitles {
	return @[ TGL(@"ChatListFolder.CategoryContacts", @"Contacts"),
		TGL(@"ChatListFolder.CategoryNonContacts", @"Non-Contacts"),
		TGL(@"ChatListFolder.CategoryGroups", @"Groups"),
		TGL(@"ChatListFolder.CategoryChannels", @"Channels"),
		TGL(@"ChatListFolder.CategoryBots", @"Bots") ];
}

- (NSArray *)excludeKeys {
	return @[ @"excludeMuted", @"excludeRead", @"excludeArchived" ];
}

- (NSArray *)excludeTitles {
	return @[ TGL(@"ChatListFolder.CategoryMuted", @"Muted"),
		TGL(@"ChatListFolder.CategoryRead", @"Read"),
		TGL(@"ChatListFolder.CategoryArchived", @"Archived") ];
}

- (BOOL)draftHasExcludeOrFilterSet {
	NSArray *excludedChatIds = self.draft[@"excludedChatIds"];
	if ([excludedChatIds isKindOfClass:[NSArray class]] && excludedChatIds.count > 0)
		return YES;
	NSArray *keys = [[self includeKeys] arrayByAddingObjectsFromArray:[self excludeKeys]];
	for (NSString *key in keys)
		if ([self.draft[key] boolValue])
			return YES;
	return NO;
}

- (void)toggleChanged:(UISwitch *)sender {
	NSArray *keys = [[self includeKeys] arrayByAddingObjectsFromArray:[self excludeKeys]];
	if (sender.tag < 0 || sender.tag >= (NSInteger)keys.count)
		return;
	if (sender.on && [self.draft[@"isShareable"] boolValue]) {
		sender.on = NO;
		[self showInviteLinkFiltersUnsupportedAlert];
		return;
	}
	self.draft[keys[sender.tag]] = @(sender.on);
	[self refreshDefaultIcon];
}

- (void)nameChanged:(UITextField *)field {
	self.draft[@"title"] = field.text ?: @"";
	[self refreshSaveButtonEnabled];
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	[field resignFirstResponder];
	return NO;
}

- (void)confirmDeleteFolder {
	__weak typeof(self) weakSelf = self;
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"ChatList.AlertDeleteFolderTitle", @"Delete Folder")
				  message:TGL(@"ChatList.RemoveFolderConfirmation", @"The chats in this folder will not be deleted.")
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:@[ TGL(@"Common.Delete", @"Delete") ]
		  completionBlock:^(bool okPressed) {
			  typeof(self) strongSelf = weakSelf;
			  if (!okPressed || !strongSelf)
				  return;
			  [strongSelf offerToLeaveChatsThenDelete];
		  }];
	[alert show];
}

- (void)offerToLeaveChatsThenDelete {
	NSInteger identifier = self.folderId;
	__weak typeof(self) weakSelf = self;
	[self offerToLeaveChatsForFolder:identifier completion:^(NSArray *leaveChatIds) {
		[weakSelf finishDeletingFolder:identifier leavingChats:leaveChatIds];
	}];
}

- (void)offerToLeaveChatsForFolder:(NSInteger)identifier completion:(void (^)(NSArray *leaveChatIds))completion {
	[[TGClient shared] chatsToLeaveWhenDeletingFolder:identifier completion:^(NSArray *chats) {
		NSMutableArray *chatIds = [NSMutableArray array];
		if ([chats isKindOfClass:[NSArray class]]) {
			for (NSDictionary *row in chats) {
				if (![row isKindOfClass:[NSDictionary class]])
					continue;
				NSNumber *chatId = row[@"id"];
				if ([chatId isKindOfClass:[NSNumber class]])
					[chatIds addObject:chatId];
			}
		}
		if (chatIds.count == 0) {
			if (completion)
				completion(nil);
			return;
		}
		NSString *message = TGLPlural(@"Folders.ChatsOnlyInThisFolder", (NSInteger)chatIds.count,
			@"One chat is only in this folder. Leave it as well?",
			@"%d chats are only in this folder. Leave them as well?");
		TGAlertView *sheet = [TGAlertView alloc];
		sheet = [sheet initWithTitle:TGL(@"FolderLinkPreview.ButtonRemoveFolderAndChats", @"Leave Chats")
							 message:message
				   cancelButtonTitle:TGL(@"FolderLinkPreview.ButtonRemoveFolder", @"Keep Chats")
				   otherButtonTitles:@[ TGL(@"FolderLinkPreview.ButtonRemoveFolderAndChats", @"Leave Chats") ]
					 completionBlock:^(bool leave) {
						 if (completion)
							 completion(leave ? chatIds : nil);
					 }];
		[sheet show];
	}];
}

- (void)finishDeletingFolder:(NSInteger)identifier leavingChats:(NSArray *)chatIds {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteFolder:identifier leavingChats:chatIds completion:^(BOOL success, NSString *errorMessage) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!success) {
			TGAlertView *alert = [[TGAlertView alloc]
					initWithTitle:@""
						  message:TGFriendlyErrorText(errorMessage, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
					okButtonTitle:nil
				  completionBlock:nil];
			[alert show];
			return;
		}
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

#pragma mark - editing

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGFoldersPageList)
		return indexPath.section == 0 && [self folderIndexForRow:indexPath.row] >= 0;
	if (self.page == TGFoldersPageEditor && indexPath.section == 3)
		return indexPath.row < (NSInteger)self.inviteLinks.count;
	if (self.page == TGFoldersPageEditor && (indexPath.section == 1 || indexPath.section == 2)) {
		BOOL included = (indexPath.section == 1);
		NSArray *keys = included ? [self includeKeys] : [self excludeKeys];
		NSArray *chatIds = self.draft[included ? @"includedChatIds" : @"excludedChatIds"];
		return indexPath.row >= (NSInteger)keys.count && indexPath.row < (NSInteger)(keys.count + chatIds.count);
	}
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return self.page == TGFoldersPageList && indexPath.section == 0 && indexPath.row < [self listRowCount];
}

- (void)tableView:(UITableView *)tableView
	moveRowAtIndexPath:(NSIndexPath *)from
		   toIndexPath:(NSIndexPath *)to {
	if (to.section != 0 || from.row >= [self listRowCount])
		return;
	NSMutableArray *combined = [self combinedListRows];
	id entry = combined[from.row];
	[combined removeObjectAtIndex:from.row];
	NSInteger target = MIN(to.row, (NSInteger)combined.count);
	[combined insertObject:entry atIndex:target];
	[self adoptCombinedListRows:combined];
	self.orderDirty = YES;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
	targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from
						 toProposedIndexPath:(NSIndexPath *)proposed {
	if (proposed.section != 0)
		return [NSIndexPath indexPathForRow:[self listRowCount] - 1 inSection:0];
	return proposed;
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (style != UITableViewCellEditingStyleDelete)
		return;

	if (self.page == TGFoldersPageEditor && indexPath.section == 3) {
		[self deleteLinkAtIndex:indexPath.row];
		return;
	}

	if (self.page == TGFoldersPageEditor) {
		BOOL included = (indexPath.section == 1);
		NSString *key = included ? @"includedChatIds" : @"excludedChatIds";
		NSArray *keys = included ? [self includeKeys] : [self excludeKeys];
		NSMutableArray *chatIds = self.draft[key];
		NSInteger index = indexPath.row - keys.count;
		if (index >= 0 && index < (NSInteger)chatIds.count) {
			[chatIds removeObjectAtIndex:index];
			[tableView deleteRowsAtIndexPaths:@[ indexPath ]
							 withRowAnimation:UITableViewRowAnimationFade];
		}
		return;
	}

	NSInteger folderIndex = [self folderIndexForRow:indexPath.row];
	if (folderIndex < 0 || folderIndex >= (NSInteger)self.folders.count)
		return;
	self.pendingDeleteIndex = folderIndex;
	NSDictionary *folder = self.folders[folderIndex];
	NSString *title = folder[@"title"];
	__weak typeof(self) weakSelf = self;
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:[NSString stringWithFormat:
								  TGL(@"ChatList.RemoveFolderConfirmationTitle", @"Remove %@?"),
							  [title isKindOfClass:[NSString class]] ? title : @"this folder"]
				  message:TGL(@"ChatList.RemoveFolderConfirmation", @"The chats in this folder will not be deleted.")
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:@[ TGL(@"Common.Delete", @"Delete") ]
		  completionBlock:^(bool okPressed) {
			  typeof(self) strongSelf = weakSelf;
			  if (!strongSelf)
				  return;
			  NSInteger index = strongSelf.pendingDeleteIndex;
			  strongSelf.pendingDeleteIndex = -1;
			  if (!okPressed || index < 0 || index >= (NSInteger)strongSelf.folders.count)
				  return;
			  NSNumber *identifier = strongSelf.folders[index][@"id"];
			  [strongSelf offerToLeaveChatsForFolder:identifier.integerValue
										   completion:^(NSArray *leaveChatIds) {
				  typeof(self) innerSelf = weakSelf;
				  if (!innerSelf)
					  return;
				  [[TGClient shared] deleteFolder:identifier.integerValue leavingChats:leaveChatIds completion:^(BOOL success, NSString *errorMessage) {
					  typeof(self) finalSelf = weakSelf;
					  if (!finalSelf)
						  return;
					  if (!success) {
						  TGAlertView *errorAlert = [[TGAlertView alloc]
								  initWithTitle:@""
									  message:TGFriendlyErrorText(errorMessage, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))
							cancelButtonTitle:TGL(@"Common.OK", @"OK")
								okButtonTitle:nil
							  completionBlock:nil];
						  [errorAlert show];
						  return;
					  }
					  NSInteger currentIndex = [finalSelf.folders indexOfObjectPassingTest:
							  ^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
						  return [row[@"id"] isEqual:identifier];
					  }];
					  if (currentIndex != NSNotFound)
						  [finalSelf.folders removeObjectAtIndex:currentIndex];
					  [finalSelf.counts removeObjectForKey:identifier];
					  if (finalSelf.mainListPosition > (NSInteger)finalSelf.folders.count)
						  finalSelf.mainListPosition = finalSelf.folders.count;
					  [finalSelf.tableView reloadData];
					  if (finalSelf.folders.count == 0)
						  [finalSelf showStatus:TGL(@"Folders.NoFoldersYet", @"No folders yet.\nCreate one to group your chats.")];
				  }];
			  }];
		  }];
	[alert show];
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGFoldersPageEditor && indexPath.section == 3)
		return TGL(@"Common.Delete", @"Delete");
	return self.page == TGFoldersPageEditor
		? TGL(@"ChatList.RemoveFolderAction", @"Remove")
		: TGL(@"Common.Delete", @"Delete");
}

@end
