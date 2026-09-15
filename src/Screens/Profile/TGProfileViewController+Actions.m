#import "TGClient+ChatManagement.h"
#import "TGVCard.h"
#import "TGProfileViewController.h"
#import "TGProfileViewControllerInternal.h"
#import "TGProfileButtonsCell.h"
#import "TGProfileRedButtonCell.h"
#import "TGProfilePermissionsController.h"
#import "TGProfileStatisticsController.h"
#import "TGProfileBoostsController.h"
#import "TGProfileCommonGroupsController.h"
#import "TGProfileLinkJoinsController.h"
#import "TGLocalization.h"
#import "TGProfileService.h"
#import "TGContactsService.h"
#import "TGClient.h"
#import "TGClient+Privacy.h"
#import "TGClient+SecretChats.h"
#import "TGProfileAutoDeleteSubtitle.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGGiftPremiumViewController.h"
#import "TGNewContactViewController.h"
#import "TGPreferenceFlags.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"

@implementation TGProfileViewController (Actions)

- (void)showMoreMenuFrom:(UIView *)tile {
	NSMutableArray *items = [NSMutableArray array];
	if (self.userId) {
		if (!self.chatId || ![TGContactsService isSecretChat:self.chatId])
			[items addObject:@{@"title" : TGL(@"UserInfo.StartSecretChat", @"Start Secret Chat"), @"icon" : @"privacy"}];
		else
			[items addObject:@{@"title" : TGL(@"Profile.EncryptionKey", @"Encryption Key"), @"icon" : @"privacy"}];
	}
	if (self.userId && self.contact) {
		[items addObject:@{@"title" : TGL(@"Profile.EditContact", @"Edit contact"), @"icon" : @"privacy"}];
		[items addObject:@{@"title" : [self setCustomPhotoTitle], @"icon" : @"privacy"}];
		[items addObject:@{@"title" : TGL(@"Conversation.ShareMyPhoneNumber", @"Share My Phone Number"), @"icon" : @"privacy"}];
	}
	if (!self.userId && self.chatId)
		[items addObject:@{@"title" : TGL(@"Report.Title.Group", @"Report group"), @"icon" : @"privacy"}];
	if (!self.userId && self.chatId && self.channelChat)
		[items addObject:@{@"title" : TGL(@"Premium.Limit.SimilarChatCount.Title", @"Similar Channels"), @"icon" : @"chat"}];
	if (self.userId && [TGPreferenceFlags storiesEnabled])
		[items addObject:@{@"title" : TGL(@"PeerInfo.PaneStories", @"Stories"), @"icon" : @"chat"}];
	if (self.userId && self.recipientAcceptsGifts)
		[items addObject:@{@"title" : TGL(@"PeerInfo.Gifts.SendGift", @"Send Gift"), @"icon" : @"chat"}];
	if (self.userId && self.recipientAcceptsPremiumGift)
		[items addObject:@{@"title" : TGL(@"PeerInfo.GiftPremium", @"Gift Premium"), @"icon" : @"chat"}];
	if (self.userId)
		[items addObject:@{@"title" : TGL(@"Profile.ExportVCard", @"Export vCard"), @"icon" : @"chat"}];
	if (self.userId)
		[items addObject:@{@"title" : TGL(@"ReportPeer.Report", @"Report"), @"icon" : @"privacy"}];
	if (self.chatId)
		[items addObject:@{@"title" : TGL(@"UserInfo.ChangeWallpaper", @"Change Wallpaper"), @"icon" : @"chat"}];
	if (self.userId && self.chatId)
		[items addObject:@{@"title" : TGL(@"Conversation.Theme", @"Chat Theme"), @"icon" : @"chat"}];
	if (self.chatId && (self.userId || self.canEditChat))
		[items addObject:@{@"title" : [NSString stringWithFormat:@"%@ (%@)",
			TGL(@"PeerInfo.AutoremoveMessages", @"Auto-Delete Messages"),
			[self autoDeleteMenuSubtitle]], @"icon" : @"delete"}];
	if (self.chatId)
		[items addObject:@{@"title" : (self.translatable ? TGL(@"PeerInfo.DisableAutoTranslate", @"Disable Auto-Translate") : TGL(@"PeerInfo.EnableAutoTranslate", @"Enable Auto-Translate")), @"icon" : @"chat"}];
	if (self.chatId)
		[items addObject:@{@"title" : TGL(@"DialogList.ClearHistoryConfirmation", @"Clear history"), @"icon" : @"delete"}];
	if (self.userId)
		[items addObject:@{@"title" : (self.blocked ? TGL(@"Conversation.UnblockUser", @"Unblock User") : TGL(@"Conversation.BlockUser", @"Block User")),
			@"icon" : @"privacy",
			@"destructive" : @YES}];
	if (!items.count)
		return;

	CGPoint where = [tile convertPoint:CGPointMake(tile.bounds.size.width / 2,
										   tile.bounds.size.height)
								toView:self.navigationController.view];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.navigationController.view
				  onChoice:^(NSInteger index, NSString *title) {
					  [weakSelf runMoreAction:title];
				  }];
}

