#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGInstantViewController.h"
#import "TGMessageInfoViewController.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGLinkPreviewView.h"
#import "TGClient+Bots.h"
#import "TGClient+MessageContent.h"
#import "TGClient+WebLinks.h"
#import "TGClient+Search.h"
#import "TGClient+Contacts.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Translation.h"
#import "TGStickerCatalogService.h"
#import "TGStickersViewController.h"
#import "TGRichText.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGPremiumViewController.h"
#import "TGClient+Channels.h"
#import "TGProfileBoostsController.h"
#import "TGStarsViewController.h"
#import "TGAlertView.h"
#import "TGWebViewController.h"
#import "TGTheme.h"
#import "TGMessageRowCell.h"
#import "TGClient+Account.h"
#import "TGSessionsViewController.h"
#import "TGPrivacyViewController.h"
#import "TGFoldersViewController.h"
#import "TGEditProfileViewController.h"
#import "TGSettingsViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGQRCodeViewController.h"

@implementation TGChatViewController (Links)

#pragma mark - links

- (void)openLink:(NSString *)url {
	if (!url.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] botStartLinkInfo:url completion:^(NSDictionary *info) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *username = info[@"username"];
		if (!username.length) {
			[strongSelf resolveAndOpenLink:url];
			return;
		}
		if ([info[@"inGroup"] boolValue] || [info[@"inChannel"] boolValue]) {
			[strongSelf addBotFromLink:url];
			return;
		}
		if ([info[@"autostart"] boolValue]) {
			[strongSelf startPendingBotLink:url];
			return;
		}
		strongSelf.pendingBotStartLink = url;
		NSString *botTitle = [NSString stringWithFormat:@"@%@", username];
		UIAlertView *ask = [UIAlertView alloc];
		ask = [ask initWithTitle:botTitle
						 message:TGL(@"Chat.StartAChatWithThisBot", @"Start a chat with this bot?")
						delegate:strongSelf
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"UserInfo.StartSecretChatStart", @"Start"), nil];
		ask.tag = kBotStartAlertTag;
		[ask show];
	}];
}

- (void)touchedMessageBackground {
	if ([self.input isFirstResponder])
		[self.input resignFirstResponder];
	else if ([self.chatSearchBar isFirstResponder])
		[self.chatSearchBar resignFirstResponder];
	else if (self.stickerPanel)
		[self toggleStickerPanel];
}

- (void)openLinkInMessage:(NSDictionary *)m {
	NSString *text = [self originalTextOf:m];
	if (!text.length) {
		[self touchedMessageBackground];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] entitiesInText:text completion:^(NSArray *entities) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSMutableArray *targets = [NSMutableArray array];
		for (NSDictionary *entity in entities) {
			if (![entity isKindOfClass:NSDictionary.class])
				continue;
			NSString *kind = [([entity[@"kind"] isKindOfClass:NSString.class]
					? entity[@"kind"]
					: @"") lowercaseString];
			NSString *fragment = [strongSelf fragmentOf:text entity:entity];
			if (!fragment.length)
				continue;
			if ([kind isEqualToString:@"url"]) {
				[targets addObject:@{@"label" : fragment, @"url" : fragment}];
			} else if ([kind isEqualToString:@"texturl"]) {
				NSString *href = [entity[@"url"] isKindOfClass:NSString.class]
					? entity[@"url"]
					: nil;
				if (href.length)
					[targets addObject:@{@"label" : fragment, @"url" : href}];
			} else if ([kind isEqualToString:@"mention"] && fragment.length > 1) {
				[targets addObject:@{@"label" : fragment,
					@"mention" : [fragment substringFromIndex:1]}];
			} else if ([kind isEqualToString:@"mentionname"]) {
				int64_t mentioned = [entity[@"userId"] longLongValue];
				if (mentioned > 0)
					[targets addObject:@{@"label" : fragment,
						@"userId" : @(mentioned)}];
			} else if (([kind isEqualToString:@"hashtag"] ||
						   [kind isEqualToString:@"cashtag"]) &&
				fragment.length > 1) {
				[targets addObject:@{@"label" : fragment, @"hashtag" : fragment}];
			} else if ([kind isEqualToString:@"botcommand"] && fragment.length > 1) {
				[targets addObject:@{@"label" : fragment, @"command" : fragment}];
			} else if ([kind isEqualToString:@"phonenumber"]) {
				[targets addObject:@{@"label" : fragment,
					@"url" : [@"tel:" stringByAppendingString:fragment]}];
			} else if ([kind isEqualToString:@"emailaddress"]) {
				[targets addObject:@{@"label" : fragment,
					@"url" : [@"mailto:" stringByAppendingString:fragment]}];
			}
		}
		if (!targets.count) {
			[strongSelf tapFellThroughOnMessage:m];
			return;
		}
		if (targets.count == 1) {
			[strongSelf followTextTarget:[targets objectAtIndex:0]];
			return;
		}
		strongSelf.tappedLinkTargets = targets;
		UIActionSheet *sheet = [UIActionSheet alloc];
		sheet = [sheet initWithTitle:TGL(@"PeerInfo.PaneLinks", @"Links")
							delegate:strongSelf
				   cancelButtonTitle:nil
			  destructiveButtonTitle:nil
				   otherButtonTitles:nil];
		NSInteger shown = MIN((NSUInteger)8, targets.count);
		for (NSInteger i = 0; i < shown; i++)
			[sheet addButtonWithTitle:[targets objectAtIndex:i][@"label"]];
		sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
		sheet.tag = kTextLinksSheetTag;
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(strongSelf.view.bounds), CGRectGetMidY(strongSelf.view.bounds), 1, 1) inView:strongSelf.view];
	}];
}

