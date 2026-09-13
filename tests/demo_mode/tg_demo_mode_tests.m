#import "tg_demo_mode_tests.h"

#import "../../src/TDLibClient/TGDemoData.h"
#import "../../src/TDLibClient/TGDemoTransport.h"
#import "../../src/Utilities/TGDemoMode.h"

TGTestOutcome TGDemoModeTestReadsTheFlag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGDemoModeWanted(@"1", NO, NO),
		"the environment variable turns demo mode on");
	TGTestExpectTrue(&outcome, TGDemoModeWanted(@"YES", NO, NO),
		"any non-negative value counts as on, so TG_DEMO_MODE=YES works");
	TGTestExpectTrue(&outcome, !TGDemoModeWanted(@"0", YES, YES),
		"an explicit zero wins over the stored setting, so a screenshot run can be turned off");
	TGTestExpectTrue(&outcome, !TGDemoModeWanted(@"false", YES, YES),
		"false reads as off rather than as a non-empty string");
	TGTestExpectTrue(&outcome, TGDemoModeWanted(nil, YES, NO),
		"with no environment variable the stored setting decides");
	TGTestExpectTrue(&outcome, !TGDemoModeWanted(nil, NO, NO),
		"the app is not in demo mode by default");
	TGTestExpectTrue(&outcome, !TGDemoModeWanted(@"", NO, NO),
		"an empty variable is no answer at all, so the stored setting decides");
	TGTestExpectTrue(&outcome, TGDemoModeWanted(nil, NO, YES),
		"a marker file turns demo mode on, which is how a device with no shell environment does it");
	TGTestExpectTrue(&outcome, !TGDemoModeWanted(@"0", NO, YES),
		"the environment still wins over the marker, so a build can be forced back to the real client");

	return outcome;
}

TGTestOutcome TGDemoModeTestAnswersTheRequestsAScreenNeeds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *chats = TGDemoResponseForRequest(@{@"@type" : @"getChats",
		@"chat_list" : @{@"@type" : @"chatListMain"}, @"limit" : @(100)});
	TGTestExpectTrue(&outcome,
		[chats[@"@type"] isEqualToString:@"chats"] &&
			[chats[@"chat_ids"] count] == TGDemoChats().count,
		"the main list answers with every demo chat, so the chat list fills");

	NSDictionary *archive = TGDemoResponseForRequest(@{@"@type" : @"getChats",
		@"chat_list" : @{@"@type" : @"chatListArchive"}, @"limit" : @(100)});
	TGTestExpectTrue(&outcome, [archive[@"chat_ids"] count] == 0,
		"the archive is empty rather than a copy of the main list");

	NSDictionary *history = TGDemoResponseForRequest(@{@"@type" : @"getChatHistory",
		@"chat_id" : @(900002), @"limit" : @(50)});
	TGTestExpectTrue(&outcome,
		[history[@"@type"] isEqualToString:@"messages"] && [history[@"messages"] count] > 0,
		"a demo chat opens with a conversation in it");

	NSDictionary *me = TGDemoResponseForRequest(@{@"@type" : @"getMe"});
	TGTestExpectTrue(&outcome, [me[@"@type"] isEqualToString:@"user"],
		"getMe answers with a user, which settings and the profile screen both need");

	NSDictionary *state = TGDemoResponseForRequest(@{@"@type" : @"getAuthorizationState"});
	TGTestExpectTrue(&outcome,
		[state[@"@type"] isEqualToString:@"authorizationStateReady"],
		"demo mode is logged in from the first frame, with no code to enter");

	TGTestExpectTrue(&outcome, TGDemoResponseForRequest(@{@"@type" : @"sendMessage"}) == nil,
		"a request demo mode has no answer for is left unanswered rather than faked");

	NSDictionary *first = [TGDemoStartupUpdates() firstObject];
	TGTestExpectTrue(&outcome,
		[first[@"@type"] isEqualToString:@"updateAuthorizationState"],
		"the first thing the demo transport says is that the client is ready");

	return outcome;
}

