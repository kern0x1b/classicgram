#import "tg_chat_title_mute_tests.h"
#import "../../src/Screens/Chat/TGChatTitleMute.h"

TGTestOutcome TGChatTitleMuteTestTitleMakesRoomForTheIcon(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatTitleWidthWithMuteIcon(120, 20, 300) == 120,
		"a title with room to spare keeps its width");
	TGTestExpectTrue(&outcome, TGChatTitleWidthWithMuteIcon(300, 20, 300) == 276,
		"a title that fills the bar gives the icon its width and the gap");
	TGTestExpectTrue(&outcome, TGChatTitleWidthWithMuteIcon(300, 20, 20) == 20,
		"a bar too narrow for both still leaves a readable title rather than a negative width");

	return outcome;
}

TGTestOutcome TGChatTitleMuteTestIconSitsAfterTheName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGRect frame = TGChatTitleMuteIconFrame(200, 100, CGSizeMake(20, 22), 0);
	TGTestExpectTrue(&outcome, frame.origin.x == 154,
		"the icon follows the centred name text, four points after it");
	TGTestExpectTrue(&outcome, frame.origin.y == 6,
		"the icon sits six points below the name's top, as the original places it");
	TGTestExpectTrue(&outcome, frame.size.width == 20 && frame.size.height == 22,
		"the icon keeps its own size");

	CGRect clipped = TGChatTitleMuteIconFrame(200, 400, CGSizeMake(20, 22), 1);
	TGTestExpectTrue(&outcome, clipped.origin.x == 204,
		"a name wider than the title is measured at the title's width, not its own");
	TGTestExpectTrue(&outcome, clipped.origin.y == 7,
		"the icon follows the name's top wherever it is");

	return outcome;
}
