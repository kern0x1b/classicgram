#import "tg_downloads_update_tests.h"

#import "../../src/Wire/Flatten/TGDownloadsUpdate.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGDownloadsUpdateTestSummaryReadsTheTotals(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *summary = TGDownloadsSummaryFromUpdate(@{
		@"@type" : @"updateFileDownloads",
		@"total_size" : @4194304,
		@"total_count" : @3,
		@"downloaded_size" : @1048576,
	});

	TGTestExpectTrue(&outcome, [summary[@"totalSize"] longLongValue] == 4194304,
			"the size of everything queued comes across");
	TGTestExpectTrue(&outcome, [summary[@"totalCount"] integerValue] == 3,
			"and how many files are queued");
	TGTestExpectTrue(&outcome, [summary[@"downloadedSize"] longLongValue] == 1048576,
			"and how much of it has arrived");

	NSDictionary *asStrings = TGDownloadsSummaryFromUpdate(@{
		@"@type" : @"updateFileDownloads",
		@"total_size" : @"4194304",
		@"total_count" : @3,
		@"downloaded_size" : @"1048576",
	});
	TGTestExpectTrue(&outcome, [asStrings[@"totalSize"] longLongValue] == 4194304,
			"a total sent as a string is still a number, the way TDLib sends large integers");

	return outcome;
}

TGTestOutcome TGDownloadsUpdateTestAnotherUpdateCarriesNoSummary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGDownloadsSummaryFromUpdate(@{@"@type" : @"updateFileAddedToDownloads"}) == nil,
			"a file joining the list says nothing about the totals, so it carries no summary");
	TGTestExpectTrue(&outcome,
			TGDownloadsSummaryFromUpdate(@{@"@type" : @"updateFile"}) == nil,
			"and neither does an ordinary file update");

	return outcome;
}

TGTestOutcome TGDownloadsUpdateTestListMembershipDecidesTheReload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entries = @[ @{@"fileId" : @41}, @{@"fileId" : @42} ];

	TGTestExpectTrue(&outcome, TGDownloadsListShowsFileId(entries, 42),
			"a file the list shows makes the screen reload");
	TGTestExpectTrue(&outcome, !TGDownloadsListShowsFileId(entries, 77),
			"a file the list does not show must not, or every photo downloading in a chat "
			"would reload this screen");
	TGTestExpectTrue(&outcome, !TGDownloadsListShowsFileId(entries, 0),
			"and neither does a file with no id at all");

	return outcome;
}

TGTestOutcome TGDownloadsUpdateTestMissingInputIsHandled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGDownloadsSummaryFromUpdate(nil) == nil,
			"a missing update carries no summary");
	TGTestExpectTrue(&outcome, TGDownloadsSummaryFromUpdate((id)@"updateFileDownloads") == nil,
			"and neither does something that is not an update at all");
	TGTestExpectTrue(&outcome, !TGDownloadsListShowsFileId(nil, 42),
			"an empty screen shows no file");
	TGTestExpectTrue(&outcome, !TGDownloadsListShowsFileId(@[ (id)@"row" ], 42),
			"and a malformed row is not a file either");

	return outcome;
}
