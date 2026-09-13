#import "tg_chat_message_layout_tests.h"
#import "../../src/Layout/TGChatMessageLayout.h"

TGTestOutcome TGLayoutTestGenericHeightWithoutMedia(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatMessageLayout layout = TGChatMessageLayoutMakeGeneric(
			CGSizeMake(200, 40), CGSizeMake(0, 0), 6, 18, 6, 6, 14, 36, 220, 0, 320, NO);

	TGTestExpectEqualDouble(&outcome, layout.height, 88, 0.01,
			"text-only bubble height should be senderHeight+pads+decoration+bodyHeight+1(over min)+3(row pad)");
	TGTestExpectEqualDouble(&outcome, layout.bubbleFrame.origin.x, 8, 0.01,
			"incoming bubble should sit 8pt from the left edge with no avatar shift");
	TGTestExpectEqualDouble(&outcome, layout.bubbleFrame.size.width, 220, 0.01,
			"bubble width should pass through unchanged");
	TGTestExpectEqualDouble(&outcome, layout.bubbleFrame.size.height, 85, 0.01,
			"bubble frame height should be exactly 3pt shorter than the row height it is drawn inside");
	TGTestExpectTrue(&outcome,
			CGRectGetMaxY(layout.bubbleFrame) <= layout.height,
			"the bubble frame must never extend past the row height that is supposed to contain it");

	return outcome;
}

TGTestOutcome TGLayoutTestGenericHeightWithMedia(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatMessageLayout layout = TGChatMessageLayoutMakeGeneric(
			CGSizeMake(0, 0), CGSizeMake(210, 140), 4, 0, 2, 8, 16, 40, 210, 0, 320, YES);

	TGTestExpectEqualDouble(&outcome, layout.height, 174, 0.01,
			"photo bubble height should include picture height plus the gap under media");
	TGTestExpectEqualDouble(&outcome, layout.bubbleFrame.origin.x, 102, 0.01,
			"outgoing bubble should be pinned to the right: tableWidth - bubbleWidth - 8");
	TGTestExpectEqualDouble(&outcome, layout.bubbleFrame.size.height, 171, 0.01,
			"bubble frame height should be exactly 3pt shorter than the row height for a media bubble too");
	TGTestExpectTrue(&outcome,
			CGRectGetMaxY(layout.bubbleFrame) <= layout.height,
			"a media bubble frame must also never extend past its own row height");

	return outcome;
}

TGTestOutcome TGLayoutTestGenericHeightClampedAtMinimum(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatMessageLayout layout = TGChatMessageLayoutMakeGeneric(
			CGSizeMake(0, 0), CGSizeMake(0, 0), 0, 0, 0, 0, 10, 60, 90, 0, 320, NO);

	TGTestExpectEqualDouble(&outcome, layout.bubbleFrame.size.height, 60, 0.01,
			"a bubble whose content is exactly the minimum height must not receive the +1 overflow pad");
	TGTestExpectEqualDouble(&outcome, layout.height, 63, 0.01,
			"row height at the clamp boundary should be minHeight+3, not minHeight+1+3");

	return outcome;
}

TGTestOutcome TGLayoutTestGenericXShiftsByAvatarShift(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatMessageLayout unshifted = TGChatMessageLayoutMakeGeneric(
			CGSizeMake(200, 40), CGSizeMake(0, 0), 6, 18, 6, 6, 14, 36, 220, 0, 320, NO);
	TGChatMessageLayout shifted = TGChatMessageLayoutMakeGeneric(
			CGSizeMake(200, 40), CGSizeMake(0, 0), 6, 18, 6, 6, 14, 36, 220, 12, 320, NO);

	TGTestExpectEqualDouble(&outcome,
			shifted.bubbleFrame.origin.x - unshifted.bubbleFrame.origin.x, 12, 0.01,
			"avatarShift must move the bubble by exactly its own value, in either direction");
	TGTestExpectEqualDouble(&outcome, shifted.height, unshifted.height, 0.01,
			"avatarShift must not change row height, only horizontal position");

	return outcome;
}

