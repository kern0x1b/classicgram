#import "TGLaunchScreenChoice.h"

TGLaunchScreen TGLaunchScreenForAuthState(TGAuthState state, BOOL wasSignedIn) {
	switch (state) {
		case TGAuthStateReady:
			return TGLaunchScreenMain;
		case TGAuthStateWaitPhoneNumber:
		case TGAuthStateWaitCode:
		case TGAuthStateWaitEmailAddress:
		case TGAuthStateWaitEmailCode:
		case TGAuthStateWaitPassword:
		case TGAuthStateWaitRegistration:
		case TGAuthStateLoggingOut:
		case TGAuthStateClosed:
			return TGLaunchScreenLogin;
		default:
			return wasSignedIn ? TGLaunchScreenMain : TGLaunchScreenLoading;
	}
}
