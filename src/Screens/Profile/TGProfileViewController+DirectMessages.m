#import "TGListBackground.h"
#import "TGProfileViewController.h"
#import "TGProfileViewControllerInternal.h"
#import "TGProfileButtonsCell.h"
#import "TGProfileRedButtonCell.h"
#import "TGProfilePermissionsController.h"
#import "TGProfileStatisticsController.h"
#import "TGProfileBoostsController.h"
#import "TGProfileCommonGroupsController.h"
#import "TGProfileLinkJoinsController.h"
#import "TGSupergroupUsernamesViewController.h"
#import "TGLocalization.h"
#import "TGProfileService.h"
#import "TGContactsService.h"
#import "TGFileDownloadService.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGDirectMessagesViewController.h"
#import "TGDirectMessagesSettingsViewController.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGGroupCallViewController.h"
#import "TGChatBackgroundViewController.h"
#import "TGChatThemeViewController.h"
#import "TGGroupMembersViewController.h"
#import "TGInviteLinksViewController.h"
#import "TGChatEventsViewController.h"
#import "TGChatViewController.h"
#import "TGContactsViewController.h"
#import "TGStoriesViewController.h"
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

@implementation TGProfileViewController (DirectMessages)

- (void)openOrToggleDirectMessagesGroup {
	TGDirectMessagesSettingsViewController *settings =
		[[TGDirectMessagesSettingsViewController alloc] init];
	settings.topicsChatId = self.directMessagesChatId;
	settings.chatTitle = self.groupTitle;
	settings.enabled = self.directMessagesGroup;
	settings.starCount = self.directMessagesStarCount;

	__weak typeof(self) weakSelf = self;
	settings.onChange = ^(BOOL enabled, NSInteger starCount, void (^completion)(BOOL ok)) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(NO);
			return;
		}
		[strongSelf setDirectMessagesGroupEnabled:enabled starCount:starCount completion:completion];
	};
	settings.onOpenTopics = ^{
		TGProfileViewController *strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf pushDirectMessagesTopics];
	};

	[self.navigationController pushViewController:settings animated:YES];
}

- (void)pushDirectMessagesTopics {
	if (!self.directMessagesChatId)
		return;
	TGDirectMessagesViewController *topics = [[TGDirectMessagesViewController alloc] init];
	topics.chatId = self.directMessagesChatId;
	topics.chatTitle = self.groupTitle;
	[self.navigationController pushViewController:topics animated:YES];
}

- (void)setDirectMessagesGroupEnabled:(BOOL)enabled
							 starCount:(NSInteger)starCount
							completion:(void (^)(BOOL ok))completion {
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChat:self.chatId directMessagesGroupEnabled:enabled starCount:starCount completion:^(BOOL ok) {
		TGProfileViewController *strongSelf = weakSelf;
		if (strongSelf && ok) {
			strongSelf.directMessagesGroup = enabled;
			strongSelf.directMessagesStarCount = starCount;
			[strongSelf loadManagement];
		}
		if (completion)
			completion(ok);
	}];
}

- (void)showUnrestrictBoostActions {
	NSMutableArray *titles = [NSMutableArray arrayWithObject:TGL(@"PrivacySettings.PasscodeOff", @"Off")];
	for (NSInteger count = 1; count <= 8; count++)
		[titles addObject:TGLPlural(@"GroupInfo.Permissions.BoostCount", count, @"%ld Boost", @"%ld Boosts")];
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"GroupInfo.Permissions.DontRestrictBoostersInfo", @"Members who boost this group by this many times ignore slow mode and permission restrictions.")
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 95;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)applyUnrestrictBoostPresetAtIndex:(NSInteger)index {
	if (index < 0)
		return;
	NSInteger count = index;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setGroup:self.chatId unrestrictBoostCount:count
					completion:^(BOOL ok) {
						if (ok) {
							weakSelf.unrestrictBoostCount = count;
							[weakSelf rebuildManageRows];
						}
						[weakSelf showToast:(ok ? TGL(@"Toast.BoostBypassUpdated", @"Boost bypass updated")
												: TGL(@"Toast.CouldNotChangeBoostBypass", @"Could not change the boost bypass"))];
					}];
}

- (void)showChannelMainProfileTabActions {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Profile.WhichTabDoesThisChannelS", @"Which tab does this channel's profile open on?")
					  delegate:self
				   otherTitles:@[ TGL(@"ChatList.Search.FilterGlobalPosts", @"Posts"),
					   TGL(@"PeerInfo.PaneGifts", @"Gifts") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 98;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)applyChannelMainProfileTabAtIndex:(NSInteger)index {
	if (index != 0 && index != 1)
		return;
	NSString *tab = index == 1 ? @"gifts" : @"posts";
	NSString *previous = self.channelMainProfileTab;
	self.channelMainProfileTab = tab;
	[self rebuildManageRows];
	__weak typeof(self) weakSelf = self;
	[TGProfileService setGroup:self.chatId mainProfileTab:tab completion:^(BOOL ok) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			strongSelf.channelMainProfileTab = previous;
			[strongSelf rebuildManageRows];
			[strongSelf showToast:TGL(@"Toast.CouldNotChangeProfileTab", @"Could not change this channel's profile tab")];
			return;
		}
		[strongSelf showToast:TGL(@"PeerInfo.Tabs.SetMainTab.Succeed", @"Tab order changed.")];
	}];
}

