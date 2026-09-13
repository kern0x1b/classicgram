#import "tg_story_composer_privacy_reset_tests.h"
#import "../../src/Screens/Stories/TGStoryComposerPrivacyReset.h"

TGTestOutcome TGStoryComposerPrivacyResetTestPersonalProfileShowsPrivacy(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryComposerShowsPrivacyForChat(0),
			"the default personal-profile chat id must still show the Privacy row");

	return outcome;
}

TGTestOutcome TGStoryComposerPrivacyResetTestOwnAccountShowsPrivacy(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryComposerShowsPrivacyForChat(123456789LL),
			"a positive chat id, which is always a user, must show the Privacy row");

	return outcome;
}

TGTestOutcome TGStoryComposerPrivacyResetTestChannelHidesPrivacy(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGStoryComposerShowsPrivacyForChat(-1001234567890LL),
			"a channel's negative chat id must hide the Privacy row");

	return outcome;
}

TGTestOutcome TGStoryComposerPrivacyResetTestSupergroupHidesPrivacy(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGStoryComposerShowsPrivacyForChat(-1LL),
			"any negative chat id must hide the Privacy row, not only large channel ids");

	return outcome;
}