- (void)runMoreAction:(NSString *)title {
	if ([title isEqualToString:@"Add to contacts"]) {
		if (!self.userId)
			return;
		[self promptToAddContact];
		return;
	}

	if ([title isEqualToString:TGL(@"Profile.EditContact", @"Edit contact")]) {
		if (!self.userId)
			return;
		[self pushContactFormEditing:YES];
		return;
	}

	if ([title isEqualToString:TGL(@"Conversation.ShareMyPhoneNumber", @"Share My Phone Number")]) {
		if (!self.userId)
			return;
		[self confirmShareMyPhoneNumber];
		return;
	}

	if ([title isEqualToString:[self setCustomPhotoTitle]]) {
		[self showContactPhotoActions];
		return;
	}

	if ([title isEqualToString:TGL(@"Report.Title.Group", @"Report group")]) {
		self.reportChatId = self.chatId;
		[self reportGroupWithOption:nil text:nil];
		return;
	}

	if ([title isEqualToString:TGL(@"Premium.Limit.SimilarChatCount.Title", @"Similar Channels")]) {
		[self showSimilarChannels];
		return;
	}

	if ([title isEqualToString:TGL(@"ReportPeer.Report", @"Report")]) {
		[self reportUser];
		return;
	}

	if ([title isEqualToString:TGL(@"PeerInfo.Gifts.SendGift", @"Send Gift")]) {
		[self openGiftsPageOpeningCatalogue:YES];
		return;
	}

	if ([title isEqualToString:TGL(@"PeerInfo.GiftPremium", @"Gift Premium")]) {
		if (!self.userId)
			return;
		TGGiftPremiumViewController *gift = [[TGGiftPremiumViewController alloc]
			initWithUserId:self.userId
					  name:self.name];
		[self.navigationController pushViewController:gift animated:YES];
		return;
	}

	if ([title isEqualToString:TGL(@"UserInfo.StartSecretChat", @"Start Secret Chat")]) {
		[self startSecretChat];
		return;
	}

	if ([title isEqualToString:TGL(@"Profile.EncryptionKey", @"Encryption Key")]) {
		[self openSecretChatInfo];
		return;
	}

	if ([title isEqualToString:TGL(@"PeerInfo.PaneStories", @"Stories")]) {
		[self openStoriesList];
		return;
	}

	if ([title isEqualToString:@"Share contact"]) {
		[self pushContactForwardPicker];
		return;
	}

	if ([title isEqualToString:TGL(@"Profile.ExportVCard", @"Export vCard")]) {
		[self exportContactVCard];
		return;
	}

	if ([title isEqualToString:TGL(@"UserInfo.ChangeWallpaper", @"Change Wallpaper")]) {
		[self openChatBackground];
		return;
	}

	if ([title isEqualToString:TGL(@"Conversation.Theme", @"Chat Theme")]) {
		[self openChatTheme];
		return;
	}

	if ([title hasPrefix:TGL(@"PeerInfo.AutoremoveMessages", @"Auto-Delete Messages")]) {
		[self showAutoDeleteActions];
		return;
	}

	if ([title isEqualToString:TGL(@"PeerInfo.EnableAutoTranslate", @"Enable Auto-Translate")] ||
		[title isEqualToString:TGL(@"PeerInfo.DisableAutoTranslate", @"Disable Auto-Translate")]) {
		[self toggleChatTranslatable];
		return;
	}

	if ([title isEqualToString:TGL(@"DialogList.ClearHistoryConfirmation", @"Clear history")]) {
		[self confirmClearHistory];
		return;
	}

	if (!self.userId)
		return;
	if (![title isEqualToString:TGL(@"Conversation.BlockUser", @"Block User")] && ![title isEqualToString:TGL(@"Conversation.UnblockUser", @"Unblock User")])
		return;
	[self toggleBlockedState];
}

