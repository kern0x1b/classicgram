#import "tg_layout_builder_tests.h"
#import "TGMessageItem.h"
#import "TGMessageItemBuilder.h"
#import "TGMessageItemResolvedInputs.h"
#import "TGChatLayoutContext.h"
#import "TGMessageLayoutBuilder+Private.h"
#import <UIKit/UIKit.h>

static const CGFloat kPad = 10.0f;

static TGChatLayoutContext *TGTestContext(CGFloat tableWidth, BOOL wide) {
	return [[TGChatLayoutContext alloc] initWithTableWidth:tableWidth
											  baseFontSize:16
											   screenScale:1
												   isGroup:NO
											  isWideLayout:wide
											   isSelecting:NO
												generation:1];
}

static TGMessageItem *TGTestPhotoItem(TGMessageItemResolvedInputs *resolved) {
	NSDictionary *flat = @{
		@"id"          : @4242,
		@"kind"        : @"messagePhoto",
		@"outgoing"    : @NO,
		@"date"        : @1700000000,
		@"photoId"     : @77,
		@"photoWidth"  : @800,
		@"photoHeight" : @600,
	};
	return [TGMessageItemBuilder itemFromFlatMessage:flat
											  chatId:7
									 reuseIdentifier:@"TGBubbleCell.Photo"
										albumMembers:nil
											resolved:resolved];
}

static TGMessageItemResolvedInputs *TGTestPhotoInputs(CGSize picture) {
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.pictureSize = picture;
	resolved.stampText = @"19:38";
	return resolved;
}

static TGMessageItem *TGTestChannelPostItem(NSInteger commentCount) {
	NSDictionary *flat = @{
		@"id"           : @9090,
		@"kind"         : @"messageText",
		@"outgoing"     : @NO,
		@"date"         : @1700000000,
		@"channelPost"  : @YES,
		@"commentCount" : @(commentCount),
		@"hasCommentThread" : @(commentCount > 0),
	};
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.bodyText = @"Breaking news from the newsroom.";
	resolved.stampText = @"19:38";
	return [TGMessageItemBuilder itemFromFlatMessage:flat
											  chatId:9
									 reuseIdentifier:@"TGBubbleCell.Text"
										albumMembers:nil
											resolved:resolved];
}

