#import "tg_service_shared_line_tests.h"
#import "../../src/Wire/Flatten/TGServiceSharedLine.h"

TGTestOutcome TGServiceSharedLineTestSharingWithABotReadsAsASentence(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *oneUser = @{@"users" : @[ @{@"first_name" : @"Marianna", @"last_name" : @"K"} ]};
	TGTestExpectTrue(&outcome,
			[TGServiceSharedLine(oneUser, @"messageUsersShared", @"Photo Bot")
					isEqualToString:@"You shared Marianna K with Photo Bot."],
			"sharing a contact with a bot says who was shared and with whom, rather than telling "
			"the reader their Telegram is too old");
	TGTestExpectTrue(&outcome,
			[TGServiceSharedLine(@{@"users" : @[ @{@"first_name" : @"A"}, @{@"username" : @"bee"} ]},
					@"messageUsersShared", @"Photo Bot")
					isEqualToString:@"You shared A, @bee with Photo Bot."],
			"several people are listed, and someone with no name at all is named by username");
	TGTestExpectTrue(&outcome,
			[TGServiceSharedLine(@{@"chat" : @{@"title" : @"Photo Club"}}, @"messageChatShared",
					@"Photo Bot") isEqualToString:@"You shared Photo Club with Photo Bot."],
			"a shared chat reads the same way");
	TGTestExpectTrue(&outcome,
			[TGServiceSharedLine(oneUser, @"messageUsersShared", nil)
					isEqualToString:@"You shared Marianna K with the bot."],
			"with no bot name to hand the line still reads as a sentence");

	NSDictionary *webApp = @{@"reason" : @{@"@type" : @"botWriteAccessAllowReasonLaunchedWebApp"}};
	TGTestExpectTrue(&outcome,
			[TGServiceSharedLine(webApp, @"messageBotWriteAccessAllowed", @"Photo Bot")
					isEqualToString:@"You allowed this bot to message you in the app."],
			"allowing a bot to write says which way it was allowed");
	NSDictionary *website = @{@"reason" : @{@"@type" : @"botWriteAccessAllowReasonConnectedWebsite",
		@"domain_name" : @"example.org"}};
	TGTestExpectTrue(&outcome,
			[TGServiceSharedLine(website, @"messageBotWriteAccessAllowed", nil)
					isEqualToString:@"You allowed this bot to message you when you logged in on example.org."],
			"a website reason names the site");
	TGTestExpectTrue(&outcome,
			[TGServiceSharedLine(@{}, @"messageBotWriteAccessAllowed", nil)
					isEqualToString:@"You allowed this bot to message you when you added it to your attachment menu."],
			"a reason TDLib did not send falls back to the attachment-menu wording rather than "
			"to nothing");

	TGTestExpectTrue(&outcome, TGServiceSharedLine(@{}, @"messageUsersShared", @"Bot") == nil,
			"a shared-users message with nobody in it is left to the caller");
	TGTestExpectTrue(&outcome, TGServiceSharedLine(@{}, @"messageText", @"Bot") == nil,
			"an ordinary message is not a service line");
	TGTestExpectTrue(&outcome, TGServiceSharedLine(nil, @"messageChatShared", @"Bot") == nil,
			"no content at all is not a crash");

	return outcome;
}
