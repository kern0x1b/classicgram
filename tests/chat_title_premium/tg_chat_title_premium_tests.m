#import "tg_chat_title_premium_tests.h"
#import "../../src/Screens/Chat/TGChatTitlePremium.h"

TGTestOutcome TGChatTitlePremiumTestWhoGetsTheStar(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatTitleShowsPremium(@{@"isPremium" : @YES}),
		"a premium account shows the star beside the name");
	TGTestExpectTrue(&outcome, !TGChatTitleShowsPremium(@{@"isPremium" : @NO}),
		"a non-premium account shows no star");
	TGTestExpectTrue(&outcome, !TGChatTitleShowsPremium(@{}),
		"badges without the flag show no star");
	TGTestExpectTrue(&outcome, !TGChatTitleShowsPremium(nil),
		"badges that never arrived show no star");

	return outcome;
}

TGTestOutcome TGChatTitlePremiumTestTheStarSitsAfterTheName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatTitlePremiumRoom(0) == 0,
		"no star asks for no room");
	TGTestExpectTrue(&outcome, TGChatTitlePremiumRoom(16) == 20,
		"a star asks for its own width and the same gap the mute icon uses");

	CGRect frame = TGChatTitlePremiumFrame(200, 100, CGSizeMake(16, 16), 0);
	TGTestExpectTrue(&outcome, frame.origin.x == 154,
		"the star follows the centred name text, four points after it");
	TGTestExpectTrue(&outcome, frame.origin.y == 4,
		"it sits against the name rather than the bar's top edge");
	TGTestExpectTrue(&outcome, frame.size.width == 16 && frame.size.height == 16,
		"the star keeps its icon size");

	CGRect wide = TGChatTitlePremiumFrame(100, 400, CGSizeMake(16, 16), 1);
	TGTestExpectTrue(&outcome, wide.origin.x == 104,
		"a name wider than the title still puts the star right after the title, not inside it");

	return outcome;
}