- (TGEmojiLabel *)richBodyLabelForCell:(UITableViewCell *)cell {
	if ([cell isKindOfClass:TGMessageRowCell.class])
		return [(TGMessageRowCell *)cell tg_richTextLabel];
	return nil;
}

- (void)forgetLayoutOfMessage:(NSNumber *)messageId {
	if (messageId) {
		[self.bodyLayouts removeObjectForKey:messageId];
		[self.bodyLayoutOrder removeObject:messageId];
	}
}

- (void)followRichLink:(NSDictionary *)link inRow:(NSInteger)row {
	NSString *kind = link[TGRichLinkKindKey];
	NSString *value = link[TGRichLinkValueKey];
	if (![kind isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class])
		return;

	if ([kind isEqualToString:@"url"] || [kind isEqualToString:@"bankcard"]) {
		if ([kind isEqualToString:@"bankcard"]) {
			[self followBankCardNumber:value];
			return;
		}
		[self openLink:value];
		return;
	}
	if ([kind isEqualToString:@"phone"]) {
		[self openLink:[@"tel:" stringByAppendingString:value]];
		return;
	}
	if ([kind isEqualToString:@"hashtag"]) {
		[self searchChatForTag:value];
		return;
	}
	if ([kind isEqualToString:@"mention"]) {
		[self followTextTarget:@{@"mention" : (value.length > 1
									   ? [value substringFromIndex:1]
									   : value)}];
		return;
	}
	if ([kind isEqualToString:@"user"]) {
		long long userId = [value longLongValue];
		if (userId > 0)
			[self openProfileForUserId:userId];
		return;
	}
	if ([kind isEqualToString:@"timestamp"]) {
		NSTimeInterval seconds = [value doubleValue];
		if (![self openMediaTimestamp:seconds forRow:row]) {
			NSDictionary *m = [self messageAtRow:row];
			if ([m[@"kind"] isEqualToString:@"messageVoiceNote"] ||
				[m[@"kind"] isEqualToString:@"messageAudio"])
				[self playAudioMessage:m fromSeconds:seconds];
		}
		return;
	}
}

- (BOOL)handleRichTapInRow:(NSInteger)row {
	UITableViewCell *raw = [self.table cellForRowAtIndexPath:
			[NSIndexPath indexPathForRow:row inSection:0]];
	if (![raw isKindOfClass:TGMessageRowCell.class])
		return NO;
	id touchTracked = raw;
	if (![touchTracked lastTouchKnown])
		return NO;
	[touchTracked setLastTouchKnown:NO];

	TGEmojiLabel *body = [self richBodyLabelForCell:raw];
	TGRichTextLayout *layout = body.richLayout;
	if (!layout || body.hidden)
		return NO;

	CGPoint point = [body convertPoint:[touchTracked lastTouchInCell]
							  fromView:raw.contentView];
	CGRect box = body.bounds;
	NSDictionary *m = [self messageAtRow:row];
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;

	NSDictionary *link = [layout linkAtPoint:point inRect:box];
	if (link) {
		[self followRichLink:link inRow:row];
		return YES;
	}

	if (layout.carriesSpoilers && messageId &&
		![self.revealedSpoilers containsObject:messageId] &&
		[layout spoilerAtPoint:point inRect:box]) {
		[self.revealedSpoilers addObject:messageId];
		[self forgetLayoutOfMessage:messageId];
		[self reloadRow:row];
		return YES;
	}

	NSNumber *block = [layout collapsibleBlockAtPoint:point inRect:box];
	if (block && messageId) {
		NSMutableSet *open = [(self.expandedQuotes[messageId] ?: [NSSet set]) mutableCopy];
		if ([open containsObject:block])
			[open removeObject:block];
		else
			[open addObject:block];
		self.expandedQuotes[messageId] = open;
		[self forgetLayoutOfMessage:messageId];
		[self reloadRow:row];
		return YES;
	}
	return NO;
}