TGTestOutcome TGLayoutBuilderTestPhotoStampSitsBesideTheBubble(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItem *item = TGTestPhotoItem(TGTestPhotoInputs(CGSizeMake(150, 200)));
	TGMessageLayoutComputed computed = TGMessageLayoutBuildPhoto(item, TGTestContext(320, NO));

	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartPlateBeside) != 0,
			"a photo's timestamp plate belongs beside the bubble, never on the artwork");
	TGTestExpectTrue(&outcome, computed.row.platePlate.size.width > 0,
			"the plate beside the bubble must be given a frame, or no time is drawn at all");
	TGTestExpectTrue(&outcome, CGRectGetMinX(computed.row.platePlate) >=
			CGRectGetMaxX(computed.row.bubble) - 1,
			"an incoming plate sits to the right of the bubble, on the wallpaper");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestPhotoBubbleHugsThePicture(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize picture = CGSizeMake(150, 200);
	TGMessageItem *item = TGTestPhotoItem(TGTestPhotoInputs(picture));
	TGMessageLayoutComputed computed = TGMessageLayoutBuildPhoto(item, TGTestContext(320, NO));

	TGTestExpectEqualDouble(&outcome, computed.row.bubble.size.width,
			picture.width + 2 * kPad, 0.5,
			"a photo with no caption gets a bubble exactly as wide as the picture and its padding");
	TGTestExpectEqualDouble(&outcome, computed.bubble.picture.size.width, picture.width, 0.5,
			"the picture keeps the size it was given");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestForwardedPhotoFitsItsForwardLine(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItemResolvedInputs *resolved = TGTestPhotoInputs(CGSizeMake(112, 200));
	resolved.forwardDisplayName = @"Анжела";
	TGMessageItem *item = TGTestPhotoItem(resolved);
	TGMessageLayoutComputed computed = TGMessageLayoutBuildPhoto(item, TGTestContext(448, YES));

	CGFloat lineWidth = TGMessageLayoutForwardLineWidth(item);
	TGTestExpectTrue(&outcome, computed.bubble.forward.size.width >= lineWidth - 0.5,
			"a forwarded bubble must be wide enough to draw the whole forwarded-from line");
	TGTestExpectTrue(&outcome, computed.row.bubble.size.width <= lineWidth + 2 * kPad + 0.5,
			"and no wider than that line needs, so the bubble still hugs the artwork");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestCaptionWrapsAtThePictureWidth(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize picture = CGSizeMake(150, 200);
	TGMessageItemResolvedInputs *resolved = TGTestPhotoInputs(picture);
	resolved.bodyText = @"a caption long enough to run past the picture it belongs to";
	TGMessageItem *item = TGTestPhotoItem(resolved);
	TGMessageLayoutComputed computed = TGMessageLayoutBuildPhoto(item, TGTestContext(448, YES));

	TGTestExpectTrue(&outcome, computed.bubble.body.size.width <= picture.width + 0.5,
			"a caption wraps at the width of the picture instead of widening the bubble");
	TGTestExpectTrue(&outcome, computed.row.bubble.size.width <= picture.width + 2 * kPad + 0.5,
			"so the bubble stays as wide as the artwork");
	TGTestExpectTrue(&outcome, computed.bubble.body.size.height > 0,
			"and the caption still gets a height to draw in");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestAlbumCaptionWrapsAtTheMosaicWidth(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize mosaic = CGSizeMake(305, 200);
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.mosaicSize = mosaic;
	resolved.stampText = @"18:43";
	resolved.bodyText = @"an album caption that is far longer than one line of the mosaic above it";
	resolved.pictureSize = CGSizeMake(112, 200);

	NSDictionary *flat = @{
		@"id"       : @99,
		@"kind"     : @"messagePhoto",
		@"outgoing" : @NO,
		@"date"     : @1700000000,
		@"albumId"  : @"9001",
	};
	TGMessageItem *item = [TGMessageItemBuilder itemFromFlatMessage:flat
															 chatId:7
													reuseIdentifier:@"TGBubbleCell.Album"
													   albumMembers:nil
														   resolved:resolved];
	TGMessageLayoutComputed computed = TGMessageLayoutBuildAlbum(item, TGTestContext(448, YES));

	TGTestExpectTrue(&outcome, computed.bubble.body.size.width <= mosaic.width + 0.5,
			"an album caption wraps at the mosaic width, not at the width of one tile");
	TGTestExpectTrue(&outcome, computed.bubble.body.size.width > 112,
			"and it is not squeezed into a single tile's width either");

	return outcome;
}

static TGMessageItem *TGTestIndentedItem(NSString *kind, NSString *reuse,
	void (^fill)(TGMessageItemResolvedInputs *)) {
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.stampText = @"11:31";
	resolved.viewCountText = @"659";
	resolved.forwardDisplayName = @"LegacyProjects News";
	resolved.forwardAvatarChatId = -100123;
	if (fill)
		fill(resolved);
	NSDictionary *flat = @{
		@"id"       : @5150,
		@"kind"     : kind,
		@"outgoing" : @NO,
		@"date"     : @1700000000,
	};
	return [TGMessageItemBuilder itemFromFlatMessage:flat
											  chatId:7
									 reuseIdentifier:reuse
										albumMembers:nil
											resolved:resolved];
}

TGTestOutcome TGLayoutBuilderTestAnAvatarNeverPushesABubbleOffTheTable(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	CGFloat tableWidth = 447;
	TGChatLayoutContext *context = TGTestContext(tableWidth, YES);

	TGMessageItemResolvedInputs *mine = [[TGMessageItemResolvedInputs alloc] init];
	mine.stampText = @"11:31";
	mine.forwardDisplayName = @"LegacyProjects News";
	mine.forwardAvatarChatId = -100123;
	mine.bodyText = @"a note I forwarded into Saved Messages myself";
	NSDictionary *outgoingFlat = @{ @"id" : @61, @"kind" : @"messageText",
		@"outgoing" : @YES, @"date" : @1700000000 };
	TGMessageItem *outgoing = [TGMessageItemBuilder itemFromFlatMessage:outgoingFlat
																 chatId:7
														reuseIdentifier:@"TGBubbleCell.Text"
														   albumMembers:nil
															   resolved:mine];
	TGMessageLayoutComputed sent = TGMessageLayoutBuildText(outgoing, context);

	TGTestExpectTrue(&outcome, CGRectGetMaxX(sent.row.bubble) <= tableWidth - 7,
			"a row of ours that carries an origin avatar keeps its bubble on the screen, rather "
			"than being shoved off the right edge by the space the avatar wanted");
	TGTestExpectTrue(&outcome, (sent.parts & TGMessageLayoutPartAvatar) != 0,
			"the avatar is still drawn");
	TGTestExpectTrue(&outcome, CGRectGetMinX(sent.row.avatar) >= CGRectGetMaxX(sent.row.bubble) - 1,
			"and it sits beside the bubble on the side the message came from, not adrift in the "
			"middle of the row");
	TGTestExpectTrue(&outcome, CGRectGetMaxX(sent.row.avatar) <= tableWidth,
			"with the avatar itself inside the table too");

	TGMessageItemResolvedInputs *theirs = [[TGMessageItemResolvedInputs alloc] init];
	theirs.stampText = @"11:31";
	theirs.forwardDisplayName = @"LegacyProjects News";
	theirs.forwardAvatarChatId = -100123;
	theirs.bodyText = @"a note somebody else sent";
	NSDictionary *incomingFlat = @{ @"id" : @62, @"kind" : @"messageText",
		@"outgoing" : @NO, @"date" : @1700000000 };
	TGMessageItem *incoming = [TGMessageItemBuilder itemFromFlatMessage:incomingFlat
																 chatId:7
														reuseIdentifier:@"TGBubbleCell.Text"
														   albumMembers:nil
															   resolved:theirs];
	TGMessageLayoutComputed received = TGMessageLayoutBuildText(incoming, context);

	TGTestExpectTrue(&outcome, CGRectGetMinX(received.row.bubble) > 8,
			"an incoming row is still indented by the avatar it carries");
	TGTestExpectTrue(&outcome, CGRectGetMaxX(received.row.avatar) <=
			CGRectGetMinX(received.row.bubble) + 1,
			"and that avatar still sits to the left of the bubble");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestEveryKindLeavesItsStampRoomWhenIndented(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGFloat tableWidth = 447;
	TGChatLayoutContext *context = TGTestContext(tableWidth, YES);

	NSString *longBody = @"a body long enough that the bubble grows to whatever width the layout "
		"is willing to give it, which is the case this test is about";

	TGMessageItem *text = TGTestIndentedItem(@"messageText", @"TGBubbleCell.Text",
			^(TGMessageItemResolvedInputs *r) { r.bodyText = longBody; });
	TGMessageItem *photo = TGTestIndentedItem(@"messagePhoto", @"TGBubbleCell.Photo",
			^(TGMessageItemResolvedInputs *r) {
				r.pictureSize = CGSizeMake(2000, 1200);
				r.bodyText = longBody;
			});
	TGMessageItem *file = TGTestIndentedItem(@"messageDocument", @"TGBubbleCell.File",
			^(TGMessageItemResolvedInputs *r) { r.bodyText = longBody; });
	TGMessageItem *poll = TGTestIndentedItem(@"messagePoll", @"TGBubbleCell.Poll",
			^(TGMessageItemResolvedInputs *r) { r.pollQuestionText = longBody; });

	struct {
		TGMessageItem *item;
		TGMessageLayoutComputed (*build)(TGMessageItem *, TGChatLayoutContext *);
	} cases[] = {
		{text, TGMessageLayoutBuildText},
		{photo, TGMessageLayoutBuildPhoto},
		{file, TGMessageLayoutBuildFile},
		{poll, TGMessageLayoutBuildPoll},
	};

	for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
		TGMessageLayoutComputed computed = cases[i].build(cases[i].item, context);
		if ((computed.parts & TGMessageLayoutPartPlateBeside) == 0)
			continue;
		TGTestExpectTrue(&outcome, CGRectGetMinX(computed.row.platePlate) >=
				CGRectGetMaxX(computed.row.bubble) - 1,
				"a row indented by an origin avatar keeps its plate off the bubble, whatever "
				"the message is made of");
		TGTestExpectTrue(&outcome, CGRectGetMaxX(computed.row.platePlate) <= tableWidth - 1,
				"and the plate stays inside the table");
		TGTestExpectTrue(&outcome, CGRectGetMinX(computed.row.bubble) > 8,
				"the row really is indented, or the check above proves nothing");
	}

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestWideAlbumLeavesRoomForItsStamp(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGFloat tableWidth = 447;
	TGChatLayoutContext *context = TGTestContext(tableWidth, YES);

	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.stampText = @"11:31";
	resolved.viewCountText = @"659";
	resolved.forwardDisplayName = @"LegacyProjects News";
	resolved.forwardAvatarChatId = -100123;
	resolved.bodyText = @"a caption under the mosaic";
	resolved.pictureSize = CGSizeMake(160, 120);

	NSDictionary *flat = @{
		@"id"       : @4711,
		@"kind"     : @"messagePhoto",
		@"outgoing" : @NO,
		@"date"     : @1700000000,
		@"albumId"  : @"4711",
	};

	CGFloat budget = 0;
	{
		TGMessageItem *probe = [TGMessageItemBuilder itemFromFlatMessage:flat
																  chatId:7
														 reuseIdentifier:@"TGBubbleCell.Album"
															albumMembers:nil
																resolved:resolved];
		budget = TGMessageLayoutMaxBubbleWidth(probe, context) - 2 * kPad;
	}
	resolved.mosaicSize = CGSizeMake(budget, 300);

	TGMessageItem *item = [TGMessageItemBuilder itemFromFlatMessage:flat
															 chatId:7
													reuseIdentifier:@"TGBubbleCell.Album"
													   albumMembers:nil
														   resolved:resolved];
	TGMessageLayoutComputed computed = TGMessageLayoutBuildAlbum(item, context);

	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartPlateBeside) != 0,
			"an album's timestamp plate belongs beside the bubble");
	TGTestExpectTrue(&outcome, CGRectGetMinX(computed.row.platePlate) >=
			CGRectGetMaxX(computed.row.bubble) - 1,
			"an album as wide as the layout allows still leaves the plate room on the wallpaper, "
			"rather than sliding it back over the artwork");
	TGTestExpectTrue(&outcome, CGRectGetMaxX(computed.row.platePlate) <= tableWidth - 1,
			"and the plate stays inside the table");

	TGMessageItemResolvedInputs *plain = [[TGMessageItemResolvedInputs alloc] init];
	plain.stampText = @"11:31";
	plain.viewCountText = @"659";
	plain.mosaicSize = CGSizeMake(200, 300);
	plain.pictureSize = CGSizeMake(160, 120);
	TGMessageItem *unindented = [TGMessageItemBuilder itemFromFlatMessage:flat
																  chatId:7
														 reuseIdentifier:@"TGBubbleCell.Album"
															albumMembers:nil
																resolved:plain];
	TGTestExpectTrue(&outcome, !TGMessageLayoutRowIsAvatarIndented(unindented, context),
			"a message with nobody's avatar beside it is not indented");
	TGTestExpectTrue(&outcome, TGMessageLayoutRowIsAvatarIndented(item, context),
			"a forwarded row in Saved Messages carries the origin's avatar, so it is indented");
	TGTestExpectTrue(&outcome,
			TGMessageLayoutMaxBubbleWidth(item, context) <
			TGMessageLayoutMaxBubbleWidth(unindented, context),
			"an indented row gets a narrower bubble, which is what leaves the plate its room");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestBubbleWithoutArtworkKeepsItsTailAndCorners(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItem *item = TGTestPhotoItem(TGTestPhotoInputs(CGSizeMake(150, 200)));
	TGMessageLayoutComputed computed = TGMessageLayoutBuildPhoto(item, TGTestContext(320, NO));

	BOOL artwork = (computed.parts & TGMessageLayoutPartBubbleArtwork) != 0;
	if (artwork){
		TGTestExpectEqualDouble(&outcome, computed.bubbleCornerRadius, 0, 0.01,
				"a bubble drawn from artwork carries its corners in the image, not on the layer");
	} else {
		TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartTail) != 0,
				"a bubble with no artwork has to draw its own tail, or it loses the tail entirely");
		TGTestExpectTrue(&outcome, computed.bubbleCornerRadius > 0,
				"and round its own corners");
		TGTestExpectTrue(&outcome, computed.row.tail.size.height > 0,
				"with a tail that has a size");
	}

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestChannelPostShowsCommentsRow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItem *item = TGTestChannelPostItem(7);
	TGMessageLayoutComputed computed = TGMessageLayoutBuildText(item, TGTestContext(320, NO));

	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartComments) != 0,
			"a channel post with an active discussion thread must carry the comments row part");
	TGTestExpectTrue(&outcome, computed.bubble.comments.size.height > 0,
			"the comments row must have a real, non-zero frame inside the bubble");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestOrdinaryMessageHasNoCommentsRow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItem *withoutComments = TGTestChannelPostItem(0);
	TGMessageLayoutComputed computed = TGMessageLayoutBuildText(withoutComments, TGTestContext(320, NO));
	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartComments) == 0,
			"a channel post with no discussion thread must not draw a comments row");

	TGMessageItem *ordinaryChat = TGTestPhotoItem(TGTestPhotoInputs(CGSizeMake(150, 200)));
	TGMessageLayoutComputed photoComputed = TGMessageLayoutBuildPhoto(ordinaryChat, TGTestContext(320, NO));
	TGTestExpectTrue(&outcome, (photoComputed.parts & TGMessageLayoutPartComments) == 0,
			"an ordinary (non-channel-post) message must never show a comments row");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestItemBuilderCarriesDestructFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = @{
		@"id"            : @6060,
		@"kind"          : @"messagePhoto",
		@"outgoing"      : @NO,
		@"date"          : @1700000000,
		@"photoId"       : @55,
		@"photoWidth"    : @400,
		@"photoHeight"   : @300,
		@"viewOnce"      : @YES,
		@"destructTimer" : @8,
		@"destructIn"    : @3.5,
	};
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.pictureSize = CGSizeMake(150, 200);
	TGMessageItem *item = [TGMessageItemBuilder itemFromFlatMessage:flat
															  chatId:11
													 reuseIdentifier:@"TGBubbleCell.Photo"
													    albumMembers:nil
													        resolved:resolved];

	TGTestExpectTrue(&outcome, item.message.viewOnce == YES,
			"a view-once photo's viewOnce flag must survive from the flattened message into TGMessage, not be hardcoded off");
	TGTestExpectEqualLongLong(&outcome, (long long)item.message.destructTimer, 8,
			"the self-destruct timer duration must round-trip into TGMessage");
	TGTestExpectEqualDouble(&outcome, item.message.destructIn, 3.5, 0.01,
			"the live self-destruct countdown must round-trip into TGMessage");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestAlbumChannelPostShowsCommentsRow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize mosaic = CGSizeMake(305, 200);
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.mosaicSize = mosaic;
	resolved.stampText = @"18:43";
	resolved.pictureSize = CGSizeMake(112, 200);

	NSDictionary *flat = @{
		@"id"           : @9091,
		@"kind"         : @"messagePhoto",
		@"outgoing"     : @NO,
		@"date"         : @1700000000,
		@"albumId"      : @"9002",
		@"channelPost"  : @YES,
		@"commentCount" : @4,
		@"hasCommentThread" : @YES,
	};
	TGMessageItem *item = [TGMessageItemBuilder itemFromFlatMessage:flat
															 chatId:7
													reuseIdentifier:@"TGBubbleCell.Album"
													   albumMembers:nil
														   resolved:resolved];
	TGMessageLayoutComputed computed = TGMessageLayoutBuildAlbum(item, TGTestContext(448, YES));

	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartComments) != 0,
			"an album posted to a channel with an active discussion thread must carry the comments row part");
	TGTestExpectTrue(&outcome, computed.bubble.comments.size.height > 0,
			"the comments row must have a real, non-zero frame on an album post");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestZeroCommentThreadShowsLeaveACommentRow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = @{
		@"id"           : @9092,
		@"kind"         : @"messageText",
		@"outgoing"     : @NO,
		@"date"         : @1700000000,
		@"channelPost"  : @YES,
		@"commentCount" : @0,
		@"hasCommentThread" : @YES,
	};
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.bodyText = @"Nothing said yet.";
	resolved.stampText = @"19:38";
	TGMessageItem *item = [TGMessageItemBuilder itemFromFlatMessage:flat
															  chatId:9
													 reuseIdentifier:@"TGBubbleCell.Text"
													    albumMembers:nil
													        resolved:resolved];
	TGMessageLayoutComputed computed = TGMessageLayoutBuildText(item, TGTestContext(320, NO));

	TGTestExpectTrue(&outcome, item.commentCount == 0,
			"this fixture models a linked discussion group with no comments yet");
	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartComments) != 0,
			"a channel post with a linked discussion group must show the comments row even at zero comments");
	TGTestExpectTrue(&outcome, computed.bubble.comments.size.height > 0,
			"the zero-state comments row must have a real, non-zero frame inside the bubble");

	return outcome;
}