- (void)pushUsernamesInto:(UINavigationController *)navigation {
	TGSupergroupUsernamesViewController *screen = [[TGSupergroupUsernamesViewController alloc]
		   initWithChatId:self.chatId
		  activeUsernames:self.activeUsernames
		disabledUsernames:self.disabledUsernames
		 editableUsername:self.editableUsername];
	__weak typeof(self) weakSelf = self;
	screen.onChanged = ^(NSArray *active, NSArray *disabled) {
		weakSelf.activeUsernames = active;
		weakSelf.disabledUsernames = disabled;
		[weakSelf rebuildManageRows];
	};
	[navigation pushViewController:screen animated:YES];
}

- (void)pushGroupMembersInto:(UINavigationController *)navigation
				 adminsFirst:(BOOL)adminsFirst {
	TGGroupMembersViewController *members =
		[[TGGroupMembersViewController alloc] init];
	members.chatId = self.chatId;
	members.initialMode = adminsFirst ? 1 : 0;
	__weak typeof(self) weakSelf = self;
	members.onChatUpgraded = ^(int64_t newChatId) {
		[weakSelf applyUpgradedChatId:newChatId];
	};
	[navigation pushViewController:members animated:YES];
}

- (void)pushInviteLinksInto:(UINavigationController *)navigation {
	TGInviteLinksViewController *links =
		[[TGInviteLinksViewController alloc] initWithChatId:self.chatId];
	[navigation pushViewController:links animated:YES];
}

- (void)pushGroupCallInto:(UINavigationController *)navigation {
	TGGroupCallViewController *screen = [[TGGroupCallViewController alloc]
		initWithChatId:self.chatId
		   groupCallId:self.videoChatGroupCallId
				 title:self.groupTitle];
	[navigation pushViewController:screen animated:YES];
}

- (void)pushChatEventsInto:(UINavigationController *)navigation {
	TGChatEventsViewController *events =
		[[TGChatEventsViewController alloc] initWithChatId:self.chatId];
	events.chatTitle = TGProfileText(self.name);
	[navigation pushViewController:events animated:YES];
}

- (void)pushStatisticsInto:(UINavigationController *)navigation {
	TGProfileStatisticsController *stats =
		[[TGProfileStatisticsController alloc] init];
	stats.chatId = self.chatId;
	stats.channelChat = self.channelChat;
	[navigation pushViewController:stats animated:YES];
}

- (void)pushBoostsInto:(UINavigationController *)navigation {
	TGProfileBoostsController *boosts =
		[[TGProfileBoostsController alloc] initWithStyle:UITableViewStyleGrouped];
	boosts.chatId = self.chatId;
	boosts.channel = self.channelChat;
	[navigation pushViewController:boosts animated:YES];
}

- (void)pushPermissionsInto:(UINavigationController *)navigation {
	TGProfilePermissionsController *permissions =
		[[TGProfilePermissionsController alloc] initWithStyle:UITableViewStyleGrouped];
	permissions.chatId = self.chatId;
	[navigation pushViewController:permissions animated:YES];
}

