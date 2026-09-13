#import "tg_story_viewers_footer_tests.h"

#import "../../src/Screens/Stories/TGStoryViewersFooter.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGStoryViewersFooterTestAFailedLoadSaysSo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = TGStoryViewersFooterText(YES, YES, 0);

	TGTestExpectTrue(&outcome, [text isEqualToString:@"The list of viewers could not be loaded."],
			"a viewer list that could not be loaded must say so, where before the screen "
			"drew an empty table that reads as nobody having seen the story");

	return outcome;
}

TGTestOutcome TGStoryViewersFooterTestAnEmptyListIsNotAFailure(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryViewersFooterText(YES, NO, 0) isEqualToString:@"Nobody has seen this story yet."],
			"a story nobody has opened says that instead");
	TGTestExpectTrue(&outcome,
			[TGStoryViewersFooterText(NO, NO, 0) isEqualToString:@"Loading…"],
			"and a list still being fetched says neither");

	return outcome;
}

TGTestOutcome TGStoryViewersFooterTestRowsSayNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStoryViewersFooterText(YES, NO, 3) isEqualToString:@""],
			"with viewers on screen the footer is out of the way");

	return outcome;
}

TGTestOutcome TGStoryViewersFooterTestRowsOutrankALaterFailure(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStoryViewersFooterText(YES, YES, 3) isEqualToString:@""],
			"a page that failed after viewers were already listed must not replace them "
			"with a failure notice");

	return outcome;
}
