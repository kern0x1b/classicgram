#import "tg_rich_text_tests.h"
#import "../../src/Utilities/TGRichText.h"

static TGRichTextPalette *TGRichTextTestPalette(void) {
	return [TGRichTextPalette paletteWithFont:[UIFont systemFontOfSize:15]
									   colour:[UIColor blackColor]
								   linkColour:[UIColor blueColor]
								 accentColour:[UIColor blueColor]];
}

static NSDictionary *TGRichTextTestEntity(NSString *kind, NSInteger offset, NSInteger length) {
	return @{@"kind" : kind, @"offset" : @(offset), @"length" : @(length)};
}

static NSDictionary *TGRichTextTestLinkAt(NSAttributedString *string, NSInteger index) {
	if (index < 0 || (NSUInteger)index >= string.length)
		return nil;
	id value = [string attribute:TGRichLinkAttribute atIndex:(NSUInteger)index effectiveRange:NULL];
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

TGTestOutcome TGRichTextTestEmptyTextBuildsNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGRichTextBuild(@"", @[], TGRichTextTestPalette(), NO) == nil,
			"empty text must build no attributed string at all, so callers can treat nil as \"nothing to draw\"");
	TGTestExpectTrue(&outcome, TGRichTextBuild(nil, @[], TGRichTextTestPalette(), NO) == nil,
			"nil text must build nothing rather than an empty string");

	return outcome;
}

TGTestOutcome TGRichTextTestPlainTextKeepsItsCharactersWithNoEntityAttributes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSAttributedString *built = TGRichTextBuild(@"hello", @[], TGRichTextTestPalette(), NO);

	TGTestExpectTrue(&outcome, [built.string isEqualToString:@"hello"],
			"text with no entities must survive verbatim");
	TGTestExpectTrue(&outcome, TGRichTextTestLinkAt(built, 0) == nil,
			"text with no entities must carry no link attribute");
	TGTestExpectTrue(&outcome,
			[built attribute:TGRichSpoilerAttribute atIndex:0 effectiveRange:NULL] == nil,
			"text with no entities must carry no spoiler attribute");

	return outcome;
}

TGTestOutcome TGRichTextTestUrlEntityCarriesTheUrlItSpans(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"go to telegram.org now";
	NSAttributedString *built = TGRichTextBuild(text,
			@[ TGRichTextTestEntity(@"url", 6, 12) ], TGRichTextTestPalette(), NO);
	NSDictionary *link = TGRichTextTestLinkAt(built, 6);

	TGTestExpectTrue(&outcome, [link[TGRichLinkKindKey] isEqualToString:@"url"],
			"a url entity must produce a url link");
	TGTestExpectTrue(&outcome, [link[TGRichLinkValueKey] isEqualToString:@"telegram.org"],
			"a url entity carries no url of its own, so the value must be exactly the text it spans");
	TGTestExpectTrue(&outcome, TGRichTextTestLinkAt(built, 5) == nil,
			"the character before the entity must not be part of the link");
	TGTestExpectTrue(&outcome, TGRichTextTestLinkAt(built, 18) == nil,
			"the character after the entity must not be part of the link");

	return outcome;
}

TGTestOutcome TGRichTextTestTextUrlEntityCarriesTheEntitysOwnUrlNotTheSpannedText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableDictionary *entity = [TGRichTextTestEntity(@"textUrl", 0, 4) mutableCopy];
	entity[@"url"] = @"https://telegram.org/faq";
	NSAttributedString *built = TGRichTextBuild(@"here", @[ entity ], TGRichTextTestPalette(), NO);
	NSDictionary *link = TGRichTextTestLinkAt(built, 0);

	TGTestExpectTrue(&outcome, [link[TGRichLinkValueKey] isEqualToString:@"https://telegram.org/faq"],
			"a textUrl entity's target is the url it carries, never the visible text it spans");

	return outcome;
}

