#import "TGFolderChatCount.h"
#import "TGFriendlyError.h"
#import "TGFoldersViewController.h"
#import "TGFoldersInternal.h"
#import "TGLocalization.h"
#import "TGClient+ChatList.h"
#import "TGClient+Premium.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"

@implementation TGFoldersViewController (FolderList)

#pragma mark - folder list data

- (void)loadFolders {
	NSArray *known = [TGClient shared].folders;
	if (![known isKindOfClass:[NSArray class]])
		known = nil;
	[self.folders removeAllObjects];
	for (NSDictionary *folder in known) {
		if ([folder isKindOfClass:[NSDictionary class]] && folder[@"id"])
			[self.folders addObject:folder];
	}
	self.listLoaded = YES;
	if (!self.orderDirty)
		self.mainListPosition = [TGClient shared].mainChatListPosition;
	if (self.mainListPosition > (NSInteger)self.folders.count)
		self.mainListPosition = self.folders.count;

	if (![TGClient shared].available && self.folders.count == 0)
		[self showStatus:TGL(@"Folders.NotConnected", @"Not connected.\nFolders will appear once the app is online.")];
	else if (self.folders.count == 0)
		[self showStatus:TGL(@"Folders.NoFoldersYet", @"No folders yet.\nCreate one to group your chats.")];
	else
		[self showStatus:nil];

	[self.tableView reloadData];
	[self refreshCounts];
}

- (void)refreshCounts {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *folder in self.folders) {
		NSNumber *identifier = folder[@"id"];
		if (![identifier isKindOfClass:[NSNumber class]])
			continue;
		if (self.counts[identifier])
			continue;
		[[TGClient shared] folderWithId:identifier.integerValue
							 completion:^(NSDictionary *definition) {
								 if (![definition isKindOfClass:[NSDictionary class]])
									 return;
								 NSString *icon = definition[@"icon"];
								 if ([icon isKindOfClass:[NSString class]] && icon.length)
									 weakSelf.icons[identifier] = icon;
								 [[TGClient shared] chatCountForFolder:definition completion:^(NSInteger count) {
									 typeof(self) strongSelf = weakSelf;
									 if (!strongSelf)
										 return;
									 if (!TGFolderChatCountIsTrustworthy(count,
											 [[TGClient shared] chatListsAreLoaded]))
										 return;
									 strongSelf.counts[identifier] = @(count);
									 [strongSelf reloadRowForFolderId:identifier];
								 }];
							 }];
	}
}

- (void)reloadRowForFolderId:(NSNumber *)identifier {
	NSInteger row = NSNotFound;
	for (NSInteger index = 0; index < self.folders.count; index++) {
		if ([self.folders[index][@"id"] isEqual:identifier]) {
			row = (NSInteger)index + ((NSInteger)index >= self.mainListPosition ? 1 : 0);
			break;
		}
	}
	if (row == NSNotFound || self.tableView.isEditing) {
		[self.tableView reloadData];
		return;
	}
	[self.tableView reloadRowsAtIndexPaths:
			@[ [NSIndexPath indexPathForRow:row inSection:0] ]
						  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)loadRecommended {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recommendedFoldersWithCompletion:^(NSArray *entries, BOOL failed) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || strongSelf.page != TGFoldersPageList || failed)
			return;
		NSMutableArray *kept = [NSMutableArray array];
		if ([entries isKindOfClass:[NSArray class]]) {
			for (NSDictionary *entry in entries) {
				if (![entry isKindOfClass:[NSDictionary class]])
					continue;
				if (![entry[@"folder"] isKindOfClass:[NSDictionary class]])
					continue;
				[kept addObject:entry];
			}
		}
		if (kept.count == strongSelf.recommended.count && [kept isEqualToArray:strongSelf.recommended])
			return;
		strongSelf.recommended = kept;
		[strongSelf.tableView reloadData];
	}];
}

