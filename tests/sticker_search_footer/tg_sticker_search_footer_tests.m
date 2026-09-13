#import "tg_sticker_search_footer_tests.h"

#import "../../src/Screens/Stickers/TGStickerSearchFooter.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGStickerSearchFooterTestAFailedSearchSaysSo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStickerSearchFooterText(YES, 0) hasPrefix:@"Sticker sets could not be searched"],
			"a search that never reached the server must not report that the query "
			"matched nothing");

	return outcome;
}

TGTestOutcome TGStickerSearchFooterTestNoMatchesSaysThat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStickerSearchFooterText(NO, 0) isEqualToString:@"No sticker sets found."],
			"a search that came back empty says so");

	return outcome;
}

TGTestOutcome TGStickerSearchFooterTestResultsSayNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStickerSearchFooterText(NO, 3) == nil,
			"with sets on screen the footer stays out of the way");
	TGTestExpectTrue(&outcome, TGStickerSearchFooterText(YES, 3) == nil,
			"and a later failure does not cover sets already found");

	return outcome;
}
