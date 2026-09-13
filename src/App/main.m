#import <UIKit/UIKit.h>
#import "AppDelegate.h"

static NSTimeInterval TGImageReadyAt = 0;

__attribute__((constructor)) static void tgNoteImageReady(void) {
	TGImageReadyAt = [NSDate timeIntervalSinceReferenceDate];
}

int main(int argc, char *argv[]) {
	@autoreleasepool {
		TGRedirectLogToFile();
		TGNoteImageReady(TGImageReadyAt);
		TGMarkLaunchStage(@"main");
		return UIApplicationMain(argc, argv, nil,
			NSStringFromClass([AppDelegate class]));
	}
}