- (void)promptForChatTitle {
	UIAlertView *rename = [[TGAlertView alloc]
			initWithTitle:nil
				  message:(self.channelChat ? TGL(@"GroupInfo.ChannelListNamePlaceholder", @"Channel name") : TGL(@"GroupInfo.GroupNamePlaceholder", @"Group name"))
		delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	rename.tag = 73;
	if ([rename respondsToSelector:@selector(setAlertViewStyle:)]) {
		rename.alertViewStyle = UIAlertViewStylePlainTextInput;
		[rename textFieldAtIndex:0].text = TGProfileText(self.name) ?: @"";
	}
	[rename show];
}

- (void)showChatPhotoActions {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:@[ TGL(@"Common.ChoosePhoto", @"Choose Photo"),
					   TGL(@"UserInfo.RemoveCustomPhoto", @"Remove Photo") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 87;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)promptForChatDescription {
	UIAlertView *editor = [[TGAlertView alloc]
			initWithTitle:nil
				  message:TGL(@"Channel.Edit.AboutItem", @"Description")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	editor.tag = 91;
	if ([editor respondsToSelector:@selector(setAlertViewStyle:)]) {
		editor.alertViewStyle = UIAlertViewStylePlainTextInput;
		[editor textFieldAtIndex:0].text = self.chatDescription ?: @"";
	}
	[editor show];
}

- (void)promptForStickerSet {
	UIAlertView *editor = [[TGAlertView alloc]
			initWithTitle:nil
				  message:TGL(@"StickerPack.EditName.Title", @"Sticker set name")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	editor.tag = 90;
	if ([editor respondsToSelector:@selector(setAlertViewStyle:)])
		editor.alertViewStyle = UIAlertViewStylePlainTextInput;
	[editor show];
}

- (void)confirmUpgradeToSupergroup {
	UIAlertView *confirm = [UIAlertView alloc];
	confirm = [confirm initWithTitle:TGL(@"GroupInfo.UpgradeButton", @"Upgrade to Supergroup")
							 message:TGL(@"ConvertToSupergroup.HelpText", @"• New members can see the full message history\n• Deleted messages will disappear for all members\n• Admins can pin important messages\n• Creator can set a public link for the group")
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"Gift.Upgrade.Upgrade", @"Upgrade"), nil];
	confirm.tag = 88;
	[confirm show];
}

- (void)confirmConvertToBroadcast {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"BroadcastGroups.ConfirmationAlert.Text", @"Only administrators will be able to post. This cannot be undone.")
					  delegate:self
				   otherTitles:@[ TGL(@"GroupInfo.Permissions.BroadcastConvert", @"Convert to Broadcast Group") ]
			  destructiveIndex:0
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 89;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)confirmForumModeChange {
	if (self.forumChat) {
		[self setForumMode:NO];
		return;
	}
	UIAlertView *confirm = [UIAlertView alloc];
	confirm = [confirm initWithTitle:TGL(@"ChatList.Search.FilterTopics", @"Topics")
							 message:TGL(@"PeerInfo.Topics.EnableTopicsInfo", @"Members will be able to open separate topics instead of one message list. Only the owner may change this.")
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"PeerInfo.Topics.EnableTopics", @"Turn On"), nil];
	confirm.tag = 93;
	[confirm show];
}

- (void)showChatHistoryActions {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"GroupInfo.GroupHistory", @"Chat history for new members")
					  delegate:self
				   otherTitles:@[ TGL(@"GroupInfo.GroupHistoryVisible", @"Visible"),
					   TGL(@"GroupInfo.GroupHistoryHidden", @"Hidden") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 79;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)showSlowModeActions {
	NSArray *presets = [TGProfileService slowModePresets];
	NSMutableArray *titles = [NSMutableArray array];
	for (id preset in presets) {
		NSInteger seconds = [preset isKindOfClass:[NSNumber class]]
			? [preset integerValue]
			: 0;
		[titles addObject:[self slowModeTitle:seconds]];
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"GroupInfo.Permissions.SlowmodeHeader", @"Slow mode")
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 74;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)pickChatPhoto {
	if (![UIImagePickerController isSourceTypeAvailable:
				UIImagePickerControllerSourceTypePhotoLibrary]) {
		[self showToast:TGL(@"Toast.NoPhotoLibrary", @"No photo library")];
		return;
	}
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.allowsEditing = YES;
	picker.delegate = self;
	self.pickerMode = kPickerModeChatPhoto;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)pickPersonalPhotoSuggesting:(BOOL)suggest {
	if (![UIImagePickerController isSourceTypeAvailable:
				UIImagePickerControllerSourceTypePhotoLibrary]) {
		[self showToast:TGL(@"Toast.NoPhotoLibrary", @"No photo library")];
		return;
	}
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.allowsEditing = YES;
	picker.delegate = self;
	self.pickerMode = suggest ? kPickerModeSuggestPhoto : kPickerModePersonalPhoto;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)removeChatPhoto {
	__weak typeof(self) weakSelf = self;
	[TGProfileService removePhotoForChat:self.chatId completion:^(BOOL ok) {
		if (ok) {
			[weakSelf cancelAvatarDownload];
			weakSelf.avatarImage = nil;
			weakSelf.avatarIsPlaceholder = NO;
			[weakSelf showPlaceholderAvatarPlate];
		}
		[weakSelf showToast:(ok ? TGL(@"Toast.PhotoRemoved", @"Photo removed") : TGL(@"Toast.CouldNotRemovePhoto", @"Could not remove the photo"))];
	}];
}

- (void)removePersonalPhoto {
	if (!self.userId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGContactsService removePersonalPhotoForUser:self.userId completion:^(BOOL ok) {
		if (ok)
			weakSelf.personalPhoto = NO;
		[weakSelf showToast:(ok ? TGL(@"Toast.PhotoRemoved", @"Photo removed") : TGL(@"Toast.CouldNotRemovePhoto", @"Could not remove the photo"))];
	}];
}

- (void)upgradeToSupergroup {
	__weak typeof(self) weakSelf = self;
	[TGProfileService upgradeBasicGroupToSupergroup:self.chatId
										 completion:^(int64_t newChatId) {
											 if (!newChatId) {
												 [weakSelf showToast:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")];
												 return;
											 }
											 [weakSelf applyUpgradedChatId:newChatId];
											 [weakSelf showToast:TGL(@"Toast.GroupUpgraded", @"Group upgraded")];
										 }];
}

- (void)applyUpgradedChatId:(int64_t)newChatId {
	if (!newChatId)
		return;
	self.chatId = newChatId;
	self.managementLoaded = NO;
	self.manageFlagsKnown = NO;
	self.manageRows = @[];
	[self rebuildSections];
	[self.tableView reloadData];
	[self loadDetails];
	[self refreshStatus];
	if (self.onChatUpgraded)
		self.onChatUpgraded(newChatId);
}

- (void)convertToBroadcastGroup {
	__weak typeof(self) weakSelf = self;
	[TGProfileService convertGroupToBroadcastGroup:self.chatId completion:^(BOOL ok) {
		if (ok)
			[weakSelf loadManagement];
		[weakSelf showToast:(ok ? TGL(@"Toast.ConvertedToBroadcastGroup", @"Converted to a broadcast group")
								: TGL(@"Toast.CouldNotConvertGroup", @"Could not convert this group"))];
	}];
}

- (void)setStickerSetNamed:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	[TGProfileService setGroup:self.chatId
				stickerSetName:(name.length ? name : nil)
		completion:^(BOOL ok) {
			if (ok) {
				[weakSelf showToast:(name.length ? TGL(@"Toast.GroupStickersSet", @"Group stickers set")
												 : TGL(@"Toast.GroupStickersRemoved", @"Group stickers removed"))];
				return;
			}
			[weakSelf showToast:TGL(@"Channel.Stickers.NotFound", @"No such sticker set found")];
		}];
}

- (void)saveChatDescription:(NSString *)description {
	__weak typeof(self) weakSelf = self;
	[TGProfileService setDescription:(description ?: @"") forChat:self.chatId completion:^(BOOL ok) {
		if (ok) {
			weakSelf.chatDescription = description.length ? description : nil;
			if (description.length) {
				[weakSelf setDetail:description forLabel:@"about"];
			} else {
				NSMutableArray *kept = [NSMutableArray array];
				for (NSArray *pair in weakSelf.details) {
					if (pair.count > 0 && [pair[0] isEqualToString:@"about"])
						continue;
					[kept addObject:pair];
				}
				weakSelf.details = kept;
				[weakSelf.tableView reloadData];
			}
			[weakSelf rebuildManageRows];
		}
		[weakSelf showToast:(ok ? TGL(@"Toast.DescriptionSaved", @"Description saved")
								: TGL(@"Toast.CouldNotSaveDescription", @"Could not save the description"))];
	}];
}

- (void)reportUser {
	if (!self.userId)
		return;
	if (self.chatId) {
		self.reportChatId = self.chatId;
		[self reportGroupWithOption:nil text:nil];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGContactsService privateChatWithUser:self.userId completion:^(int64_t chatId) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!chatId) {
			[strongSelf showToast:TGL(@"Toast.CouldNotOpenReport", @"Could not open the report")];
			return;
		}
		strongSelf.reportChatId = chatId;
		[strongSelf reportGroupWithOption:nil text:nil];
	}];
}

