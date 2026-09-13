#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGFolderLinksNotice.h"
#import "TGFriendlyError.h"
#import "TGFoldersViewController.h"
#import "TGFoldersInternal.h"
#import "TGLocalization.h"
#import "TGClient+ChatList.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"

@implementation TGFoldersViewController (InviteLinks)

#pragma mark - invite links

- (void)loadInviteLinks {
	if (!self.folderId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] inviteLinksForFolder:self.folderId completion:^(NSArray *links, BOOL failed) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *notice = TGFolderLinksNoticeText(failed, strongSelf.inviteLinks.count);
		if (notice.length) {
			[TGSnackbar showInView:strongSelf.view text:notice seconds:3 onCommit:nil];
			strongSelf.linksLoaded = YES;
			if (strongSelf.draftLoaded)
				[strongSelf.tableView reloadData];
			return;
		}
		if (failed)
			return;
		NSMutableArray *kept = [NSMutableArray array];
		if ([links isKindOfClass:[NSArray class]]) {
			for (NSDictionary *link in links) {
				if ([link isKindOfClass:[NSDictionary class]] && [link[@"link"] isKindOfClass:[NSString class]])
					[kept addObject:link];
			}
		}
		strongSelf.inviteLinks = kept;
		strongSelf.linksLoaded = YES;
		if (strongSelf.draftLoaded)
			[strongSelf.tableView reloadData];
	}];
}

- (void)showNoChatsSelectedAlert {
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"FolderLinkScreen.ChatCountHeaderUnavailable", @"No Chats to Share")
				  message:TGL(@"FolderLinkScreen.TitleDescriptionUnavailable", @"Only groups and channels you can invite people to can go into a folder link.")
		cancelButtonTitle:TGL(@"Common.OK", @"OK")
			okButtonTitle:nil
		  completionBlock:nil];
	[alert show];
}

- (void)showInviteLinkFiltersUnsupportedAlert {
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"FolderLinkScreen.Title", @"Share Folder")
				  message:TGL(@"ChatListFilter.CreateLinkFiltersUnsupported", @"Invite links can only be created for folders with no excluded chats or filters. Remove them first.")
		cancelButtonTitle:TGL(@"Common.OK", @"OK")
			okButtonTitle:nil
		  completionBlock:nil];
	[alert show];
}

- (void)createInviteLink {
	if (!self.folderId)
		return;
	if ([self draftHasExcludeOrFilterSet]) {
		[self showInviteLinkFiltersUnsupportedAlert];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] shareableChatsInFolder:self.folderId completion:^(NSArray *chats) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSArray *rows = [chats isKindOfClass:[NSArray class]] ? chats : @[];
		NSMutableArray *chatIds = [NSMutableArray array];
		for (NSDictionary *row in rows) {
			if (![row isKindOfClass:[NSDictionary class]])
				continue;
			NSNumber *chatId = row[@"id"];
			if ([chatId isKindOfClass:[NSNumber class]])
				[chatIds addObject:chatId];
		}
		if (chatIds.count == 0) {
			[strongSelf showNoChatsSelectedAlert];
			return;
		}
		[strongSelf pushChatPickerWithFixedChats:rows
										 selected:chatIds
											title:TGL(@"FolderLinkScreen.Title", @"Share Folder")
									   completion:^(NSArray *selectedChatIds) {
											 typeof(self) innerSelf = weakSelf;
											 if (!innerSelf)
												 return;
											 [innerSelf finishCreatingInviteLinkWithChatIds:selectedChatIds];
										 }];
	}];
}

- (void)finishCreatingInviteLinkWithChatIds:(NSArray *)chatIds {
	if (chatIds.count == 0) {
		[self showNoChatsSelectedAlert];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] createInviteLinkForFolder:self.folderId name:@"" chatIds:chatIds
									   completion:^(NSDictionary *link) {
		if (![link isKindOfClass:[NSDictionary class]]) {
			TGAlertView *alert = [[TGAlertView alloc]
					initWithTitle:TGL(@"FolderLinkScreen.Title", @"Share Folder")
						  message:TGL(@"ChatListFilter.CreateLinkUnknownError", @"Link Not Created")
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
					okButtonTitle:nil
				  completionBlock:nil];
			[alert show];
			return;
		}
		typeof(self) strongSelf = weakSelf;
		if (strongSelf.draft)
			strongSelf.draft[@"isShareable"] = @(YES);
		[weakSelf loadInviteLinks];
	}];
}

