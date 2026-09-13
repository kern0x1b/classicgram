#import "tg_translation_response_staleness_tests.h"
#import "../../src/Screens/Chat/TGTranslationResponseStaleness.h"

TGTestOutcome TGTranslationResponseStalenessTestPendingKeyIsNotStale(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pending = @{@(42) : @(1)};
	TGTestExpectTrue(&outcome, !TGTranslationResponseIsStale(pending, @(42), @(1)),
			"a translate response whose generation still matches the pending entry must not be treated as stale");

	return outcome;
}

TGTestOutcome TGTranslationResponseStalenessTestClearedKeyIsStale(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pending = @{@(7) : @(1)};
	TGTestExpectTrue(&outcome, TGTranslationResponseIsStale(pending, @(42), @(1)),
			"a translate response for a message whose pending entry was cleared by an edit must be treated as stale");

	return outcome;
}

TGTestOutcome TGTranslationResponseStalenessTestNilKeyIsStale(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pending = @{@(42) : @(1)};
	TGTestExpectTrue(&outcome, TGTranslationResponseIsStale(pending, nil, @(1)),
			"a missing message key must never be treated as still pending");

	return outcome;
}

TGTestOutcome TGTranslationResponseStalenessTestNilGenerationIsStale(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pending = @{@(42) : @(1)};
	TGTestExpectTrue(&outcome, TGTranslationResponseIsStale(pending, @(42), nil),
			"a response with no request generation of its own must never be treated as still pending");

	return outcome;
}

TGTestOutcome TGTranslationResponseStalenessTestNonDictionaryPendingIsStale(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTranslationResponseIsStale((NSDictionary *)@"not a dictionary", @(42), @(1)),
			"a corrupted pending collection must be treated as having nothing pending");

	return outcome;
}

TGTestOutcome TGTranslationResponseStalenessTestEmptyPendingIsStale(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pending = @{};
	TGTestExpectTrue(&outcome, TGTranslationResponseIsStale(pending, @(42), @(1)),
			"once translationsPending is empty, any in-flight response for it must be treated as stale");

	return outcome;
}

TGTestOutcome TGTranslationResponseStalenessTestSupersededGenerationIsStale(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pending = @{@(42) : @(2)};
	TGTestExpectTrue(&outcome, TGTranslationResponseIsStale(pending, @(42), @(1)),
			"a response from an older request must be treated as stale once a newer request for the same message id is in flight");

	return outcome;
}
