#import "TGContactsViewController.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGContactsViewControllerInternal.h"
#import "TGFlatActionCell.h"
#import "TGContactRowCell.h"
#import "TGInviteFriendsViewController.h"
#import "TGSecretChatViewController.h"
#import "TGChatViewController.h"
#import "TGClient+Groups.h"
#import "TGContactsService.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGImageDecode.h"
#import "TGNewContactViewController.h"
#import "RootViewController.h"
#import "UIView+SafeTint.h"
#import "TGEmoji.h"
#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>
#import <dlfcn.h>
#import "TGAlertView.h"
#import "TGSnackbar.h"

@implementation TGContactsViewController (Actions)

- (void)longPressed:(UILongPressGestureRecognizer *)gesture {
	if (gesture.state != UIGestureRecognizerStateBegan || self.pickerMode)
		return;
	CGPoint point = [gesture locationInView:self.tableView];
	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
	if (!indexPath || [self actionIdentifierAtIndexPath:indexPath])
		return;
	NSDictionary *u = [self userAtIndexPath:indexPath];
	if (!u)
		return;
	self.actionUser = u;
	self.actionBirthdate = nil;
	self.actionFlags = nil;
	self.actionSheetShown = NO;
	self.actionBirthdateReady = NO;
	self.actionFlagsReady = NO;

	NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
	id cached = userId ? self.birthdays[userId] : nil;
	if (cached) {
		if ([cached isKindOfClass:NSDictionary.class])
			self.actionBirthdate = [self birthdayTextFrom:cached];
		self.actionBirthdateReady = YES;
	}
	NSDictionary *cachedFlags = userId ? self.contactFlags[userId] : nil;
	if (cachedFlags) {
		self.actionFlags = cachedFlags;
		self.actionFlagsReady = YES;
	}
	if (self.actionBirthdateReady && self.actionFlagsReady) {
		[self showContactActions];
		return;
	}

	[self requestActionDetailsForUser:u userId:userId];
}

- (void)requestActionDetailsForUser:(NSDictionary *)u userId:(NSNumber *)userId {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(showContactActions)
											   object:nil];
	[self performSelector:@selector(showContactActions) withObject:nil afterDelay:0.4f];
	__weak typeof(self) weakSelf = self;
	if (!self.actionBirthdateReady) {
		[TGContactsService birthdateForUser:[u[@"id"] longLongValue]
								 completion:^(NSDictionary *birthdate) {
									 TGContactsViewController *strongSelf = weakSelf;
									 if (!strongSelf)
										 return;
									 if (userId)
										 strongSelf.birthdays[userId] = [birthdate isKindOfClass:NSDictionary.class]
											 ? birthdate
											 : (id)[NSNull null];
									 if (strongSelf.actionUser != u)
										 return;
									 NSString *text = [birthdate isKindOfClass:NSDictionary.class]
										 ? [strongSelf birthdayTextFrom:birthdate]
										 : nil;
									 if (text.length)
										 strongSelf.actionBirthdate = text;
									 strongSelf.actionBirthdateReady = YES;
									 [strongSelf showContactActionsWhenReady];
								 }];
	}
	if (!self.actionFlagsReady) {
		[TGContactsService contactFlagsForUser:[u[@"id"] longLongValue]
									completion:^(NSDictionary *flags) {
										TGContactsViewController *strongSelf = weakSelf;
										if (!strongSelf)
											return;
										if (userId)
											strongSelf.contactFlags[userId] = [flags isKindOfClass:NSDictionary.class] ? flags : @{};
										if (strongSelf.actionUser != u)
											return;
										if ([flags isKindOfClass:NSDictionary.class])
											strongSelf.actionFlags = flags;
										strongSelf.actionFlagsReady = YES;
										[strongSelf showContactActionsWhenReady];
									}];
	}
}

- (void)showContactActionsWhenReady {
	if (self.actionBirthdateReady && self.actionFlagsReady)
		[self showContactActions];
}

