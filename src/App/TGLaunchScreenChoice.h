#ifndef TG_LAUNCH_SCREEN_CHOICE_H
#define TG_LAUNCH_SCREEN_CHOICE_H

#import <Foundation/Foundation.h>
#import "TGAuthState.h"

typedef NS_ENUM(NSInteger, TGLaunchScreen) {
	TGLaunchScreenLoading = 0,
	TGLaunchScreenLogin,
	TGLaunchScreenMain,
};

TGLaunchScreen TGLaunchScreenForAuthState(TGAuthState state, BOOL wasSignedIn);

#endif
