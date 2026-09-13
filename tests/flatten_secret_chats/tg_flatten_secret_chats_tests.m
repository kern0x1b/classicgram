#import "tg_flatten_secret_chats_tests.h"
#import "../../src/Wire/Flatten/TGFlattenSecretChats.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenSecretChatsTestStateNameForReady(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *secretChat = @{@"state" : @{@"@type" : @"secretChatStateReady"}};

	TGTestExpectTrue(&outcome, [TGScStateName(secretChat) isEqualToString:@"ready"],
			"secretChatStateReady must map to \"ready\"");

	return outcome;
}

TGTestOutcome TGFlattenSecretChatsTestStateNameForClosed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *secretChat = @{@"state" : @{@"@type" : @"secretChatStateClosed"}};

	TGTestExpectTrue(&outcome, [TGScStateName(secretChat) isEqualToString:@"closed"],
			"secretChatStateClosed must map to \"closed\"");

	return outcome;
}

TGTestOutcome TGFlattenSecretChatsTestStateNameFallsBackToPending(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pendingState = @{@"state" : @{@"@type" : @"secretChatStatePending"}};

	TGTestExpectTrue(&outcome, [TGScStateName(pendingState) isEqualToString:@"pending"],
			"secretChatStatePending must fall back to the generic \"pending\" name");
	TGTestExpectTrue(&outcome, [TGScStateName(@{}) isEqualToString:@"pending"],
			"a secret chat with no state at all must fall back to \"pending\", not crash");
	TGTestExpectTrue(&outcome, [TGScStateName(nil) isEqualToString:@"pending"],
			"a nil secret chat must fall back to \"pending\", not crash");

	return outcome;
}

TGTestOutcome TGFlattenSecretChatsTestBase64DecodeValidInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *decoded = TGScBase64Decode(@"TWFu");
	NSData *expected = [@"Man" dataUsingEncoding:NSUTF8StringEncoding];

	TGTestExpectTrue(&outcome, [decoded isEqualToData:expected],
			"a padding-free base64 string must decode to its exact original bytes");

	return outcome;
}

TGTestOutcome TGFlattenSecretChatsTestBase64DecodeEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGScBase64Decode(@"") == nil,
			"an empty string must decode to nil, not an empty NSData or a crash");
	TGTestExpectTrue(&outcome, TGScBase64Decode(nil) == nil,
			"a nil string must decode to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenSecretChatsTestBase64DecodeInputNeedingPadding(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *decoded = TGScBase64Decode(@"SGVsbG8=");
	NSData *expected = [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];

	TGTestExpectTrue(&outcome, [decoded isEqualToData:expected],
			"a base64 string with trailing '=' padding must decode to its exact original bytes");

	return outcome;
}

TGTestOutcome TGFlattenSecretChatsTestBase64DecodeMalformedInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGScBase64Decode(@"!!!@@@") == nil,
			"a string with no valid base64 characters at all must decode to nil");

	NSData *decoded = TGScBase64Decode(@"SGVs bG8=");
	NSData *expected = [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];
	TGTestExpectTrue(&outcome, [decoded isEqualToData:expected],
			"stray non-alphabet characters embedded in an otherwise valid string must be skipped, not corrupt the result");

	return outcome;
}
