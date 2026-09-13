#import "tg_search_author_line_tests.h"
#import "../../src/Screens/Search/TGSearchAuthorLine.h"

TGTestOutcome TGSearchAuthorLineTestARowNamesTheSenderOnlyWhenItIsNotTheChat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGSearchResultShowsAuthorLine(@"Marianna", @"Marianna", NO, NO),
			"a message from the person the private chat is with does not repeat their name under it");
	TGTestExpectTrue(&outcome, TGSearchResultShowsAuthorLine(@"Photo Club", @"Marianna", NO, NO),
			"a message in a group names the member who wrote it");
	TGTestExpectTrue(&outcome, TGSearchResultShowsAuthorLine(@"Marianna", @"Marianna", YES, NO),
			"our own message says who wrote it even in a private chat, as the chat list does");
	TGTestExpectTrue(&outcome, !TGSearchResultShowsAuthorLine(@"Photo Club", @"Marianna", NO, YES),
			"searching inside one chat already names the sender in the title, so there is no second line");
	TGTestExpectTrue(&outcome, !TGSearchResultShowsAuthorLine(@"Photo Club", @"Marianna", YES, YES),
			"that holds for our own message inside one chat too");
	TGTestExpectTrue(&outcome, !TGSearchResultShowsAuthorLine(@"Photo Club", @"", NO, NO),
			"a channel post has no sender to name");
	TGTestExpectTrue(&outcome, !TGSearchResultShowsAuthorLine(@"Photo Club", nil, NO, NO),
			"a missing sender is not an author line");
	TGTestExpectTrue(&outcome, !TGSearchResultShowsAuthorLine(@"", @"Marianna", NO, NO),
			"with no chat title to compare against the row stays as it was");
	TGTestExpectTrue(&outcome, !TGSearchResultShowsAuthorLine(nil, @"Marianna", NO, NO),
			"a missing chat title is not an author line either");

	return outcome;
}
