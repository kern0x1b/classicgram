#import "tg_push_extra_line_tests.h"
#import "../../src/Wire/Flatten/TGPushExtraLine.h"

static NSString *TGPushLine(NSString *type, NSDictionary *fields) {
	NSMutableDictionary *content = [NSMutableDictionary dictionaryWithDictionary:fields];
	content[@"@type"] = type;
	return TGPushExtraLine(content, @"Marianna");
}

TGTestOutcome TGPushExtraLineTestKindsThatReadAsANewMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentStory", @{}) isEqualToString:
					@"Marianna shared a story with you"],
			"a story notification says a story was shared, not that there is a new message");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentStory", @{@"is_mention" : @YES}) isEqualToString:
					@"Marianna mentioned you in a story"],
			"being mentioned in a story is a different line from being shown one");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentChatSetTheme", @{@"name" : @"Emerald"}) isEqualToString:
					@"Marianna changed chat theme to Emerald"],
			"a theme change names the theme");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentChatSetTheme", @{@"name" : @""}) isEqualToString:
					@"Marianna disabled chat theme"],
			"an empty theme name is a theme being turned off");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentChatSetBackground", @{@"is_same" : @YES})
					isEqualToString:@"Marianna set the same wallpaper for this chat"],
			"the same wallpaper and a new one read differently");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentChatSetBackground", @{}) isEqualToString:
					@"Marianna set a new wallpaper for this chat"],
			"a new wallpaper reads as a new one");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentRecurringPayment", @{@"amount" : @"$5.00"})
					isEqualToString:@"You were charged $5.00"],
			"a recurring payment names the amount charged");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentProximityAlertTriggered", @{@"distance" : @1500})
					isEqualToString:@"Marianna is now within 1.5 km from you"],
			"a proximity alert reads in kilometres past a thousand metres");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentProximityAlertTriggered", @{@"distance" : @300})
					isEqualToString:@"Marianna is now within 300 m from you"],
			"and in metres below that");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentChecklistTasksAdded", @{@"task_count" : @3})
					isEqualToString:@"Marianna added 3 tasks to the checklist"],
			"added checklist tasks are counted");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentChecklistTasksDone", @{@"task_count" : @1})
					isEqualToString:@"Marianna marked 1 task as done."],
			"one finished task is singular");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentPollOptionAdded", @{@"text" : @"Tuesday"})
					isEqualToString:@"Marianna added the poll option \"Tuesday\""],
			"a new poll option is quoted");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentSuggestProfilePhoto", @{}) isEqualToString:
					@"Suggested Profile Photo"],
			"a suggested photo reads as the chat's own service line does");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentSuggestBirthdate", @{}) isEqualToString:
					@"Suggested Date of Birth"],
			"and so does a suggested birthdate");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentUpgradedGift", @{@"is_upgrade" : @YES})
					isEqualToString:@"Marianna turned a gift into a unique collectible"],
			"an upgraded gift says what happened to it");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentGift", @{@"star_count" : @0}) isEqualToString:
					@"Marianna sent you a gift"],
			"a gift with no stars behind it is simply a gift");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentInviteVideoChatParticipants",
					@{@"is_current_user" : @YES}) isEqualToString:
					@"Marianna invited you to a video chat"],
			"being invited to a video chat is not the same as others being invited");
	TGTestExpectTrue(&outcome,
			[TGPushLine(@"pushMessageContentHidden", @{}) isEqualToString:
					@"You have a new message"],
			"a hidden push is the one kind that really is just a new message");

	TGTestExpectTrue(&outcome, TGPushExtraLine(@{@"@type" : @"pushMessageContentText"}, @"M") == nil,
			"a kind the older path already writes is left to it");
	TGTestExpectTrue(&outcome, TGPushExtraLine(nil, @"M") == nil,
			"no content at all is not a line");

	TGTestExpectTrue(&outcome,
			TGPushExtraLineIsSelfNarrating(@"pushMessageContentRecurringPayment"),
			"a line that does not name its actor must not be prefixed with the sender's name");
	TGTestExpectTrue(&outcome,
			!TGPushExtraLineIsSelfNarrating(@"pushMessageContentSuggestBirthdate"),
			"a bare noun phrase still wants the sender's name in front of it");

	return outcome;
}