TGTestOutcome TGRichTextTestEmailEntityGetsMailtoScheme(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSAttributedString *built = TGRichTextBuild(@"a@b.co",
			@[ TGRichTextTestEntity(@"emailAddress", 0, 6) ], TGRichTextTestPalette(), NO);
	NSDictionary *link = TGRichTextTestLinkAt(built, 0);

	TGTestExpectTrue(&outcome, [link[TGRichLinkKindKey] isEqualToString:@"url"],
			"an email address opens as a url");
	TGTestExpectTrue(&outcome, [link[TGRichLinkValueKey] isEqualToString:@"mailto:a@b.co"],
			"an email address must be prefixed with the mailto scheme, or the opener has no scheme to act on");

	return outcome;
}

TGTestOutcome TGRichTextTestMentionNameEntityCarriesTheUserId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableDictionary *entity = [TGRichTextTestEntity(@"mentionName", 0, 4) mutableCopy];
	entity[@"userId"] = @(777000123456789LL);
	NSAttributedString *built = TGRichTextBuild(@"Alex", @[ entity ], TGRichTextTestPalette(), NO);
	NSDictionary *link = TGRichTextTestLinkAt(built, 0);

	TGTestExpectTrue(&outcome, [link[TGRichLinkKindKey] isEqualToString:@"user"],
			"a mentionName entity resolves to a user, not to a @username lookup");
	TGTestExpectTrue(&outcome, [link[TGRichLinkValueKey] isEqualToString:@"777000123456789"],
			"the user id must survive as its full int53 value, not be truncated on the way into the link");

	return outcome;
}

TGTestOutcome TGRichTextTestSpoilerEntityMarksItsRangeAndHidesItUntilRevealed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[ TGRichTextTestEntity(@"spoiler", 0, 6) ];
	NSAttributedString *hiddenBuild = TGRichTextBuild(@"secret", entities, TGRichTextTestPalette(), NO);
	NSAttributedString *revealedBuild = TGRichTextBuild(@"secret", entities, TGRichTextTestPalette(), YES);

	TGTestExpectTrue(&outcome,
			[[hiddenBuild attribute:TGRichSpoilerAttribute atIndex:0 effectiveRange:NULL] boolValue],
			"a spoiler entity must mark its range whether or not it is revealed, so a tap can find it");
	TGTestExpectTrue(&outcome,
			[[revealedBuild attribute:TGRichSpoilerAttribute atIndex:0 effectiveRange:NULL] boolValue],
			"revealing a spoiler must not erase the marker the tap handler relies on");

	id hiddenColour = [hiddenBuild attribute:(__bridge NSString *)kCTForegroundColorAttributeName
									 atIndex:0
							  effectiveRange:NULL];
	id revealedColour = [revealedBuild attribute:(__bridge NSString *)kCTForegroundColorAttributeName
										 atIndex:0
								  effectiveRange:NULL];
	TGTestExpectTrue(&outcome,
			CGColorGetAlpha((CGColorRef)hiddenColour) == 0.0f,
			"an unrevealed spoiler must draw fully transparent, or the text under the cover is readable");
	TGTestExpectTrue(&outcome,
			CGColorGetAlpha((CGColorRef)revealedColour) > 0.0f,
			"a revealed spoiler must draw in a visible colour");

	return outcome;
}

