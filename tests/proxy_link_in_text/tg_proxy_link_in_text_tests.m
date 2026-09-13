#import "tg_proxy_link_in_text_tests.h"
#import "../../src/Screens/Settings/TGProxyLinkInText.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGProxyLinkInTextTestFindsTgProxyLinkAndStopsAtWhitespace(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *link = TGProxyLinkInText(@"Check out tg://proxy?server=1.2.3.4&port=443 for a fast connection");

	TGTestExpectTrue(&outcome, [link isEqualToString:@"tg://proxy?server=1.2.3.4&port=443"],
			"the link must be extracted from surrounding prose and cut off at the first whitespace");

	return outcome;
}

TGTestOutcome TGProxyLinkInTextTestMatchIsCaseInsensitive(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *link = TGProxyLinkInText(@"TG://SOCKS?server=example.com&port=1080");

	TGTestExpectTrue(&outcome, [link isEqualToString:@"TG://SOCKS?server=example.com&port=1080"],
			"the needle search must be case-insensitive while the returned text keeps its original casing");

	return outcome;
}

TGTestOutcome TGProxyLinkInTextTestReturnsNilWhenNoKnownLinkIsPresent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *link = TGProxyLinkInText(@"just some ordinary clipboard text with no proxy link in it at all");

	TGTestExpectTrue(&outcome, link == nil,
			"text carrying none of the recognised link prefixes must return nil");

	return outcome;
}

TGTestOutcome TGProxyLinkInTextTestReturnsNilForTextShorterThanTheShortestNeedle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *link = TGProxyLinkInText(@"short");

	TGTestExpectTrue(&outcome, link == nil,
			"text shorter than the eight character floor must return nil rather than attempt a search");

	return outcome;
}

TGTestOutcome TGProxyLinkInTextTestReturnsNilForNonStringInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *link = TGProxyLinkInText((NSString *)[NSNull null]);

	TGTestExpectTrue(&outcome, link == nil,
			"a non-string pasteboard payload must not be treated as text");

	return outcome;
}

TGTestOutcome TGProxyLinkInTextTestDottedCapitalIPrefixDoesNotCrashAndStillMatches(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableString *text = [NSMutableString string];
	for (NSInteger i = 0; i < 20; i++)
		[text appendString:@"İ"];
	NSString *needle = @"TG://Proxy?server=203.0.113.9";
	[text appendString:needle];

	NSString *link = TGProxyLinkInText(text);

	TGTestExpectTrue(&outcome, [link isEqualToString:needle],
			"a dotted capital I prefix lowercases to a longer string; the match must not be computed by mixing a "
			"lowercased copy's indices with the original string, which used to throw an uncaught NSRangeException");

	return outcome;
}