- (void)reportGroupWithOption:(NSString *)optionId text:(NSString *)text {
	int64_t target = self.reportChatId ? self.reportChatId : self.chatId;
	if (!target) {
		[self showToast:TGL(@"Toast.CouldNotSendReport", @"Could not send the report")];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGProfileService reportGroup:target optionId:optionId text:text
					   completion:^(NSString *status, NSString *title,
						   NSArray *options, NSString *newOptionId, BOOL optional) {
						   if ([status isEqualToString:@"ok"]) {
							   [weakSelf showToast:TGL(@"Report.Succeed", @"Telegram moderators will study your report. Thank you!")];
							   return;
						   }
						   if ([status isEqualToString:@"options"]) {
							   [weakSelf showReportOptionsSheet:options title:title];
							   return;
						   }
						   if ([status isEqualToString:@"text"]) {
							   [weakSelf promptForReportTextWithTitle:title optionId:(newOptionId ?: optionId) optional:optional];
							   return;
						   }
						   if ([status isEqualToString:@"messagesRequired"]) {
							   [weakSelf showToast:TGL(@"Report.SelectMessagesInChat", @"Open the chat and select the messages you want to report, then use Report from there.")];
							   return;
						   }
						   [weakSelf showToast:TGL(@"Toast.CouldNotSendReport", @"Could not send the report")];
					   }];
}