- (void)reloadRow:(NSInteger)row {
	[self.table reloadRowsAtIndexPaths:
			@[ [NSIndexPath indexPathForRow:row inSection:0] ]
					  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)followTextTarget:(NSDictionary *)target {
	NSString *url = target[@"url"];
	if ([url isKindOfClass:NSString.class] && url.length) {
		[self openLink:url];
		return;
	}
	NSString *hashtag = target[@"hashtag"];
	if ([hashtag isKindOfClass:NSString.class] && hashtag.length) {
		[self searchChatForTag:hashtag];
		return;
	}
	NSString *command = target[@"command"];
	if ([command isKindOfClass:NSString.class] && command.length) {
		[[TGClient shared] sendText:command toChat:self.chatId
							 thread:self.threadId];
		return;
	}
	NSNumber *userId = target[@"userId"];
	if ([userId isKindOfClass:NSNumber.class] && [userId longLongValue] > 0) {
		[self openProfileForUserId:[userId longLongValue]];
		return;
	}
	NSString *mention = target[@"mention"];
	if (![mention isKindOfClass:NSString.class] || !mention.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] publicLinkForUsername:mention completion:^(NSString *link) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!link.length) {
			[strongSelf showAlertTitle:@""
					   message:TGL(@"Resolve.ErrorNotFound", @"Sorry, this user doesn't seem to exist.")];
			return;
		}
		[strongSelf openLink:link];
	}];
}

- (void)resolveAndOpenLink:(NSString *)url {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resolveLink:url completion:^(NSDictionary *link) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *kind = link[@"kind"];
		if ([kind isEqualToString:@"message"]) {
			[[TGClient shared] resolveMessageLink:url completion:^(NSDictionary *info) {
				TGChatViewController *innerSelf = weakSelf;
				if (!innerSelf)
					return;
				int64_t messageId = [info[@"messageId"] longLongValue];
				if (messageId && [info[@"chatId"] longLongValue] == innerSelf.chatId &&
					[innerSelf scrollToMessageId:messageId])
					return;
				[innerSelf confirmExternalLink:url];
			}];
			return;
		}
		if ([strongSelf routeInternalLink:link])
			return;
		if (link && ![link[@"supported"] boolValue]) {
			[strongSelf explainUnsupportedLink:url];
			return;
		}
		[strongSelf confirmExternalLink:url];
	}];
}

