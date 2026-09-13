#import "TGVideoNoteRingResume.h"
#import <math.h>

TGVideoNoteRingResumeAnimation TGVideoNoteRingResumeAnimationForPosition(
		NSTimeInterval elapsedSeconds, NSTimeInterval totalLength, float rate) {
	if (isnan(elapsedSeconds) || elapsedSeconds < 0)
		elapsedSeconds = 0;
	if (totalLength <= 0)
		return (TGVideoNoteRingResumeAnimation){0.0, 0.0};

	double fraction = elapsedSeconds / totalLength;
	if (fraction < 0.0)
		fraction = 0.0;
	if (fraction > 1.0)
		fraction = 1.0;

	NSTimeInterval remaining = totalLength * (1.0 - fraction);
	NSTimeInterval duration = remaining / MAX(0.5f, rate);
	return (TGVideoNoteRingResumeAnimation){fraction, duration};
}