- (void)showReportOptionsSheet:(NSArray *)options title:(NSString *)title {
	NSMutableArray *usable = [NSMutableArray array];
	if (![options isKindOfClass:[NSArray class]])
		options = @[];
	for (id option in options) {
		if (![option isKindOfClass:[NSDictionary class]])
			continue;
		if (TGProfileText(option[@"id"]) && TGProfileText(option[@"text"]))
			[usable addObject:option];
	}
	if (!usable.count) {
		[self showToast:TGL(@"Toast.CouldNotSendReport", @"Could not send the report")];
		return;
	}
	self.reportOptions = usable;
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *option in usable)
		[titles addObject:TGProfileText(option[@"text"])];
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:(TGProfileText(title) ?: TGL(@"ReportPeer.Report", @"Report"))
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 85;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)promptForReportTextWithTitle:(NSString *)title optionId:(NSString *)optionId optional:(BOOL)optional {
	self.reportOptionId = optionId;
	self.reportTextOptional = optional;
	NSString *message = TGProfileText(title) ?: TGL(@"ReportPeer.ReasonOther.Placeholder", @"Describe the problem");
	UIAlertView *alert = optional
		? [[TGAlertView alloc] initWithTitle:nil
									  message:message
									 delegate:self
							cancelButtonTitle:nil
							otherButtonTitles:TGL(@"PhotoEditor.Skip", @"Skip"), TGL(@"MediaPicker.Send", @"Send"), nil]
		: [[TGAlertView alloc] initWithTitle:nil
									  message:message
									 delegate:self
							cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
							otherButtonTitles:TGL(@"MediaPicker.Send", @"Send"), nil];
	alert.tag = 86;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert show];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.pickerMode = kPickerModeChatPhoto;
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)writeJpegOf:(UIImage *)image maxSide:(CGFloat)maxSide named:(NSString *)name {
	CGFloat side = MAX(image.size.width, image.size.height);
	UIImage *scaled = image;
	if (side > maxSide || image.imageOrientation != UIImageOrientationUp) {
		CGFloat factor = MIN(1.0f, maxSide / side);
		CGSize target = CGSizeMake(floorf(image.size.width * factor),
			floorf(image.size.height * factor));
		UIGraphicsBeginImageContextWithOptions(target, YES, 1.0f);
		[image drawInRect:CGRectMake(0, 0, target.width, target.height)];
		scaled = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	}
	NSData *data = UIImageJPEGRepresentation(scaled, 0.87f);
	if (!data.length)
		return nil;
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	return [data writeToFile:path atomically:YES] ? path : nil;
}

- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info {
	NSInteger mode = self.pickerMode;
	self.pickerMode = kPickerModeChatPhoto;
	[self dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerEditedImage]
		?: info[UIImagePickerControllerOriginalImage];
	if (![image isKindOfClass:[UIImage class]])
		return;

	if (mode == kPickerModePersonalPhoto || mode == kPickerModeSuggestPhoto) {
		[self applyPickedPersonalPhoto:image
							   suggest:(mode == kPickerModeSuggestPhoto)];
		return;
	}

	if (mode == kPickerModeStory) {
		[self applyPickedStoryPhoto:image];
		return;
	}

	[self applyPickedChatPhoto:image];
}

- (void)applyPickedPersonalPhoto:(UIImage *)image suggest:(BOOL)suggest {
	if (!self.userId)
		return;
	NSString *personalPath = [self writeJpegOf:image maxSide:640.0f
										 named:@"personal-photo.jpg"];
	if (!personalPath) {
		[self showToast:TGL(@"Toast.CouldNotPreparePhoto", @"Could not prepare the photo")];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGContactsService setPersonalPhotoAtPath:personalPath
									  forUser:self.userId
									  suggest:suggest
								   completion:^(BOOL ok) {
									   if (ok && !suggest) {
										   weakSelf.personalPhoto = YES;
										   UIImage *preview = TGDecodeSquareThumbnail(personalPath,
											   kProfileAvatarSide);
										   if (preview) {
											   [weakSelf cancelAvatarDownload];
											   weakSelf.avatarImage = preview;
											   weakSelf.avatarIsPlaceholder = NO;
											   [weakSelf setAvatarViewImage:preview crossfade:YES];
										   }
									   }
									   if (ok)
										   [weakSelf showToast:(suggest ? TGL(@"Toast.PhotoSuggested", @"Photo suggested") : TGL(@"Toast.PhotoSet", @"Photo set"))];
									   else
										   [weakSelf showToast:TGL(@"Toast.CouldNotSetPhoto", @"Could not set the photo")];
								   }];
}

- (void)applyPickedStoryPhoto:(UIImage *)image {
	self.storyPath = [self writeJpegOf:image maxSide:720.0f named:@"story.jpg"];
	if (!self.storyPath) {
		[self showToast:TGL(@"Toast.CouldNotPreparePhoto", @"Could not prepare the photo")];
		return;
	}
	[self askStoryPrivacy];
}

- (void)applyPickedChatPhoto:(UIImage *)image {
	if (!self.chatId)
		return;
	NSString *path = [self writeJpegOf:image maxSide:640.0f named:@"chat-photo.jpg"];
	if (!path)
		return;

	__weak typeof(self) weakSelf = self;
	[TGProfileService setPhotoAtPath:path forChat:self.chatId completion:^(BOOL ok) {
		[weakSelf showToast:(ok ? TGL(@"Toast.PhotoUpdated", @"Photo updated") : TGL(@"Toast.CouldNotSetPhoto", @"Could not set the photo"))];
		if (!ok)
			return;
		UIImage *preview = TGDecodeSquareThumbnail(path, kProfileAvatarSide);
		if (!preview)
			return;
		[weakSelf cancelAvatarDownload];
		weakSelf.avatarImage = preview;
		weakSelf.avatarIsPlaceholder = NO;
		[weakSelf setAvatarViewImage:preview crossfade:YES];
	}];
}

