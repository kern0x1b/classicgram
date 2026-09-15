#import "tg_story_audience_tests.h"
#import "../../src/Utilities/TGStoryAudience.h"

TGTestOutcome TGStoryAudienceTestWhoCanBeLeftOut(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryAudienceAllowsExceptions(@"everyone"),
		"a story for everyone can leave people out");
	TGTestExpectTrue(&outcome, TGStoryAudienceAllowsExceptions(@"contacts"),
		"a story for contacts can leave people out");
	TGTestExpectTrue(&outcome, !TGStoryAudienceAllowsExceptions(@"closeFriends"),
		"close friends is already a list, so nothing is left out of it");
	TGTestExpectTrue(&outcome, !TGStoryAudienceAllowsExceptions(@"selected"),
		"a hand-picked audience names who is in, never who is out");
	TGTestExpectTrue(&outcome, !TGStoryAudienceAllowsExceptions(nil),
		"no audience at all leaves nobody out");

	return outcome;
}

TGTestOutcome TGStoryAudienceTestWhatSurvivesAChangeOfAudience(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *people = @[ @(11), @(22) ];

	TGTestExpectTrue(&outcome,
		TGStoryAudienceExceptionsAfterChange(@"everyone", @"contacts", people) == people,
		"moving between the two audiences that allow exceptions keeps them");
	TGTestExpectTrue(&outcome,
		TGStoryAudienceExceptionsAfterChange(@"everyone", @"closeFriends", people) == nil,
		"an audience that allows no exceptions drops them");
	TGTestExpectTrue(&outcome,
		TGStoryAudienceExceptionsAfterChange(@"selected", @"everyone", people) == nil,
		"a hand-picked list never becomes a list of people to hide from");
	TGTestExpectTrue(&outcome,
		TGStoryAudienceExceptionsAfterChange(@"everyone", @"everyone", @[]) == nil,
		"an empty list of exceptions is no list at all");

	return outcome;
}