TGTestOutcome TGRichTextTestCustomEmojiEntityCarriesItsIdAsLongLong(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableDictionary *entity = [TGRichTextTestEntity(@"customEmoji", 0, 1) mutableCopy];
	entity[@"customEmojiId"] = @(5350305076663608320LL);
	NSAttributedString *built = TGRichTextBuild(@"x", @[ entity ], TGRichTextTestPalette(), NO);
	id carried = [built attribute:TGRichCustomEmojiAttribute atIndex:0 effectiveRange:NULL];

	TGTestExpectTrue(&outcome, [carried isKindOfClass:NSNumber.class],
			"a custom-emoji entity must mark its range with the emoji id the renderer looks the image up by");
	TGTestExpectEqualInteger(&outcome, [carried longLongValue], 5350305076663608320LL,
			"a custom-emoji id is an int64 document id: it must survive whole, not be narrowed on the way in");

	NSMutableDictionary *zeroed = [TGRichTextTestEntity(@"customEmoji", 0, 1) mutableCopy];
	zeroed[@"customEmojiId"] = @0;
	NSAttributedString *withoutId = TGRichTextBuild(@"x", @[ zeroed ], TGRichTextTestPalette(), NO);
	TGTestExpectTrue(&outcome,
			[withoutId attribute:TGRichCustomEmojiAttribute atIndex:0 effectiveRange:NULL] == nil,
			"a custom-emoji entity with no usable id must not mark the range, or the renderer would request image 0");

	return outcome;
}

TGTestOutcome TGRichTextTestEntityRunningPastTheEndIsClampedNotDropped(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSAttributedString *built = TGRichTextBuild(@"abc",
			@[ TGRichTextTestEntity(@"url", 1, 99) ], TGRichTextTestPalette(), NO);
	NSDictionary *link = TGRichTextTestLinkAt(built, 2);

	TGTestExpectTrue(&outcome, link != nil,
			"an entity whose length runs past the end of the text must be clamped to the text, not discarded");
	TGTestExpectTrue(&outcome, [link[TGRichLinkValueKey] isEqualToString:@"bc"],
			"the clamped link must span exactly the characters that exist");

	return outcome;
}

TGTestOutcome TGRichTextTestOutOfRangeAndMalformedEntitiesAreIgnored(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[
		TGRichTextTestEntity(@"url", -1, 3),
		TGRichTextTestEntity(@"url", 0, 0),
		TGRichTextTestEntity(@"url", 9, 2),
		@{@"offset" : @0, @"length" : @3},
		@"not a dictionary",
	];
	NSAttributedString *built = TGRichTextBuild(@"abc", entities, TGRichTextTestPalette(), NO);

	TGTestExpectTrue(&outcome, [built.string isEqualToString:@"abc"],
			"malformed entities must leave the text itself untouched");
	TGTestExpectTrue(&outcome, TGRichTextTestLinkAt(built, 0) == nil,
			"a negative offset, a zero length, an offset past the end, a missing kind and a non-dictionary "
			"entry must each be skipped rather than crashing or producing a link");

	return outcome;
}

TGTestOutcome TGRichTextTestEntityOffsetsAreUtf16UnitsNotCharacters(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"🙂 telegram.org";
	NSAttributedString *built = TGRichTextBuild(text,
			@[ TGRichTextTestEntity(@"url", 3, 12) ], TGRichTextTestPalette(), NO);
	NSDictionary *link = TGRichTextTestLinkAt(built, 3);

	TGTestExpectTrue(&outcome, [link[TGRichLinkValueKey] isEqualToString:@"telegram.org"],
			"TDLib entity offsets count UTF-16 code units, so an emoji ahead of the entity occupies two of them: "
			"treating the offset as a character index would slice the link one unit early");

	return outcome;
}

TGTestOutcome TGRichTextTestBlockquoteEntityMarksItsRangeAndNumbersBlocks(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"one\ntwo";
	NSAttributedString *built = TGRichTextBuild(text,
			@[ TGRichTextTestEntity(@"blockquote", 0, 3),
			   TGRichTextTestEntity(@"expandableBlockquote", 4, 3) ],
			TGRichTextTestPalette(), NO);

	id first = [built attribute:TGRichBlockAttribute atIndex:0 effectiveRange:NULL];
	id second = [built attribute:TGRichBlockAttribute atIndex:4 effectiveRange:NULL];

	TGTestExpectTrue(&outcome, first != nil && second != nil,
			"both a plain and an expandable blockquote must mark their own range with a block spec");
	TGTestExpectTrue(&outcome, first != second,
			"two blockquotes in one message must be two distinct specs, or expanding one would expand both");

	return outcome;
}
