#import "TGCountAfterRead.h"
#import "TGProfileViewController.h"
#import "TGFriendlyError.h"
#import "TGProfileViewControllerInternal.h"
#import "TGProfileButtonsCell.h"
#import "TGProfileRedButtonCell.h"
#import "TGProfilePermissionsController.h"
#import "TGProfileStatisticsController.h"
#import "TGProfileBoostsController.h"
#import "TGProfileCommonGroupsController.h"
#import "TGProfileLinkJoinsController.h"
#import "TGSimilarChannelsViewController.h"
#import "TGLocalization.h"
#import "TGProfileService.h"
#import "TGSettingsService.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGColourViewController.h"
#import "TGEmojiStatusPickerViewController.h"
#import "TGChatViewController.h"
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

@implementation TGProfileViewController (Management)

- (BOOL)hasRight:(NSString *)right {
	return [[self.myRights objectForKey:right] boolValue];
}

- (void)refreshDerivedManagementRights {
	self.canEditChat = [self hasRight:@"canChangeInfo"];
}

- (void)loadManagement {
	if (self.userId || !self.chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGProfileService myAdministratorRightsForChat:self.chatId
										 completion:^(NSDictionary *rights) {
											 TGProfileViewController *strongSelf = weakSelf;
											 if (!strongSelf)
												 return;
											 if ([rights isKindOfClass:[NSDictionary class]])
												 strongSelf.myRights = rights;
											 [strongSelf refreshDerivedManagementRights];
											 [strongSelf rebuildManageRows];
										 }];
	[TGProfileService groupInfoForChat:self.chatId completion:^(NSDictionary *info) {
		if (![info isKindOfClass:[NSDictionary class]]) {
			if (!weakSelf.managementLoaded) {
				weakSelf.managementLoaded = YES;
				weakSelf.canListMembers = !weakSelf.channelChat;
			}
			[weakSelf rebuildManageRows];
			return;
		}
		NSString *status = TGProfileText(info[@"myStatus"]) ?: @"";
		BOOL admin = [status isEqualToString:@"creator"] || [status isEqualToString:@"administrator"];
		weakSelf.chatAdmin = admin;
		weakSelf.chatOwner = [status isEqualToString:@"creator"];
		if (!admin) {
			weakSelf.adminCount = 0;
			weakSelf.inviteLinkCount = 0;
			weakSelf.pendingJoinRequests = 0;
			weakSelf.manageFlagsKnown = NO;
			weakSelf.signaturesKnown = NO;
			weakSelf.discussionKnown = NO;
			weakSelf.canGetStatistics = NO;
			weakSelf.canHideMembers = NO;
			weakSelf.canToggleAntiSpam = NO;
		}
		weakSelf.unrestrictBoostCount =
			[info[@"unrestrictBoostCount"] isKindOfClass:[NSNumber class]]
			? [info[@"unrestrictBoostCount"] integerValue]
			: 0;
		weakSelf.automaticTranslation = TGProfileBool(info[@"hasAutomaticTranslation"]);
		weakSelf.channelMainProfileTab = TGProfileText(info[@"mainProfileTab"]) ?: @"";
		weakSelf.videoChatGroupCallId = [info[@"videoChatGroupCallId"] intValue];
		weakSelf.videoChatHasParticipants = TGProfileBool(info[@"videoChatHasParticipants"]);
		weakSelf.activeUsernames = [info[@"activeUsernames"] isKindOfClass:[NSArray class]]
			? info[@"activeUsernames"]
			: @[];
		weakSelf.disabledUsernames = [info[@"disabledUsernames"] isKindOfClass:[NSArray class]]
			? info[@"disabledUsernames"]
			: @[];
		weakSelf.editableUsername = TGProfileText(info[@"editableUsername"]) ?: @"";
		[weakSelf refreshDerivedManagementRights];
		weakSelf.channelChat = TGProfileBool(info[@"isChannel"]);
		weakSelf.supergroupChat = TGProfileBool(info[@"isSupergroup"]);
		weakSelf.forumChat = TGProfileBool(info[@"isForum"]);
		weakSelf.slowModeDelay = [info[@"slowModeDelay"] isKindOfClass:[NSNumber class]]
			? [info[@"slowModeDelay"] integerValue]
			: 0;
		weakSelf.hasRestrictedSendPermissions = TGProfileBool(info[@"hasRestrictedSendPermissions"]);

		weakSelf.historyAvailable = TGProfileBool(info[@"isAllHistoryAvailable"]);
		weakSelf.hiddenMembers = TGProfileBool(info[@"hasHiddenMembers"]);
		weakSelf.canHideMembers = TGProfileBool(info[@"canHideMembers"]);
		weakSelf.canSetStickerSet = TGProfileBool(info[@"canSetStickerSet"]);
		weakSelf.antiSpam = TGProfileBool(info[@"hasAggressiveAntiSpam"]);
		weakSelf.canToggleAntiSpam =
			TGProfileBool(info[@"canToggleAggressiveAntiSpam"]);
		weakSelf.directMessagesGroup = TGProfileBool(info[@"hasDirectMessagesGroup"]);
		weakSelf.directMessagesStarCount =
			[info[@"directMessagesStarCount"] integerValue];
		weakSelf.directMessagesChatId = [info[@"directMessagesChatId"] longLongValue];
		weakSelf.pendingJoinRequests =
			[info[@"pendingJoinRequests"] isKindOfClass:[NSNumber class]]
			? [info[@"pendingJoinRequests"] integerValue]
			: 0;

		weakSelf.groupTitle = TGProfileText(info[@"title"]) ?: @"";
		weakSelf.canListMembers = TGProfileBool(info[@"canGetMembers"]) || admin || !weakSelf.channelChat;
		weakSelf.managementLoaded = YES;
		weakSelf.restrictionReason = TGProfileText(info[@"restrictionReason"]) ?: @"";
		[weakSelf rebuildManageRows];
		[weakSelf rebuildDetailRows];
		[weakSelf loadChannelExtras];
		[weakSelf loadForumTopicCount];
	}];
}

