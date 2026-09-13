#import "tg_link_preview_fetch_decision_tests.h"
#import "../../src/Screens/Chat/TGLinkPreviewFetchDecision.h"

TGTestOutcome TGLinkPreviewFetchDecisionTestEmptyTextIsNotCandidate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGLinkPreviewFetchCandidateText(@""),
			"empty text must never trigger a link preview fetch");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestNilTextIsNotCandidate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGLinkPreviewFetchCandidateText(nil),
			"nil text must never trigger a link preview fetch");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestPlainTextIsCandidate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGLinkPreviewFetchCandidateText(@"hello there"),
			"ordinary text with no obvious scheme must still be attempted, since TDLib decides");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestBareDomainTextIsCandidate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGLinkPreviewFetchCandidateText(@"example.com/path"),
			"a bare domain with no http prefix must be attempted, since TDLib can still find it");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestNilOptionsAreNotDisabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGLinkPreviewOptionsAreDisabled(nil),
			"a message with no stored options must not be treated as disabled");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestNonDictionaryOptionsAreNotDisabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGLinkPreviewOptionsAreDisabled((NSDictionary *)[NSNull null]),
			"NSNull stored options (the flattener's placeholder) must not be treated as disabled");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestExplicitIsDisabledTrueIsDisabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *options = @{@"is_disabled" : @YES};
	TGTestExpectTrue(&outcome, TGLinkPreviewOptionsAreDisabled(options),
			"a sender's explicit is_disabled must be honored on redisplay");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestExplicitIsDisabledFalseIsNotDisabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *options = @{@"is_disabled" : @NO};
	TGTestExpectTrue(&outcome, !TGLinkPreviewOptionsAreDisabled(options),
			"an explicit is_disabled of false must not suppress the preview");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestMissingIsDisabledKeyIsNotDisabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *options = @{@"url" : @"https://example.com"};
	TGTestExpectTrue(&outcome, !TGLinkPreviewOptionsAreDisabled(options),
			"a missing is_disabled key must default to not disabled");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestNilOptionsProduceDefaultValues(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *values = TGLinkPreviewOptionValuesFromMessage(nil);
	TGTestExpectTrue(&outcome, [values[TGLinkPreviewOptionURL] isEqualToString:@""],
			"nil options must fall back to an empty url so TDLib finds the first link itself");
	TGTestExpectTrue(&outcome, ![values[TGLinkPreviewOptionForceSmallMedia] boolValue],
			"nil options must not force small media");
	TGTestExpectTrue(&outcome, ![values[TGLinkPreviewOptionForceLargeMedia] boolValue],
			"nil options must not force large media");
	TGTestExpectTrue(&outcome, ![values[TGLinkPreviewOptionShowAboveText] boolValue],
			"nil options must not show the preview above the text");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestNonDictionaryOptionsProduceDefaultValues(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *values = TGLinkPreviewOptionValuesFromMessage((NSDictionary *)[NSNull null]);
	TGTestExpectTrue(&outcome, [values[TGLinkPreviewOptionURL] isEqualToString:@""],
			"NSNull options must fall back to the same defaults as nil");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestValuesEchoStoredUrlAndFlags(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *options = @{
		@"url" : @"https://example.com/chosen",
		@"force_small_media" : @NO,
		@"force_large_media" : @YES,
		@"show_above_text" : @YES,
	};
	NSDictionary *values = TGLinkPreviewOptionValuesFromMessage(options);
	TGTestExpectTrue(&outcome,
			[values[TGLinkPreviewOptionURL] isEqualToString:@"https://example.com/chosen"],
			"the sender's chosen url must be echoed back exactly, not discarded");
	TGTestExpectTrue(&outcome, [values[TGLinkPreviewOptionForceLargeMedia] boolValue],
			"the sender's forced large media choice must be echoed back");
	TGTestExpectTrue(&outcome, ![values[TGLinkPreviewOptionForceSmallMedia] boolValue],
			"force_small_media must be read independently of force_large_media");
	TGTestExpectTrue(&outcome, [values[TGLinkPreviewOptionShowAboveText] boolValue],
			"the sender's show-above-text position must be echoed back");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestMissingUrlKeyFallsBackToEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *options = @{@"force_small_media" : @YES};
	NSDictionary *values = TGLinkPreviewOptionValuesFromMessage(options);
	TGTestExpectTrue(&outcome, [values[TGLinkPreviewOptionURL] isEqualToString:@""],
			"a missing url key must fall back to empty, not nil, so it stays a valid request field");

	return outcome;
}

TGTestOutcome TGLinkPreviewFetchDecisionTestNonStringUrlFallsBackToEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *options = @{@"url" : [NSNull null]};
	NSDictionary *values = TGLinkPreviewOptionValuesFromMessage(options);
	TGTestExpectTrue(&outcome, [values[TGLinkPreviewOptionURL] isEqualToString:@""],
			"a non-string url value must not be passed through as-is");

	return outcome;
}