- (void)addRecommendedAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.recommended.count)
		return;
	if ([self folderLimitReached]) {
		[self showFolderLimitAlert];
		return;
	}
	NSDictionary *entry = self.recommended[index];
	NSMutableDictionary *definition = [entry[@"folder"] mutableCopy];
	[definition removeObjectForKey:@"id"];
	NSString *title = entry[@"title"];
	if ([title isKindOfClass:[NSString class]] && title.length)
		definition[@"title"] = title;
	NSString *icon = entry[@"icon"];
	if ([icon isKindOfClass:[NSString class]] && icon.length)
		definition[@"icon"] = icon;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] saveFolder:definition completion:^(NSInteger savedId, NSString *errorMessage) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (savedId == 0) {
			if ([strongSelf folderLimitReached]) {
				[strongSelf showFolderLimitAlert];
				return;
			}
			TGAlertView *alert = [[TGAlertView alloc]
					initWithTitle:TGL(@"Folders.FolderNotSaved", @"Folder Not Saved")
						  message:TGFriendlyErrorText(errorMessage, TGL(@"Folders.TelegramRefusedThisFolderItMay", @"Telegram refused this folder. It may be full, or the name may be taken."))
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
					okButtonTitle:nil
				  completionBlock:nil];
			[alert show];
			return;
		}
		[strongSelf loadFolders];
		[strongSelf loadRecommended];
	}];
}

- (void)loadFolderLimit {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] effectivePremiumLimit:@"chatFolderCount"
								  completion:^(NSInteger value) {
									  typeof(self) strongSelf = weakSelf;
									  if (!strongSelf || value <= 0 || strongSelf.folderLimit == value)
										  return;
									  strongSelf.folderLimit = value;
									  [strongSelf.tableView reloadData];
								  }];
}

- (void)loadChosenChatLimit {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] effectivePremiumLimit:@"chatFolderChosenChatCount"
								  completion:^(NSInteger value) {
									  if (value > 0)
										  weakSelf.chosenChatLimit = value;
								  }];
}

- (BOOL)folderLimitReached {
	NSArray *known = [TGClient shared].folders;
	NSInteger count = [known isKindOfClass:[NSArray class]] ? (NSInteger)known.count : 0;
	return self.folderLimit > 0 && count >= self.folderLimit;
}

- (void)folderTagsToggled:(UISwitch *)toggle {
	BOOL enabled = toggle.on;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] toggleFolderTagsEnabled:enabled completion:^(BOOL ok) {
		if (ok)
			return;
		[toggle setOn:!enabled animated:YES];
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[TGSnackbar showInView:strongSelf.view
						  text:TGL(@"Toast.CouldNotChangeFolderTags", @"Could not change folder tags")
					   seconds:2
					  onCommit:nil];
	}];
}

- (void)showFolderLimitAlert {
	NSString *message = [NSString stringWithFormat:
			TGL(@"ChatListFolder.LimitAlertMessageFormat", @"This account can keep %d folders. Delete one to make room for another."),
		(int)self.folderLimit];
	NSString *title = TGL(@"Premium.Limits.Folders", @"Folder Limit");
	NSString *okTitle = TGL(@"Common.OK", @"OK");
	TGAlertView *alert = [[TGAlertView alloc] initWithTitle:title message:message
										  cancelButtonTitle:okTitle
											  okButtonTitle:nil
											completionBlock:nil];
	[alert show];
}

- (NSInteger)listRowCount {
	return (NSInteger)self.folders.count + 1;
}

- (NSInteger)folderIndexForRow:(NSInteger)row {
	if (row == self.mainListPosition)
		return -1;
	return row < self.mainListPosition ? row : row - 1;
}

- (NSMutableArray *)combinedListRows {
	NSMutableArray *combined = [NSMutableArray arrayWithArray:self.folders];
	NSInteger position = MIN(MAX(self.mainListPosition, 0), (NSInteger)self.folders.count);
	[combined insertObject:[NSNull null] atIndex:position];
	return combined;
}

- (void)adoptCombinedListRows:(NSArray *)combined {
	NSMutableArray *ordered = [NSMutableArray array];
	NSInteger position = 0;
	for (NSInteger index = 0; index < combined.count; index++) {
		id entry = combined[index];
		if (entry == [NSNull null])
			position = (NSInteger)ordered.count;
		else
			[ordered addObject:entry];
	}
	self.folders = ordered;
	self.mainListPosition = position;
}

