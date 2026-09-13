#import "tg_language_list_text_tests.h"

#import "../../src/Screens/Settings/TGLanguageListText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGLanguageListTextTestAFailedListIsNotAnEmptyOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *failed = TGLanguageListText(YES, YES);
	NSString *empty = TGLanguageListText(YES, NO);
	NSString *loading = TGLanguageListText(NO, NO);

	TGTestExpectTrue(&outcome, ![failed isEqualToString:empty],
			"a language list that could not be fetched no longer claims Telegram offers no "
			"languages");
	TGTestExpectTrue(&outcome, ![loading isEqualToString:failed] && loading.length,
			"and a list still arriving says neither");
	TGTestExpectTrue(&outcome, [failed rangeOfString:@"language"].location != NSNotFound,
			"the failure says what could not be read rather than being a bare error");

	return outcome;
}
