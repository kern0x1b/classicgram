#import "tg_live_location_message_id_remap_tests.h"
#import "../../src/Screens/Chat/TGLiveLocationMessageIdRemap.h"

TGTestOutcome TGLiveLocationMessageIdRemapTestTrackedMessagePromotedToServerId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int64_t remapped = TGRemappedLiveLocationMessageId(4611686018427387904, 4611686018427387904, 5000000000);
	TGTestExpectEqualLongLong(&outcome, remapped, 5000000000,
			"the tracked live-location message id must follow the message it was sent as once TDLib promotes it to a server id");

	return outcome;
}

TGTestOutcome TGLiveLocationMessageIdRemapTestUnrelatedMessagePromotionLeavesIdUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int64_t remapped = TGRemappedLiveLocationMessageId(4611686018427387904, 1234567890, 5000000000);
	TGTestExpectEqualLongLong(&outcome, remapped, 4611686018427387904,
			"a different message being promoted to a server id must not disturb the tracked live-location message id");

	return outcome;
}

TGTestOutcome TGLiveLocationMessageIdRemapTestNoActiveShareLeavesIdAtZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int64_t remapped = TGRemappedLiveLocationMessageId(0, 1234567890, 5000000000);
	TGTestExpectEqualLongLong(&outcome, remapped, 0,
			"with no active live-location share, a message promotion must not start tracking one");

	return outcome;
}

TGTestOutcome TGLiveLocationMessageIdRemapTestZeroOldMessageIdLeavesIdUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int64_t remapped = TGRemappedLiveLocationMessageId(4611686018427387904, 0, 5000000000);
	TGTestExpectEqualLongLong(&outcome, remapped, 4611686018427387904,
			"a missing old message id cannot be a promotion of the tracked live-location message");

	return outcome;
}

TGTestOutcome TGLiveLocationMessageIdRemapTestZeroNewMessageIdLeavesIdUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int64_t remapped = TGRemappedLiveLocationMessageId(4611686018427387904, 4611686018427387904, 0);
	TGTestExpectEqualLongLong(&outcome, remapped, 4611686018427387904,
			"a missing new message id must not clear the tracked live-location message id");

	return outcome;
}