TGTestOutcome TGDemoModeTestTransportKeepsTheRequestExtra(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *reply = TGDemoTransportReplyForRequestJSON(
		@"{\"@type\":\"getMe\",\"@extra\":\"req-7\"}");
	NSDictionary *object = [NSJSONSerialization
		JSONObjectWithData:[reply dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
	TGTestExpectTrue(&outcome, [object[@"@extra"] isEqualToString:@"req-7"],
		"the reply carries the request's extra back, or the caller's completion never runs");

	NSString *unknown = TGDemoTransportReplyForRequestJSON(
		@"{\"@type\":\"sendMessage\",\"@extra\":\"req-8\"}");
	NSDictionary *error = [NSJSONSerialization
		JSONObjectWithData:[unknown dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
	TGTestExpectTrue(&outcome,
		[error[@"@type"] isEqualToString:@"error"] &&
			[error[@"@extra"] isEqualToString:@"req-8"],
		"an unanswerable request gets an error back, so the screen stops waiting");

	TGTestExpectTrue(&outcome,
		TGDemoTransportReplyForRequestJSON(@"{\"@type\":\"getMe\"}") == nil,
		"a request with no extra expects no reply");
	TGTestExpectTrue(&outcome, TGDemoTransportReplyForRequestJSON(@"not json") == nil,
		"malformed input is dropped rather than crashing the transport");

	return outcome;
}

TGTestOutcome TGDemoModeTestCarriesNoRealAccountData(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	BOOL everyUserIsInvented = YES;
	for (NSDictionary *user in TGDemoUsers()) {
		long long userId = [user[@"id"] longLongValue];
		if (userId < 900000 || userId > 999999)
			everyUserIsInvented = NO;
	}
	TGTestExpectTrue(&outcome, everyUserIsInvented,
		"every demo user id sits in the invented range, so no screenshot shows a real account");

	NSString *phone = TGDemoMe()[@"phone_number"];
	TGTestExpectTrue(&outcome, [phone hasPrefix:@"99966"],
		"the demo account's number is one of Telegram's reserved test numbers");

	BOOL everyChatIsDemo = YES;
	for (NSDictionary *chat in TGDemoChats()) {
		if (![chat[@"last_message"] isKindOfClass:NSDictionary.class])
			everyChatIsDemo = NO;
	}
	TGTestExpectTrue(&outcome, everyChatIsDemo,
		"every demo chat carries a last message, so the list draws a full row");

	return outcome;
}

TGTestOutcome TGDemoModeTestShowsEveryKindOfMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableSet *kinds = [NSMutableSet set];
	for (NSDictionary *chat in TGDemoChats()) {
		for (NSDictionary *message in TGDemoHistoryForChat([chat[@"id"] longLongValue]))
			[kinds addObject:message[@"content"][@"@type"] ?: @"?"];
	}

	TGTestExpectTrue(&outcome, [kinds containsObject:@"messageText"],
		"the demo has plain text, the bubble every other kind is measured against");
	TGTestExpectTrue(&outcome, [kinds containsObject:@"messagePhoto"],
		"the demo has a photo, so a screenshot shows how media is drawn");
	TGTestExpectTrue(&outcome, [kinds containsObject:@"messageVoiceNote"],
		"the demo has a voice note, which draws a waveform rather than text");
	TGTestExpectTrue(&outcome, [kinds containsObject:@"messageDocument"],
		"the demo has a file, which draws the document row");
	TGTestExpectTrue(&outcome, [kinds containsObject:@"messageLocation"],
		"the demo has a location, which draws a map rather than a bubble of text");
	TGTestExpectTrue(&outcome, [kinds containsObject:@"messageCall"],
		"the demo has a call, so the Calls tab and the call bubble both have something to show");
	TGTestExpectTrue(&outcome, [kinds containsObject:@"messagePoll"],
		"the demo has a poll, the one kind that is interactive inside the bubble");
	TGTestExpectTrue(&outcome, [kinds containsObject:@"messageChatAddMembers"],
		"the demo has a service line, which is drawn as a centred plate");

	return outcome;
}

TGTestOutcome TGDemoModeTestServesItsOwnFiles(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGDemoSetAssetProvider(^NSString *(NSString *key) {
		return [@"/demo/" stringByAppendingString:key];
	});

	NSDictionary *user = TGDemoUsers()[1];
	TGTestExpectTrue(&outcome,
		[user[@"profile_photo"][@"small"][@"local"][@"path"] hasPrefix:@"/demo/avatar-"],
		"a demo person carries a profile photo, so the chat list is not a column of blank squares");

	NSDictionary *update = TGDemoFileUpdateForRequest(@{@"@type" : @"downloadFile",
		@"file_id" : @(100)});
	TGTestExpectTrue(&outcome,
		[update[@"@type"] isEqualToString:@"updateFile"] &&
			[update[@"file"][@"local"][@"is_downloading_completed"] boolValue],
		"a download is answered with the file already complete, since it never leaves the device");

	NSDictionary *response = TGDemoResponseForRequest(@{@"@type" : @"downloadFile",
		@"file_id" : @(400)});
	TGTestExpectTrue(&outcome,
		[response[@"local"][@"path"] isEqualToString:@"/demo/voice"],
		"each file id maps to its own asset rather than to one shared picture");

	TGTestExpectTrue(&outcome,
		TGDemoFileUpdateForRequest(@{@"@type" : @"getMe"}) == nil,
		"a request that is not about a file produces no file update");

	TGDemoSetAssetProvider(nil);
	return outcome;
}