- (void)openStoriesList {
	if (!self.userId || !self.navigationController)
		return;
	NSDictionary *me = [TGContactsService me];
	int64_t myId = [me isKindOfClass:[NSDictionary class]]
		? TGProfileInt64(me[@"id"])
		: 0;
	if (myId && myId == self.userId) {
		[TGStoriesViewController pushMyStoriesFrom:self];
		return;
	}
	[TGStoriesViewController pushStoriesOfChat:self.userId
										  name:TGProfileText(self.name) ?: TGL(@"PeerInfo.PaneStories", @"Stories")
										  from:self];
}

- (void)openSecretChatInfo {
	if (!self.chatId || !self.navigationController)
		return;
	UIViewController *info = [TGContactsViewController
		secretChatInfoForChat:self.chatId
					   userId:self.userId
						 name:TGProfileText(self.name) ?: @""];
	[self.navigationController pushViewController:info animated:YES];
}

- (void)openChatBackground {
	if (!self.chatId || !self.navigationController)
		return;
	TGChatBackgroundViewController *screen = [[TGChatBackgroundViewController alloc]
		initWithChatId:self.chatId
				 title:TGProfileText(self.name) ?: @""];
	[self.navigationController pushViewController:screen animated:YES];
}

- (void)openChatTheme {
	if (!self.chatId || !self.navigationController)
		return;
	TGChatThemeViewController *screen = [[TGChatThemeViewController alloc]
		initWithChatId:self.chatId
				 title:TGProfileText(self.name) ?: @""];
	[self.navigationController pushViewController:screen animated:YES];
}

