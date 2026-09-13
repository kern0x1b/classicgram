#import "tg_shared_media_visibility_tests.h"

#import "../../src/Screens/Media/TGSharedMediaVisibility.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGSharedMediaVisibilityTestOrdinaryMediaIsListed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSharedMediaShowsContent(@{
			@"@type" : @"messagePhoto",
			@"photo" : @{@"sizes" : @[]},
		}), "an ordinary photo belongs in Shared Media");
	TGTestExpectTrue(&outcome, TGSharedMediaShowsContent(@{@"@type" : @"messageDocument"}),
			"and so does a file");

	return outcome;
}

TGTestOutcome TGSharedMediaVisibilityTestViewOnceMediaIsNot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGSharedMediaShowsContent(@{
			@"@type" : @"messagePhoto",
			@"self_destruct_type" : @{@"@type" : @"messageSelfDestructTypeImmediately"},
		}), "a photo meant to be seen once must not sit in Shared Media afterwards, "
			"where its thumbnail can be opened again");
	TGTestExpectTrue(&outcome, !TGSharedMediaShowsContent(@{
			@"@type" : @"messageVideo",
			@"self_destruct_type" : @{@"@type" : @"messageSelfDestructTypeTimer",
				@"self_destruct_time" : @30},
		}), "and neither does a video on a timer");

	return outcome;
}

TGTestOutcome TGSharedMediaVisibilityTestSecretMediaIsNot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGSharedMediaShowsContent(@{
			@"@type" : @"messagePhoto",
			@"is_secret" : @YES,
		}), "secret-chat media is not shared media either");

	return outcome;
}

TGTestOutcome TGSharedMediaVisibilityTestMissingContentIsNotListed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGSharedMediaShowsContent(nil),
			"a message with no content at all has nothing to list");
	TGTestExpectTrue(&outcome, !TGSharedMediaShowsContent((id)@"messagePhoto"),
			"and neither has something that is not a content dictionary");

	return outcome;
}
