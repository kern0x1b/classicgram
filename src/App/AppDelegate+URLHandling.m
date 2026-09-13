#import "AppDelegate+Private.h"
#import "TGClient.h"
#import "TGClient+WebLinks.h"
#import "TGClient+MessageContent.h"
#import "TGClient+Search.h"
#import "TGClient+Network.h"
#import "TGClient+Channels.h"
#import "TGClient+ChatState.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Contacts.h"
#import "TGSnackbar.h"
#import "TGLocalization.h"
#import "TGStickerCatalogService.h"
#import "TGStickersViewController.h"
#import "TGProxyViewController.h"
#import "TGProfileViewController.h"
#import "TGProfileBoostsController.h"
#import "TGClient+Translation.h"

const NSInteger kAppLanguagePackAlertTag = 124;
const NSInteger kAppJoinLinkAlertTag = 125;

@implementation AppDelegate (URLHandling)

- (BOOL)application:(UIApplication *)application
			openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
		 annotation:(id)annotation {
	return [self handleAppURL:url];
}

- (BOOL)handleAppURL:(NSURL *)url {
	NSString *scheme = url.scheme;
	NSString *host = url.host;
	NSLog(@"handleAppURL: %@", host ?: @"(launch)");

	if ([scheme isEqualToString:@"tg"] || [scheme isEqualToString:@"telegram"])
		return [self handleTelegramLinkURL:url host:host];

	if ([scheme isEqualToString:@"telegramdev"] &&
		[self respondsToSelector:@selector(handleDebugHarnessURL:)])
		return [self handleDebugHarnessURL:url];

	return NO;
}

- (BOOL)handleTelegramLinkURL:(NSURL *)url host:(NSString *)host {
	if ([host isEqualToString:@"resolve"]) {
		[self resolveAndHandleTelegramLinkURL:url];
		return YES;
	}

	if ([host isEqualToString:@"join"]) {
		[self resolveAndHandleTelegramLinkURL:url];
		return YES;
	}

	if ([host isEqualToString:@"addlist"]) {
		[self handleChatFolderInviteLinkURL:url];
		return YES;
	}

	if ([host isEqualToString:@"addstickers"] || [host isEqualToString:@"addemoji"]) {
		[self resolveAndHandleStickerSetLinkURL:url];
		return YES;
	}

	if ([host isEqualToString:@"proxy"] || [host isEqualToString:@"socks"]) {
		[self resolveAndHandleProxyLinkURL:url];
		return YES;
	}

	if ([host isEqualToString:@"setlanguage"]) {
		[self resolveAndHandleLanguagePackLinkURL:url];
		return YES;
	}

	[self showLinkCouldNotBeOpenedToast];
	return YES;
}

- (void)resolveAndHandleTelegramLinkURL:(NSURL *)url {
	NSString *link = url.absoluteString;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resolveLink:link completion:^(NSDictionary *info) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *kind = info[@"kind"];
		if ([kind isEqualToString:@"botStart"] || [kind isEqualToString:@"botStartInGroup"]) {
			[strongSelf handleBotStartLinkURL:url];
			return;
		}
		if ([kind isEqualToString:@"publicChat"]) {
			[strongSelf openPublicChatLinkWithInfo:info];
			return;
		}
		if ([kind isEqualToString:@"message"]) {
			[strongSelf openMessageLinkURL:link];
			return;
		}
		if ([kind isEqualToString:@"chatBoost"]) {
			NSString *infoUrl = info[@"url"];
			NSString *boostUrl = infoUrl.length ? infoUrl : link;
			[strongSelf openChatBoostLinkURL:boostUrl];
			return;
		}
		if ([kind isEqualToString:@"chatInvite"]) {
			NSString *inviteLink = info[@"inviteLink"];
			NSString *invite = inviteLink.length ? inviteLink : info[@"link"];
			if (invite.length) {
				[strongSelf openChatInviteLinkURL:invite];
				return;
			}
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		if ([kind isEqualToString:@"userToken"]) {
			NSString *token = info[@"token"];
			if (token.length) {
				[strongSelf openUserTokenLinkURL:token];
				return;
			}
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		[strongSelf showLinkCouldNotBeOpenedToast];
	}];
}

- (void)openChatInviteLinkURL:(NSString *)link {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] previewInviteLink:link completion:^(NSDictionary *info) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!info) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		int64_t known = [info[@"chatId"] longLongValue];
		if (known) {
			[strongSelf openChatFromNotification:known focusMessageId:0];
			return;
		}
		[strongSelf confirmJoinChatByInviteLinkURL:link info:info];
	}];
}

