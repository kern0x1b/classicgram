#import "TGPendingRunShift.h"

NSValue *TGPendingRunRangeAfterEdit(NSRange runRange, NSRange editRange,
	NSInteger replacementLength) {
	NSInteger delta = replacementLength - (NSInteger)editRange.length;

	if (NSMaxRange(editRange) <= runRange.location) {
		NSRange shifted = NSMakeRange((NSUInteger)((NSInteger)runRange.location + delta),
			runRange.length);
		return [NSValue valueWithRange:shifted];
	}

	if (editRange.location >= NSMaxRange(runRange))
		return [NSValue valueWithRange:runRange];

	if (runRange.location <= editRange.location && NSMaxRange(editRange) <= NSMaxRange(runRange)) {
		NSInteger shrunkLength = (NSInteger)runRange.length + delta;
		if (shrunkLength <= 0)
			return nil;
		return [NSValue valueWithRange:NSMakeRange(runRange.location, (NSUInteger)shrunkLength)];
	}

	return nil;
}