- (BOOL)routeInternalLink:(NSDictionary *)link {
	NSString *kind = link[@"kind"];
	if (!kind.length)
		return NO;

	if ([kind isEqualToString:@"publicChat"] || [kind isEqualToString:@"publicChatUsername"]) {
		NSString *username = link[@"username"];
		if (!username.length)
			return NO;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] publicChatWithUsername:username completion:^(NSDictionary *chat) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			int64_t target = [chat[@"id"] longLongValue];
			if (!target)
				target = [chat[@"chatId"] longLongValue];
			if (!target) {
				[strongSelf showAlertTitle:@"" message:TGL(@"Resolve.ChannelErrorNotFound", @"Sorry, this channel doesn't seem to exist.")];
				return;
			}
			[strongSelf openChatId:target
					 title:(chat[@"title"] ?: [NSString stringWithFormat:@"@%@", username])
				isGroup:[chat[@"isGroup"] boolValue]];
		}];
		return YES;
	}

	if ([kind isEqualToString:@"userToken"]) {
		NSString *token = link[@"token"];
		if (!token.length)
			return NO;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] userForToken:token completion:^(NSDictionary *user) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			int64_t userId = [user[@"id"] longLongValue];
			if (!userId) {
				[strongSelf showAlertTitle:@"" message:TGL(@"Resolve.ErrorNotFound", @"Sorry, this user doesn't seem to exist.")];
				return;
			}
			[strongSelf openProfileForUserId:userId];
		}];
		return YES;
	}

	if ([kind isEqualToString:@"chatInvite"]) {
		NSString *invite = link[@"inviteLink"] ?: link[@"link"];
		if (!invite.length)
			return NO;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] previewInviteLink:invite completion:^(NSDictionary *info) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!info) {
				[strongSelf showAlertTitle:@"" message:TGL(@"InviteLinks.InviteLinkExpired", @"This invite link has expired.")];
				return;
			}
			int64_t known = [info[@"chatId"] longLongValue];
			if (known) {
				[strongSelf openChatId:known
								  title:(info[@"title"] ?: TGL(@"ChatList.UnnamedChat", @"Chat"))
					isGroup:YES];
				return;
			}
			[strongSelf confirmJoinChatByInviteLink:invite info:info];
		}];
		return YES;
	}

	if ([kind isEqualToString:@"languagePack"]) {
		NSString *packId = link[@"languagePackId"];
		if (!packId.length)
			return NO;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] languagePackInfoForId:packId completion:^(NSDictionary *pack) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!pack) {
				[strongSelf showAlertTitle:@"" message:TGL(@"ApplyLanguage.LanguageNotSupportedError", @"This language pack does not exist.")];
				return;
			}
			NSString *name = pack[@"nativeName"];
			if (!name.length)
				name = pack[@"name"];
			if (!name.length)
				name = packId;
			strongSelf.pendingLanguagePackId = packId;
			UIAlertView *ask = [UIAlertView alloc];
			ask = [ask initWithTitle:name
							 message:[NSString stringWithFormat:TGL(@"ApplyLanguage.ChangeLanguageOfficialText", @"You are about to apply a language pack %1$@.\n\nThis will translate the entire interface. You can suggest corrections in the translation panel.\n\nYou can change your language back at any time in Settings."), name]
							delegate:strongSelf
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"Conversation.ApplyLocalization", @"Add"), nil];
			ask.tag = kAddLanguagePackAlertTag;
			[ask show];
		}];
		return YES;
	}

	if ([kind isEqualToString:@"chatAffiliateProgram"]) {
		NSString *username = link[@"username"];
		if (!username.length)
			return NO;
		__weak typeof(self) weakSelf = self;
		TGClient *client = [TGClient shared];
		NSString *referrer = link[@"referrer"];
		[client chatAffiliateProgramWithUsername:username referrer:referrer completion:^(NSDictionary *chat) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			int64_t target = [chat[@"id"] longLongValue];
			if (!target)
				target = [chat[@"chatId"] longLongValue];
			if (!target) {
				[strongSelf showAlertTitle:@"" message:TGL(@"Resolve.ChannelErrorNotFound", @"Sorry, this channel doesn't seem to exist.")];
				return;
			}
			NSString *chatTitle = chat[@"title"] ?: [NSString stringWithFormat:@"@%@", username];
			[strongSelf openChatId:target title:chatTitle isGroup:[chat[@"isGroup"] boolValue]];
		}];
		return YES;
	}

	if ([kind isEqualToString:@"stickerSet"]) {
		NSString *name = link[@"stickerSetName"];
		if (!name.length)
			return NO;
		__weak typeof(self) weakSelf = self;
		[TGStickerCatalogService stickerSetWithName:name completion:^(NSDictionary *set) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!set) {
				[strongSelf showAlertTitle:@"" message:TGL(@"StickerPack.ErrorNotFound", @"This sticker set no longer exists.")];
				return;
			}
			TGStickersViewController *preview = [[TGStickersViewController alloc] init];
			preview.page = TGStickersPageSet;
			preview.set = set;
			preview.setId = [set[@"id"] longLongValue];
			[strongSelf.navigationController pushViewController:preview animated:YES];
		}];
		return YES;
	}

	if ([kind isEqualToString:@"oauth"]) {
		NSString *url = link[@"url"];
		if (!url.length)
			return NO;
		[self presentOauthLoginForUrl:url];
		return YES;
	}

	if ([kind isEqualToString:@"premiumGiftCode"]) {
		NSString *code = link[@"code"];
		if (!code.length)
			return NO;
		TGPremiumViewController *premium = [[TGPremiumViewController alloc] init];
		[self.navigationController pushViewController:premium animated:YES];
		[premium checkCode:code];
		return YES;
	}

	if ([kind isEqualToString:@"chatBoost"]) {
		NSString *url = link[@"url"] ?: link[@"link"];
		if (!url.length)
			return NO;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] resolveBoostLink:url completion:^(NSNumber *chatId, BOOL isPublic) {
			typeof(self) strongSelf = weakSelf;
			if (!strongSelf || !chatId)
				return;
			int64_t resolvedChatId = [chatId longLongValue];
			[[TGClient shared] isChannelChat:resolvedChatId completion:^(BOOL isChannel) {
				typeof(self) innerSelf = weakSelf;
				if (!innerSelf)
					return;
				TGProfileBoostsController *boosts = [[TGProfileBoostsController alloc]
					initWithStyle:UITableViewStyleGrouped];
				boosts.chatId = resolvedChatId;
				boosts.channel = isChannel;
				[innerSelf.navigationController pushViewController:boosts animated:YES];
			}];
		}];
		return YES;
	}

	if ([kind isEqualToString:@"instantView"]) {
		NSString *articleUrl = link[@"url"];
		if (!articleUrl.length)
			return NO;
		[self openInstantView:articleUrl fallbackURL:link[@"fallbackUrl"]];
		return YES;
	}

	if ([kind isEqualToString:@"invoice"]) {
		NSString *name = link[@"invoiceName"];
		if (!name.length)
			return NO;
		[TGStarsViewController presentInvoiceNamed:name fromViewController:self];
		return YES;
	}

	if ([kind isEqualToString:@"upgradedGift"]) {
		NSString *name = link[@"upgradedGiftName"];
		if (!name.length)
			return NO;
		TGUpgradedGiftInfoViewController *info = [[TGUpgradedGiftInfoViewController alloc]
			initWithGiftName:name
					   title:nil];
		[self.navigationController pushViewController:info animated:YES];
		return YES;
	}

	if ([kind isEqualToString:@"settings"])
		return [self routeSettingsLink:link];

	return NO;
}

