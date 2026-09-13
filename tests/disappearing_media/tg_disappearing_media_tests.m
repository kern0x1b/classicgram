#import "tg_disappearing_media_tests.h"
#import "../../src/Wire/Flatten/TGDisappearingMedia.h"

TGTestOutcome TGDisappearingMediaTestEveryPreviewAgreesOnWhatBurns(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMediaContentDisappears(@{@"is_secret" : @YES}),
			"a secret-chat photo disappears");
	TGTestExpectTrue(&outcome,
			TGMediaContentDisappears(@{@"self_destruct_type" :
				@{@"@type" : @"messageSelfDestructTypeImmediately"}}),
			"and so does a view-once one, which the server marks a different way");
	TGTestExpectTrue(&outcome,
			TGMediaContentDisappears(@{@"self_destruct_type" :
				@{@"@type" : @"messageSelfDestructTypeTimer", @"self_destruct_time" : @30}}),
			"a timed self-destruct counts too");
	TGTestExpectTrue(&outcome, !TGMediaContentDisappears(@{@"is_secret" : @NO}),
			"an ordinary message does not");
	TGTestExpectTrue(&outcome, !TGMediaContentDisappears(@{}),
			"nor does one with neither field");
	TGTestExpectTrue(&outcome, !TGMediaContentDisappears(nil),
			"nor no content at all");

	TGTestExpectTrue(&outcome,
			[TGDisappearingMediaLabel(@"messagePhoto") isEqualToString:@"Disappearing Photo"],
			"a photo that burns names itself");
	TGTestExpectTrue(&outcome,
			[TGDisappearingMediaLabel(@"messageVideo") isEqualToString:@"Disappearing Video"],
			"so does a video");
	TGTestExpectTrue(&outcome,
			[TGDisappearingMediaLabel(@"messageVoiceNote")
					isEqualToString:@"Disappearing Voice Message"],
			"so does a voice message");
	TGTestExpectTrue(&outcome,
			[TGDisappearingMediaLabel(@"messageVideoNote")
					isEqualToString:@"Disappearing Video Message"],
			"so does a round note");
	TGTestExpectTrue(&outcome, TGDisappearingMediaLabel(@"messageText") == nil,
			"text has no disappearing form, so the caller falls through to its own wording");
	TGTestExpectTrue(&outcome, TGDisappearingMediaLabel(nil) == nil,
			"and neither does a message with no kind");

	return outcome;
}