- (NSDictionary *)activeLink {
	if (self.activeLinkIndex < 0 || self.activeLinkIndex >= (NSInteger)self.inviteLinks.count)
		return nil;
	return self.inviteLinks[self.activeLinkIndex];
}

- (void)openLinkActionsAtIndex:(NSInteger)index {
	self.activeLinkIndex = index;
	NSDictionary *link = [self activeLink];
	if (!link)
		return;
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:link[@"link"]
					  delegate:self
				   otherTitles:@[ TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link"),
					   TGL(@"FolderLinkScreen.ContextActionNameLink", @"Rename Link"),
					   TGL(@"Business.Links.DeleteItemConfirmationAction", @"Delete Link") ]
			  destructiveIndex:2
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = kLinkSheetTag;
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:3];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	[sheet tg_showFromRect:cell.frame inView:self.tableView];
}

- (void)renameActiveLink {
	NSDictionary *link = [self activeLink];
	if (!link)
		return;
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"InviteLink.Create.LinkNameTitle", @"Link Name")
				  message:nil
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	alert.tag = kRenameLinkAlertTag;
	NSString *name = link[@"name"];
	if ([name isKindOfClass:[NSString class]])
		[alert textFieldAtIndex:0].text = name;
	[alert show];
}

- (void)deleteLinkAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.inviteLinks.count)
		return;
	NSDictionary *link = self.inviteLinks[index];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteInviteLink:link[@"link"] forFolder:self.folderId
							  completion:^(BOOL success, NSString *errorMessage) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!success) {
			TGAlertView *alert = [[TGAlertView alloc]
					initWithTitle:TGL(@"FolderLinkScreen.Title", @"Share Folder")
						  message:TGFriendlyErrorText(errorMessage, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
					okButtonTitle:nil
				  completionBlock:nil];
			[alert show];
			return;
		}
		NSInteger currentIndex = [strongSelf.inviteLinks indexOfObject:link];
		if (currentIndex != NSNotFound)
			[strongSelf.inviteLinks removeObjectAtIndex:currentIndex];
		strongSelf.activeLinkIndex = -1;
		[strongSelf.tableView reloadData];
	}];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag != kRenameLinkAlertTag || buttonIndex == alertView.cancelButtonIndex)
		return;
	NSDictionary *link = [self activeLink];
	if (!link)
		return;
	NSString *name = [alertView textFieldAtIndex:0].text ?: @"";
	[self pushChatPickerForEditingLink:link withName:name];
}

- (void)pushChatPickerForEditingLink:(NSDictionary *)link withName:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] shareableChatsInFolder:self.folderId completion:^(NSArray *chats) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSArray *rows = [chats isKindOfClass:[NSArray class]] ? chats : @[];
		NSArray *currentChatIds = [link[@"chatIds"] isKindOfClass:[NSArray class]] ? link[@"chatIds"] : @[];
		[strongSelf pushChatPickerWithFixedChats:rows
										 selected:currentChatIds
											title:TGL(@"FolderLinkScreen.Title", @"Share Folder")
									   completion:^(NSArray *selectedChatIds) {
											 typeof(self) innerSelf = weakSelf;
											 if (!innerSelf)
												 return;
											 [innerSelf finishEditingLink:link name:name chatIds:selectedChatIds];
										 }];
	}];
}

- (void)finishEditingLink:(NSDictionary *)link name:(NSString *)name chatIds:(NSArray *)chatIds {
	if (chatIds.count == 0) {
		[self showNoChatsSelectedAlert];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] editInviteLink:link[@"link"]
							forFolder:self.folderId
								 name:name
							  chatIds:chatIds
						   completion:^(NSDictionary *updated) {
							   if (![updated isKindOfClass:[NSDictionary class]]) {
								   TGAlertView *alert = [[TGAlertView alloc]
										   initWithTitle:TGL(@"FolderLinkScreen.Title", @"Share Folder")
											     message:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
									   cancelButtonTitle:TGL(@"Common.OK", @"OK")
											okButtonTitle:nil
										  completionBlock:nil];
								   [alert show];
								   return;
							   }
							   [weakSelf loadInviteLinks];
						   }];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex)
		return;

	if (sheet.tag == kLinkSheetTag) {
		NSDictionary *link = [self activeLink];
		if (!link)
			return;
		if (index == sheet.destructiveButtonIndex) {
			[self deleteLinkAtIndex:self.activeLinkIndex];
			return;
		}
		if (index == 0) {
			[UIPasteboard generalPasteboard].string = link[@"link"];
			return;
		}
		if (index == 1)
			[self renameActiveLink];
	}
}

@end