- (BOOL)routeSettingsLink:(NSDictionary *)link {
	NSString *section = link[@"section"];
	if (!section.length)
		return NO;

	if ([section isEqualToString:@"devices"]) {
		[self.navigationController pushViewController:[[TGSessionsViewController alloc] init] animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"privacyAndSecurity"]) {
		[self.navigationController pushViewController:[[TGPrivacyViewController alloc] init] animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"chatFolders"]) {
		TGFoldersViewController *folders = [[TGFoldersViewController alloc] init];
		folders.page = TGFoldersPageList;
		[self.navigationController pushViewController:folders animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"editProfile"]) {
		[self.navigationController pushViewController:[[TGEditProfileViewController alloc] init] animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"premium"]) {
		[self.navigationController pushViewController:[[TGPremiumViewController alloc] init] animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"myStars"]) {
		[self.navigationController pushViewController:[[TGStarsViewController alloc] init] animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"sendGift"]) {
		TGStarsViewController *gifts = [[TGStarsViewController alloc] init];
		gifts.opensGiftCatalogue = YES;
		[self.navigationController pushViewController:gifts animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"dataAndStorage"]) {
		TGSettingsViewController *settings = [[TGSettingsViewController alloc] init];
		settings.page = TGSettingsPageData;
		[self.navigationController pushViewController:settings animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"appearance"]) {
		TGSettingsViewController *settings = [[TGSettingsViewController alloc] init];
		settings.page = TGSettingsPageAppearance;
		[self.navigationController pushViewController:settings animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"notifications"]) {
		TGSettingsViewController *settings = [[TGSettingsViewController alloc] init];
		settings.page = TGSettingsPageNotifications;
		[self.navigationController pushViewController:settings animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"language"]) {
		TGSettingsViewController *settings = [[TGSettingsViewController alloc] init];
		settings.page = TGSettingsPageLanguage;
		[self.navigationController pushViewController:settings animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"inAppBrowser"]) {
		[self.navigationController pushViewController:[[TGWebBrowserSettingsViewController alloc] init] animated:YES];
		return YES;
	}

	if ([section isEqualToString:@"faq"] || [section isEqualToString:@"privacyPolicy"]) {
		NSString *url = [section isEqualToString:@"faq"]
			? @"https://telegram.org/faq"
			: @"https://telegram.org/privacy";
		UIViewController *browser = [TGWebViewController controllerForURLString:url];
		if (browser)
			[self.navigationController pushViewController:browser animated:YES];
		else
			[TGWebViewController openURLString:url fromViewController:self];
		return YES;
	}

	if ([section isEqualToString:@"askQuestion"]) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] publicChatWithUsername:@"BotSupport" completion:^(NSDictionary *chat) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			int64_t target = [chat[@"id"] longLongValue];
			if (!target)
				target = [chat[@"chatId"] longLongValue];
			if (!target)
				return;
			[strongSelf openChatId:target
					 title:(chat[@"title"] ?: TGL(@"Profile.ContactTelegramSupport", @"Telegram support"))
				isGroup:NO];
		}];
		return YES;
	}

	if ([section isEqualToString:@"qrCode"]) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] publicLinkWithCompletion:^(NSString *url, NSInteger expiresIn) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || !url.length)
				return;
			TGQRCodeViewController *code = [[TGQRCodeViewController alloc]
				initWithLink:url
					 caption:nil];
			[strongSelf.navigationController pushViewController:code animated:YES];
		}];
		return YES;
	}

	return NO;
}

