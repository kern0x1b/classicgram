#import "tg_message_disappears_tests.h"

#import "../../src/Wire/Flatten/TGDisappearingMedia.h"
#import "../../src/Wire/Flatten/TGFlattenSavedMessages.h"

#import <Foundation/Foundation.h>

static NSDictionary *TGTestSelfDestructing(NSString *kind, NSString *caption) {
	return @{
		@"id" : @11,
		@"self_destruct_type" : @{@"@type" : @"messageSelfDestructTypeImmediately"},
		@"content" : @{@"@type" : kind,
			@"caption" : @{@"@type" : @"formattedText", @"text" : caption ?: @""}},
	};
}

TGTestOutcome TGMessageDisappearsTestTheMessageCarriesTheTimer(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMessageDisappears(TGTestSelfDestructing(@"messagePhoto", @"x")),
			"TDLib puts self_destruct_type on the message, not on the content, so asking "
			"the content alone could never see a photo sent to be seen once");
	TGTestExpectTrue(&outcome,
			!TGMediaContentDisappears(TGTestSelfDestructing(@"messagePhoto", @"x")[@"content"]),
			"and the content on its own says nothing about it");

	return outcome;
}

TGTestOutcome TGMessageDisappearsTestContentStillCounts(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *secret = @{@"id" : @12,
		@"content" : @{@"@type" : @"messageVideo", @"is_secret" : @YES}};

	TGTestExpectTrue(&outcome, TGMessageDisappears(secret),
			"the blur-until-tapped flag on the content is still enough on its own");

	return outcome;
}

TGTestOutcome TGMessageDisappearsTestAnOrdinaryMessageStays(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *ordinary = @{@"id" : @13,
		@"content" : @{@"@type" : @"messagePhoto",
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"the harbour"}}};

	TGTestExpectTrue(&outcome, !TGMessageDisappears(ordinary),
			"an ordinary photo is not disappearing media");
	TGTestExpectTrue(&outcome,
			[TGSavedPreview(ordinary) isEqualToString:@"the harbour"],
			"and its caption is still what a preview shows");

	return outcome;
}

TGTestOutcome TGMessageDisappearsTestAVoiceNoteOnATimerIsNamed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *voice = @{
		@"id" : @14,
		@"self_destruct_type" : @{@"@type" : @"messageSelfDestructTypeTimer",
			@"self_destruct_time" : @60},
		@"content" : @{@"@type" : @"messageVoiceNote",
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"the address is"}},
	};

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(voice) isEqualToString:@"Disappearing Voice Message"],
			"a voice note has no is_secret flag of its own, so only the message-level timer "
			"keeps its caption out of a preview");

	return outcome;
}

TGTestOutcome TGMessageDisappearsTestMissingInputIsHandled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGMessageDisappears(nil), "no message, nothing to hide");
	TGTestExpectTrue(&outcome, !TGMessageDisappears(@{@"id" : @15}),
			"and a message with no content either");
	TGTestExpectTrue(&outcome,
			!TGMessageDisappears(@{@"id" : @16, @"self_destruct_type" : @"immediately"}),
			"a self-destruct type that is not the object TDLib sends is not trusted");

	return outcome;
}
