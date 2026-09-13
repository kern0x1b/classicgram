#import "TGServiceSharedLine.h"
#import "TGLocalization.h"

static NSString *TGSharedLineString(id value) {
	return [value isKindOfClass:[NSString class]] && [value length] ? value : nil;
}

static NSString *TGSharedUserName(NSDictionary *user) {
	if (![user isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *first = TGSharedLineString(user[@"first_name"]);
	NSString *last = TGSharedLineString(user[@"last_name"]);
	if (first && last)
		return [NSString stringWithFormat:@"%@ %@", first, last];
	if (first)
		return first;
	if (last)
		return last;
	NSString *username = TGSharedLineString(user[@"username"]);
	return username ? [@"@" stringByAppendingString:username] : nil;
}

static NSString *TGSharedUsersName(NSArray *users) {
	if (![users isKindOfClass:[NSArray class]] || !users.count)
		return nil;
	NSMutableArray *names = [NSMutableArray array];
	for (NSDictionary *user in users) {
		NSString *name = TGSharedUserName(user);
		if (name)
			[names addObject:name];
	}
	if (!names.count)
		return nil;
	return [names componentsJoinedByString:@", "];
}

static NSString *TGBotWriteAccessLine(NSDictionary *content) {
	NSString *reason = TGSharedLineString(content[@"reason"][@"@type"]);
	if ([reason isEqualToString:@"botWriteAccessAllowReasonLaunchedWebApp"] ||
		[reason isEqualToString:@"botWriteAccessAllowReasonAcceptedRequest"])
		return TGL(@"Notification.BotWriteAllowedRequest",
			@"You allowed this bot to message you in the app.");
	if ([reason isEqualToString:@"botWriteAccessAllowReasonConnectedWebsite"]) {
		NSString *domain = TGSharedLineString(content[@"reason"][@"domain_name"]);
		if (domain)
			return [NSString stringWithFormat:TGL(@"Notification.BotWriteAllowedWebsite",
									  @"You allowed this bot to message you when you logged in on %@."),
				domain];
	}
	return TGL(@"Notification.BotWriteAllowedMenu",
		@"You allowed this bot to message you when you added it to your attachment menu.");
}

NSString *TGServiceSharedLine(NSDictionary *content, NSString *ctype, NSString *botName) {
	if (![content isKindOfClass:[NSDictionary class]] || !ctype.length)
		return nil;
	NSString *bot = TGSharedLineString(botName) ?: TGL(@"Chat.ServiceBot", @"the bot");

	if ([ctype isEqualToString:@"messageUsersShared"]) {
		NSString *shared = TGSharedUsersName(content[@"users"]);
		if (!shared)
			return nil;
		return [NSString stringWithFormat:TGL(@"Notification.RequestedPeer",
								  @"You shared %1$@ with %2$@."), shared, bot];
	}
	if ([ctype isEqualToString:@"messageChatShared"]) {
		NSString *title = TGSharedLineString(content[@"chat"][@"title"]);
		if (!title)
			return nil;
		return [NSString stringWithFormat:TGL(@"Notification.RequestedPeer",
								  @"You shared %1$@ with %2$@."), title, bot];
	}
	if ([ctype isEqualToString:@"messageBotWriteAccessAllowed"])
		return TGBotWriteAccessLine(content);
	return nil;
}
