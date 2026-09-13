#import "tg_failed_message_title_tests.h"

#import "../../src/Screens/Chat/TGFailedMessageTitle.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGFailedMessageTitleTestAWireCodeIsNeverShown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGFailedMessageTitle(@"CHAT_WRITE_FORBIDDEN")
					isEqualToString:@"You are not allowed to do that here."],
			"tapping a message that failed to send titled the sheet with the wire's own "
			"code, which is not a sentence anyone can act on");
	TGTestExpectTrue(&outcome,
			[TGFailedMessageTitle(@"USER_PRIVACY_RESTRICTED")
					isEqualToString:@"This person's privacy settings do not allow that."],
			"and a privacy refusal reads as one");
	TGTestExpectTrue(&outcome,
			[TGFailedMessageTitle(@"SOME_CODE_NOBODY_MAPPED")
					isEqualToString:@"This message was not sent"],
			"a code nothing maps falls back to the plain sentence rather than showing itself");

	return outcome;
}

TGTestOutcome TGFailedMessageTitleTestASentenceIsKept(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *slowMode = @"Slow mode is active. Try again in 30 seconds";

	TGTestExpectTrue(&outcome, [TGFailedMessageTitle(slowMode) isEqualToString:slowMode],
			"a reason already written as a sentence - slow mode, a paid-message price - "
			"reaches the sheet unchanged");

	return outcome;
}

TGTestOutcome TGFailedMessageTitleTestNoReasonFallsBack(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGFailedMessageTitle(nil) isEqualToString:@"This message was not sent"],
			"a failure with no reason at all still titles the sheet");
	TGTestExpectTrue(&outcome,
			[TGFailedMessageTitle(@"") isEqualToString:@"This message was not sent"],
			"and so does an empty one");

	return outcome;
}