- (void)promptToAddContact {
	[self pushContactFormEditing:NO];
}

- (void)pushContactFormEditing:(BOOL)editing {
	TGNewContactViewController *form = [[TGNewContactViewController alloc] init];
	form.peerUserId = self.userId;
	form.prefillFirstName = self.firstName.length
		? self.firstName
		: (TGProfileText(self.name) ?: @"");
	form.prefillLastName = self.lastName ?: @"";
	form.prefillPhone = self.phoneNumber ?: @"";
	form.editingExistingContact = editing;
	form.offersShareException = !editing;
	__weak typeof(self) weakSelf = self;
	form.onDone = ^(BOOL saved, int64_t userId) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (saved && userId) {
			strongSelf.contact = YES;
			[strongSelf loadContactFlags];
			[strongSelf rebuildDetailRows];
		}
		[strongSelf showToast:(saved
							  ? (editing ? TGL(@"Toast.ContactUpdated", @"Contact updated") : TGL(@"Toast.ContactAdded", @"Added to contacts"))
							  : TGL(@"Toast.CouldNotSaveContact", @"Could not save the contact"))];
	};
	[self.navigationController pushViewController:form animated:YES];
}

- (void)confirmShareMyPhoneNumber {
	NSString *name = TGProfileText(self.name) ?: @"";
	UIAlertView *confirm = [UIAlertView alloc];
	confirm = [confirm initWithTitle:TGL(@"Conversation.ShareMyPhoneNumber", @"Share My Phone Number")
							 message:[NSString stringWithFormat:
								 TGL(@"Conversation.ShareMyPhoneNumberConfirmation", @"Are you sure you want to share your phone number with %@?"), name]
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"Share.Title", @"Share"), nil];
	confirm.tag = 107;
	[confirm show];
}

- (void)performShareMyPhoneNumber {
	if (!self.userId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGContactsService sharePhoneNumberWithUser:self.userId completion:^(BOOL ok) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf showToast:(ok
				? [NSString stringWithFormat:TGL(@"Conversation.ShareMyPhoneNumber.StatusSuccess", @"%@ can now see your phone number."), TGProfileText(strongSelf.name) ?: @""]
				: TGL(@"Login.UnknownError", @"An error occurred, please try again later."))];
	}];
}

- (void)showContactPhotoActions {
	NSMutableArray *titles = [NSMutableArray arrayWithObjects:
		TGL(@"Common.ChoosePhoto", @"Choose Photo"),
		TGL(@"AvatarEditor.SuggestProfilePhoto", @"Suggest Photo"), nil];
	if (self.personalPhoto)
		[titles addObject:TGL(@"UserInfo.RemoveCustomPhoto", @"Remove Photo")];
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 84;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)confirmLeaveGroup {
	if (self.chatOwner && self.chatId) {
		__weak typeof(self) weakSelf = self;
		[TGProfileService ownerAfterLeavingGroup:self.chatId completion:^(NSString *name) {
			[weakSelf presentLeaveGroupConfirmationWithSuccessorName:name];
		}];
		return;
	}
	[self presentLeaveGroupConfirmationWithSuccessorName:nil];
}

- (void)presentLeaveGroupConfirmationWithSuccessorName:(NSString *)name {
	if (!name.length) {
		[self leaveGroupConfirmed];
		return;
	}
	NSString *message = [NSString stringWithFormat:
			  TGL(@"LeaveGroup.Text",
				  @"You will stop receiving messages from this group. If you do not return within 7 days, %@ will become the owner."),
		  name];
	UIAlertView *confirm = [UIAlertView alloc];
	confirm = [confirm initWithTitle:TGL(@"Group.LeaveGroup", @"Leave Group")
							 message:message
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"PeerInfo.AlertLeaveAction", @"Leave"), nil];
	confirm.tag = 72;
	[confirm show];
}