- (void)rebuildManageRows {
	if (!self.managementLoaded)
		return;
	BOOL admin = self.chatAdmin;
	NSMutableArray *rows = [NSMutableArray array];
	[self appendVideoChatManageRowsTo:rows];
	[self appendMembershipManageRowsTo:rows admin:admin];
	[self appendChatEditingManageRowsTo:rows];
	[self appendChannelManageRowsTo:rows admin:admin];
	[self appendGroupManageRowsTo:rows admin:admin];
	[self appendFlagManageRowsTo:rows admin:admin];
	if (self.canGetStatistics)
		[rows addObject:@[ TGL(@"Stats.Statistics", @"Statistics"), @"stats", @"" ]];
	if (self.boostsKnown)
		[rows addObject:@[ TGL(@"Stats.Boosts", @"Boosts"), @"boosts",
			[NSString stringWithFormat:TGL(@"ChannelBoost.Level", @"Level %@"), [@(self.boostLevel) stringValue]] ]];
	self.manageRows = rows;
	[self rebuildSections];
	[self.tableView reloadData];
}

- (void)appendVideoChatManageRowsTo:(NSMutableArray *)rows {
	if (self.videoChatGroupCallId <= 0 || !self.videoChatHasParticipants)
		return;
	[rows addObject:@[ TGL(@"VoiceChat.Title", @"Video Chat"), @"videochat",
		self.videoChatHasParticipants ? TGL(@"GroupInfo.VideoChatActive", @"Active") : TGL(@"GroupInfo.VideoChatLive", @"Live") ]];
}

- (void)appendMembershipManageRowsTo:(NSMutableArray *)rows admin:(BOOL)admin {
	if (self.canListMembers)
		[rows addObject:@[ TGL(@"Compose.ChannelMembers", @"Members"), @"members",
			(self.memberCount > 0
					? [NSString stringWithFormat:@"%ld",
						  (long)self.memberCount]
					: @"") ]];
	if (admin) {
		[rows addObject:@[ TGL(@"GroupInfo.Administrators", @"Administrators"), @"admins",
			(self.adminCount > 0
					? [NSString stringWithFormat:@"%ld",
						  (long)self.adminCount]
					: @"") ]];
		if ([self hasRight:@"canInviteUsers"])
			[rows addObject:@[ TGL(@"GroupInfo.InviteLinks", @"Invite Links"), @"links",
				(self.inviteLinkCount > 0
						? [NSString stringWithFormat:@"%ld",
							  (long)self.inviteLinkCount]
						: @"") ]];
		[rows addObject:@[ TGL(@"Group.Info.AdminLog", @"Recent Actions"), @"events", @"" ]];
	}
}

- (void)appendChatEditingManageRowsTo:(NSMutableArray *)rows {
	if (!self.canEditChat)
		return;
	[rows addObject:@[ (self.channelChat ? TGL(@"GroupInfo.ChannelListNamePlaceholder", @"Channel name") : TGL(@"GroupInfo.GroupNamePlaceholder", @"Group name")),
		@"title", self.groupTitle ?: @"" ]];
	[rows addObject:@[ TGL(@"Channel.Edit.AboutItem", @"Description"), @"description",
		(self.chatDescription.length ? self.chatDescription : @"") ]];
	[rows addObject:@[ TGL(@"Settings.SetPhoto", @"Set Photo"), @"photo", @"" ]];
}