- (void)commitOrder {
	if (!self.orderDirty || self.folders.count == 0)
		return;
	self.orderDirty = NO;
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *folder in self.folders) {
		NSNumber *identifier = folder[@"id"];
		if ([identifier isKindOfClass:[NSNumber class]])
			[ids addObject:identifier];
	}
	NSInteger position = MIN(MAX(self.mainListPosition, 0), (NSInteger)ids.count);
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderFolders:ids mainListPosition:position completion:^(BOOL success, NSString *errorMessage) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || success)
			return;
		[strongSelf loadFolders];
		[strongSelf.tableView reloadData];
		if (strongSelf.view.window) {
			[TGSnackbar showInView:strongSelf.view
							  text:TGFriendlyErrorText(errorMessage,
									   TGL(@"ChatList.Context.PinFailed",
										   @"Telegram could not update the chat."))
						   seconds:2
						  onCommit:nil];
		}
	}];
}

- (void)openFolder:(NSInteger)identifier {
	TGFoldersViewController *editor = [[TGFoldersViewController alloc] init];
	editor.page = TGFoldersPageEditor;
	editor.folderId = identifier;
	[self.navigationController pushViewController:editor animated:YES];
}

#pragma mark - table structure

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	switch (self.page) {
		case TGFoldersPageEditor:
			if (!self.draftLoaded)
				return 0;
			return self.folderId ? 5 : 3;
		case TGFoldersPageChatPicker:
		case TGFoldersPageIconPicker:
			return 1;
		default:
			return self.recommended.count ? 3 : 2;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.page == TGFoldersPageChatPicker)
		return self.pickerChats.count;
	if (self.page == TGFoldersPageIconPicker)
		return self.iconNames.count + 1;
	if (self.page == TGFoldersPageEditor) {
		if (section == 0)
			return 3;
		if (section == 1)
			return [self includeKeys].count + [self.draft[@"includedChatIds"] count] + 1;
		if (section == 2)
			return [self excludeKeys].count + [self.draft[@"excludedChatIds"] count] + 1;
		if (section == 3)
			return self.inviteLinks.count + 1;
		return 1;
	}
	if (section == 0)
		return [self listRowCount];
	if (section == 1)
		return 2;
	if (section == 2)
		return self.recommended.count;
	return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGFoldersPageChatPicker)
		return kChatRowHeight;
	if (self.page == TGFoldersPageEditor && indexPath.section == 3 && indexPath.row < (NSInteger)self.inviteLinks.count)
		return kChatRowHeight;
	return kRowHeight;
}

- (NSString *)captionForSection:(NSInteger)section {
	if (self.page == TGFoldersPageList) {
		if (section == 1) {
			NSString *base = TGL(@"ChatListFolder.ListSectionInfo", @"Folders let you group chats and switch between them from the chat list. Drag All Chats to change which tab opens first."
							  "from the chat list. Drag All Chats to change which tab opens first.");
			if (self.folderLimit > 0)
				return [NSString stringWithFormat:TGL(@"ChatListFolder.ListSectionInfoWithCountFormat", @"%@\n\nYou have created %d of %d folders."),
					base, (int)self.folders.count, (int)self.folderLimit];
			return base;
		}
		return nil;
	}
	if (self.page == TGFoldersPageEditor) {
		if (section == 1)
			return TGL(@"ChatListFolder.IncludeSectionInfo", @"Choose chats and types of chats that will appear in this folder.");
		if (section == 2)
			return TGL(@"ChatListFolder.ExcludeSectionInfo", @"Choose chats and types of chats that will never appear in this folder.");
		if (section == 3)
			return TGL(@"ChatListFolder.InviteLinksSectionInfo", @"Invite links let other people join the groups and channels of this folder in one step."
					"of this folder in one step.");
	}
	return nil;
}

- (NSString *)headerTitleForSection:(NSInteger)section {
	if (self.page == TGFoldersPageList && section == 2 && self.recommended.count)
		return TGL(@"ChatListFolder.RecommendedSectionTitle", @"Recommended Folders");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	if (title)
		return [[TGTheme shared] groupedHeaderHeightForTitle:title];
	NSString *caption = [self captionForSection:section];
	if (!caption)
		return section == 0 ? 12 : 20;
	return [[TGTheme shared] groupedCommentHeightForText:caption width:self.tableView.bounds.size.width];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	UIView *header = title
		? [[TGTheme shared] groupedHeaderViewWithTitle:title width:self.tableView.bounds.size.width]
		: [[TGTheme shared] groupedCommentViewWithText:[self captionForSection:section]
												 width:self.tableView.bounds.size.width];
	TGApplyRTLHeaderMirroring(header);
	return header;
}