- (void)confirmJoinChatByInviteLinkURL:(NSString *)link info:(NSDictionary *)info {
	self.pendingInviteLink = link;
	NSString *chatTitle = info[@"title"];
	if (!chatTitle.length)
		chatTitle = TGL(@"InviteLink.InviteLink", @"Invite Link");
	BOOL requiresApproval = [info[@"requiresApproval"] boolValue];
	NSInteger memberCount = [info[@"memberCount"] integerValue];
	NSString *membersLine = memberCount > 0
		? TGLPlural(@"Conversation.StatusMembers", memberCount, @"1 member", @"%@ members")
		: nil;
	NSString *action = requiresApproval
		? TGL(@"Chat.RequestToJoinPrompt", @"Do you want to request to join this chat?")
		: TGL(@"Chat.JoinPrompt", @"Do you want to join this chat?");
	NSString *message = membersLine.length
		? [NSString stringWithFormat:@"%@\n%@", membersLine, action]
		: action;
	NSString *confirmTitle = requiresApproval
		? TGL(@"MemberRequests.RequestToJoin", @"Request to Join")
		: TGL(@"Channel.JoinChannel", @"Join");
	UIAlertView *ask = [UIAlertView alloc];
	ask = [ask initWithTitle:chatTitle
					 message:message
					delegate:self
		   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		   otherButtonTitles:confirmTitle, nil];
	ask.tag = kAppJoinLinkAlertTag;
	[ask show];
}

- (void)handleJoinLinkAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSString *link = self.pendingInviteLink;
	self.pendingInviteLink = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !link.length)
		return;
	[self joinChatByInviteLinkURL:link];
}

- (void)showJoinLinkAlertTitle:(NSString *)title message:(NSString *)message {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:(title ?: @"")
							 message:(message ?: @"")
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
	});
}

- (void)joinChatByInviteLinkURL:(NSString *)link {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] joinChatByInviteLink:link completion:^(int64_t joinedChatId, BOOL requestSent, NSString *errorCode) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (joinedChatId) {
			[strongSelf openChatFromNotification:joinedChatId focusMessageId:0];
			return;
		}
		if (requestSent) {
			[strongSelf showJoinLinkAlertTitle:@"" message:TGL(@"Group.RequestToJoinSent", @"Your request to join has been sent.")];
			return;
		}
		if ([errorCode isEqualToString:@"GUARD_BOT_REQUIRED"]) {
			[strongSelf showJoinLinkAlertTitle:TGL(@"Login.Fee.Verification.Title", @"Verification Required")
										message:TGL(@"Chat.VerificationRequiredMessage", @"This chat is protected by a verification bot. Complete the verification in the Telegram app, then use the invite link again.")];
			return;
		}
		if ([errorCode isEqualToString:@"GUARD_BOT_DECLINED"]) {
			[strongSelf showJoinLinkAlertTitle:TGL(@"Chat.VerificationDeclined", @"Verification Declined")
										message:TGL(@"Chat.VerificationDeclinedMessage", @"The verification bot declined this join request.")];
			return;
		}
		[strongSelf showLinkCouldNotBeOpenedToast];
	}];
}

- (void)openUserTokenLinkURL:(NSString *)token {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] userForToken:token completion:^(NSDictionary *user) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		int64_t userId = [user[@"id"] longLongValue];
		if (!userId) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		NSString *name = [[TGClient shared] nameForUserId:userId] ?: @"";
		[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
			AppDelegate *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (!chatId) {
				[innerSelf showLinkCouldNotBeOpenedToast];
				return;
			}
			[TGProfileViewController showProfileForChatId:chatId
												   userId:userId
													title:name
											 inNavigation:[innerSelf navigationControllerForPush]];
		}];
	}];
}

- (void)openChatBoostLinkURL:(NSString *)url {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resolveBoostLink:url completion:^(NSNumber *chatId, BOOL isPublic) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!chatId) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		int64_t resolvedChatId = [chatId longLongValue];
		[[TGClient shared] isChannelChat:resolvedChatId completion:^(BOOL isChannel) {
			AppDelegate *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			TGProfileBoostsController *boosts = [[TGProfileBoostsController alloc]
				initWithStyle:UITableViewStyleGrouped];
			boosts.chatId = resolvedChatId;
			boosts.channel = isChannel;
			[[innerSelf navigationControllerForPush] pushViewController:boosts animated:YES];
		}];
	}];
}

- (void)openPublicChatLinkWithInfo:(NSDictionary *)info {
	NSString *username = info[@"username"];
	if (!username.length) {
		[self showLinkCouldNotBeOpenedToast];
		return;
	}
	BOOL openProfile = [info[@"openProfile"] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] publicChatWithUsername:username completion:^(NSDictionary *chat) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		int64_t target = [chat[@"id"] longLongValue];
		if (!target) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		if (openProfile) {
			int64_t userId = [chat[@"isPrivate"] boolValue] ? target : 0;
			[TGProfileViewController showProfileForChatId:target
												   userId:userId
													title:chat[@"title"]
											 inNavigation:[strongSelf navigationControllerForPush]];
			return;
		}
		[strongSelf openChatFromNotification:target focusMessageId:0];
	}];
}

