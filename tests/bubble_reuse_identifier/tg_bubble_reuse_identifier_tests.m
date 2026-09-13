#import "tg_bubble_reuse_identifier_tests.h"
#import "../../src/Screens/Chat/TGBubbleReuseIdentifier.h"

static NSString *TGReuseFor(NSString *kind) {
	return TGBubbleReuseIdentifierForKind(kind, NO, NO, NO, NO, NO);
}

TGTestOutcome TGBubbleReuseIdentifierTestEveryKindLandsOnItsOwnCell(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGReuseFor(@"messageText") isEqualToString:@"TGBubbleCell.Text"],
			"text is a text bubble");
	TGTestExpectTrue(&outcome, [TGReuseFor(@"messagePhoto") isEqualToString:@"TGBubbleCell.Photo"],
			"a photo is a picture bubble");
	TGTestExpectTrue(&outcome, [TGReuseFor(@"messageVideo") isEqualToString:@"TGBubbleCell.Photo"],
			"and so is a video");
	TGTestExpectTrue(&outcome,
			[TGReuseFor(@"messageVideoNote") isEqualToString:@"TGBubbleCell.VideoNote"],
			"a round note gets the round cell whether or not its size has arrived");
	TGTestExpectTrue(&outcome,
			[TGReuseFor(@"messageVoiceNote") isEqualToString:@"TGBubbleCell.Voice"],
			"a voice note gets the voice cell");
	TGTestExpectTrue(&outcome, [TGReuseFor(@"messageCall") isEqualToString:@"TGBubbleCell.Call"],
			"a call gets the call cell");
	TGTestExpectTrue(&outcome,
			[TGReuseFor(@"messageGroupCall") isEqualToString:@"TGBubbleCell.Call"],
			"and so does a group call");
	TGTestExpectTrue(&outcome,
			[TGReuseFor(@"messageContact") isEqualToString:@"TGBubbleCell.File"],
			"a contact is drawn by the file cell, as a document and an audio file are");
	TGTestExpectTrue(&outcome, [TGReuseFor(@"messagePoll") isEqualToString:@"TGBubbleCell.Poll"],
			"a poll gets the poll cell");
	TGTestExpectTrue(&outcome,
			[TGReuseFor(@"messageChecklist") isEqualToString:@"TGBubbleCell.Checklist"],
			"a checklist gets the checklist cell");
	TGTestExpectTrue(&outcome,
			[TGReuseFor(@"messageVenue") isEqualToString:@"TGBubbleCell.Location"],
			"a venue is a map card, as a location and a live location are");
	TGTestExpectTrue(&outcome,
			[TGReuseFor(@"messageSomethingTelegramAddedLater")
					isEqualToString:@"TGBubbleCell.Text"],
			"a kind this build has never heard of still gets a cell rather than nothing");
	TGTestExpectTrue(&outcome, [TGReuseFor(nil) isEqualToString:@"TGBubbleCell.Text"],
			"and so does a message with no kind at all");

	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messagePhoto", YES, NO, NO, NO, NO)
					isEqualToString:@"TGBubbleCell.Album"],
			"a photo that belongs to a mosaic is drawn by the album cell");
	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messageChatChangeTitle", NO, YES, NO, NO, NO)
					isEqualToString:@"TGBubbleCell.Service"],
			"a service line is drawn by the service cell whatever its kind");
	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messageSticker", NO, NO, YES, NO, NO)
					isEqualToString:@"TGBubbleCell.AnimatedSticker"],
			"a sticker with a lottie file on disk animates");
	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messageDice", NO, NO, NO, YES, NO)
					isEqualToString:@"TGBubbleCell.Sticker"],
			"a dice that resolved to a sticker is drawn as one");
	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messageDice", NO, NO, NO, NO, NO)
					isEqualToString:@"TGBubbleCell.BareEmoji"],
			"and one that did not is drawn as a bare emoji");

	return outcome;
}

TGTestOutcome TGBubbleReuseIdentifierTestBurningMediaKeepsItsLabel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messagePhoto", NO, NO, NO, NO, YES)
					isEqualToString:@"TGBubbleCell.Text"],
			"a view-once photo has no picture to draw yet, so it is the row that carries the "
			"tap-to-open line");
	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messageVideoNote", NO, NO, NO, NO, YES)
					isEqualToString:@"TGBubbleCell.Text"],
			"a view-once round note carries the same line rather than an empty circle");
	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messageVideoNote", NO, NO, NO, NO, NO)
					isEqualToString:@"TGBubbleCell.VideoNote"],
			"an ordinary round note is still a circle");
	TGTestExpectTrue(&outcome,
			[TGBubbleReuseIdentifierForKind(@"messageVoiceNote", NO, NO, NO, NO, YES)
					isEqualToString:@"TGBubbleCell.Voice"],
			"a view-once voice note keeps the voice cell, which already draws its own state");

	return outcome;
}