- (void)showContactActions {
	NSDictionary *u = self.actionUser;
	if (!u || self.actionSheetShown)
		return;
	self.actionSheetShown = YES;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(showContactActions)
											   object:nil];
	NSMutableString *title = [NSMutableString stringWithString:TGContactName(u)];
	NSString *username = TGContactString(u, @"username");
	if (username.length)
		[title appendFormat:@"\n@%@", username];
	NSString *phone = TGContactString(u, @"phone");
	if (phone.length)
		[title appendFormat:@"\n+%@", phone];
	if (self.actionBirthdate.length)
		[title appendFormat:@"\n%@", [NSString stringWithFormat:TGL(@"UserInfo.BirthdayFormat", @"Birthday %@"), self.actionBirthdate]];
	BOOL mutual = [self.actionFlags[@"isMutualContact"] boolValue];
	if ([self.actionFlags[@"isSupport"] boolValue])
		[title appendFormat:@"\n%@", TGL(@"Profile.ContactTelegramSupport", @"Telegram support")];
	else if (mutual)
		[title appendFormat:@"\n%@", TGL(@"Profile.ContactMutualContact", @"Mutual contact")];

	NSMutableArray *keys = [NSMutableArray array];
	NSMutableArray *otherTitles = [NSMutableArray array];
	[otherTitles addObject:TGL(@"UserInfo.SendMessage", @"Send Message")];
	[keys addObject:@"message"];
	[otherTitles addObject:TGL(@"UserInfo.StartSecretChat", @"Start Secret Chat")];
	[keys addObject:@"secret"];
	if (!mutual) {
		[otherTitles addObject:TGL(@"Conversation.ShareMyPhoneNumber", @"Share My Phone Number")];
		[keys addObject:@"sharePhone"];
	}
	if (!self.actionBirthdate.length) {
		[otherTitles addObject:TGL(@"UserInfo.SuggestBirthdate", @"Suggest Birthday")];
		[keys addObject:@"suggestBirthday"];
	}
	NSInteger deleteIndex = (NSInteger)otherTitles.count;
	[otherTitles addObject:TGL(@"UserInfo.DeleteContact", @"Delete Contact")];
	[keys addObject:@"delete"];
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:title
					  delegate:self
				   otherTitles:otherTitles
			  destructiveIndex:deleteIndex
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	self.actionKeys = keys;
	sheet.tag = 2;
	[self presentSheet:sheet];
}

- (void)startSecretChatWithUser:(NSDictionary *)u {
	NSString *name = TGContactName(u);
	__weak typeof(self) weakSelf = self;
	[TGContactsService
		createSecretChatWithUser:[u[@"id"] longLongValue]
					  completion:^(NSDictionary *info) {
						  TGContactsViewController *strongSelf = weakSelf;
						  if (!strongSelf)
							  return;
						  if (![info isKindOfClass:NSDictionary.class]) {
							  UIAlertView *alert = [[UIAlertView alloc]
									  initWithTitle:nil
											message:TGL(@"Profile.CreateEncryptedChatError", @"Could not start a secret chat.")
										   delegate:nil
								  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  otherButtonTitles:nil];
							  [alert show];
							  return;
						  }
						  TGSecretChatViewController *vc = [[TGSecretChatViewController alloc] init];
						  vc.chatId = [info[@"chatId"] longLongValue];
						  vc.secretChatId = [info[@"secretChatId"] intValue];
						  vc.userId = [u[@"id"] longLongValue];
						  vc.peerName = name;
						  if (vc.chatId == 0 && vc.secretChatId == 0) {
							  UIAlertView *alert = [[UIAlertView alloc]
									  initWithTitle:nil
											message:TGL(@"Profile.CreateEncryptedChatError", @"Could not start a secret chat.")
										   delegate:nil
								  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  otherButtonTitles:nil];
							  [alert show];
							  return;
						  }
						  if (vc.chatId == 0) {
							  [TGContactsService openSecretChatId:vc.secretChatId completion:^(int64_t chatId) {
								  TGContactsViewController *innerSelf = weakSelf;
								  if (!innerSelf)
									  return;
								  if (chatId == 0)
									  return;
								  vc.chatId = chatId;
								  [innerSelf openTarget:vc];
							  }];
							  return;
						  }
						  [strongSelf openTarget:vc];
					  }];
}

