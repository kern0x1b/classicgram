#import "tg_profile_section_metrics_tests.h"
#import "../../src/Views/TGProfileSectionMetrics.h"

TGTestOutcome TGProfileSectionMetricsTestUserProfileGapsFollowTheOriginal(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
		TGProfileSectionHeaderHeight(@"details", YES, NO, NO, NO, YES) == 12,
		"the first section keeps the 12 point gap the original gives it");
	TGTestExpectTrue(&outcome,
		TGProfileSectionHeaderHeight(@"details", YES, NO, NO, NO, NO) == 2,
		"a first section with no detail rows collapses to 2, as in the original");
	TGTestExpectTrue(&outcome,
		TGProfileSectionHeaderHeight(@"actions", NO, NO, NO, NO, YES) == 10,
		"the action buttons sit 10 points below what is above them");
	TGTestExpectTrue(&outcome,
		TGProfileSectionHeaderHeight(@"media", NO, NO, NO, NO, YES) == 28,
		"the shared-media block sits 28 points down, which is what the original reserves");
	TGTestExpectTrue(&outcome,
		TGProfileSectionHeaderHeight(@"media", NO, NO, YES, NO, YES) == 10,
		"in a secret chat that same block sits 10 points down instead");
	TGTestExpectTrue(&outcome,
		TGProfileSectionHeaderHeight(@"manage", NO, NO, NO, NO, YES) == 12,
		"every other section keeps the default 12");

	return outcome;
}

TGTestOutcome TGProfileSectionMetricsTestGroupAndEmptySections(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	for (NSString *kind in @[ @"details", @"actions", @"media", @"members" ])
		TGTestExpectTrue(&outcome,
			TGProfileSectionHeaderHeight(kind, NO, YES, NO, NO, YES) == 8,
			"a group profile uses one gap of 8 for every section, as the original does");

	TGTestExpectTrue(&outcome,
		TGProfileSectionHeaderHeight(@"media", NO, NO, NO, YES, YES) == 0,
		"a section with no rows takes no space at all");
	TGTestExpectTrue(&outcome,
		TGProfileSectionHeaderHeight(@"details", YES, NO, NO, YES, NO) == 2,
		"the first section is measured even when it has no rows yet");

	return outcome;
}
