#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGAuthState) {
	TGAuthStateUnknown = 0,
	TGAuthStateWaitPhoneNumber,
	TGAuthStateWaitCode,
	TGAuthStateWaitEmailAddress,
	TGAuthStateWaitEmailCode,
	TGAuthStateWaitPassword,
	TGAuthStateWaitRegistration,
	TGAuthStateReady,
	TGAuthStateLoggingOut,
	TGAuthStateClosed
};