static TGMessageItem *TGTestPollItem(BOOL closed, BOOL isQuiz, BOOL allowsRevoting) {
	NSDictionary *flat = @{
		@"id"                        : @9093,
		@"kind"                      : @"messagePoll",
		@"outgoing"                  : @NO,
		@"date"                      : @1700000000,
		@"pollQuestion"              : @"Pick one",
		@"pollOptions"               : @[
			@{@"id" : @"0", @"text" : @"First", @"vote_percentage" : @100, @"is_chosen" : @YES},
			@{@"id" : @"1", @"text" : @"Second", @"vote_percentage" : @0, @"is_chosen" : @NO},
		],
		@"pollTotal"                 : @1,
		@"pollClosed"                : @(closed),
		@"pollAnonymous"             : @YES,
		@"pollCanAddOption"          : @NO,
		@"pollIsQuiz"                : @(isQuiz),
		@"pollAllowsMultipleAnswers" : @NO,
		@"pollAllowsRevoting"        : @(allowsRevoting),
		@"pollCorrectOptionId"       : @(-1),
		@"pollExplanation"           : @"",
		@"pollExplanationEntities"   : @[],
	};
	return [TGMessageItemBuilder itemFromFlatMessage:flat
											  chatId:7
									 reuseIdentifier:@"TGBubbleCell.Poll"
										albumMembers:nil
											resolved:[[TGMessageItemResolvedInputs alloc] init]];
}

