#import "tg_autosave_tests.h"
#import "../../src/Screens/Chat/TGAutosaveDecision.h"

static NSDictionary *TGAutosaveTestSettings(BOOL photos, BOOL videos, long long maxVideoBytes) {
	return @{
		@"photos" : @(photos),
		@"videos" : @(videos),
		@"maxVideoBytes" : @(maxVideoBytes),
	};
}

TGTestOutcome TGAutosaveTestCategoryForKindMapsPhotoAndVideoOnly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGAutosaveCategoryForKind(@"messagePhoto") isEqualToString:TGAutosaveCategoryPhoto],
			"messagePhoto must map to the photo category");
	TGTestExpectTrue(&outcome,
			[TGAutosaveCategoryForKind(@"messageVideo") isEqualToString:TGAutosaveCategoryVideo],
			"messageVideo must map to the video category");
	TGTestExpectTrue(&outcome, TGAutosaveCategoryForKind(@"messageVideoNote") == nil,
			"messageVideoNote is not autosave-eligible content");
	TGTestExpectTrue(&outcome, TGAutosaveCategoryForKind(@"messageAnimation") == nil,
			"messageAnimation is not autosave-eligible content");
	TGTestExpectTrue(&outcome, TGAutosaveCategoryForKind(@"messageDocument") == nil,
			"messageDocument is not autosave-eligible content");

	return outcome;
}

TGTestOutcome TGAutosaveTestNilSettingsAndNilExceptionBlocksSave(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			!TGShouldAutosaveFile(nil, nil, TGAutosaveCategoryPhoto, 500000),
			"settings never loaded yet must not silently start saving to the camera roll");

	return outcome;
}

TGTestOutcome TGAutosaveTestScopePhotosDisabledBlocksPhoto(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutosaveTestSettings(NO, YES, 10 * 1024 * 1024);
	TGTestExpectTrue(&outcome,
			!TGShouldAutosaveFile(settings, nil, TGAutosaveCategoryPhoto, 1000),
			"photo autosave off for the scope must block a photo");

	return outcome;
}

TGTestOutcome TGAutosaveTestScopePhotosEnabledAllowsPhotoRegardlessOfSize(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutosaveTestSettings(YES, NO, 0);
	TGTestExpectTrue(&outcome,
			TGShouldAutosaveFile(settings, nil, TGAutosaveCategoryPhoto, 50 * 1024 * 1024),
			"TDLib defines no photo size cap, so a large photo must still be allowed");

	return outcome;
}

TGTestOutcome TGAutosaveTestScopeVideosDisabledBlocksVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutosaveTestSettings(YES, NO, 10 * 1024 * 1024);
	TGTestExpectTrue(&outcome,
			!TGShouldAutosaveFile(settings, nil, TGAutosaveCategoryVideo, 1000),
			"video autosave off for the scope must block a video");

	return outcome;
}

TGTestOutcome TGAutosaveTestVideoUnderCapIsAllowed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutosaveTestSettings(YES, YES, 10 * 1024 * 1024);
	TGTestExpectTrue(&outcome,
			TGShouldAutosaveFile(settings, nil, TGAutosaveCategoryVideo, 5 * 1024 * 1024),
			"a video under the cap must be allowed");

	return outcome;
}

TGTestOutcome TGAutosaveTestVideoOverCapIsBlocked(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutosaveTestSettings(YES, YES, 10 * 1024 * 1024);
	TGTestExpectTrue(&outcome,
			!TGShouldAutosaveFile(settings, nil, TGAutosaveCategoryVideo, 20 * 1024 * 1024),
			"a video over the cap must be blocked");

	return outcome;
}

TGTestOutcome TGAutosaveTestZeroCapFallsBackToTenMegabyteDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = TGAutosaveTestSettings(YES, YES, 0);
	TGTestExpectTrue(&outcome,
			TGShouldAutosaveFile(settings, nil, TGAutosaveCategoryVideo, 5 * 1024 * 1024),
			"an unset cap must fall back to the same 10 MB default the settings screen uses");
	TGTestExpectTrue(&outcome,
			!TGShouldAutosaveFile(settings, nil, TGAutosaveCategoryVideo, 20 * 1024 * 1024),
			"the 10 MB fallback must still block a file larger than that");

	return outcome;
}

TGTestOutcome TGAutosaveTestChatExceptionOverridesScopeSettings(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *scopeSettings = TGAutosaveTestSettings(YES, YES, 10 * 1024 * 1024);
	NSDictionary *exception = TGAutosaveTestSettings(NO, NO, 0);
	TGTestExpectTrue(&outcome,
			!TGShouldAutosaveFile(scopeSettings, exception, TGAutosaveCategoryPhoto, 1000),
			"a per-chat exception must override the scope default, not merge with it");

	return outcome;
}

TGTestOutcome TGAutosaveTestNilExceptionFallsBackToScopeSettings(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *scopeSettings = TGAutosaveTestSettings(YES, YES, 10 * 1024 * 1024);
	TGTestExpectTrue(&outcome,
			TGShouldAutosaveFile(scopeSettings, nil, TGAutosaveCategoryPhoto, 1000),
			"with no exception for this chat, the scope default must apply");

	return outcome;
}
