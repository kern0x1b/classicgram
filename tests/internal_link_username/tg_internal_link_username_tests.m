#import "tg_internal_link_username_tests.h"
#import "../../src/TDLibClient/TGInternalLinkUsername.h"

TGTestOutcome TGInternalLinkUsernameTestReadsPublicChatLinks(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGUsernameInInternalPublicChatLink(@"tg://resolve?domain=publicname") isEqualToString:@"publicname"],
			"the username comes out of the internal link TDLib hands back for an account with one");
	TGTestExpectTrue(&outcome,
			[TGUsernameInInternalPublicChatLink(@"tg://resolve?domain=publicname&profile") isEqualToString:@"publicname"],
			"a trailing parameter is not part of the username");
	TGTestExpectTrue(&outcome,
			TGUsernameInInternalPublicChatLink(@"https://t.me/publicname") == nil,
			"a link that is already an https one is left alone");
	TGTestExpectTrue(&outcome, TGUsernameInInternalPublicChatLink(@"tg://resolve?domain=") == nil,
			"an internal link with no username asks for no second lookup");
	TGTestExpectTrue(&outcome, TGUsernameInInternalPublicChatLink(nil) == nil,
			"a missing link is not a username");
	TGTestExpectTrue(&outcome, TGUsernameInInternalPublicChatLink(@"tg://login?token=abc") == nil,
			"another kind of internal link is not a public chat link");

	return outcome;
}