static BOOL TGTestComputedHasPollRetractRow(TGMessageLayoutComputed computed) {
	for (NSUInteger i = 0; i < computed.repeatedRowCount; i++)
		if (computed.repeatedRows[i].kind == TGMessageLayoutRowPollRetract)
			return YES;
	return NO;
}

TGTestOutcome TGLayoutBuilderTestPollRetractRowRespectsAllowsRevoting(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItem *revotable = TGTestPollItem(NO, NO, YES);
	TGMessageLayoutComputed revotableComputed = TGMessageLayoutBuildPoll(revotable, TGTestContext(320, NO));
	TGTestExpectTrue(&outcome, TGTestComputedHasPollRetractRow(revotableComputed),
			"an open, non-quiz poll that allows revoting must offer a Retract Vote row once answered");

	TGMessageItem *locked = TGTestPollItem(NO, NO, NO);
	TGMessageLayoutComputed lockedComputed = TGMessageLayoutBuildPoll(locked, TGTestContext(320, NO));
	TGTestExpectTrue(&outcome, !TGTestComputedHasPollRetractRow(lockedComputed),
			"a poll created with revoting disabled must never offer a Retract Vote row, even when answered");

	TGMessageItem *quiz = TGTestPollItem(NO, YES, YES);
	TGMessageLayoutComputed quizComputed = TGMessageLayoutBuildPoll(quiz, TGTestContext(320, NO));
	TGTestExpectTrue(&outcome, !TGTestComputedHasPollRetractRow(quizComputed),
			"a quiz must never offer a Retract Vote row regardless of allows_revoting");

	TGMessageItem *closedPoll = TGTestPollItem(YES, NO, YES);
	TGMessageLayoutComputed closedComputed = TGMessageLayoutBuildPoll(closedPoll, TGTestContext(320, NO));
	TGTestExpectTrue(&outcome, !TGTestComputedHasPollRetractRow(closedComputed),
			"a closed poll must never offer a Retract Vote row even when it allowed revoting while open");

	return outcome;
}

