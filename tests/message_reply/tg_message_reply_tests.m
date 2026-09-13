#import "tg_message_reply_tests.h"
#import "../../src/TDLibClient/TGMessageReply.h"

TGTestOutcome TGMessageReplyTestNoReplyMeansNoReplyTo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGReplyToDictionary(0, @"quoted", nil, 3) == nil,
		"a message that replies to nothing must carry no reply_to, quote or not");

	return outcome;
}

TGTestOutcome TGMessageReplyTestAPlainReplyCarriesOnlyTheMessageId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *replyTo = TGReplyToDictionary(4149609075835084LL, nil, nil, 0);

	TGTestExpectTrue(&outcome,
		[replyTo[@"@type"] isEqualToString:@"inputMessageReplyToMessage"],
		"a reply names the inputMessageReplyToMessage constructor");
	TGTestExpectEqualLongLong(&outcome, [replyTo[@"message_id"] longLongValue], 4149609075835084LL,
		"the message id survives as a 64-bit value");
	TGTestExpectTrue(&outcome, replyTo[@"quote"] == nil,
		"a reply without a quote must not carry an empty quote");
	TGTestExpectTrue(&outcome, TGReplyToDictionary(7, @"", nil, 0)[@"quote"] == nil,
		"an empty quote text is the same as no quote");

	return outcome;
}

TGTestOutcome TGMessageReplyTestAQuotedReplyCarriesTheQuoteAndItsEntities(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[ @{@"@type" : @"textEntity",
		@"offset" : @0,
		@"length" : @4} ];
	NSDictionary *replyTo = TGReplyToDictionary(7, @"quoted words", entities, 11);
	NSDictionary *quote = replyTo[@"quote"];

	TGTestExpectTrue(&outcome, [quote[@"@type"] isEqualToString:@"inputTextQuote"],
		"the quote names the inputTextQuote constructor");
	TGTestExpectTrue(&outcome, [quote[@"text"][@"text"] isEqualToString:@"quoted words"],
		"the quoted text is carried as a formattedText");
	TGTestExpectEqualLongLong(&outcome, (long long)[quote[@"text"][@"entities"] count], 1,
		"the quote's own entities are carried with it");
	TGTestExpectEqualLongLong(&outcome, [quote[@"position"] longLongValue], 11,
		"the position of the quote inside the replied-to message is carried");

	NSDictionary *withoutEntities = TGReplyToDictionary(7, @"quoted words", @[], 0);
	TGTestExpectTrue(&outcome, withoutEntities[@"quote"][@"text"][@"entities"] == nil,
		"an empty entity list is left out rather than sent as an empty array");

	return outcome;
}