- (void)openMessageLinkURL:(NSString *)link {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resolveMessageLink:link completion:^(NSDictionary *info) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		int64_t chatId = [info[@"chatId"] longLongValue];
		if (!chatId) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		int64_t messageId = [info[@"messageId"] longLongValue];
		[strongSelf openChatFromNotification:chatId focusMessageId:messageId];
	}];
}

- (void)resolveAndHandleStickerSetLinkURL:(NSURL *)url {
	NSString *link = url.absoluteString;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resolveLink:link completion:^(NSDictionary *info) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *kind = info[@"kind"];
		NSString *name = info[@"stickerSetName"];
		if (![kind isEqualToString:@"stickerSet"] || !name.length) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		[strongSelf openStickerSetLinkWithName:name];
	}];
}

- (void)openStickerSetLinkWithName:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	[TGStickerCatalogService stickerSetWithName:name completion:^(NSDictionary *set) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!set) {
			[strongSelf showStickerSetNotFoundToast];
			return;
		}
		TGStickersViewController *preview = [[TGStickersViewController alloc] init];
		preview.page = TGStickersPageSet;
		preview.set = set;
		preview.setId = [set[@"id"] longLongValue];
		[[strongSelf navigationControllerForPush] pushViewController:preview animated:YES];
	}];
}

- (void)resolveAndHandleProxyLinkURL:(NSURL *)url {
	NSString *link = url.absoluteString;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] proxyFromLink:link completion:^(NSDictionary *proxy) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![proxy isKindOfClass:[NSDictionary class]] || !proxy.count) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		[TGProxyViewController presentFormForProxyLink:link inNavigationController:[strongSelf navigationControllerForPush]];
	}];
}

- (void)resolveAndHandleLanguagePackLinkURL:(NSURL *)url {
	NSString *link = url.absoluteString;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resolveLink:link completion:^(NSDictionary *info) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *kind = info[@"kind"];
		NSString *packId = info[@"languagePackId"];
		if (![kind isEqualToString:@"languagePack"] || !packId.length) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		[[TGClient shared] languagePackInfoForId:packId completion:^(NSDictionary *pack) {
			AppDelegate *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (!pack) {
				[innerSelf showLinkCouldNotBeOpenedToast];
				return;
			}
			NSString *name = pack[@"nativeName"];
			if (!name.length)
				name = pack[@"name"];
			if (!name.length)
				name = packId;
			innerSelf.pendingLanguagePackId = packId;
			UIAlertView *ask = [UIAlertView alloc];
			ask = [ask initWithTitle:name
							 message:[NSString stringWithFormat:
									 TGL(@"ApplyLanguage.ChangeLanguageOfficialText",
											 @"You are about to apply a language pack %1$@.\n\nThis will translate the entire interface. You can suggest corrections in the translation panel.\n\nYou can change your language back at any time in Settings."), name]
							delegate:innerSelf
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"Conversation.ApplyLocalization", @"Add"), nil];
			ask.tag = kAppLanguagePackAlertTag;
			[ask show];
		}];
	}];
}

- (void)handleLanguagePackAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSString *packId = self.pendingLanguagePackId;
	self.pendingLanguagePackId = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !packId.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] applyLanguagePack:packId completion:^(BOOL success, BOOL packNotFound) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!success) {
			NSString *message = packNotFound
				? TGL(@"ApplyLanguage.LanguageNotSupportedError", @"This language pack does not exist.")
				: TGL(@"Login.UnknownError", @"An error occurred, please try again later.");
			dispatch_async(dispatch_get_main_queue(), ^{
				[TGSnackbar showInView:strongSelf.window.rootViewController.view text:message seconds:3 onCommit:nil];
			});
			return;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[TGSnackbar showInView:strongSelf.window.rootViewController.view text:TGL(@"ApplyLanguage.ApplySuccess", @"Language changed") seconds:3 onCommit:nil];
		});
	}];
}

- (void)showLinkCouldNotBeOpenedToast {
	dispatch_async(dispatch_get_main_queue(), ^{
		[TGSnackbar showInView:self.window.rootViewController.view
						   text:TGL(@"Toast.CouldNotOpenLink", @"Could not open this link")
						seconds:2
					   onCommit:nil];
	});
}

- (void)showStickerSetNotFoundToast {
	dispatch_async(dispatch_get_main_queue(), ^{
		[TGSnackbar showInView:self.window.rootViewController.view
						   text:TGL(@"StickerPack.ErrorNotFound", @"This sticker set no longer exists.")
						seconds:2
					   onCommit:nil];
	});
}

@end