TGTestOutcome TGLayoutTestTailOnRightForOutgoing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatMessageContentFrames frames = TGChatMessageLayoutMakeContentFrames(
			102, 210, 171, 0, 2, YES, NO, 0, 8, 30, 5, 0);

	TGTestExpectEqualDouble(&outcome, frames.tailFrame.origin.x, 311, 0.01,
			"an outgoing bubble's tail must sit at bubbleX + bubbleWidth - 1, on the right of the bubble");
	TGTestExpectTrue(&outcome,
			frames.tailFrame.origin.x >= 102 + 210 - 1,
			"an outgoing bubble's tail must not be drawn to the left of the bubble's right edge");

	return outcome;
}

TGTestOutcome TGLayoutTestTailOnLeftForIncoming(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatMessageContentFrames frames = TGChatMessageLayoutMakeContentFrames(
			8, 220, 85, 18, 6, NO, NO, 0, 8, 30, 5, 0);

	TGTestExpectEqualDouble(&outcome, frames.tailFrame.origin.x, 3, 0.01,
			"an incoming bubble's tail must sit at bubbleX - 5, on the left of the bubble");
	TGTestExpectTrue(&outcome,
			frames.tailFrame.origin.x < 8,
			"an incoming bubble's tail must not be drawn to the right of the bubble's left edge");

	return outcome;
}

TGTestOutcome TGLayoutTestTailSizeNonZeroBothDirections(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatMessageContentFrames outgoingFrames = TGChatMessageLayoutMakeContentFrames(
			102, 210, 171, 0, 2, YES, NO, 0, 8, 30, 5, 0);
	TGChatMessageContentFrames incomingFrames = TGChatMessageLayoutMakeContentFrames(
			8, 220, 85, 18, 6, NO, NO, 0, 8, 30, 5, 0);

	TGTestExpectEqualDouble(&outcome, outgoingFrames.tailFrame.size.width, 6, 0.01,
			"the outgoing tail must have a nonzero width, or it silently disappears");
	TGTestExpectEqualDouble(&outcome, outgoingFrames.tailFrame.size.height, 10, 0.01,
			"the outgoing tail must have a nonzero height, or it silently disappears");
	TGTestExpectEqualDouble(&outcome, incomingFrames.tailFrame.size.width, 6, 0.01,
			"the incoming tail must have a nonzero width, or it silently disappears");
	TGTestExpectEqualDouble(&outcome, incomingFrames.tailFrame.size.height, 10, 0.01,
			"the incoming tail must have a nonzero height, or it silently disappears");

	return outcome;
}

TGTestOutcome TGLayoutTestStickerArtAvoidsTailSideWhenOutgoing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatMessageContentFrames frames = TGChatMessageLayoutMakeContentFrames(
			0, 150, 150, 0, 0, YES, YES, 60, 8, 30, 5, 0);

	TGTestExpectEqualDouble(&outcome, frames.artX, 82, 0.01,
			"an outgoing sticker's art must be pushed to the far side of the bubble, away from the tail");

	return outcome;
}

TGTestOutcome TGLayoutTestCenteredDiscIsCenteredOnPicture(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGRect disc = TGChatMessageLayoutMakeCenteredDiscFrame(20, 30, 200, 200, 48);

	CGFloat discCenterX = CGRectGetMidX(disc);
	CGFloat discCenterY = CGRectGetMidY(disc);
	CGFloat pictureCenterX = 20 + 200 / 2.0;
	CGFloat pictureCenterY = 30 + 200 / 2.0;

	TGTestExpectEqualDouble(&outcome, discCenterX, pictureCenterX, 0.01,
			"the play/pause disc must be centred horizontally on the picture behind it");
	TGTestExpectEqualDouble(&outcome, discCenterY, pictureCenterY, 0.01,
			"the play/pause disc must be centred vertically on the picture behind it");
	TGTestExpectEqualDouble(&outcome, disc.size.width, 48, 0.01,
			"the disc must keep the side length it was asked for");

	return outcome;
}