- (void)presentOauthLoginForUrl:(NSString *)url {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] oauthLinkInfoForUrl:url completion:^(NSDictionary *info) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!info) {
			[strongSelf openExternalLink:url];
			return;
		}
		NSArray *codes = info[@"matchCodes"];
		if ([info[@"matchCodeFirst"] boolValue] && codes.count > 0) {
			[strongSelf presentOauthMatchCodePickerForUrl:url info:info codes:codes];
			return;
		}
		[strongSelf presentOauthConfirmForUrl:url info:info matchCode:@""];
	}];
}

- (void)presentOauthMatchCodePickerForUrl:(NSString *)url
									 info:(NSDictionary *)info
									codes:(NSArray *)codes {
	NSMutableArray *actions = [NSMutableArray array];
	for (NSString *code in codes) {
		if (![code isKindOfClass:[NSString class]] || !code.length)
			continue;
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:code action:code]];
	}
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:TGL(@"Common.Cancel", @"Cancel")
								  action:@"cancel"
									type:TGActionSheetActionTypeCancel]];
	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:TGL(@"AuthConfirmation.Emoji.Title", @"Tap the emoji shown\non your other device")
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGChatViewController *strongSelf = weakSelf;
			  if (!strongSelf)
				  return;
			  if ([action isEqualToString:@"cancel"]) {
				  [[TGClient shared] declineOauthRequestForUrl:url];
				  return;
			  }
			  [[TGClient shared] checkOauthMatchCode:action forUrl:url completion:^(BOOL ok) {
				  TGChatViewController *innerSelf = weakSelf;
				  if (!innerSelf)
					  return;
				  if (!ok) {
					  [[TGClient shared] declineOauthRequestForUrl:url];
					  [innerSelf showAlertTitle:TGL(@"AuthConfirmation.LoginFail.Title", @"Login Failed") message:TGL(@"AuthConfirmation.LoginFail.TextUnknown", @"Please try logging in again.")];
					  return;
				  }
				  [innerSelf presentOauthConfirmForUrl:url info:info matchCode:action];
			  }];
		  }
			   target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)presentOauthConfirmForUrl:(NSString *)url info:(NSDictionary *)info matchCode:(NSString *)matchCode {
	NSString *domain = [info[@"domain"] isKindOfClass:[NSString class]] && [info[@"domain"] length]
		? info[@"domain"]
		: url;
	NSString *appName = info[@"verifiedAppName"];
	NSMutableString *message = [NSMutableString string];
	if ([appName isKindOfClass:[NSString class]] && appName.length) {
		[message appendFormat:TGL(@"Conversation.OpenBotLinkLogin", @"Log in to %@ as %@?"), domain, appName];
	} else {
		[message appendFormat:TGL(@"AuthConfirmation.Title", @"Log in to %@?"), domain];
	}
	NSString *platform = info[@"platform"];
	NSString *location = info[@"location"];
	if ([platform isKindOfClass:[NSString class]] && platform.length) {
		[message appendFormat:@"\n\n%@", platform];
		if ([location isKindOfClass:[NSString class]] && location.length)
			[message appendFormat:@", %@", location];
	}

	__weak typeof(self) weakSelf = self;
	BOOL allowWrite = [info[@"requestWriteAccess"] boolValue];
	BOOL allowPhone = [info[@"requestPhoneNumberAccess"] boolValue];
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"AuthConfirmation.LogIn", @"Log in")
				  message:message
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			okButtonTitle:TGL(@"AuthConfirmation.LogIn", @"Log in")
		  completionBlock:^(bool okButtonPressed) {
			  TGClient *client = [TGClient shared];
			  if (!okButtonPressed) {
				  [client declineOauthRequestForUrl:url];
				  return;
			  }
			  [client acceptOauthRequestForUrl:url
									 matchCode:matchCode ?: @""
							  allowWriteAccess:allowWrite
						allowPhoneNumberAccess:allowPhone
									completion:^(NSString *openUrl) {
										TGChatViewController *strongSelf = weakSelf;
										if (!strongSelf)
											return;
										if (openUrl.length)
											[TGWebViewController openURLString:openUrl fromViewController:strongSelf];
										else
											[strongSelf showAlertTitle:TGL(@"AuthConfirmation.LoginSuccess.Title", @"Login Successful") message:[NSString stringWithFormat:TGL(@"AuthConfirmation.LoginSuccess.Text", @"You are now logged in to %@."), domain]];
									}];
		  }];
	[alert show];
}