- (void)startSecretChat {
	if (!self.userId)
		return;
	UINavigationController *navigation = self.navigationController;
	NSString *name = TGProfileText(self.name) ?: @"";
	__weak typeof(self) weakSelf = self;
	[TGContactsService createSecretChatWithUser:self.userId
									 completion:^(NSDictionary *info) {
										 int64_t chatId = [info isKindOfClass:[NSDictionary class]]
											 ? TGProfileInt64(info[@"chatId"])
											 : 0;
										 if (!chatId) {
											 [weakSelf showToast:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")];
											 return;
										 }
										 TGChatViewController *chat = [[TGChatViewController alloc] init];
										 chat.chatId = chatId;
										 chat.chatTitle = name;
										 [navigation pushViewController:chat animated:YES];
									 }];
}

- (void)loadDetails {
	if (self.chatId)
		self.muted = [TGProfileService isChatMuted:self.chatId];

	[self loadManagement];

	if (!self.userId && self.chatId) {
		[self loadGroupDetailRows];
		return;
	}

	if (!self.userId)
		return;

	[self loadUserDetailRows];
}

- (void)loadGroupDetailRows {
	__weak typeof(self) weakSelf = self;
	[TGProfileService membersOfChat:self.chatId completion:^(NSArray *members) {
		weakSelf.members = [members isKindOfClass:[NSArray class]] ? members : @[];
		[weakSelf rebuildSections];
		[weakSelf.tableView reloadData];
	}];
	[TGProfileService chatProfile:self.chatId completion:^(NSDictionary *info) {
		if (![info isKindOfClass:[NSDictionary class]])
			return;
		NSMutableArray *rows = [NSMutableArray array];
		NSString *about = TGProfileText(info[@"description"]);
		weakSelf.chatDescription = about;
		if (about)
			[rows addObject:@[ @"about", about ]];
		NSString *members = TGProfileNumberText(info[@"members"]);
		if (members.integerValue > 0)
			[rows addObject:@[ @"members", members ]];
		NSString *admins = TGProfileNumberText(info[@"admins"]);
		if (admins.integerValue > 0)
			[rows addObject:@[ @"admins", admins ]];
		NSString *link = TGProfileText(info[@"inviteLink"]);
		if (link) {
			weakSelf.primaryInviteLink = link;
			[rows addObject:@[ @"invite link", link ]];
		}
		weakSelf.details = rows;
		[weakSelf.tableView reloadData];
		[weakSelf rebuildManageRows];
	}];
}

- (void)loadUserDetailRows {
	__weak typeof(self) weakSelf = self;
	[TGProfileService userInfo:self.userId completion:^(NSDictionary *user) {
		if (![user isKindOfClass:[NSDictionary class]])
			return;
		NSMutableArray *rows = [NSMutableArray array];
		[weakSelf appendPhoneRowTo:rows fromUser:user];
		weakSelf.firstName = TGProfileText(user[@"first_name"]);
		weakSelf.lastName = TGProfileText(user[@"last_name"]);
		weakSelf.contact = TGProfileBool(user[@"is_contact"]) || TGProfileBool(user[@"is_mutual_contact"]);
		[weakSelf applyFallbackNameFromUser];
		[weakSelf appendUsernameRowTo:rows fromUser:user];
		if (TGProfileBool(user[@"is_premium"]))
			[rows addObject:@[ @"subscription", TGL(@"Premium.Title", @"Telegram Premium") ]];
		weakSelf.baseDetailRows = rows;
		[weakSelf rebuildDetailRows];

		[weakSelf loadFullUserProfile];
		[weakSelf loadNoteAndCommonGroups];
		[weakSelf loadContactFlags];

		[weakSelf loadAvatarFromUserRecord:user];
	}];
}

- (void)appendPhoneRowTo:(NSMutableArray *)rows fromUser:(NSDictionary *)user {
	NSString *phone = TGProfileText(user[@"phone_number"]);
	if (phone) {
		[rows addObject:@[ @"mobile", [@"+" stringByAppendingString:phone] ]];
		self.phoneNumber = phone;
	} else {
		[rows addObject:@[ @"mobile", TGL(@"ContactInfo.PhoneNumberHidden", @"Hidden"), @YES ]];
		self.phoneNumber = nil;
	}
}

- (void)applyFallbackNameFromUser {
	if (TGProfileText(self.name))
		return;
	NSMutableArray *parts = [NSMutableArray array];
	if (self.firstName)
		[parts addObject:self.firstName];
	if (self.lastName)
		[parts addObject:self.lastName];
	if (!parts.count)
		return;
	self.name = [parts componentsJoinedByString:@" "];
	self.nameLabel.text = self.name;
	[self layoutNameBadge];
	if (!self.avatarImage && !self.avatarIsPlaceholder)
		[self showPlaceholderAvatarPlate];
}

- (void)appendUsernameRowTo:(NSMutableArray *)rows fromUser:(NSDictionary *)user {
	NSString *username = nil;
	id usernames = user[@"usernames"];
	NSArray *collectible = nil;
	if ([usernames isKindOfClass:[NSDictionary class]]) {
		id active = usernames[@"active_usernames"];
		if ([active isKindOfClass:[NSArray class]] && [active count])
			username = TGProfileText([active objectAtIndex:0]);
		if ([usernames[@"collectible_usernames"] isKindOfClass:[NSArray class]])
			collectible = usernames[@"collectible_usernames"];
	}
	if (!username)
		username = TGProfileText(user[@"username"]);
	if (username) {
		[rows addObject:@[ @"username", [@"@" stringByAppendingString:username] ]];
		self.usernameIsCollectible = [collectible containsObject:username];
		self.collectibleUsername = self.usernameIsCollectible ? username : nil;
	}
}

- (void)loadFullUserProfile {
	__weak typeof(self) weakSelf = self;
	[TGProfileService userProfile:self.userId completion:^(NSDictionary *info) {
		if (![info isKindOfClass:[NSDictionary class]])
			return;
		weakSelf.profileBio = TGProfileText(info[@"bio"]);
		weakSelf.profileBioEntities = [info[@"bioEntities"] isKindOfClass:[NSArray class]]
			? info[@"bioEntities"]
			: @[];
		weakSelf.profileBirthdayText = TGProfileText(info[@"birthday"]);
		weakSelf.profileCommonGroupCount =
			TGProfileNumberText(info[@"commonGroups"]).integerValue;
		weakSelf.personalPhoto = TGProfileBool(info[@"hasPersonalPhoto"]);
		weakSelf.canCall = TGProfileBool(info[@"canCall"]);
		weakSelf.canVideoCall = TGProfileBool(info[@"canVideoCall"]);
		weakSelf.fullProfileLoaded = YES;
		[weakSelf rebuildDetailRows];
	}];
}

- (void)loadAvatarFromUserRecord:(NSDictionary *)user {
	id photo = user[@"profile_photo"];
	id small = [photo isKindOfClass:[NSDictionary class]] ? photo[@"small"] : nil;
	id photoId = [small isKindOfClass:[NSDictionary class]] ? small[@"id"] : nil;
	if (self.avatarImage)
		return;
	if ([photo isKindOfClass:[NSDictionary class]])
		[self showPlaceholderAvatarFromData:
				[TGFileDownloadService minithumbnailData:photo[@"minithumbnail"]]];
	if ([photoId isKindOfClass:[NSNumber class]])
		[self loadAvatarFile:[photoId longLongValue]];
}

- (void)rebuildDetailRows {
	NSMutableArray *more = [(self.baseDetailRows ?: @[]) mutableCopy];
	if (self.restrictionReason.length)
		[more insertObject:@[ @"restricted", self.restrictionReason ] atIndex:0];
	NSString *bio = self.profileBio;
	if (bio)
		[more insertObject:@[ @"about", bio ] atIndex:MIN((NSUInteger)2, more.count)];
	NSString *birthday = self.profileBirthdayText ?: self.birthdayDetail;
	if (birthday)
		[more addObject:@[ @"birthday", birthday ]];
	if (self.emojiStatusDetail.length)
		[more addObject:@[ @"status", self.emojiStatusDetail ]];
	if (self.contactRelation.length)
		[more addObject:@[ @"contact", self.contactRelation ]];
	if (self.noteLoaded && (self.contact || self.profileNote.length))
		[more addObject:@[ @"note", self.profileNote.length ? self.profileNote : TGL(@"Profile.AddNote", @"Add note") ]];
	NSInteger common = self.commonGroupsLoaded
		? (NSInteger)self.commonGroups.count
		: (self.fullProfileLoaded ? self.profileCommonGroupCount : 0);
	if (common > 0)
		[more addObject:@[ @"groups in common",
			[NSString stringWithFormat:@"%ld", (long)common] ]];
	self.details = more;
	[self refreshProfileDetailPresenter];
	[self actionItems];
	[self rebuildSections];
	[self.tableView reloadData];
}

- (void)loadNoteAndCommonGroups {
	if (!self.userId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGContactsService noteForUser:self.userId completion:^(NSString *note) {
		weakSelf.noteLoaded = YES;
		weakSelf.profileNote = TGProfileText(note);
		[weakSelf rebuildDetailRows];
	}];
	[TGContactsService groupsInCommonWithUser:self.userId completion:^(NSArray *chats) {
		weakSelf.commonGroups = [chats isKindOfClass:[NSArray class]] ? chats : @[];
		weakSelf.commonGroupsLoaded = YES;
		[weakSelf rebuildDetailRows];
	}];
}

- (void)editNote {
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:nil
				  message:TGL(@"PeerInfo.AddNotesPlaceholder", @"Note about this contact")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	alert.tag = 81;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].text = self.profileNote ?: @"";
	}
	[alert show];
}

