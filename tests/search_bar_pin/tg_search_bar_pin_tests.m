#import "tg_search_bar_pin_tests.h"
#import "../../src/Screens/ChatList/TGSearchBarPin.h"

static const CGFloat kBar = 44.0f;

TGTestOutcome TGSearchBarPinTestAHalfShownSearchBarIsSettled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatListShouldPinSearchBar(20, kBar, kBar, 3610) == YES,
			"a search bar left half shown is settled to its resting place");
	TGTestExpectTrue(&outcome, TGChatListShouldPinSearchBar(0, kBar, kBar, 3610) == YES,
			"a list resting at the very top hides the search bar again");
	TGTestExpectTrue(&outcome, TGChatListShouldPinSearchBar(44, kBar, kBar, 3610) == NO,
			"a list already at rest is not moved");
	TGTestExpectTrue(&outcome, TGChatListShouldPinSearchBar(20, 0, kBar, 3610) == YES,
			"when the search bar is meant to be shown, the same settling happens towards zero");

	return outcome;
}

TGTestOutcome TGSearchBarPinTestAReaderFurtherDownIsLeftAlone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatListShouldPinSearchBar(1544, kBar, kBar, 3610) == NO,
			"a reader fifteen hundred points down a long list keeps their place when the list "
			"reloads under them");
	TGTestExpectTrue(&outcome, TGChatListShouldPinSearchBar(45, kBar, kBar, 3610) == NO,
			"one point past the search bar already counts as reading the list");
	TGTestExpectTrue(&outcome, TGChatListShouldPinSearchBar(10, kBar, kBar, 20) == NO,
			"a list too short to hide its search bar has nothing to settle");

	return outcome;
}