- (void)exportContactVCard {
	id handle = self.activeUsernames.firstObject;
	NSString *card = TGVCardForContact(self.firstName, self.lastName, self.phoneNumber,
		[handle isKindOfClass:NSString.class] ? handle : nil);
	if (!card.length || !self.view.window)
		return;
	NSString *fileName = TGVCardFileNameForContact(
		self.firstName.length ? self.firstName : self.name, self.lastName);
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
	if (![card writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL])
		return;
	UIDocumentInteractionController *interaction = [UIDocumentInteractionController
		interactionControllerWithURL:[NSURL fileURLWithPath:path]];
	if (!interaction)
		return;
	self.documentInteraction = interaction;
	if (![interaction presentOpenInMenuFromRect:self.view.bounds inView:self.view animated:YES])
		self.documentInteraction = nil;
}

- (void)pushContactForwardPicker {
	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	NSString *firstName = self.firstName.length ? self.firstName : self.name;
	NSString *lastName = self.lastName;
	int64_t userId = self.userId;
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSArray *chatIds) {
		int64_t targetChatId = [[chatIds firstObject] longLongValue];
		NSString *phone = weakSelf.phoneNumber;
		if (!phone.length) {
			UIAlertView *alert = [UIAlertView alloc];
			alert = [alert initWithTitle:TGL(@"Profile.ShareContactButton", @"Share contact")
								 message:TGL(@"Contacts.CannotShareWithoutPhoneNumber", @"This account does not show its phone number.")
								delegate:nil
					   cancelButtonTitle:TGL(@"Common.OK", @"OK")
					   otherButtonTitles:nil];
			[alert show];
			return;
		}
		[TGProfileService sendContactFirstName:firstName
									   lastName:lastName
										  phone:phone
										 userId:userId
										 toChat:targetChatId];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (NSString *)setCustomPhotoTitle {
	return [NSString stringWithFormat:TGL(@"UserInfo.SetCustomPhoto", @"Set Photo for %@"),
			TGProfileText(self.name) ?: @""];
}

- (NSString *)autoDeleteMenuSubtitle {
	NSInteger seconds = self.chatId ? [TGProfileService autoDeleteSecondsForChat:self.chatId] : 0;
	return TGProfileAutoDeleteSubtitleForSeconds(seconds);
}

- (void)showAutoDeleteActions {
	if (self.chatId && [TGContactsService isSecretChat:self.chatId]) {
		[self showSecretAutoDeleteActions];
		return;
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"PeerInfo.AutoremoveMessages", @"Auto-Delete Messages")
					  delegate:self
				   otherTitles:@[ TGL(@"PrivacySettings.PasscodeOff", @"Off"),
					   TGL(@"Notification.MessageLifetime1d", @"1 day"),
					   TGL(@"Notification.MessageLifetime1w", @"1 week"),
					   TGLPlural(@"MessageTimer.Months", 1, @"%ld month", @"%ld months") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 70;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)showSecretAutoDeleteActions {
	if (!self.chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] secretChatInfoForChat:self.chatId completion:^(NSDictionary *info) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *state = [info isKindOfClass:NSDictionary.class] ? info[@"state"] : nil;
		if (![state isEqualToString:@"ready"]) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"SecretChat.CannotChangeTimerNow", @"You can't change the self-destruct timer for this chat right now.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		[strongSelf presentSecretAutoDeleteLadder];
	}];
}

- (void)presentSecretAutoDeleteLadder {
	NSArray *ladder = [TGClient autoDeleteLadder];
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:ladder.count];
	for (NSDictionary *entry in ladder) {
		NSString *title = [entry isKindOfClass:NSDictionary.class] ? entry[@"title"] : nil;
		if ([title isKindOfClass:NSString.class])
			[titles addObject:title];
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"GlobalAutodeleteSettings.SetConfirmTitle", @"Self-Destruct Timer")
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 106;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)toggleChatTranslatable {
	if (!self.chatId)
		return;
	BOOL enabled = !self.translatable;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChat:self.chatId translatable:enabled
					completion:^(BOOL ok) {
						if (ok)
							weakSelf.translatable = enabled;
						NSString *changed = enabled ? TGL(@"Toast.ChatAutoTranslateOn", @"Auto-translate turned on for this chat") : TGL(@"Toast.ChatAutoTranslateOff", @"Auto-translate turned off for this chat");
						[weakSelf showToast:(ok ? changed : TGL(@"Toast.CouldNotChangeAutoTranslation", @"Could not change auto-translation"))];
					}];
}