static TGMessageItem *TGTestWallpaperItem(NSString *kind, NSString *reuse,
		NSString *forwardName, NSString *quoteBody) {
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.pictureSize = CGSizeMake(128, 128);
	resolved.stampText = @"19:38";
	resolved.forwardDisplayName = forwardName;
	resolved.quoteBodyText = quoteBody;
	resolved.roundNoteDurationText = @"0:12";
	NSDictionary *flat = @{
		@"id"       : @91,
		@"kind"     : kind,
		@"outgoing" : @NO,
		@"date"     : @1700000000,
	};
	return [TGMessageItemBuilder itemFromFlatMessage:flat
											  chatId:7
									 reuseIdentifier:reuse
										albumMembers:nil
											resolved:resolved];
}

TGTestOutcome TGLayoutBuilderTestStickerSitsOnTheWallpaperWithNoBubbleChrome(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItem *item = TGTestWallpaperItem(@"messageSticker", @"TGBubbleCell.Sticker", nil, nil);
	TGMessageLayoutComputed computed = TGMessageLayoutBuildSticker(item, TGTestContext(320, NO));

	TGTestExpectTrue(&outcome, computed.sitsOnWallpaper,
			"a sticker is one of the five kinds that sit directly on the wallpaper");
	TGTestExpectTrue(&outcome, computed.bubbleCornerRadius == 0 && computed.bubbleBorderWidth == 0,
			"so its bubble struct is a positioning frame with no visible chrome");
	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartPlateBeside) != 0,
			"and its timestamp plate sits beside the artwork on the wallpaper, never on it");
	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartForward) == 0,
			"an ordinary sticker carries no forward header");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestForwardedWallpaperContentReservesAHeader(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct {
		NSString *kind;
		NSString *reuse;
		TGMessageLayoutComputed (*build)(TGMessageItem *, TGChatLayoutContext *);
	} cases[] = {
		{@"messageSticker", @"TGBubbleCell.Sticker", TGMessageLayoutBuildSticker},
		{@"messageVideoNote", @"TGBubbleCell.VideoNote", TGMessageLayoutBuildVideoNote},
		{@"messageAnimatedSticker", @"TGBubbleCell.AnimatedSticker", TGMessageLayoutBuildAnimatedSticker},
	};

	for (int i = 0; i < 3; i++) {
		TGChatLayoutContext *context = TGTestContext(320, NO);
		TGMessageItem *plain = TGTestWallpaperItem(cases[i].kind, cases[i].reuse, nil, nil);
		TGMessageItem *forwarded = TGTestWallpaperItem(cases[i].kind, cases[i].reuse, @"Alex", nil);
		TGMessageLayoutComputed plainLayout = cases[i].build(plain, context);
		TGMessageLayoutComputed forwardedLayout = cases[i].build(forwarded, context);

		TGTestExpectTrue(&outcome, (forwardedLayout.parts & TGMessageLayoutPartForward) != 0,
				"a forwarded round video note or animated sticker must show its origin the way a forwarded "
				"sticker already does: only the layout builders were missing it, the cells already draw it");
		TGTestExpectTrue(&outcome, forwardedLayout.bubble.forward.size.height > 0,
				"the forward header needs a real rect, not a zero one the cell would draw nothing into");
		TGTestExpectTrue(&outcome,
				forwardedLayout.messageHeight > plainLayout.messageHeight,
				"the row has to grow by the header, or the header would overlap the artwork");
	}

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestQuotedWallpaperContentSitsBelowTheQuote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatLayoutContext *context = TGTestContext(320, NO);
	TGMessageItem *quotedNote = TGTestWallpaperItem(@"messageVideoNote", @"TGBubbleCell.VideoNote",
			nil, @"the message being answered");
	TGMessageLayoutComputed note = TGMessageLayoutBuildVideoNote(quotedNote, context);

	TGTestExpectTrue(&outcome, (note.parts & TGMessageLayoutPartQuote) != 0,
			"a round video note sent as a reply must carry the quote badge");
	TGTestExpectTrue(&outcome,
			CGRectGetMaxY(note.bubble.quoteTapTarget) <= note.bubble.roundRim.origin.y + 0.5f,
			"the quote sits above the circle, not across it");
	TGTestExpectTrue(&outcome,
			note.bubble.picture.origin.y >= note.bubble.roundRim.origin.y,
			"the video frame stays inside its rim after the shift");

	TGMessageItem *quotedSticker = TGTestWallpaperItem(@"messageAnimatedSticker",
			@"TGBubbleCell.AnimatedSticker", @"Alex", @"the message being answered");
	TGMessageLayoutComputed sticker = TGMessageLayoutBuildAnimatedSticker(quotedSticker, context);

	TGTestExpectTrue(&outcome,
			(sticker.parts & TGMessageLayoutPartForward) != 0 &&
			(sticker.parts & TGMessageLayoutPartQuote) != 0,
			"a forwarded animated sticker sent as a reply carries both blocks");
	TGTestExpectTrue(&outcome,
			CGRectGetMaxY(sticker.bubble.forward) <= sticker.bubble.quoteBar.origin.y,
			"and they stack, forward first, rather than sharing a row");
	TGTestExpectTrue(&outcome,
			CGRectGetMaxY(sticker.bubble.quoteTapTarget) <= sticker.bubble.lottie.origin.y + 0.5f,
			"with the artwork below both");

	return outcome;
}