- (void)explainUnsupportedLink:(NSString *)url {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deepLinkInfoForUrl:url completion:^(NSString *text, BOOL needsUpdate) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		(void)needsUpdate;
		if (!text.length) {
			[strongSelf openExternalLink:url];
			return;
		}
		[strongSelf showAlertTitle:@"" message:text];
	}];
}

- (void)openChatId:(int64_t)targetChatId title:(NSString *)title isGroup:(BOOL)isGroup {
	[self openChatId:targetChatId title:title isGroup:isGroup focusMessage:0];
}

- (void)openChatId:(int64_t)targetChatId
			 title:(NSString *)title
		   isGroup:(BOOL)isGroup
	  focusMessage:(int64_t)messageId {
	[self openChatId:targetChatId title:title isGroup:isGroup focusMessage:messageId completion:nil];
}

- (void)openChatId:(int64_t)targetChatId
			 title:(NSString *)title
		   isGroup:(BOOL)isGroup
	  focusMessage:(int64_t)messageId
		completion:(void (^)(TGChatViewController *chat))completion {
	if (targetChatId == self.chatId) {
		if (messageId && ![self scrollToMessageId:messageId])
			[self loadDeeperHistoryAndScrollTo:messageId];
		if (completion)
			completion(self);
		return;
	}
	for (UIViewController *existing in self.navigationController.viewControllers) {
		if (![existing isKindOfClass:TGChatViewController.class])
			continue;
		TGChatViewController *open = (TGChatViewController *)existing;
		if (open.chatId != targetChatId)
			continue;
		open.focusMessageId = messageId;
		[self.navigationController popToViewController:existing animated:YES];
		if (messageId && ![open scrollToMessageId:messageId])
			[open loadDeeperHistoryAndScrollTo:messageId];
		if (completion)
			completion(open);
		return;
	}
	TGChatViewController *controller = [[TGChatViewController alloc] init];
	controller.chatId = targetChatId;
	controller.chatTitle = title.length ? title : @"Chat";
	controller.group = isGroup;
	controller.focusMessageId = messageId;
	[self.navigationController pushViewController:controller animated:YES];
	if (completion)
		completion(controller);
}

- (void)confirmExternalLink:(NSString *)url {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] externalLinkInfoForUrl:url completion:^(NSDictionary *info) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *target = info[@"url"] ?: url;
		if (info && ![info[@"needsConfirmation"] boolValue]) {
			[strongSelf openExternalLink:target];
			return;
		}
		NSString *domain = info[@"domain"];
		if (!domain.length)
			domain = [[NSURL URLWithString:url] host] ?: url;

		strongSelf.pendingLinkURL = target;
		UIActionSheet *sheet = [UIActionSheet alloc];
		sheet = [sheet initWithTitle:domain
							delegate:strongSelf
				   cancelButtonTitle:nil
			  destructiveButtonTitle:nil
				   otherButtonTitles:TGL(@"Web.OpenExternal", @"Open in Safari"),
			TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link"), nil];
		sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
		sheet.tag = kLinkSheetTag;
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(strongSelf.view.bounds), CGRectGetMidY(strongSelf.view.bounds), 1, 1) inView:strongSelf.view];
	}];
}