- (void)confirmClearHistory {
	BOOL isPrivate = self.chatId && [TGProfileService isChatPrivate:self.chatId];
	BOOL isSecret = self.chatId && [TGContactsService isSecretChat:self.chatId];
	int64_t savedMessagesChatId = [[TGClient shared] savedMessagesChatId];
	BOOL isSelfChat = self.chatId && savedMessagesChatId && self.chatId == savedMessagesChatId;
	BOOL offersRevokeChoice = isPrivate && !self.isBot && !isSelfChat;

	if (offersRevokeChoice) {
		NSString *name = TGProfileText(self.name) ?: @"";
		NSInteger cancelIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:[NSString stringWithFormat:TGL(@"PeerInfo.ClearConfirmationUser", @"Are you sure you want to delete all messages with %@?"), name]
						  delegate:self
					   otherTitles:@[ TGL(@"ChatList.DeleteForCurrentUser", @"Delete just for me"),
						   [NSString stringWithFormat:TGL(@"ChatList.DeleteForEveryone", @"Delete for me and %@"), name] ]
				  destructiveIndex:1
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:NULL
				 cancelButtonIndex:&cancelIndex];
		sheet.tag = 103;
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
		return;
	}

	NSString *message = isSecret
		? TGL(@"PeerInfo.ClearConfirmationSecret", @"This will delete all messages in this secret chat, for both you and the other person.")
		: TGL(@"PeerInfo.ClearConfirmationGroup", @"Are you sure you want to delete all messages in this chat?");
	UIAlertView *confirm = [UIAlertView alloc];
	confirm = [confirm initWithTitle:TGL(@"DialogList.ClearHistoryConfirmation", @"Clear history")
							 message:message
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"WebSearch.RecentSectionClear", @"Clear"), nil];
	confirm.tag = 71;
	[confirm show];
}

- (void)toggleBlockedState {
	if (self.blocked) {
		[self confirmUnblockUser];
		return;
	}
	[self confirmBlockUser];
}

- (void)confirmBlockUser {
	NSString *name = TGProfileText(self.name) ?: @"";
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:[NSString stringWithFormat:
					TGL(@"UserInfo.BlockConfirmationTitle", @"Do you want to block %@ from messaging and calling you on Telegram?"), name]
					  delegate:self
				   otherTitles:@[ [NSString stringWithFormat:TGL(@"UserInfo.BlockActionTitle", @"Block %@"), name] ]
			  destructiveIndex:0
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 101;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)confirmUnblockUser {
	NSString *name = TGProfileText(self.name) ?: @"";
	UIAlertView *confirm = [UIAlertView alloc];
	confirm = [confirm initWithTitle:nil
							 message:[NSString stringWithFormat:TGL(@"UserInfo.UnblockConfirmation", @"Unblock %@?"), name]
							delegate:self
				   cancelButtonTitle:TGL(@"Common.No", @"No")
				   otherButtonTitles:TGL(@"Common.Yes", @"Yes"), nil];
	confirm.tag = 102;
	[confirm show];
}

- (void)applyBlockedState:(BOOL)blocked {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setUser:self.userId blocked:blocked completion:^(BOOL ok) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (ok) {
			strongSelf.blocked = blocked;
			[strongSelf showToast:(blocked ? TGL(@"Toast.UserBlocked", @"User blocked") : TGL(@"Toast.UserUnblocked", @"User unblocked"))];
		} else {
			[strongSelf showToast:(blocked ? TGL(@"Toast.CouldNotBlockUser", @"Could not block this user") : TGL(@"Toast.CouldNotUnblockUser", @"Could not unblock this user"))];
		}
		[strongSelf.tableView reloadData];
	}];
}

