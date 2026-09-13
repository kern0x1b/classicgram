#import "tg_quote_body_text_tests.h"
#import "../../src/Screens/Chat/TGQuoteBodyText.h"

TGTestOutcome TGQuoteBodyTextTestAReplyToADeletedMessageStillSaysSo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGQuoteBodyText(@"the quoted words", @"whatever was fetched", NO)
					isEqualToString:@"the quoted words"],
			"a quote the server sent inline is what the bar shows");
	TGTestExpectTrue(&outcome,
			[TGQuoteBodyText(nil, @"the original message", NO)
					isEqualToString:@"the original message"],
			"otherwise the fetched original fills the bar");
	TGTestExpectTrue(&outcome, [TGQuoteBodyText(nil, nil, NO) isEqualToString:@"..."],
			"a reply whose original has not arrived yet holds the bar open with an ellipsis");
	TGTestExpectTrue(&outcome,
			[TGQuoteBodyText(nil, nil, YES) isEqualToString:@"Deleted message"],
			"a reply to a message that is gone says so, where returning nothing dropped the "
			"reply bar entirely and the message read as if it replied to nobody");
	TGTestExpectTrue(&outcome,
			[TGQuoteBodyText(@"", @"", YES) isEqualToString:@"Deleted message"],
			"empty strings count as nothing, not as a quote of nothing");
	TGTestExpectTrue(&outcome,
			[TGQuoteBodyText(@"the quoted words", nil, YES)
					isEqualToString:@"the quoted words"],
			"a manual quote survives the original's deletion, which is the point of quoting");

	return outcome;
}