- (void)openExternalLink:(NSString *)url {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] externalLinkForUrl:url allowWriteAccess:NO
							   completion:^(NSString *opened) {
								   TGChatViewController *strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   [TGWebViewController openURLString:(opened.length ? opened : url) fromViewController:strongSelf];
							   }];
}

- (void)openInstantView:(NSString *)url {
	[self openInstantView:url fallbackURL:nil];
}

- (void)openInstantView:(NSString *)url fallbackURL:(NSString *)fallbackURL {
	if (!url.length)
		return;
	TGInstantViewController *reader = [[TGInstantViewController alloc] init];
	reader.url = url;
	reader.fallbackUrl = fallbackURL;
	[self.navigationController pushViewController:reader animated:YES];
}

- (void)pushRichMessageReaderWithBlocks:(NSArray *)blocks title:(NSString *)title {
	TGInstantViewController *reader = [[TGInstantViewController alloc] init];
	reader.presetBlocks = blocks ?: @[];
	reader.readerTitle = title.length ? title : TGL(@"Attachment.Article", @"Article");
	[self.navigationController pushViewController:reader animated:YES];
}

- (void)openRichMessage:(NSDictionary *)m {
	NSArray *blocks = [m[@"richMessageBlocks"] isKindOfClass:NSArray.class]
		? m[@"richMessageBlocks"]
		: @[];
	NSString *title = m[@"richTitle"];

	if ([m[@"richMessageIsFull"] boolValue] || ![m[@"id"] isKindOfClass:NSNumber.class]) {
		[self pushRichMessageReaderWithBlocks:blocks title:title];
		return;
	}

	int64_t messageId = [m[@"id"] longLongValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] fullRichMessageForMessage:messageId inChat:self.chatId
									  completion:^(NSArray *fullBlocks, BOOL isRtl) {
										  TGChatViewController *strongSelf = weakSelf;
										  if (!strongSelf)
											  return;
										  (void)isRtl;
										  [strongSelf pushRichMessageReaderWithBlocks:(fullBlocks.count ? fullBlocks : blocks) title:title];
									  }];
}

- (NSTimeInterval)mediaTimestampInMessage:(NSDictionary *)m {
	NSString *text = [self textOf:m];
	if (!text.length)
		return -1;

	NSScanner *scanner = [NSScanner scannerWithString:text];
	NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
	while (![scanner isAtEnd]) {
		[scanner scanUpToCharactersFromSet:digits intoString:NULL];
		NSInteger first = 0;
		NSInteger mark = scanner.scanLocation;
		if (![scanner scanInteger:&first])
			break;
		if (scanner.scanLocation >= text.length ||
			[text characterAtIndex:scanner.scanLocation] != ':') {
			if (scanner.scanLocation == mark)
				scanner.scanLocation = mark + 1;
			continue;
		}
		scanner.scanLocation += 1;
		NSInteger second = 0;
		if (![scanner scanInteger:&second])
			continue;
		if (scanner.scanLocation < text.length &&
			[text characterAtIndex:scanner.scanLocation] == ':') {
			scanner.scanLocation += 1;
			NSInteger third = 0;
			if ([scanner scanInteger:&third])
				return first * 3600 + second * 60 + third;
			continue;
		}
		return first * 60 + second;
	}
	return -1;
}

- (BOOL)openMediaTimestamp:(NSTimeInterval)seconds forRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	NSDictionary *target = nil;

	NSNumber *replyTo = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	int64_t replyChatId = [m[@"replyChatId"] longLongValue];
	if (replyTo && (!replyChatId || replyChatId == self.chatId)) {
		for (NSDictionary *candidate in self.messages)
			if ([candidate[@"id"] isEqual:replyTo])
				target = candidate;
	}
	if (!target)
		return NO;

	NSString *kind = target[@"kind"];
	if (![@"messageVoiceNote" isEqualToString:kind] &&
		![@"messageAudio" isEqualToString:kind])
		return NO;

	[self playAudioMessage:target fromSeconds:seconds];
	return YES;
}

@end
