#import "tg_launch_screen_choice_tests.h"
#import "../../src/App/TGLaunchScreenChoice.h"

TGTestOutcome TGLaunchScreenChoiceTestShowsTheScreenTheAuthStateAsksFor(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateWaitPhoneNumber, NO) == TGLaunchScreenLogin,
			"a client waiting for a phone number opens on the login screen");
	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateWaitCode, NO) == TGLaunchScreenLogin,
			"a client waiting for a code opens on the login screen");
	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateWaitPassword, YES) == TGLaunchScreenLogin,
			"a two-step password is asked for even when the device was signed in before");
	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateWaitRegistration, NO) == TGLaunchScreenLogin,
			"a client that still has to register opens on the login screen");
	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateReady, NO) == TGLaunchScreenMain,
			"an authorized client opens on the chat list");
	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateLoggingOut, YES) == TGLaunchScreenLogin,
			"logging out leaves the login screen, not the chat list");
	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateClosed, YES) == TGLaunchScreenLogin,
			"a closed client leaves the login screen");

	return outcome;
}

TGTestOutcome TGLaunchScreenChoiceTestOnlySpinsWhileTheStateIsUnknown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateUnknown, NO) == TGLaunchScreenLoading,
			"a first launch with no state yet spins");
	TGTestExpectTrue(&outcome,
			TGLaunchScreenForAuthState(TGAuthStateUnknown, YES) == TGLaunchScreenMain,
			"a device that was signed in shows its cached chats instead of a spinner");

	return outcome;
}
