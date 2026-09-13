#import "tg_stars_action_tests.h"

#import "../../src/Screens/Stars/TGStarsAction.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGStarsActionTestADestructiveActionSaysSo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *convert = TGStarsAction(@"Convert to Stars", @"400 Stars", YES, NULL);

	TGTestExpectTrue(&outcome, [convert[@"destructive"] boolValue],
			"an action that takes something away is marked, which is what decides whether its "
			"row is red");
	TGTestExpectTrue(&outcome, [convert[@"value"] isEqualToString:@"400 Stars"],
			"and it keeps the value shown on its right, which is why such a row stays a row "
			"rather than becoming the red plate");

	return outcome;
}

TGTestOutcome TGStarsActionTestAnActionWithNoValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *plain = TGStarsAction(nil, @"", NO, NULL);

	TGTestExpectTrue(&outcome, [plain[@"title"] isEqualToString:@""],
			"an action with no title of its own is given an empty one rather than nothing, so "
			"a row never draws (null)");
	TGTestExpectTrue(&outcome, plain[@"value"] == nil,
			"an empty value is no value at all");
	TGTestExpectTrue(&outcome, plain[@"destructive"] == nil,
			"and an ordinary action carries no destructive mark to be misread");

	return outcome;
}