- (void)loadContactFlags {
	if (!self.userId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGContactsService contactFlagsForUser:self.userId
								completion:^(NSDictionary *flags) {
									if (![flags isKindOfClass:[NSDictionary class]])
										return;
									BOOL contact = TGProfileBool(flags[@"isContact"]) || TGProfileBool(flags[@"isMutualContact"]);
									NSString *note = nil;
									if (TGProfileBool(flags[@"isCloseFriend"]))
										note = TGL(@"Profile.ContactCloseFriend", @"Close friend");
									else if (TGProfileBool(flags[@"isMutualContact"]))
										note = TGL(@"Profile.ContactMutualContact", @"Mutual contact");
									else if (TGProfileBool(flags[@"isSupport"]))
										note = TGL(@"Profile.ContactTelegramSupport", @"Telegram support");
									weakSelf.contact = contact;
									weakSelf.contactRelation = note;
									weakSelf.isBot = TGProfileBool(flags[@"isBot"]);
									weakSelf.restrictionReason = TGProfileText(flags[@"restrictionReason"]) ?: @"";
									[weakSelf rebuildDetailRows];
								}];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex)
		return;

	if (sheet.tag == 82) {
		if (index == 0)
			[self deleteContactConfirmed];
		return;
	}

	if (sheet.tag == 84) {
		[self handleContactPhotoSheetIndex:index];
		return;
	}

	if (sheet.tag == 85) {
		[self handleReportOptionSheetIndex:index];
		return;
	}

	if (sheet.tag == 87) {
		[self handleChatPhotoSheetIndex:index];
		return;
	}

	if (sheet.tag == 100) {
		[self handleReportPhotoReasonSheetIndex:index];
		return;
	}

	if (sheet.tag == 89) {
		if (index == 0)
			[self convertToBroadcastGroup];
		return;
	}

	if (sheet.tag == 92) {
		[self runInviteLinkAction:[sheet buttonTitleAtIndex:index]];
		return;
	}

	if (sheet.tag == 77) {
		[self pickStoryPhotoFromCamera:(index == 0)];
		return;
	}

	if (sheet.tag == 78) {
		[self handleStoryPrivacySheetIndex:index];
		return;
	}

	if (sheet.tag == 79) {
		[self handleChatHistorySheetIndex:index];
		return;
	}

	if (sheet.tag == 76) {
		[self handleDiscussionSheetIndex:index];
		return;
	}

	if (sheet.tag == 75) {
		[self handleDiscussionCandidateSheetIndex:index];
		return;
	}

	if (sheet.tag == 74) {
		[self applySlowModePresetAtIndex:index];
		return;
	}

	if (sheet.tag == 95) {
		[self applyUnrestrictBoostPresetAtIndex:index];
		return;
	}

	if (sheet.tag == 98) {
		[self applyChannelMainProfileTabAtIndex:index];
		return;
	}

	if (sheet.tag == 101) {
		if (index == 0)
			[self applyBlockedState:YES];
		return;
	}

	if (sheet.tag == 103) {
		if (index == 0)
			[self clearHistoryConfirmed:NO];
		else if (index == 1)
			[self clearHistoryConfirmed:YES];
		return;
	}

	if (sheet.tag == 106) {
		[self applySecretAutoDeletePresetAtIndex:index];
		return;
	}

	if (sheet.tag != 70)
		return;
	[self applyAutoDeletePresetAtIndex:index];
}

- (void)handleContactPhotoSheetIndex:(NSInteger)index {
	if (index == 0 || index == 1) {
		[self pickPersonalPhotoSuggesting:(index == 1)];
		return;
	}
	if (index == 2 && self.personalPhoto)
		[self removePersonalPhoto];
}

- (void)handleReportOptionSheetIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.reportOptions.count)
		return;
	NSDictionary *option = self.reportOptions[index];
	[self reportGroupWithOption:TGProfileText(option[@"id"]) text:nil];
}

- (void)handleChatPhotoSheetIndex:(NSInteger)index {
	if (index == 0)
		[self pickChatPhoto];
	else if (index == 1)
		[self removeChatPhoto];
}

- (void)handleStoryPrivacySheetIndex:(NSInteger)index {
	NSArray *values = @[ @"everyone", @"contacts", @"closeFriends" ];
	if (index < 0 || index >= (NSInteger)values.count)
		return;
	self.storyPrivacy = values[index];
	[self askStoryCaption];
}

- (void)handleChatHistorySheetIndex:(NSInteger)index {
	if (index != 0 && index != 1)
		return;
	[self setHistoryAvailableTo:(index == 0)];
}

- (void)handleDiscussionSheetIndex:(NSInteger)index {
	if (index == 0) {
		[self openChatId:self.discussionChatId title:self.discussionTitle];
		return;
	}
	if (index == 1)
		[self linkDiscussionChat:0];
}

- (void)handleDiscussionCandidateSheetIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.discussionCandidates.count)
		return;
	NSDictionary *chat = self.discussionCandidates[index];
	NSString *ineligibility = chat[@"ineligibility"];
	if ([ineligibility isKindOfClass:NSString.class] && ineligibility.length) {
		[self showToast:[self discussionCandidateIneligibilityToast:ineligibility]];
		return;
	}
	[self linkDiscussionChat:TGProfileInt64(chat[@"id"])];
}

- (void)applyAutoDeletePresetAtIndex:(NSInteger)index {
	static const NSInteger seconds[4] = {0, 86400, 604800, 2592000};
	if (index < 0 || index > 3)
		return;
	if (!self.chatId)
		return;
	NSArray *durations = @[ TGL(@"Notification.MessageLifetime1d", @"1 day"),
		TGL(@"Notification.MessageLifetime1w", @"1 week"),
		TGLPlural(@"MessageTimer.Months", 1, @"%ld month", @"%ld months") ];
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChat:self.chatId autoDeleteSeconds:seconds[index] completion:^(BOOL ok) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showToast:TGL(@"Toast.CouldNotChangeAutoDelete", @"Could not change the auto-delete timer")];
			return;
		}
		if (index == 0) {
			[strongSelf showToast:TGL(@"Conversation.AutoremoveOff", @"Auto-Delete is now off.")];
			return;
		}
		[strongSelf showToast:[NSString stringWithFormat:TGL(@"Conversation.AutoremoveChanged", @"Auto-Delete timer set to %@"), durations[index - 1]]];
	}];
}

- (void)applySecretAutoDeletePresetAtIndex:(NSInteger)index {
	NSArray *ladder = [TGClient autoDeleteLadder];
	if (index < 0 || index >= (NSInteger)ladder.count)
		return;
	NSDictionary *entry = ladder[(NSUInteger)index];
	if (![entry isKindOfClass:NSDictionary.class])
		return;
	NSInteger seconds = [entry[@"seconds"] integerValue];
	if (!self.chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setChat:self.chatId autoDeleteSeconds:seconds completion:^(BOOL ok) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"SecretChat.TimerCouldNotBeChanged", @"That setting could not be changed.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		if (seconds <= 0) {
			[strongSelf showToast:TGL(@"Notification.MessageLifetimeRemovedOutgoing", @"You disabled the self-destruct timer")];
			return;
		}
		[strongSelf showToast:[NSString stringWithFormat:
			TGL(@"Notification.MessageLifetimeChangedOutgoing", @"You set the self-destruct timer to %1$@"),
			[TGClient autoDeleteTitleForSeconds:seconds]]];
	}];
}

- (void)runInviteLinkAction:(NSString *)pressed {
	if ([pressed isEqualToString:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link")]) {
		[UIPasteboard generalPasteboard].string = self.primaryInviteLink ?: @"";
		[self showToast:TGL(@"InviteLink.InviteLinkCopiedText", @"Invite link copied to clipboard")];
		return;
	}
	if ([pressed isEqualToString:TGL(@"Profile.WhoJoined", @"Who Joined")]) {
		[self openLinkJoins];
		return;
	}
	if ([pressed isEqualToString:TGL(@"GroupInfo.InviteLink.RevokeLink", @"Revoke Link")] && self.chatAdmin)
		[self replacePrimaryInviteLink];
}

- (void)applySlowModePresetAtIndex:(NSInteger)index {
	NSArray *presets = [TGProfileService slowModePresets];
	if (index < 0 || index >= (NSInteger)presets.count)
		return;
	id preset = presets[index];
	NSInteger seconds = [preset isKindOfClass:[NSNumber class]]
		? [preset integerValue]
		: 0;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setSlowModeDelay:seconds forChat:self.chatId
							completion:^(BOOL ok) {
								if (ok) {
									weakSelf.slowModeDelay = seconds;
									[weakSelf loadManagement];
								}
								[weakSelf showToast:(ok ? TGL(@"Toast.SlowModeUpdated", @"Slow mode updated") : TGL(@"Toast.CouldNotChangeSlowMode", @"Could not change slow mode"))];
							}];
}

