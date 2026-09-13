#import "tg_flood_wait_notice_tests.h"

#import "../../src/Utilities/TGFloodWaitText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGFloodWaitNoticeTestSecondsAndMinutes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFloodWaitNoticeText(0) == nil,
			"a result with no wait in it says nothing, so an ordinary error is still an "
			"ordinary error");
	TGTestExpectTrue(&outcome, TGFloodWaitNoticeText(-5) == nil,
			"and a nonsense wait says nothing either");
	TGTestExpectTrue(&outcome,
			[TGFloodWaitNoticeText(30) rangeOfString:@"30"].location != NSNotFound,
			"a wait under a minute is counted in seconds, so the reader knows it is seconds "
			"rather than something broken");
	TGTestExpectTrue(&outcome,
			[TGFloodWaitNoticeText(3600) rangeOfString:@"60"].location != NSNotFound,
			"an hour reads as sixty minutes rather than 3600 seconds");
	TGTestExpectTrue(&outcome,
			[TGFloodWaitNoticeText(61) rangeOfString:@"2"].location != NSNotFound,
			"and a wait just over a minute rounds up rather than down, so the reader does not "
			"come back too early");

	return outcome;
}