- (void)confirmSharePhoneWithUser:(NSDictionary *)u {
	self.phoneShareUser = u;
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:nil
				  message:[NSString stringWithFormat:TGL(@"Conversation.ShareMyPhoneNumberConfirmation", @"Are you sure you want to share your phone number with %@?"),
							  TGContactName(u)]
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Share.Title", @"Share"), nil];
	alert.tag = 12;
	[alert show];
}

- (void)openChatWithUser:(NSDictionary *)u {
	NSString *name = TGContactName(u);
	__weak typeof(self) weakSelf = self;
	[TGContactsService privateChatWithUser:[u[@"id"] longLongValue]
								completion:^(int64_t chatId) {
									TGContactsViewController *strongSelf = weakSelf;
									if (!strongSelf || chatId == 0)
										return;
									TGChatViewController *vc = [[TGChatViewController alloc] init];
									vc.chatId = chatId;
									vc.chatTitle = name;
									[strongSelf openTarget:vc];
								}];
}

- (void)newChannelTapped {
	if (self.creatingChannel)
		return;
	UIAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Compose.NewChannel", @"New Channel")
						 message:TGL(@"Channel.TitlePlaceholder", @"Channel name")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.Create", @"Create"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	alert.tag = 13;
	[alert show];
}

- (void)createChannelWithTitle:(NSString *)title {
	if (self.creatingChannel)
		return;
	self.creatingChannel = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] createSupergroupWithTitle:title
									  description:@""
										isChannel:YES
										  isForum:NO
									   completion:^(int64_t chatId) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.creatingChannel = NO;
		if (chatId == 0) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"Channel.CreateFailed", @"Could not create the channel.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		TGChatViewController *vc = [[TGChatViewController alloc] init];
		vc.chatId = chatId;
		vc.chatTitle = title;
		[strongSelf openTarget:vc];
	}];
}

- (void)handleContactSheetAtIndex:(NSInteger)index {
	NSDictionary *u = self.actionUser;
	self.actionUser = nil;
	if (!u || index < 0 || index >= (NSInteger)self.actionKeys.count)
		return;
	NSString *key = self.actionKeys[(NSUInteger)index];
	if ([key isEqualToString:@"message"])
		[self openChatWithUser:u];
	else if ([key isEqualToString:@"secret"])
		[self startSecretChatWithUser:u];
	else if ([key isEqualToString:@"sharePhone"])
		[self confirmSharePhoneWithUser:u];
	else if ([key isEqualToString:@"suggestBirthday"])
		[self showBirthdayPickerForUser:u];
	else if ([key isEqualToString:@"delete"])
		[self confirmDeleteContact:u];
}

- (void)confirmDeleteContact:(NSDictionary *)u {
	self.pendingDeleteUser = u;
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:@[ TGL(@"UserInfo.DeleteContact", @"Delete Contact") ]
			  destructiveIndex:0
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = 7;
	[self presentSheet:sheet];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex)
		return;
	if (sheet.tag == 2) {
		[self handleContactSheetAtIndex:index];
		return;
	}
	if (sheet.tag == 4) {
		[self handleLinkSheetAtIndex:index];
		return;
	}
	if (sheet.tag == 5) {
		[self handleSortSheetAtIndex:index];
		return;
	}
	if (sheet.tag == 7) {
		NSDictionary *u = self.pendingDeleteUser;
		self.pendingDeleteUser = nil;
		if (u)
			[self deleteContact:u];
	}
}