- (void)openCommonGroups {
	if (!self.userId || !self.navigationController)
		return;
	TGProfileCommonGroupsController *list =
		[[TGProfileCommonGroupsController alloc] initWithStyle:UITableViewStylePlain];
	list.userId = self.userId;
	list.chats = self.commonGroups;
	[self.navigationController pushViewController:list animated:YES];
}

- (void)loadMedia {
	__weak typeof(self) weakSelf = self;
	if (self.userId) {
		[TGProfileService giftsForUser:self.userId completion:^(NSArray *gifts) {
			weakSelf.gifts = [gifts isKindOfClass:[NSArray class]] ? gifts : @[];
			[weakSelf.tableView reloadData];
		}];
		[TGContactsService isUserBlocked:self.userId completion:^(BOOL blocked) {
			weakSelf.blocked = blocked;
		}];
	}

	if (!self.chatId) {
		self.photosLoaded = YES;
		self.filesLoaded = YES;
		[self.tableView reloadData];
		return;
	}

	[TGProfileService messageCountInChat:self.chatId
								  filter:@"searchMessagesFilterPhotoAndVideo"
							  completion:^(NSInteger count) {
								  weakSelf.photoCount = MAX((NSInteger)0, count);
								  weakSelf.photosLoaded = YES;
								  [weakSelf.tableView reloadData];
							  }];
	[TGProfileService messageCountInChat:self.chatId
								  filter:@"searchMessagesFilterDocument"
							  completion:^(NSInteger count) {
								  weakSelf.fileCount = MAX((NSInteger)0, count);
								  weakSelf.filesLoaded = YES;
								  [weakSelf.tableView reloadData];
							  }];
}

- (void)showToast:(NSString *)text {
	if (!text.length || !self.isViewLoaded)
		return;
	UIView *host = self.navigationController.view ?: self.view;
	UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 34)];
	toast.center = CGPointMake(host.bounds.size.width / 2,
		host.bounds.size.height - 70);
	toast.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	toast.text = text;
	toast.textAlignment = NSTextAlignmentCenter;
	toast.font = [UIFont systemFontOfSize:14];
	toast.textColor = [UIColor whiteColor];
	toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75f];
	toast.layer.cornerRadius = 6;
	toast.clipsToBounds = YES;
	[host addSubview:toast];
	[UIView animateWithDuration:0.3 delay:1.0 options:0
		animations:^{ toast.alpha = 0; }
		completion:^(BOOL done) { [toast removeFromSuperview]; }];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (self.chatId) {
		BOOL muted = [TGProfileService isChatMuted:self.chatId];
		if (muted != self.muted) {
			self.muted = muted;
			[self updateMuteButton];
		}
	}
	if (self.appearedOnce && self.chatId && !self.userId)
		[self loadManagement];
	self.appearedOnce = YES;
	[self refreshStatus];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[TGPopupMenu dismiss];
	[self.songPlayer stop];
	self.songPlayer = nil;
	self.songPlayerFileId = 0;
}

@end