- (NSString *)textFromAlert:(UIAlertView *)alert {
	if (![alert respondsToSelector:@selector(textFieldAtIndex:)])
		return nil;
	return TGProfileText([alert textFieldAtIndex:0].text);
}

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
	if (alert.tag == 86) {
		if (!self.reportTextOptional && index == alert.cancelButtonIndex)
			return;
		BOOL wantsText = self.reportTextOptional ? (index == 1) : (index != alert.cancelButtonIndex);
		NSString *text = wantsText ? [self textFromAlert:alert] : nil;
		[self reportGroupWithOption:self.reportOptionId text:(text ?: @"")];
		return;
	}
	if (index == alert.cancelButtonIndex)
		return;
	if (alert.tag == 97) {
		[self handleReportPhotoAlert:alert buttonIndex:index];
		return;
	}
	if (alert.tag == 88) {
		[self upgradeToSupergroup];
		return;
	}
	if (alert.tag == 93) {
		[self setForumMode:YES];
		return;
	}
	if (alert.tag == 90 && self.chatId) {
		[self setStickerSetNamed:[self textFromAlert:alert]];
		return;
	}
	if (alert.tag == 91 && self.chatId) {
		NSString *description = [self textFromAlert:alert];
		[self saveChatDescription:(description ?: @"")];
		return;
	}
	if (alert.tag == 79) {
		[self postStoryWithCaption:[self textFromAlert:alert]];
		return;
	}
	if (alert.tag == 81 && self.userId) {
		[self saveContactNote:[self textFromAlert:alert]];
		return;
	}
	if (alert.tag == 73 && self.chatId) {
		[self renameChatTo:[self textFromAlert:alert]];
		return;
	}
	if (alert.tag == 102 && self.userId) {
		[self applyBlockedState:NO];
		return;
	}
	if (alert.tag == 107) {
		[self performShareMyPhoneNumber];
		return;
	}

	if (alert.tag == 71 && self.chatId) {
		[self clearHistoryConfirmed:NO];
	} else if (alert.tag == 72 && self.chatId) {
		[self leaveGroupConfirmed];
	}
}

- (void)clearHistoryConfirmed:(BOOL)revoke {
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[TGProfileService clearHistoryInChat:chatId revoke:revoke completion:^(BOOL ok) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showToast:TGL(@"Toast.CouldNotClearHistory", @"Could not clear the chat history")];
			return;
		}
		strongSelf.photoCount = 0;
		strongSelf.fileCount = 0;
		[strongSelf.tableView reloadData];
		[strongSelf showToast:TGL(@"Undo.ChatCleared", @"Chat cleared")];
	}];
}

- (void)leaveGroupConfirmed {
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChat:self.chatId joined:NO completion:^(BOOL ok) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showToast:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")];
			return;
		}
		[strongSelf.navigationController popToRootViewControllerAnimated:YES];
	}];
}

- (void)saveContactNote:(NSString *)note {
	__weak typeof(self) weakSelf = self;
	[TGContactsService setNote:(note ?: @"") forUser:self.userId
					completion:^(BOOL ok) {
						if (ok) {
							weakSelf.profileNote = note;
							weakSelf.noteLoaded = YES;
							[weakSelf rebuildDetailRows];
						}
						[weakSelf showToast:(ok ? TGL(@"Toast.NoteSaved", @"Note saved") : TGL(@"Toast.CouldNotSaveNote", @"Could not save the note"))];
					}];
}

- (void)renameChatTo:(NSString *)title {
	if (!title.length)
		return;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setTitle:title forChat:self.chatId completion:^(BOOL ok) {
		if (ok) {
			weakSelf.name = title;
			weakSelf.nameLabel.text = title;
			[weakSelf layoutNameBadge];
			[weakSelf loadManagement];
		}
		[weakSelf showToast:(ok ? TGL(@"Toast.NameUpdated", @"Name updated") : TGL(@"Toast.CouldNotRename", @"Could not rename"))];
	}];
}

- (void)rebuildSections {
	NSMutableArray *kinds = [NSMutableArray array];
	if (self.canPostStory)
		[kinds addObject:@"story"];
	[kinds addObject:@"details"];
	[kinds addObject:@"actions"];
	if (self.personalChatId)
		[kinds addObject:@"personal"];
	if (self.manageRows.count)
		[kinds addObject:@"manage"];
	if (self.members.count)
		[kinds addObject:@"members"];
	[kinds addObject:@"media"];
	if (self.userId && self.contact)
		[kinds addObject:@"delete"];
	self.sectionKinds = kinds;
}

- (NSString *)kindForSection:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sectionKinds.count)
		return @"media";
	return self.sectionKinds[section];
}

@end
