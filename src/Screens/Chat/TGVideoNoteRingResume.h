#import <Foundation/Foundation.h>

typedef struct {
	double fromFraction;
	NSTimeInterval duration;
} TGVideoNoteRingResumeAnimation;

extern TGVideoNoteRingResumeAnimation TGVideoNoteRingResumeAnimationForPosition(
		NSTimeInterval elapsedSeconds, NSTimeInterval totalLength, float rate);
