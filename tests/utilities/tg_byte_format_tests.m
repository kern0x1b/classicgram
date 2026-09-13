#import "tg_byte_format_tests.h"
#import "../../src/Utilities/TGByteFormat.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGByteFormatTestZeroBytes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGMediaFormatBytes(0);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"0 B"],
			"zero bytes must format as 0 B");

	return outcome;
}

TGTestOutcome TGByteFormatTestSmallValueUnderKilobyte(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMediaFormatBytes(512) isEqualToString:@"512 B"],
			"a value well under 1024 must be reported verbatim in bytes");
	TGTestExpectTrue(&outcome, [TGMediaFormatBytes(1023) isEqualToString:@"1023 B"],
			"the byte just below the kilobyte boundary must still format in bytes");

	return outcome;
}

TGTestOutcome TGByteFormatTestExactlyAtKilobyteBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGMediaFormatBytes(1024);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"1 KB"],
			"1024 bytes is the smallest value reported in kilobytes, with no decimal place");

	return outcome;
}

TGTestOutcome TGByteFormatTestMidRangeKilobytesRounds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMediaFormatBytes(1600) isEqualToString:@"2 KB"],
			"a fractional kilobyte count must round to the nearest whole kilobyte");
	TGTestExpectTrue(&outcome, [TGMediaFormatBytes(51200) isEqualToString:@"50 KB"],
			"an exact multiple of 1024 bytes must format as a whole kilobyte count");

	return outcome;
}

TGTestOutcome TGByteFormatTestExactlyAtMegabyteBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGMediaFormatBytes(1024LL * 1024LL);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"1.0 MB"],
			"1024 kilobytes is the smallest value reported in megabytes, with one decimal place");

	return outcome;
}

TGTestOutcome TGByteFormatTestMidRangeMegabytes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGMediaFormatBytes(2621440);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"2.5 MB"],
			"a mid-range megabyte value must keep exactly one decimal place");

	return outcome;
}

TGTestOutcome TGByteFormatTestExactlyAtGigabyteBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGMediaFormatBytes(1024LL * 1024LL * 1024LL);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"1.00 GB"],
			"1024 megabytes is the smallest value reported in gigabytes, with two decimal places");

	return outcome;
}

TGTestOutcome TGByteFormatTestLargeGigabyteValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGMediaFormatBytes(5637144576LL);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"5.25 GB"],
			"a large gigabyte value must keep exactly two decimal places");

	return outcome;
}

TGTestOutcome TGByteFormatTestRoundingCrossesIntoNextUnit(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGMediaFormatBytes(1048500LL);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"1.0 MB"],
			"a kilobyte value that rounds up to 1024 must be reported as the next unit instead of 1024 KB");

	return outcome;
}
