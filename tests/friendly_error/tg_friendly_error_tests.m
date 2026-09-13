#import "tg_friendly_error_tests.h"
#import "../../src/Utilities/TGFriendlyError.h"

TGTestOutcome TGFriendlyErrorTestServerCodesNeverReachTheReader(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	NSString *fallback = @"That could not be saved.";

	TGTestExpectTrue(&outcome, TGErrorMessageIsMachineCode(@"CHAT_ADMIN_REQUIRED"),
		"a screaming snake-case code is a machine code");
	TGTestExpectTrue(&outcome, TGErrorMessageIsMachineCode(@"FLOOD"),
		"a short all-capitals word with no underscore is one too");
	TGTestExpectTrue(&outcome, !TGErrorMessageIsMachineCode(@"Chat not found"),
		"a sentence TDLib wrote for a person is not a machine code");
	TGTestExpectTrue(&outcome, !TGErrorMessageIsMachineCode(@""),
		"an empty message is not a code");
	TGTestExpectTrue(&outcome, !TGErrorMessageIsMachineCode(nil),
		"and neither is nothing at all");

	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"USER_PRIVACY_RESTRICTED", fallback)
			isEqualToString:@"This person's privacy settings do not allow that."],
		"a code the client knows becomes the sentence Telegram would show");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"FLOOD_WAIT_42", fallback)
			isEqualToString:@"Too many attempts. Please try again later."],
		"a flood wait is recognised by its prefix, whatever the number");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"Too Many Requests: retry after 47", fallback)
			rangeOfString:@"47"].location != NSNotFound,
		"the wording TDLib actually sends - 'Too Many Requests: retry after 47' - is read as a "
		"wait and answered with the number of seconds, rather than being handed to the reader "
		"as it arrived");
	TGTestExpectTrue(&outcome,
		[[TGFriendlyErrorText(@"Too Many Requests: retry after 300", fallback)
			lowercaseString] rangeOfString:@"minute"].location != NSNotFound,
		"and a long wait is counted in minutes");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"Too Many Requests: retry after 47", fallback)
			rangeOfString:@"retry after"].location == NSNotFound,
		"no part of the wire wording reaches the screen");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"CHAT_WRITE_FORBIDDEN", fallback)
			isEqualToString:@"You are not allowed to do that here."],
		"several codes that mean the same thing read the same way");

	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"FILTER_SLUG_INVALID", fallback) isEqualToString:fallback],
		"a code the client has never seen falls back to the screen's own sentence rather than "
		"showing the reader a server constant");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"", fallback) isEqualToString:fallback],
		"an empty message falls back too");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(nil, fallback) isEqualToString:fallback],
		"and so does a missing one");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"Chat not found", fallback)
			isEqualToString:@"That chat could not be reached."],
		"the sentences TDLib writes are English whatever language the app is in, so the ones it "
		"sends often are translated here rather than passed through");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"Have no rights to send a message", fallback)
			isEqualToString:@"You are not allowed to do that here."],
		"a TDLib sentence and the wire code that means the same thing read the same way");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"Some sentence we have never seen", fallback)
			isEqualToString:@"Some sentence we have never seen"],
		"a sentence the client does not know is still shown as written, since it is the only "
		"thing there is to say");
	TGTestExpectTrue(&outcome,
		[TGFriendlyErrorText(@"PEER_FLOOD", nil)
			isEqualToString:@"An error occurred, please try again later."],
		"with no fallback to hand there is still a sentence rather than a code");

	return outcome;
}