- (NSString *)tokenFromLink:(NSString *)link {
	NSString *text = [link stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSRange marker = [text rangeOfString:@"contact/"];
	if (marker.length)
		return [text substringFromIndex:marker.location + marker.length];
	NSRange slash = [text rangeOfString:@"/" options:NSBackwardsSearch];
	if (slash.length && slash.location + 1 < text.length)
		return [text substringFromIndex:slash.location + 1];
	return text;
}

- (void)lookUpContactToken:(NSString *)token {
	if (!token.length)
		return;
	__weak typeof(self) weakSelf = self;
	[TGContactsService userForToken:token completion:^(NSDictionary *user) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![user isKindOfClass:NSDictionary.class] || !user[@"id"]) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"Chat.ErrorFolderLinkExpired", @"That link is not valid any more.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		TGNewContactViewController *form = [[TGNewContactViewController alloc] init];
		form.peerUserId = [user[@"id"] longLongValue];
		form.prefillFirstName = TGContactString(user, @"first_name");
		form.prefillLastName = TGContactString(user, @"last_name");
		form.prefillPhone = TGContactString(user, @"phone");
		form.editingExistingContact = NO;
		form.offersShareException = YES;
		form.onDone = ^(BOOL saved, int64_t resolvedUserId) {
			TGContactsViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			(void)resolvedUserId;
			[innerSelf reloadContacts];
			[TGSnackbar showInView:innerSelf.view
							   text:(saved
								   ? TGL(@"Toast.ContactAdded", @"Added to contacts")
								   : TGL(@"Toast.CouldNotSaveContact", @"Could not save the contact"))
							seconds:2
						   onCommit:nil];
		};
		[strongSelf openTarget:form];
	}];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
	if (alertView.tag == 10) {
		if (index == alertView.cancelButtonIndex)
			return;
		[self lookUpContactToken:[self tokenFromLink:[alertView textFieldAtIndex:0].text ?: @""]];
		return;
	}
	if (alertView.tag == 13) {
		if (index == alertView.cancelButtonIndex)
			return;
		NSString *title = [[alertView textFieldAtIndex:0].text
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (!title.length)
			return;
		[self createChannelWithTitle:title];
		return;
	}
	if (alertView.tag == 12) {
		NSDictionary *u = self.phoneShareUser;
		self.phoneShareUser = nil;
		if (index == alertView.cancelButtonIndex || !u)
			return;
		__weak typeof(self) weakSelf = self;
		[TGContactsService sharePhoneNumberWithUser:[u[@"id"] longLongValue] completion:^(BOOL ok) {
			typeof(self) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			UIAlertView *alert = [[UIAlertView alloc]
					initWithTitle:nil
						  message:(ok
									  ? [NSString stringWithFormat:TGL(@"Conversation.ShareMyPhoneNumber.StatusSuccess", @"%@ can now see your phone number."), TGContactName(u)]
									  : TGL(@"Login.UnknownError", @"An error occurred, please try again later."))
						 delegate:nil
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
				otherButtonTitles:nil];
			[alert show];
			if (!ok)
				return;
			NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
			if (userId)
				[strongSelf.contactFlags removeObjectForKey:userId];
		}];
		return;
	}
}

- (void)deleteContact:(NSDictionary *)u {
	NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
	if (!userId)
		return;

	NSArray *previous = self.users;
	NSMutableArray *remaining = [NSMutableArray array];
	for (NSDictionary *other in previous)
		if ([other[@"id"] longLongValue] != userId.longLongValue)
			[remaining addObject:other];
	self.users = remaining;
	[self refreshTable];

	__weak typeof(self) weakSelf = self;
	[TGContactsService removeContacts:@[ userId ] completion:^(BOOL ok) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			strongSelf.users = previous;
			[strongSelf refreshTable];
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"Contacts.CouldNotDeleteContact", @"Could not delete the contact.")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[strongSelf.closeFriendIds removeObject:@(userId.longLongValue)];
	}];
}

@end