- (void)appendChannelManageRowsTo:(NSMutableArray *)rows admin:(BOOL)admin {
	if (self.channelChat && self.signaturesKnown && [self hasRight:@"canChangeInfo"]) {
		[rows addObject:@[ TGL(@"Channel.SignMessages", @"Sign Messages"), @"signatures",
			(self.signMessages ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off")) ]];
		if (self.signMessages)
			[rows addObject:@[ TGL(@"Channel.ShowAuthors", @"Show Authors' Profiles"), @"authors",
				(self.showAuthorProfiles ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off")) ]];
	}
	if (admin && self.channelChat && self.discussionKnown)
		[rows addObject:@[ TGL(@"VoiceChat.DiscussionGroup", @"Discussion group"), @"discussion",
			(self.discussionChatId ? (self.discussionTitle ?: TGL(@"Conversation.InfoGroup", @"Group"))
								   : TGL(@"PrivacySettings.PasscodeOff", @"Off")) ]];
	if (self.chatOwner && self.channelChat && self.managementLoaded)
		[rows addObject:@[ TGL(@"Chat.Monoforum.Subtitle", @"Direct Messages"), @"directmessages",
			(self.directMessagesGroup
					? (self.directMessagesStarCount > 0
							  ? TGLPlural(@"Privacy.Messages.Stars", self.directMessagesStarCount, @"%@ Star", @"%@ Stars")
							  : TGL(@"Chat.PostSuggestion.PriceFree", @"Free"))
					: TGL(@"PeerInfo.AllowChannelMessages.Off", @"Off")) ]];
	if (admin && self.channelChat && self.managementLoaded)
		[rows addObject:@[ TGL(@"Channel.Info.AutoTranslate", @"Auto-Translate Messages"), @"autotranslate",
			(self.automaticTranslation ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off")) ]];
	if (admin && self.channelChat && self.canEditChat && self.managementLoaded)
		[rows addObject:@[ TGL(@"GroupInfo.ProfileOpensOn", @"Profile Opens On"), @"channelprofiletab",
			([self.channelMainProfileTab isEqualToString:@"gifts"]
					? TGL(@"PeerInfo.PaneGifts", @"Gifts")
					: TGL(@"ChatList.Search.FilterGlobalPosts", @"Posts")) ]];
	if (admin && self.channelChat && self.canEditChat) {
		[rows addObject:@[ TGL(@"NameColor.Title.Account", @"Your Name Color"), @"chatcolour", @"" ]];
		[rows addObject:@[ TGL(@"Premium.EmojiStatus", @"Emoji Status"), @"chatemojistatus", @"" ]];
	}
	[self appendUsernamesManageRowTo:rows];
}

- (void)appendUsernamesManageRowTo:(NSMutableArray *)rows {
	if (!(self.chatOwner && self.supergroupChat))
		return;
	NSInteger count = self.activeUsernames.count + self.disabledUsernames.count;
	[rows addObject:@[ TGL(@"Settings.Usernames", @"Usernames"), @"usernames",
		(count > 0 ? [NSString stringWithFormat:@"%ld", (long)count] : @"") ]];
}

- (void)appendGroupManageRowsTo:(NSMutableArray *)rows admin:(BOOL)admin {
	if (!(admin && !self.channelChat))
		return;
	if ([self hasRight:@"canRestrictMembers"])
		[rows addObject:@[ TGL(@"GroupInfo.Permissions", @"Permissions"), @"permissions", @"" ]];
	if (self.supergroupChat) {
		if ([self hasRight:@"canRestrictMembers"])
			[rows addObject:@[ TGL(@"GroupInfo.Permissions.SlowmodeHeader", @"Slow mode"), @"slowmode",
				[self slowModeTitle:self.slowModeDelay] ]];
		if (self.slowModeDelay > 0 || self.hasRestrictedSendPermissions || self.unrestrictBoostCount > 0)
			[rows addObject:@[ TGL(@"GroupInfo.Permissions.DontRestrictBoosters", @"Boost-Level Bypass"), @"unrestrictboost",
				(self.unrestrictBoostCount > 0
						? [NSString stringWithFormat:@"%ld",
							  (long)self.unrestrictBoostCount]
						: TGL(@"PrivacySettings.PasscodeOff", @"Off")) ]];
		if (self.canSetStickerSet)
			[rows addObject:@[ TGL(@"Stickers.GroupStickers", @"Group Stickers"), @"stickers", @"" ]];
		if (self.chatOwner)
			[rows addObject:@[ TGL(@"ChatList.Search.FilterTopics", @"Topics"), @"topics", [self forumRowValue] ]];
		[self appendUsernamesManageRowTo:rows];
		[rows addObject:@[ TGL(@"GroupInfo.Permissions.BroadcastConvert", @"Convert to Broadcast Group"), @"broadcast", @"" ]];
	} else {
		[rows addObject:@[ TGL(@"GroupInfo.UpgradeButton", @"Upgrade to Supergroup"), @"upgrade", @"" ]];
	}
}

- (void)appendFlagManageRowsTo:(NSMutableArray *)rows admin:(BOOL)admin {
	if (!(admin && self.manageFlagsKnown))
		return;
	if (self.supergroupChat && !self.channelChat && [self hasRight:@"canChangeInfo"])
		[rows addObject:@[ TGL(@"GroupInfo.GroupHistoryShort", @"Chat History"), @"history",
			(self.historyAvailable ? TGL(@"GroupInfo.GroupHistoryVisible", @"Visible") : TGL(@"GroupInfo.GroupHistoryHidden", @"Hidden")) ]];
	if (self.canHideMembers && !self.channelChat)
		[rows addObject:@[ TGL(@"GroupMembers.HideMembers", @"Hide Members"), @"hidemembers",
			(self.hiddenMembers ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off")) ]];
	if (self.canToggleAntiSpam && self.supergroupChat && !self.channelChat)
		[rows addObject:@[ TGL(@"Group.AdminLog.AntiSpamTitle", @"Anti-Spam"), @"antispam",
			(self.antiSpam ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off")) ]];
	if (self.chatOwner)
		[rows addObject:@[ TGL(@"Group.Setup.ForwardingDisabled", @"Protect Content"), @"protected",
			(self.protectedContent ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off")) ]];
	if (self.pendingJoinRequests > 0 && (self.chatOwner || [self hasRight:@"canInviteUsers"]))
		[rows addObject:@[ TGL(@"GroupInfo.JoinRequests", @"Join Requests"), @"requests",
			[NSString stringWithFormat:@"%ld",
				(long)self.pendingJoinRequests] ]];
}

- (void)loadChannelExtras {
	if (self.userId || !self.chatId)
		return;
	__weak typeof(self) weakSelf = self;

	[TGProfileService groupMemberCount:self.chatId completion:^(NSInteger count) {
		if (count <= 0 || count == weakSelf.memberCount)
			return;
		weakSelf.memberCount = count;
		[weakSelf rebuildManageRows];
	}];
	[self loadAdministrationSummary];

	[TGProfileService canGetStatisticsForChat:self.chatId completion:^(BOOL canGet) {
		if (!canGet)
			return;
		weakSelf.canGetStatistics = YES;
		[weakSelf rebuildManageRows];
	}];

	if (self.chatAdmin)
		[self loadManagementFlags];

	if (!self.channelChat && !self.supergroupChat)
		return;

	[self loadBoostSummary];

	if (!self.channelChat)
		return;

	[self loadChannelSignatures];
	[self loadDiscussionGroupLink];
}

- (void)loadManagementFlags {
	__weak typeof(self) weakSelf = self;
	[TGProfileService managementInfoForChat:self.chatId
								 completion:^(NSDictionary *info) {
									 if (![info isKindOfClass:[NSDictionary class]])
										 return;
									 weakSelf.protectedContent = TGProfileBool(info[@"hasProtectedContent"]);
									 weakSelf.historyAvailable = TGProfileBool(info[@"isAllHistoryAvailable"]);
									 weakSelf.hiddenMembers = TGProfileBool(info[@"hasHiddenMembers"]);
									 weakSelf.canHideMembers = TGProfileBool(info[@"canHideMembers"]);
									 weakSelf.antiSpam = TGProfileBool(info[@"hasAntiSpam"]);
									 weakSelf.canToggleAntiSpam = TGProfileBool(info[@"canToggleAntiSpam"]);
									 if ([info[@"pendingJoinRequests"] isKindOfClass:[NSNumber class]])
										 weakSelf.pendingJoinRequests =
											 [info[@"pendingJoinRequests"] integerValue];
									 weakSelf.manageFlagsKnown = YES;
									 [weakSelf rebuildManageRows];
								 }];
}

- (void)loadBoostSummary {
	__weak typeof(self) weakSelf = self;
	[TGProfileService boostStatusForChat:self.chatId completion:^(NSDictionary *status) {
		if (![status isKindOfClass:[NSDictionary class]])
			return;
		weakSelf.boostsKnown = YES;
		weakSelf.boostLevel = [status[@"level"] isKindOfClass:[NSNumber class]]
			? [status[@"level"] integerValue]
			: 0;
		[weakSelf rebuildManageRows];
	}];
}

- (void)loadChannelSignatures {
	__weak typeof(self) weakSelf = self;
	[TGProfileService channelSignaturesForChat:self.chatId
									completion:^(NSDictionary *info) {
										if (![info isKindOfClass:[NSDictionary class]])
											return;
										weakSelf.signaturesKnown = YES;
										weakSelf.signMessages = TGProfileBool(info[@"sign_messages"]);
										weakSelf.showAuthorProfiles = TGProfileBool(info[@"show_message_sender"]);
										[weakSelf rebuildManageRows];
									}];
}

- (void)loadDiscussionGroupLink {
	__weak typeof(self) weakSelf = self;
	[TGProfileService discussionGroupForChannel:self.chatId completion:^(NSNumber *linkedChatId) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		int64_t newChatId = [linkedChatId isKindOfClass:[NSNumber class]]
			? [linkedChatId longLongValue]
			: 0;
		BOOL changed = !strongSelf.discussionKnown || newChatId != strongSelf.discussionChatId;
		strongSelf.discussionKnown = YES;
		strongSelf.discussionChatId = newChatId;
		if (changed) {
			if (!newChatId)
				strongSelf.discussionTitle = nil;
			[strongSelf rebuildManageRows];
		}
		if (!newChatId)
			return;
		[TGSettingsService titleForChatId:newChatId completion:^(NSString *title) {
			TGProfileViewController *strongSelf2 = weakSelf;
			if (!strongSelf2 || strongSelf2.discussionChatId != newChatId)
				return;
			NSString *resolvedTitle = TGProfileText(title);
			if ([(strongSelf2.discussionTitle ?: @"") isEqualToString:resolvedTitle ?: @""])
				return;
			strongSelf2.discussionTitle = resolvedTitle;
			[strongSelf2 rebuildManageRows];
		}];
	}];
}

- (void)loadAdministrationSummary {
	if (!self.chatAdmin || !self.chatId)
		return;
	__weak typeof(self) weakSelf = self;

	[TGProfileService administratorsInGroup:self.chatId completion:^(NSArray *admins) {
		if (![admins isKindOfClass:[NSArray class]])
			return;
		weakSelf.adminCount = (NSInteger)admins.count;
		[weakSelf rebuildManageRows];
	}];

	[TGProfileService inviteLinkCountsInGroup:self.chatId completion:^(NSArray *counts) {
		if (![counts isKindOfClass:[NSArray class]])
			return;
		NSInteger total = 0;
		for (id entry in counts) {
			if (![entry isKindOfClass:[NSDictionary class]])
				continue;
			if (![[entry objectForKey:@"isMe"] boolValue])
				continue;
			id count = [entry objectForKey:@"linkCount"];
			if ([count isKindOfClass:[NSNumber class]])
				total += [count integerValue];
		}
		weakSelf.inviteLinkCount = total;
		[weakSelf rebuildManageRows];
	}];

	[TGProfileService pendingJoinRequestCountForChat:self.chatId completion:^(NSInteger count, BOOL failed) {
		NSInteger kept = TGCountAfterRead(weakSelf.pendingJoinRequests, count, failed);
		if (kept == weakSelf.pendingJoinRequests)
			return;
		weakSelf.pendingJoinRequests = kept;
		[weakSelf rebuildManageRows];
	}];

	[TGProfileService membersJoinedViaPrimaryInviteLinkInChat:self.chatId limit:1 completion:^(NSArray *members, NSInteger total) {
		weakSelf.primaryLinkJoinCount = total;
	}];

	if (self.primaryInviteLink.length)
		return;
	[TGProfileService primaryInviteLinkForGroup:self.chatId
									 completion:^(NSDictionary *link) {
										 NSString *text = [link isKindOfClass:[NSDictionary class]]
											 ? TGProfileText(link[@"link"])
											 : nil;
										 if (!text)
											 return;
										 weakSelf.primaryInviteLink = text;
										 [weakSelf setDetail:text forLabel:@"invite link"];
									 }];
}

- (void)showInviteLinkActions {
	if (!self.primaryInviteLink.length)
		return;
	NSString *title = self.primaryInviteLink;
	if (self.primaryLinkJoinCount > 0)
		title = [NSString stringWithFormat:@"%@\n%@",
			self.primaryInviteLink,
			TGLPlural(@"InviteLink.PeopleJoined", self.primaryLinkJoinCount, @"%@ people joined", @"%@ people joined")];
	NSMutableArray *titles = [NSMutableArray arrayWithObject:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link")];
	if (self.chatAdmin && self.primaryLinkJoinCount > 0)
		[titles addObject:TGL(@"Profile.WhoJoined", @"Who Joined")];
	NSInteger revokeIndex = -1;
	if (self.chatAdmin) {
		[titles addObject:TGL(@"GroupInfo.InviteLink.RevokeLink", @"Revoke Link")];
		revokeIndex = (NSInteger)titles.count - 1;
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:title
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:revokeIndex
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 92;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)replacePrimaryInviteLink {
	__weak typeof(self) weakSelf = self;
	[TGProfileService replacePrimaryInviteLinkForGroup:self.chatId completion:^(NSDictionary *link) {
		NSString *text = [link isKindOfClass:[NSDictionary class]]
			? TGProfileText(link[@"link"])
			: nil;
		if (!text) {
			[weakSelf showToast:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")];
			return;
		}
		weakSelf.primaryInviteLink = text;
		weakSelf.primaryLinkJoinCount = 0;
		[weakSelf setDetail:text forLabel:@"invite link"];
		[weakSelf showToast:TGL(@"GroupInfo.InviteLink.RevokeAlert.Success", @"The previous invite link is now inactive. A new invite link has just been generated.")];
	}];
}

- (void)toggleSignatures:(BOOL)authorsRow {
	BOOL sign = self.signMessages;
	BOOL authors = self.showAuthorProfiles;
	if (authorsRow)
		authors = !authors;
	else
		sign = !sign;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChannelSignaturesForChat:self.chatId signMessages:sign showAuthorProfiles:authors completion:^(BOOL ok) {
		if (ok) {
			weakSelf.signMessages = sign;
			weakSelf.showAuthorProfiles = authors;
			[weakSelf rebuildManageRows];
		}
		[weakSelf showToast:(ok ? TGL(@"Toast.SignaturesUpdated", @"Signatures updated") : TGL(@"Toast.CouldNotChangeSignatures", @"Could not change signatures"))];
	}];
}

- (void)setHistoryAvailableTo:(BOOL)available {
	if (available == self.historyAvailable)
		return;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChat:self.chatId allHistoryAvailable:available completion:^(BOOL ok) {
		if (ok) {
			weakSelf.historyAvailable = available;
			[weakSelf rebuildManageRows];
			[TGProfileService isAllHistoryAvailableForChat:weakSelf.chatId completion:^(BOOL actual) {
				if (actual == weakSelf.historyAvailable)
					return;
				weakSelf.historyAvailable = actual;
				[weakSelf rebuildManageRows];
			}];
		}
		NSString *changed = available ? TGL(@"Toast.HistoryVisibleToNewMembers", @"History is visible to new members") : TGL(@"Toast.HistoryHiddenFromNewMembers", @"History is hidden from new members");
		[weakSelf showToast:(ok ? changed : TGL(@"Toast.CouldNotChangeHistorySetting", @"Could not change the history setting"))];
	}];
}

- (void)toggleHiddenMembers {
	BOOL hidden = !self.hiddenMembers;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChat:self.chatId hiddenMembers:hidden
				   completion:^(BOOL ok) {
					   if (ok) {
						   weakSelf.hiddenMembers = hidden;
						   [weakSelf rebuildManageRows];
					   }
					   NSString *changed = hidden ? TGL(@"Toast.MemberListHidden", @"Member list hidden") : TGL(@"Toast.MemberListVisible", @"Member list visible");
					   [weakSelf showToast:(ok ? changed : TGL(@"Toast.CouldNotChangeMemberList", @"Could not change the member list"))];
				   }];
}

- (void)toggleAntiSpam {
	BOOL enabled = !self.antiSpam;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChat:self.chatId antiSpamEnabled:enabled
				   completion:^(BOOL ok) {
					   if (ok) {
						   weakSelf.antiSpam = enabled;
						   [weakSelf rebuildManageRows];
					   }
					   [weakSelf showToast:(ok ? (enabled ? TGL(@"Toast.AntiSpamOn", @"Anti-spam on") : TGL(@"Toast.AntiSpamOff", @"Anti-spam off"))
											   : TGL(@"Toast.CouldNotChangeAntiSpam", @"Could not change anti-spam"))];
				   }];
}

- (void)toggleProtectedContent {
	BOOL restricted = !self.protectedContent;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setChat:self.chatId protectedContent:restricted
				   completion:^(BOOL ok) {
					   if (ok) {
						   weakSelf.protectedContent = restricted;
						   [weakSelf rebuildManageRows];
					   }
					   NSString *changed = restricted ? TGL(@"Toast.SavingContentRestricted", @"Saving content restricted") : TGL(@"Toast.SavingContentAllowed", @"Saving content allowed");
					   [weakSelf showToast:(ok ? changed : TGL(@"Toast.CouldNotChangeContentProtection", @"Could not change content protection"))];
				   }];
}

- (NSString *)forumRowValue {
	if (!self.forumChat)
		return TGL(@"PrivacySettings.PasscodeOff", @"Off");
	if (!self.forumTopicsKnown)
		return TGL(@"PrivacySettings.PasscodeOn", @"On");
	return TGLPlural(@"GroupInfo.TopicCount", self.forumTopicCount, @"1 topic", @"%ld topics");
}

- (void)loadForumTopicCount {
	if (!self.chatId || !self.forumChat)
		return;
	__weak typeof(self) weakSelf = self;
	[TGProfileService forumTopicRowsForChat:self.chatId completion:^(NSArray *topics) {
		if (![topics isKindOfClass:[NSArray class]])
			return;
		weakSelf.forumTopicsKnown = YES;
		weakSelf.forumTopicCount = (NSInteger)topics.count;
		[weakSelf rebuildManageRows];
	}];
}

- (void)setForumMode:(BOOL)isForum {
	if (!self.chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGProfileService managementInfoForChat:self.chatId
								 completion:^(NSDictionary *info) {
									 int64_t supergroupId = [info isKindOfClass:[NSDictionary class]]
										 ? TGProfileInt64(info[@"supergroupId"])
										 : 0;
									 if (!supergroupId) {
										 [weakSelf showToast:TGL(@"Toast.OnlyOwnerCanChangeTopics", @"Only the owner can change topics")];
										 return;
									 }
									 [weakSelf applyForumMode:isForum toSupergroup:supergroupId];
								 }];
}

- (void)applyForumMode:(BOOL)isForum toSupergroup:(int64_t)supergroupId {
	__weak typeof(self) weakSelf = self;
	[TGProfileService setSupergroup:supergroupId
							isForum:isForum
							hasTabs:NO
						 completion:^(BOOL success) {
							 if (success) {
								 weakSelf.forumChat = isForum;
								 weakSelf.forumTopicsKnown = NO;
								 weakSelf.forumTopicCount = 0;
								 [weakSelf rebuildManageRows];
								 [weakSelf loadForumTopicCount];
							 }
							 NSString *changed = isForum ? TGL(@"Toast.TopicsTurnedOn", @"Topics turned on") : TGL(@"Toast.TopicsTurnedOff", @"Topics turned off");
							 [weakSelf showToast:(success ? changed : TGL(@"Toast.OnlyOwnerCanChangeTopics", @"Only the owner can change topics"))];
						 }];
}

- (void)openLinkJoins {
	if (!self.primaryInviteLink.length || !self.navigationController)
		return;
	TGProfileLinkJoinsController *joins =
		[[TGProfileLinkJoinsController alloc] initWithStyle:UITableViewStylePlain];
	joins.chatId = self.chatId;
	joins.link = self.primaryInviteLink;
	[self.navigationController pushViewController:joins animated:YES];
}

- (void)openDiscussionGroup {
	if (self.discussionChatId) {
		NSInteger cancelIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:TGL(@"VoiceChat.DiscussionGroup", @"Discussion group")
						  delegate:self
					   otherTitles:@[ TGL(@"Conversation.LinkDialogOpen", @"Open"),
						   TGL(@"Channel.DiscussionGroup.UnlinkGroup", @"Unlink") ]
				  destructiveIndex:-1
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:NULL
				 cancelButtonIndex:&cancelIndex];
		sheet.tag = 76;
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGProfileService suitableDiscussionChatsWithCompletion:^(NSArray *chats) {
		NSMutableArray *usable = [NSMutableArray array];
		if (![chats isKindOfClass:[NSArray class]])
			chats = @[];
		for (id chat in chats) {
			if (![chat isKindOfClass:[NSDictionary class]])
				continue;
			if (TGProfileInt64(chat[@"id"]))
				[usable addObject:chat];
		}
		if (!usable.count) {
			[weakSelf showToast:TGL(@"Toast.NoGroupToLink", @"No group to link")];
			return;
		}
		weakSelf.discussionCandidates = usable;
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *chat in usable) {
			NSString *title = TGProfileText(chat[@"title"]) ?: TGL(@"Conversation.InfoGroup", @"Group");
			NSString *suffix = [weakSelf discussionCandidateIneligibilitySuffix:chat[@"ineligibility"]];
			if (suffix.length)
				title = [NSString stringWithFormat:@"%@ (%@)", title, suffix];
			[titles addObject:title];
		}
		NSInteger cancelIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:TGL(@"Channel.DiscussionGroup.LinkGroup", @"Link a group")
						  delegate:weakSelf
					   otherTitles:titles
				  destructiveIndex:-1
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:NULL
				 cancelButtonIndex:&cancelIndex];
		sheet.tag = 75;
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(weakSelf.view.bounds), CGRectGetMidY(weakSelf.view.bounds), 1, 1) inView:weakSelf.view];
	}];
}

- (void)linkDiscussionChat:(int64_t)discussionChatId {
	__weak typeof(self) weakSelf = self;
	[TGProfileService setDiscussionGroup:discussionChatId forChannel:self.chatId completion:^(BOOL ok, NSString *errorMessage) {
		if (ok) {
			weakSelf.discussionChatId = discussionChatId;
			weakSelf.discussionTitle = nil;
			[weakSelf rebuildManageRows];
			if (discussionChatId) {
				[TGSettingsService titleForChatId:discussionChatId completion:^(NSString *title) {
					weakSelf.discussionTitle = TGProfileText(title);
					[weakSelf rebuildManageRows];
				}];
			}
		}
		NSString *changed = discussionChatId ? TGL(@"Toast.DiscussionGroupLinked", @"Discussion group linked") : TGL(@"Toast.DiscussionGroupRemoved", @"Discussion group removed");
		NSString *failure = TGFriendlyErrorText(errorMessage, TGL(@"Toast.CouldNotChangeDiscussionGroup", @"Could not change the discussion group"));
		[weakSelf showToast:(ok ? changed : failure)];
	}];
}

- (NSString *)discussionCandidateIneligibilitySuffix:(NSString *)tag {
	if (![tag isKindOfClass:NSString.class])
		return nil;
	if ([tag isEqualToString:@"needsUpgrade"])
		return TGL(@"Channel.DiscussionGroup.NeedsUpgradeSuffix", @"needs upgrading to a supergroup first");
	if ([tag isEqualToString:@"needsHistoryToggle"])
		return TGL(@"Channel.DiscussionGroup.NeedsHistorySuffix", @"needs old messages enabled first");
	return nil;
}

- (NSString *)discussionCandidateIneligibilityToast:(NSString *)tag {
	if ([tag isEqualToString:@"needsUpgrade"])
		return TGL(@"Toast.DiscussionGroupNeedsUpgrade", @"This group needs to be upgraded to a supergroup first");
	if ([tag isEqualToString:@"needsHistoryToggle"])
		return TGL(@"Toast.DiscussionGroupNeedsHistoryEnabled", @"This group needs its old messages made available first");
	return TGL(@"Toast.CouldNotChangeDiscussionGroup", @"Could not change the discussion group");
}

- (void)showSimilarChannels {
	if (!self.chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGProfileService similarChatsForChat:self.chatId completion:^(NSArray *chats, NSInteger total) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!chats) {
			[strongSelf showToast:TGL(@"Toast.SimilarChannelsLoadFailed",
								   @"The list of similar channels could not be loaded")];
			return;
		}
		if (!chats.count) {
			[strongSelf showToast:TGL(@"Toast.NoSimilarChannelsFound", @"No similar channels were found")];
			return;
		}
		NSInteger shown = MIN((NSUInteger)8, chats.count);
		TGSimilarChannelsViewController *list = [[TGSimilarChannelsViewController alloc] init];
		list.chats = [chats subarrayWithRange:NSMakeRange(0, shown)];
		list.total = MAX(total, (NSInteger)chats.count);
		list.onPick = ^(NSDictionary *chat) {
			[weakSelf openSimilarChannel:chat];
		};
		[strongSelf.navigationController pushViewController:list animated:YES];
	}];
}

- (void)openSimilarChannel:(NSDictionary *)chat {
	int64_t targetId = [chat[@"id"] longLongValue];
	if (!targetId)
		return;
	[TGProfileService openSimilarChat:targetId fromChat:self.chatId];
	[self openChatId:targetId title:TGProfileText(chat[@"title"])];
}

- (void)openChatId:(int64_t)chatId title:(NSString *)title {
	if (!chatId)
		return;
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = title ?: @"";
	[self.navigationController pushViewController:chat animated:YES];
}

- (NSString *)slowModeTitle:(NSInteger)seconds {
	if (seconds <= 0)
		return TGL(@"GroupInfo.Permissions.SlowmodeValue.Off", @"Off");
	if (seconds < 60)
		return [NSString stringWithFormat:TGL(@"GroupInfo.SlowmodeSeconds", @"%lds"), (long)seconds];
	if (seconds < 3600)
		return [NSString stringWithFormat:TGL(@"GroupInfo.SlowmodeMinutes", @"%ldm"), (long)(seconds / 60)];
	return [NSString stringWithFormat:TGL(@"GroupInfo.SlowmodeHours", @"%ldh"), (long)(seconds / 3600)];
}

- (void)openManageRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.manageRows.count)
		return;
	NSString *key = self.manageRows[row][1];
	UINavigationController *navigation = self.navigationController;

	if ([key isEqualToString:@"members"] || [key isEqualToString:@"admins"]) {
		[self pushGroupMembersInto:navigation
					   adminsFirst:[key isEqualToString:@"admins"]];
		return;
	}

	if ([key isEqualToString:@"links"]) {
		[self pushInviteLinksInto:navigation];
		return;
	}

	if ([key isEqualToString:@"videochat"]) {
		[self pushGroupCallInto:navigation];
		return;
	}

	if ([key isEqualToString:@"events"]) {
		[self pushChatEventsInto:navigation];
		return;
	}

	if ([key isEqualToString:@"title"]) {
		[self promptForChatTitle];
		return;
	}

	if ([key isEqualToString:@"photo"]) {
		[self showChatPhotoActions];
		return;
	}

	if ([key isEqualToString:@"description"]) {
		[self promptForChatDescription];
		return;
	}

	if ([key isEqualToString:@"stickers"]) {
		[self promptForStickerSet];
		return;
	}

	if ([key isEqualToString:@"upgrade"]) {
		[self confirmUpgradeToSupergroup];
		return;
	}

	if ([key isEqualToString:@"broadcast"]) {
		[self confirmConvertToBroadcast];
		return;
	}

	if ([key isEqualToString:@"topics"]) {
		[self confirmForumModeChange];
		return;
	}

	if ([key isEqualToString:@"signatures"] || [key isEqualToString:@"authors"]) {
		[self toggleSignatures:[key isEqualToString:@"authors"]];
		return;
	}

	if ([key isEqualToString:@"history"]) {
		[self showChatHistoryActions];
		return;
	}

	if ([key isEqualToString:@"hidemembers"]) {
		[self toggleHiddenMembers];
		return;
	}

	if ([key isEqualToString:@"antispam"]) {
		[self toggleAntiSpam];
		return;
	}

	if ([key isEqualToString:@"protected"]) {
		[self toggleProtectedContent];
		return;
	}

	if ([key isEqualToString:@"requests"]) {
		[self pushInviteLinksInto:navigation];
		return;
	}

	if ([key isEqualToString:@"discussion"]) {
		[self openDiscussionGroup];
		return;
	}

	if ([key isEqualToString:@"stats"]) {
		[self pushStatisticsInto:navigation];
		return;
	}

	if ([key isEqualToString:@"boosts"]) {
		[self pushBoostsInto:navigation];
		return;
	}

	if ([key isEqualToString:@"permissions"]) {
		[self pushPermissionsInto:navigation];
		return;
	}

	if ([key isEqualToString:@"slowmode"]) {
		[self showSlowModeActions];
		return;
	}

	if ([key isEqualToString:@"directmessages"]) {
		[self openOrToggleDirectMessagesGroup];
		return;
	}

	if ([key isEqualToString:@"autotranslate"]) {
		[self toggleAutomaticTranslation];
		return;
	}

	if ([key isEqualToString:@"unrestrictboost"]) {
		[self showUnrestrictBoostActions];
		return;
	}

	if ([key isEqualToString:@"channelprofiletab"]) {
		[self showChannelMainProfileTabActions];
		return;
	}

	if ([key isEqualToString:@"usernames"]) {
		[self pushUsernamesInto:navigation];
		return;
	}

	if ([key isEqualToString:@"chatcolour"]) {
		[navigation pushViewController:
				[[TGColourViewController alloc] initForChat:self.chatId]
							  animated:YES];
		return;
	}

	if ([key isEqualToString:@"chatemojistatus"]) {
		[navigation pushViewController:
				[[TGEmojiStatusPickerViewController alloc] initForChat:self.chatId]
							  animated:YES];
	}
}

- (void)toggleAutomaticTranslation {
	BOOL enabled = !self.automaticTranslation;
	__weak typeof(self) weakSelf = self;
	[TGProfileService setGroup:self.chatId hasAutomaticTranslation:enabled
					 completion:^(BOOL ok) {
						 if (ok) {
							 weakSelf.automaticTranslation = enabled;
							 [weakSelf rebuildManageRows];
						 }
						 NSString *changed = enabled ? TGL(@"Toast.AutoTranslationOn", @"Auto-translation on") : TGL(@"Toast.AutoTranslationOff", @"Auto-translation off");
						 [weakSelf showToast:(ok ? changed : TGL(@"Toast.CouldNotChangeAutoTranslation", @"Could not change auto-translation"))];
					 }];
}

@end
