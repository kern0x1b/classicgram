#import "tg_wallpaper_revert_eligibility_tests.h"
#import "../../src/Screens/Chat/TGWallpaperRevertEligibility.h"

static NSDictionary *TGWallpaperRevertEligibilityTestMessage(BOOL outgoing, BOOL onlyForSelf,
		long long oldBackgroundMessageId, long long backgroundId) {
	return @{
		@"kind" : @"messageChatSetBackground",
		@"outgoing" : @(outgoing),
		@"onlyForSelf" : @(onlyForSelf),
		@"oldBackgroundMessageId" : @(oldBackgroundMessageId),
		@"backgroundId" : @(backgroundId),
	};
}

TGTestOutcome TGWallpaperRevertEligibilityTestNonBackgroundMessageIsNotEligible(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"kind" : @"messageText",
		@"outgoing" : @NO,
		@"onlyForSelf" : @NO,
		@"oldBackgroundMessageId" : @5000000000,
		@"backgroundId" : @900,
	};
	TGTestExpectTrue(&outcome, TGWallpaperRevertTarget(message, @"900") == nil,
			"only a messageChatSetBackground bubble can offer the revert action");

	return outcome;
}

TGTestOutcome TGWallpaperRevertEligibilityTestOutgoingMessageIsNotEligible(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = TGWallpaperRevertEligibilityTestMessage(YES, NO, 5000000000, 900);
	TGTestExpectTrue(&outcome, TGWallpaperRevertTarget(message, @"900") == nil,
			"a wallpaper change the current user sent themselves must not offer reverting it");

	return outcome;
}

TGTestOutcome TGWallpaperRevertEligibilityTestOnlyForSelfMessageIsNotEligible(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = TGWallpaperRevertEligibilityTestMessage(NO, YES, 5000000000, 900);
	TGTestExpectTrue(&outcome, TGWallpaperRevertTarget(message, @"900") == nil,
			"a background set only for the peer's own view must not offer reverting the shared wallpaper");

	return outcome;
}

TGTestOutcome TGWallpaperRevertEligibilityTestZeroOldBackgroundMessageIdIsNotEligible(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = TGWallpaperRevertEligibilityTestMessage(NO, NO, 0, 900);
	TGTestExpectTrue(&outcome, TGWallpaperRevertTarget(message, @"900") == nil,
			"a chat's first-ever wallpaper has nothing to revert to");

	return outcome;
}

TGTestOutcome TGWallpaperRevertEligibilityTestStaleBackgroundIsNotEligible(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = TGWallpaperRevertEligibilityTestMessage(NO, NO, 5000000000, 900);
	TGTestExpectTrue(&outcome, TGWallpaperRevertTarget(message, @"901") == nil,
			"a historical wallpaper-change bubble superseded by a later change must not offer reverting the current one");

	return outcome;
}

TGTestOutcome TGWallpaperRevertEligibilityTestMissingCurrentBackgroundIsNotEligible(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = TGWallpaperRevertEligibilityTestMessage(NO, NO, 5000000000, 900);
	TGTestExpectTrue(&outcome, TGWallpaperRevertTarget(message, nil) == nil,
			"with no currently-loaded chat background to compare against, the action must not be offered");

	return outcome;
}

TGTestOutcome TGWallpaperRevertEligibilityTestCurrentIncomingNotOnlyForSelfBackgroundIsEligible(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = TGWallpaperRevertEligibilityTestMessage(NO, NO, 5000000000, 900);
	NSNumber *target = TGWallpaperRevertTarget(message, @"900");
	TGTestExpectTrue(&outcome, target != nil,
			"an incoming, shared, currently-applied wallpaper change must offer reverting it");
	TGTestExpectEqualLongLong(&outcome, target.longLongValue, 5000000000,
			"the revert target must be the message's own old_background_message_id");

	return outcome;
}