#pragma mark - selection

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	TGApplyRTLCellMirroring(cell);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (self.page == TGFoldersPageList) {
		if (indexPath.section == 2) {
			[self addRecommendedAtIndex:indexPath.row];
			return;
		}
		if (indexPath.section == 1) {
			if (indexPath.row == 1)
				return;
			if ([self folderLimitReached]) {
				[self showFolderLimitAlert];
				return;
			}
			TGFoldersViewController *editor = [[TGFoldersViewController alloc] init];
			editor.page = TGFoldersPageEditor;
			[self.navigationController pushViewController:editor animated:YES];
			return;
		}
		NSInteger folderIndex = [self folderIndexForRow:indexPath.row];
		if (folderIndex >= 0 && folderIndex < (NSInteger)self.folders.count) {
			NSNumber *identifier = self.folders[folderIndex][@"id"];
			[self openFolder:identifier.integerValue];
		}
		return;
	}

	if (self.page == TGFoldersPageChatPicker) {
		NSNumber *identifier = self.pickerChats[indexPath.row][@"id"];
		if (![self.pickerSelection containsObject:identifier] && self.pickerLimit > 0 && (NSInteger)self.pickerSelection.count >= self.pickerLimit) {
			TGAlertView *alert = [[TGAlertView alloc]
					initWithTitle:TGL(@"Premium.Limits.ChatsPerFolder", @"Chat Limit")
						  message:[NSString stringWithFormat:
										  TGL(@"Premium.MaxChatsInFolderFinalText", @"Sorry, you can't add more than %@ chats to a folder."),
									  @(self.pickerLimit)]
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
					okButtonTitle:nil
				  completionBlock:nil];
			[alert show];
			return;
		}
		if ([self.pickerSelection containsObject:identifier])
			[self.pickerSelection removeObject:identifier];
		else
			[self.pickerSelection addObject:identifier];
		[tableView reloadRowsAtIndexPaths:@[ indexPath ]
						 withRowAnimation:UITableViewRowAnimationNone];
		return;
	}

	if (self.page == TGFoldersPageIconPicker) {
		NSString *name = indexPath.row == 0 ? @"" : self.iconNames[indexPath.row - 1];
		self.currentIcon = name;
		if (self.iconCompletion)
			self.iconCompletion(name);
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}

	if (indexPath.section == 0 && indexPath.row == 1) {
		[self.nameField resignFirstResponder];
		[self pushIconPicker];
		return;
	}
	if (indexPath.section == 3) {
		[self.nameField resignFirstResponder];
		if (indexPath.row < (NSInteger)self.inviteLinks.count)
			[self openLinkActionsAtIndex:indexPath.row];
		else if ([self draftHasExcludeOrFilterSet])
			[self showInviteLinkFiltersUnsupportedAlert];
		else
			[self createInviteLink];
		return;
	}
	if (indexPath.section == 4) {
		[self confirmDeleteFolder];
		return;
	}
	if (indexPath.section == 1 || indexPath.section == 2) {
		BOOL included = (indexPath.section == 1);
		NSArray *keys = included ? [self includeKeys] : [self excludeKeys];
		NSArray *chatIds = self.draft[included ? @"includedChatIds" : @"excludedChatIds"];
		if (indexPath.row == (NSInteger)(keys.count + chatIds.count)) {
			[self.nameField resignFirstResponder];
			if (!included && [self.draft[@"isShareable"] boolValue]) {
				[self showInviteLinkFiltersUnsupportedAlert];
				return;
			}
			[self pushPickerForKey:(included ? @"includedChatIds" : @"excludedChatIds")
							 title:(included ? TGL(@"ChatList.AddChatsToFolder", @"Add Chats")
											 : TGL(@"ChatListFolder.ExcludeChatsTitle", @"Exclude Chats"))];
		}
	}
}

@end
