#import "tg_redacted_request_logging_tests.h"
#import "../../src/TDLibClient/TGRedactedRequestForLogging.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGRedactedRequestLoggingTestRedactsPlainPasswordField(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *request = @{
		@"@type" : @"checkAuthenticationPassword",
		@"password" : @"hunter2",
	};
	NSDictionary *redacted = TGRedactedRequestForLogging(request);

	TGTestExpectTrue(&outcome, ![redacted[@"password"] isEqualToString:@"hunter2"],
			"the plaintext password must not survive into the redacted copy");
	TGTestExpectTrue(&outcome, [redacted[@"@type"] isEqualToString:@"checkAuthenticationPassword"],
			"non-sensitive fields must pass through unchanged");

	return outcome;
}

TGTestOutcome TGRedactedRequestLoggingTestRedactsOldAndNewPasswordFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *request = @{
		@"@type" : @"setPassword",
		@"old_password" : @"correct-horse",
		@"new_password" : @"battery-staple",
		@"hint" : @"a hint",
	};
	NSDictionary *redacted = TGRedactedRequestForLogging(request);

	TGTestExpectTrue(&outcome, ![redacted[@"old_password"] isEqualToString:@"correct-horse"],
			"old_password must be redacted");
	TGTestExpectTrue(&outcome, ![redacted[@"new_password"] isEqualToString:@"battery-staple"],
			"new_password must be redacted");
	TGTestExpectTrue(&outcome, [redacted[@"hint"] isEqualToString:@"a hint"],
			"fields that are not password-shaped must be left alone");

	return outcome;
}

TGTestOutcome TGRedactedRequestLoggingTestLeavesRequestWithoutPasswordFieldsUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *request = @{
		@"@type" : @"getAuthorizationState",
	};
	NSDictionary *redacted = TGRedactedRequestForLogging(request);

	TGTestExpectTrue(&outcome, [redacted isEqualToDictionary:request],
			"a request carrying no password-shaped field must come back unchanged");

	return outcome;
}

TGTestOutcome TGRedactedRequestLoggingTestLeavesNonStringPasswordValueUnredacted(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *request = @{
		@"@type" : @"weirdRequest",
		@"password" : @(1),
	};
	NSDictionary *redacted = TGRedactedRequestForLogging(request);

	TGTestExpectTrue(&outcome, [redacted[@"password"] isEqual:@(1)],
			"a non-string value under a password-shaped key must not crash the redaction and is left as-is");

	return outcome;
}

TGTestOutcome TGRedactedRequestLoggingTestDoesNotMutateTheOriginalRequest(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *request = @{
		@"@type" : @"deleteAccount",
		@"password" : @"hunter2",
	};
	TGRedactedRequestForLogging(request);

	TGTestExpectTrue(&outcome, [request[@"password"] isEqualToString:@"hunter2"],
			"the caller's original request dictionary must be untouched");

	return outcome;
}

TGTestOutcome TGRedactedRequestLoggingTestRedactsPasswordNestedInsideAPayloadDictionary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *request = @{
		@"@type" : @"getCallbackQueryAnswer",
		@"chat_id" : @(1),
		@"message_id" : @(2),
		@"payload" : @{
			@"@type" : @"callbackQueryPayloadDataWithPassword",
			@"password" : @"hunter2",
			@"data" : @"abc",
		},
	};
	NSDictionary *redacted = TGRedactedRequestForLogging(request);
	NSDictionary *redactedPayload = redacted[@"payload"];

	TGTestExpectTrue(&outcome, ![redactedPayload[@"password"] isEqualToString:@"hunter2"],
			"a password nested one level down inside a payload dictionary must also be redacted");
	TGTestExpectTrue(&outcome, [redactedPayload[@"data"] isEqualToString:@"abc"],
			"non-sensitive fields inside the nested dictionary must pass through unchanged");
	TGTestExpectTrue(&outcome, [request[@"payload"][@"password"] isEqualToString:@"hunter2"],
			"the caller's original nested payload dictionary must be untouched");

	return outcome;
}

TGTestOutcome TGRedactedRequestLoggingTestRedactsMtprotoProxySecretField(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *request = @{
		@"@type" : @"addProxy",
		@"proxy" : @{
			@"@type" : @"proxy",
			@"server" : @"proxy.example.com",
			@"port" : @(443),
			@"type" : @{
				@"@type" : @"proxyTypeMtproto",
				@"secret" : @"dc00112233445566778899aabbccddeeff",
			},
		},
		@"enable" : @YES,
	};
	NSDictionary *redacted = TGRedactedRequestForLogging(request);
	NSDictionary *redactedType = redacted[@"proxy"][@"type"];

	TGTestExpectTrue(&outcome, ![redactedType[@"secret"] isEqualToString:@"dc00112233445566778899aabbccddeeff"],
			"an MTProto proxy's secret must be redacted the same way a password is");
	TGTestExpectTrue(&outcome, [redacted[@"proxy"][@"server"] isEqualToString:@"proxy.example.com"],
			"non-sensitive fields alongside the secret must pass through unchanged");

	return outcome;
}
