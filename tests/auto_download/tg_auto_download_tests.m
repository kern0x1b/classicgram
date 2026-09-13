#import "tg_auto_download_tests.h"
#import "../../src/Screens/Chat/TGAutoDownloadDecision.h"

static NSDictionary *TGAutoDownloadTestSettings(BOOL enabled, long long photo, long long video, long long other) {
	return @{
		@"enabled" : @(enabled),
		@"maxPhotoSize" : @(photo),
		@"maxVideoSize" : @(video),
		@"maxOtherSize" : @(other),
	};
}

TGTestOutcome TGAutoDownloadTestCategoryForKindMapsPhotoVideoAndOthers(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGAutoDownloadCategoryForKind(@"messagePhoto") isEqualToString:TGAutoDownloadCategoryPhoto],
			"messagePhoto must map to the photo category");
	TGTestExpectTrue(&outcome,
			[TGAutoDownloadCategoryForKind(@"messageVideo") isEqualToString:TGAutoDownloadCategoryVideo],
			"messageVideo must map to the video category");
	TGTestExpectTrue(&outcome,
			[TGAutoDownloadCategoryForKind(@"messageVideoNote") isEqualToString:TGAutoDownloadCategoryVideo],
			"messageVideoNote must map to the video category");
	TGTestExpectTrue(&outcome,
			[TGAutoDownloadCategoryForKind(@"messageAnimation") isEqualToString:TGAutoDownloadCategoryOther],
			"messageAnimation must map to the other category, same as any file");
	TGTestExpectTrue(&outcome,
			[TGAutoDownloadCategoryForKind(@"messageSticker") isEqualToString:TGAutoDownloadCategoryOther],
			"messageSticker must map to the other category");
	TGTestExpectTrue(&outcome,
			[TGAutoDownloadCategoryForKind(@"messageAnimatedEmoji") isEqualToString:TGAutoDownloadCategoryOther],
			"messageAnimatedEmoji must map to the other category");

	return outcome;
}

TGTestOutcome TGAutoDownloadTestNilSettingsAllowsDownload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGShouldAutoDownloadFile(nil, TGAutoDownloadCategoryPhoto, 500000),
			"missing settings must not block a download that used to happen unconditionally");

	return outcome;
}

TGTestOutcome TGAutoDownloadTestDisabledSettingsBlocksDownload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutoDownloadTestSettings(NO, 5242880, 10485760, 3145728);
	TGTestExpectTrue(&outcome,
			!TGShouldAutoDownloadFile(settings, TGAutoDownloadCategoryPhoto, 1000),
			"auto-download disabled for the network must block every category");

	return outcome;
}

TGTestOutcome TGAutoDownloadTestZeroCapBlocksDownloadEvenWhenEnabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutoDownloadTestSettings(YES, 0, 10485760, 3145728);
	TGTestExpectTrue(&outcome,
			!TGShouldAutoDownloadFile(settings, TGAutoDownloadCategoryPhoto, 1000),
			"a zero cap for a category means off, even with the master switch enabled");

	return outcome;
}

TGTestOutcome TGAutoDownloadTestFileOverCapIsBlocked(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutoDownloadTestSettings(YES, 1048576, 10485760, 3145728);
	TGTestExpectTrue(&outcome,
			!TGShouldAutoDownloadFile(settings, TGAutoDownloadCategoryPhoto, 2097152),
			"a photo larger than the photo cap must be blocked");

	return outcome;
}

TGTestOutcome TGAutoDownloadTestFileUnderCapIsAllowed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutoDownloadTestSettings(YES, 1048576, 10485760, 3145728);
	TGTestExpectTrue(&outcome,
			TGShouldAutoDownloadFile(settings, TGAutoDownloadCategoryVideo, 5242880),
			"a video under the video cap must be allowed");

	return outcome;
}

TGTestOutcome TGAutoDownloadTestUnknownFileSizeIsAllowedWhenEnabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutoDownloadTestSettings(YES, 1048576, 10485760, 3145728);
	TGTestExpectTrue(&outcome,
			TGShouldAutoDownloadFile(settings, TGAutoDownloadCategoryOther, 0),
			"a file whose size is not yet known must not be blocked purely for that reason");

	return outcome;
}

TGTestOutcome TGAutoDownloadTestMergeForMobileTakesTheMostRestrictiveOfEachField(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *mobile = TGAutoDownloadTestSettings(YES, 5242880, 10485760, 3145728);
	NSDictionary *roaming = TGAutoDownloadTestSettings(NO, 1048576, 20971520, 1048576);
	NSDictionary *merged = TGAutoDownloadSettingsMergedForMobile(mobile, roaming);

	TGTestExpectTrue(&outcome, ![merged[@"enabled"] boolValue],
			"roaming disabled must still disable the merged mobile bucket");
	TGTestExpectEqualLongLong(&outcome, [merged[@"maxPhotoSize"] longLongValue], 1048576,
			"the smaller of the two photo caps must win");
	TGTestExpectEqualLongLong(&outcome, [merged[@"maxVideoSize"] longLongValue], 10485760,
			"the smaller of the two video caps must win");
	TGTestExpectEqualLongLong(&outcome, [merged[@"maxOtherSize"] longLongValue], 1048576,
			"the smaller of the two other caps must win");

	return outcome;
}

TGTestOutcome TGAutoDownloadTestMergeForMobileFallsBackToWhicheverBucketExists(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *mobile = TGAutoDownloadTestSettings(YES, 5242880, 10485760, 3145728);
	NSDictionary *merged = TGAutoDownloadSettingsMergedForMobile(mobile, nil);
	TGTestExpectTrue(&outcome, merged == mobile,
			"with no roaming mirror yet, the mobile bucket alone must be used");

	NSDictionary *roaming = TGAutoDownloadTestSettings(NO, 1048576, 20971520, 1048576);
	NSDictionary *mergedOther = TGAutoDownloadSettingsMergedForMobile(nil, roaming);
	TGTestExpectTrue(&outcome, mergedOther == roaming,
			"with no mobile mirror yet, the roaming bucket alone must be used");

	return outcome;
}