static TGMessageItem *TGTestKindItem(NSString *kind, NSString *reuse) {
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.pictureSize = CGSizeMake(120, 90);
	resolved.stampText = @"19:38";
	resolved.bodyText = @"body";
	resolved.fileTitleText = @"file.pdf";
	resolved.fileMetaText = @"12 KB";
	resolved.voiceDurationText = @"0:07";
	resolved.roundNoteDurationText = @"0:12";
	NSDictionary *flat = @{
		@"id"       : @55,
		@"kind"     : kind,
		@"outgoing" : @NO,
		@"date"     : @1700000000,
		@"text"     : @"body",
	};
	return [TGMessageItemBuilder itemFromFlatMessage:flat
											  chatId:7
									 reuseIdentifier:reuse
										albumMembers:nil
											resolved:resolved];
}

TGTestOutcome TGLayoutBuilderTestEveryBuilderKeepsThePlateBesideTheBubble(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct {
		NSString *kind;
		NSString *reuse;
		TGMessageLayoutComputed (*build)(TGMessageItem *, TGChatLayoutContext *);
		BOOL wallpaper;
	} cases[] = {
		{@"messageText", @"TGBubbleCell.Text", TGMessageLayoutBuildText, NO},
		{@"messagePhoto", @"TGBubbleCell.Photo", TGMessageLayoutBuildPhoto, NO},
		{@"messageVoiceNote", @"TGBubbleCell.Voice", TGMessageLayoutBuildVoice, NO},
		{@"messageDocument", @"TGBubbleCell.File", TGMessageLayoutBuildFile, NO},
		{@"messageCall", @"TGBubbleCell.Call", TGMessageLayoutBuildCall, NO},
		{@"messagePoll", @"TGBubbleCell.Poll", TGMessageLayoutBuildPoll, NO},
		{@"messageChecklist", @"TGBubbleCell.Checklist", TGMessageLayoutBuildChecklist, NO},
		{@"messageRichMessage", @"TGBubbleCell.RichMessage", TGMessageLayoutBuildRichMessage, NO},
		{@"messageLocation", @"TGBubbleCell.Location", TGMessageLayoutBuildLocation, NO},
		{@"messageSticker", @"TGBubbleCell.Sticker", TGMessageLayoutBuildSticker, YES},
		{@"messageAnimatedEmoji", @"TGBubbleCell.BareEmoji", TGMessageLayoutBuildBareEmoji, YES},
		{@"messageVideoNote", @"TGBubbleCell.VideoNote", TGMessageLayoutBuildVideoNote, YES},
		{@"messageAnimatedSticker", @"TGBubbleCell.AnimatedSticker", TGMessageLayoutBuildAnimatedSticker, YES},
	};

	TGChatLayoutContext *context = TGTestContext(320, NO);
	for (int i = 0; i < 13; i++) {
		TGMessageItem *item = TGTestKindItem(cases[i].kind, cases[i].reuse);
		TGMessageLayoutComputed computed = cases[i].build(item, context);

		TGTestExpectTrue(&outcome, computed.messageHeight > 0,
				"every builder must give its row a height, or the message draws as a zero-height gap");
		TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartBubble) != 0,
				"every message kind is laid out in a bubble frame, including the ones drawn without visible "
				"bubble chrome");
		TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartPlateBeside) != 0,
				"the timestamp plate sits beside the bubble on the wallpaper for every kind — this is the "
				"settled rule a diff must never quietly change, and only the service line, which has no "
				"stamp at all, is exempt");
		TGTestExpectTrue(&outcome, computed.sitsOnWallpaper == cases[i].wallpaper,
				"exactly the round video notes, stickers, animated stickers and animated emoji sit directly "
				"on the wallpaper; every other kind is drawn in a bubble");
		TGTestExpectTrue(&outcome,
				computed.row.bubble.origin.x >= 0 &&
				CGRectGetMaxX(computed.row.bubble) <= context.tableWidth + 0.5f,
				"the bubble frame stays inside the table width it was given, so nothing is clipped or hangs "
				"off the wallpaper");
	}

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestServiceLineHasNoStampAndARoundedPlate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItem *item = TGTestKindItem(@"messagePinMessage", @"TGBubbleCell.Service");
	TGMessageLayoutComputed computed = TGMessageLayoutBuildService(item, TGTestContext(320, NO));

	TGTestExpectTrue(&outcome, (computed.parts & TGMessageLayoutPartPlateBeside) == 0,
			"a service line carries no timestamp plate, which is why it is the one kind exempt from the "
			"plate-beside rule");
	TGTestExpectTrue(&outcome, computed.bubbleCornerRadius > 0,
			"its own plate is fully rounded — nothing in this app has square corners");
	TGTestExpectTrue(&outcome, computed.messageHeight > 0,
			"and it still occupies a row");

	return outcome;
}

TGTestOutcome TGLayoutBuilderTestVideoNoteWithoutASizeIsStillARoundNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.pictureSize = CGSizeZero;
	resolved.stampText = @"19:38";
	resolved.roundNoteDurationText = @"0:12";
	NSDictionary *flat = @{
		@"id" : @92,
		@"kind" : @"messageVideoNote",
		@"outgoing" : @NO,
		@"date" : @1700000000,
	};
	TGMessageItem *item = [TGMessageItemBuilder itemFromFlatMessage:flat
															 chatId:7
													reuseIdentifier:@"TGBubbleCell.VideoNote"
													   albumMembers:nil
														   resolved:resolved];
	TGMessageLayoutComputed computed = TGMessageLayoutBuildVideoNote(item, TGTestContext(320, NO));

	TGTestExpectTrue(&outcome, computed.messageHeight > 100,
			"a round note whose size has not arrived yet still reserves a circle rather than "
			"collapsing, which is what let a view-once note fall through to a text bubble");
	TGTestExpectTrue(&outcome, computed.row.bubble.size.width > 100,
			"and the circle is as wide as it is tall");
	TGTestExpectTrue(&outcome, computed.sitsOnWallpaper,
			"a round note never sits in a bubble, whatever its size");

	return outcome;
}
