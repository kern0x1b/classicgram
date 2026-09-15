#import "tg_chat_title_credibility_tests.h"
#import "../../src/Views/TGChatTitleCredibility.h"

TGTestOutcome TGChatTitleCredibilityTestTheMarkTheHeaderShows(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *scam = @{@"isScam" : @YES, @"isFake" : @NO, @"isVerified" : @NO};
	TGTestExpectTrue(&outcome, [TGChatTitleCredibilityMark(scam) isEqualToString:@"SCAM"],
		"a chat with a scam account says so beside the name, in capitals as Telegram writes it");
	TGTestExpectTrue(&outcome, TGChatTitleCredibilityMarkIsWarning(scam),
		"scam is a warning, not a decoration");

	NSDictionary *fake = @{@"isFake" : @YES, @"isVerified" : @YES};
	TGTestExpectTrue(&outcome, [TGChatTitleCredibilityMark(fake) isEqualToString:@"FAKE"],
		"a fake account is named fake even when it also claims to be verified");
	TGTestExpectTrue(&outcome, TGChatTitleCredibilityMarkIsWarning(fake),
		"fake is a warning too");

	NSDictionary *verified = @{@"isVerified" : @YES};
	TGTestExpectTrue(&outcome, [TGChatTitleCredibilityMark(verified) isEqualToString:@"✓"],
		"a verified account gets the tick");
	TGTestExpectTrue(&outcome, !TGChatTitleCredibilityMarkIsWarning(verified),
		"a tick is not a warning");

	TGTestExpectTrue(&outcome, TGChatTitleCredibilityMark(@{}) == nil,
		"an ordinary chat gets no mark at all");
	TGTestExpectTrue(&outcome, TGChatTitleCredibilityMark(nil) == nil,
		"and neither does a chat whose badges never arrived");
	TGTestExpectTrue(&outcome, !TGChatTitleCredibilityMarkIsWarning(nil),
		"missing badges are not a warning");

	return outcome;
}

TGTestOutcome TGChatTitleCredibilityTestTheMarkSitsAfterTheName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatTitleCredibilityRoom(0) == 0,
		"no mark asks for no room");
	TGTestExpectTrue(&outcome, TGChatTitleCredibilityRoom(30) == 34,
		"a mark asks for its own width and the same gap the mute icon uses");

	CGRect frame = TGChatTitleCredibilityFrame(200, 100, CGSizeMake(34, 13), 0);
	TGTestExpectTrue(&outcome, frame.origin.x == 154,
		"the mark follows the centred name text, four points after it");
	TGTestExpectTrue(&outcome, frame.origin.y == 3,
		"it sits against the name rather than the bar's top edge");
	TGTestExpectTrue(&outcome, frame.size.width == 34 && frame.size.height == 13,
		"the mark keeps its measured size");

	CGRect wide = TGChatTitleCredibilityFrame(100, 400, CGSizeMake(34, 13), 1);
	TGTestExpectTrue(&outcome, wide.origin.x == 104,
		"a name wider than the title still puts the mark right after the title, not inside it");

	return outcome;
}
