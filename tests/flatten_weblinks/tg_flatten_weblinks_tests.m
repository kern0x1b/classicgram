#import "tg_flatten_weblinks_tests.h"
#import "../../src/Wire/Flatten/TGFlattenWebLinks.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenWebLinksTestFlattensPlainTextWithNoRuns(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{@"@type" : @"richTextPlain", @"text" : @"hello"};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");

	TGTestExpectTrue(&outcome, pair != nil,
			"a plain text node must flatten to a non-nil pair");
	TGTestExpectTrue(&outcome, [pair[@"text"] isEqualToString:@"hello"],
			"a richTextPlain node's text must pass through unchanged");
	TGTestExpectEqualInteger(&outcome, [pair[@"runs"] count], 0,
			"a bare richTextPlain node must not produce any tappable runs");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensGenericFormattingKinds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTexts",
		@"texts" : @[
			@{@"@type" : @"richTextBold", @"text" : @{@"@type" : @"richTextPlain", @"text" : @"B"}},
			@{@"@type" : @"richTextItalic", @"text" : @{@"@type" : @"richTextPlain", @"text" : @"I"}},
			@{@"@type" : @"richTextUnderline", @"text" : @{@"@type" : @"richTextPlain", @"text" : @"U"}},
			@{@"@type" : @"richTextStrikethrough", @"text" : @{@"@type" : @"richTextPlain", @"text" : @"S"}},
		],
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSArray *runs = pair[@"runs"];

	TGTestExpectTrue(&outcome, [pair[@"text"] isEqualToString:@"BIUS"],
			"four sibling formatting runs must concatenate in order");
	TGTestExpectEqualInteger(&outcome, runs.count, 4,
			"each formatting wrapper must produce exactly one run");

	NSArray *expectedKinds = @[@"bold", @"italic", @"underline", @"strikethrough"];
	for (NSUInteger i = 0; i < expectedKinds.count; i++) {
		NSDictionary *run = runs[i];
		TGTestExpectTrue(&outcome, [run[@"kind"] isEqualToString:expectedKinds[i]],
				"the richText type prefix must be stripped and lowercased into the run kind");
		TGTestExpectEqualInteger(&outcome, [run[@"offset"] integerValue], (NSInteger)i,
				"each single-character run must sit at its own offset");
		TGTestExpectEqualInteger(&outcome, [run[@"length"] integerValue], 1,
				"each single-character run must have length 1");
		TGTestExpectTrue(&outcome, [run[@"tappable"] boolValue] == NO,
				"plain formatting runs like bold or italic must not be marked tappable");
	}

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensUrlLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTextUrl",
		@"url" : @"https://telegram.org",
		@"text" : @{@"@type" : @"richTextPlain", @"text" : @"telegram.org"},
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSDictionary *run = [pair[@"runs"] firstObject];

	TGTestExpectTrue(&outcome, [pair[@"text"] isEqualToString:@"telegram.org"],
			"a richTextUrl node's visible text must come from its nested text child");
	TGTestExpectTrue(&outcome, [run[@"kind"] isEqualToString:@"url"],
			"a richTextUrl node must flatten to a run of kind url");
	TGTestExpectTrue(&outcome, [run[@"tappable"] boolValue] == YES,
			"a url run must be marked tappable");
	TGTestExpectTrue(&outcome, [run[@"url"] isEqualToString:@"https://telegram.org"],
			"a url run must carry the target url separately from its display text");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensEmailAddress(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTextEmailAddress",
		@"email_address" : @"a@b.com",
		@"text" : @{@"@type" : @"richTextPlain", @"text" : @"a@b.com"},
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSDictionary *run = [pair[@"runs"] firstObject];

	TGTestExpectTrue(&outcome, [run[@"kind"] isEqualToString:@"emailAddress"],
			"a richTextEmailAddress node must flatten to a run of kind emailAddress");
	TGTestExpectTrue(&outcome, [run[@"tappable"] boolValue] == YES,
			"an email run must be marked tappable");
	TGTestExpectTrue(&outcome, [run[@"email"] isEqualToString:@"a@b.com"],
			"an email run must carry the email address under its own key");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensPhoneNumber(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTextPhoneNumber",
		@"phone_number" : @"+123456789",
		@"text" : @{@"@type" : @"richTextPlain", @"text" : @"+123456789"},
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSDictionary *run = [pair[@"runs"] firstObject];

	TGTestExpectTrue(&outcome, [run[@"kind"] isEqualToString:@"phoneNumber"],
			"a richTextPhoneNumber node must flatten to a run of kind phoneNumber");
	TGTestExpectTrue(&outcome, [run[@"tappable"] boolValue] == YES,
			"a phone number run must be marked tappable");
	TGTestExpectTrue(&outcome, [run[@"phone"] isEqualToString:@"+123456789"],
			"a phone number run must carry the number under its own key");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensMention(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTextMention",
		@"username" : @"durov",
		@"text" : @{@"@type" : @"richTextPlain", @"text" : @"@durov"},
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSDictionary *run = [pair[@"runs"] firstObject];

	TGTestExpectTrue(&outcome, [run[@"kind"] isEqualToString:@"mention"],
			"a richTextMention node must flatten to a run of kind mention");
	TGTestExpectTrue(&outcome, [run[@"tappable"] boolValue] == YES,
			"a mention run must be marked tappable");
	TGTestExpectTrue(&outcome, [run[@"username"] isEqualToString:@"durov"],
			"a mention run must carry the username under its own key");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensHashtagAndCashtag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTexts",
		@"texts" : @[
			@{@"@type" : @"richTextHashtag", @"hashtag" : @"telegram",
			  @"text" : @{@"@type" : @"richTextPlain", @"text" : @"#telegram"}},
			@{@"@type" : @"richTextPlain", @"text" : @" "},
			@{@"@type" : @"richTextCashtag", @"cashtag" : @"BTC",
			  @"text" : @{@"@type" : @"richTextPlain", @"text" : @"$BTC"}},
		],
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSArray *runs = pair[@"runs"];

	TGTestExpectTrue(&outcome, [pair[@"text"] isEqualToString:@"#telegram $BTC"],
			"hashtag and cashtag runs must concatenate with the plain text between them");
	TGTestExpectEqualInteger(&outcome, runs.count, 2,
			"a hashtag and a cashtag sibling must each produce exactly one run");

	NSDictionary *hashtagRun = runs[0];
	TGTestExpectTrue(&outcome, [hashtagRun[@"kind"] isEqualToString:@"hashtag"],
			"the first run must be the hashtag");
	TGTestExpectTrue(&outcome, [hashtagRun[@"hashtag"] isEqualToString:@"telegram"],
			"a hashtag run must carry the tag text without the # sign");
	TGTestExpectEqualInteger(&outcome, [hashtagRun[@"offset"] integerValue], 0,
			"the hashtag run must start at offset 0");
	TGTestExpectEqualInteger(&outcome, [hashtagRun[@"length"] integerValue], 9,
			"the hashtag run must cover the full \"#telegram\" span");

	NSDictionary *cashtagRun = runs[1];
	TGTestExpectTrue(&outcome, [cashtagRun[@"kind"] isEqualToString:@"cashtag"],
			"the second run must be the cashtag");
	TGTestExpectTrue(&outcome, [cashtagRun[@"cashtag"] isEqualToString:@"BTC"],
			"a cashtag run must carry the ticker text without the $ sign");
	TGTestExpectEqualInteger(&outcome, [cashtagRun[@"offset"] integerValue], 10,
			"the cashtag run must start after \"#telegram \"");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensBankCardNumber(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTextBankCardNumber",
		@"bank_card_number" : @"4111111111111111",
		@"text" : @{@"@type" : @"richTextPlain", @"text" : @"4111 1111 1111 1111"},
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSDictionary *run = [pair[@"runs"] firstObject];

	TGTestExpectTrue(&outcome, [run[@"kind"] isEqualToString:@"bankCardNumber"],
			"a richTextBankCardNumber node must flatten to a run of kind bankCardNumber");
	TGTestExpectTrue(&outcome, [run[@"tappable"] boolValue] == YES,
			"a bank card run must be marked tappable");
	TGTestExpectTrue(&outcome, [run[@"bankCard"] isEqualToString:@"4111111111111111"],
			"a bank card run must carry the digits-only number, not the display text");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensAnchorLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTextAnchorLink",
		@"anchor_name" : @"sec1",
		@"url" : @"https://example.com/article#sec1",
		@"text" : @{@"@type" : @"richTextPlain", @"text" : @"jump"},
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSDictionary *run = [pair[@"runs"] firstObject];

	TGTestExpectTrue(&outcome, [run[@"kind"] isEqualToString:@"anchorLink"],
			"a richTextAnchorLink node must flatten to a run of kind anchorLink");
	TGTestExpectTrue(&outcome, [run[@"anchor"] isEqualToString:@"sec1"],
			"an anchor link run must carry the anchor name");
	TGTestExpectTrue(&outcome, [run[@"url"] isEqualToString:@"https://example.com/article#sec1"],
			"an anchor link run must also carry the full url");
	TGTestExpectTrue(&outcome, [run[@"tappable"] boolValue] == YES,
			"an anchor link run must be marked tappable");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensMentionName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTextMentionName",
		@"user_id" : @12345,
		@"text" : @{@"@type" : @"richTextPlain", @"text" : @"Alice"},
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSDictionary *run = [pair[@"runs"] firstObject];

	TGTestExpectTrue(&outcome, [run[@"kind"] isEqualToString:@"mentionName"],
			"a richTextMentionName node must flatten to a run of kind mentionName");
	TGTestExpectEqualLongLong(&outcome, [run[@"userId"] longLongValue], 12345,
			"a mention-name run must carry the target user id, not a username");
	TGTestExpectTrue(&outcome, [run[@"tappable"] boolValue] == YES,
			"a mention-name run must be marked tappable");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensConcatenatedTextsList(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTexts",
		@"texts" : @[
			@{@"@type" : @"richTextPlain", @"text" : @"Hello, "},
			@{@"@type" : @"richTextBold", @"text" : @{@"@type" : @"richTextPlain", @"text" : @"world"}},
			@{@"@type" : @"richTextPlain", @"text" : @"!"},
		],
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSArray *runs = pair[@"runs"];

	TGTestExpectTrue(&outcome, [pair[@"text"] isEqualToString:@"Hello, world!"],
			"a richTexts list must concatenate every child's text in order");
	TGTestExpectEqualInteger(&outcome, runs.count, 1,
			"only the bold child inside the list must produce a run");

	NSDictionary *run = runs[0];
	TGTestExpectEqualInteger(&outcome, [run[@"offset"] integerValue], 7,
			"the bold run must start right after \"Hello, \"");
	TGTestExpectEqualInteger(&outcome, [run[@"length"] integerValue], 5,
			"the bold run must cover exactly \"world\"");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensNestedBoldContainingLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTextBold",
		@"text" : @{
			@"@type" : @"richTexts",
			@"texts" : @[
				@{@"@type" : @"richTextPlain", @"text" : @"see "},
				@{@"@type" : @"richTextUrl", @"url" : @"https://x",
				  @"text" : @{@"@type" : @"richTextPlain", @"text" : @"here"}},
			],
		},
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");
	NSArray *runs = pair[@"runs"];

	TGTestExpectTrue(&outcome, [pair[@"text"] isEqualToString:@"see here"],
			"a bold wrapper around a list containing a link must still flatten to one joined string");
	TGTestExpectEqualInteger(&outcome, runs.count, 2,
			"both the inner link and the outer bold wrapper must each produce their own run");

	NSDictionary *urlRun = runs[0];
	TGTestExpectTrue(&outcome, [urlRun[@"kind"] isEqualToString:@"url"],
			"the inner run must be recorded before the outer wrapper's run");
	TGTestExpectEqualInteger(&outcome, [urlRun[@"offset"] integerValue], 4,
			"the nested url run must start where \"here\" begins, not at 0");
	TGTestExpectEqualInteger(&outcome, [urlRun[@"length"] integerValue], 4,
			"the nested url run must cover only \"here\", not the whole bold span");

	NSDictionary *boldRun = runs[1];
	TGTestExpectTrue(&outcome, [boldRun[@"kind"] isEqualToString:@"bold"],
			"the outer wrapper must still produce a bold run spanning its whole child text");
	TGTestExpectEqualInteger(&outcome, [boldRun[@"offset"] integerValue], 0,
			"the outer bold run must start at 0");
	TGTestExpectEqualInteger(&outcome, [boldRun[@"length"] integerValue], 8,
			"the outer bold run must span the entire \"see here\" text");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensNonRunProducingKinds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *node = @{
		@"@type" : @"richTexts",
		@"texts" : @[
			@{@"@type" : @"richTextMathematicalExpression", @"expression" : @"E=mc^2"},
			@{@"@type" : @"richTextCustomEmoji", @"alternative_text" : @"🙂", @"custom_emoji_id" : @999},
			@{@"@type" : @"richTextAnchor", @"name" : @"top"},
			@{@"@type" : @"richTextIcon", @"document" : @{}},
			@{@"@type" : @"richTextPlain", @"text" : @" done"},
		],
	};
	NSDictionary *pair = TGWLRichPair(node, @"text", @"runs");

	TGTestExpectTrue(&outcome, [pair[@"text"] isEqualToString:@"E=mc^2🙂 done"],
			"mathematical expressions and custom emoji must contribute their fallback text");
	TGTestExpectEqualInteger(&outcome, [pair[@"runs"] count], 0,
			"anchors, icons, math expressions and custom emoji must never produce tappable runs");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensEmptyOrNilNode(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGWLRichPair(nil, @"text", @"runs") == nil,
			"a nil rich text node must flatten to nil, not an empty dictionary");
	TGTestExpectTrue(&outcome, TGWLRichPair(@"not a dictionary", @"text", @"runs") == nil,
			"a non-dictionary rich text node must be coerced away safely, not crash");
	TGTestExpectTrue(&outcome, TGWLRichPair(@{}, @"text", @"runs") == nil,
			"an empty dictionary with no @type must flatten to nil rather than a run of unknown kind");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensUnknownNodeTypeFallsThroughSafely(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *nodeWithChild = @{
		@"@type" : @"richTextFutureFancyStyle",
		@"text" : @{@"@type" : @"richTextPlain", @"text" : @"abc"},
	};
	NSDictionary *pair = TGWLRichPair(nodeWithChild, @"text", @"runs");

	TGTestExpectTrue(&outcome, [pair[@"text"] isEqualToString:@"abc"],
			"an unrecognised wrapper kind must still surface its child's text");
	TGTestExpectEqualInteger(&outcome, [pair[@"runs"] count], 1,
			"an unrecognised wrapper kind must still produce a generic run rather than crash");
	TGTestExpectTrue(&outcome, [pair[@"runs"][0][@"kind"] isEqualToString:@"futureFancyStyle"],
			"an unrecognised kind's run must still carry its stripped type name");
	TGTestExpectTrue(&outcome, [pair[@"runs"][0][@"tappable"] boolValue] == NO,
			"an unrecognised kind must default to non-tappable since it has no known link fields");

	NSDictionary *leafWithNoChild = @{@"@type" : @"richTextTotallyUnknownLeaf"};
	NSDictionary *leafPair = TGWLRichPair(leafWithNoChild, @"text", @"runs");

	TGTestExpectTrue(&outcome, leafPair == nil,
			"an unrecognised leaf kind with no text child must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensPageBlocksWithMultipleKinds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *rawBlocks = @[
		@{
			@"@type" : @"pageBlockTitle",
			@"title" : @{@"@type" : @"richTextPlain", @"text" : @"Big Title"},
		},
		@{
			@"@type" : @"pageBlockPhoto",
			@"photo" : @{
				@"@type" : @"photo",
				@"sizes" : @[
					@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @111},
					  @"width" : @100, @"height" : @50},
					@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @112},
					  @"width" : @400, @"height" : @300},
				],
			},
			@"url" : @"https://example.com/photo",
		},
		@{
			@"@type" : @"pageBlockCollage",
			@"blocks" : @[
				@{
					@"@type" : @"pageBlockPhoto",
					@"photo" : @{
						@"@type" : @"photo",
						@"sizes" : @[
							@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @222},
							  @"width" : @10, @"height" : @10},
						],
					},
				},
			],
		},
	];

	NSArray *flat = TGWLBlocks(rawBlocks);

	TGTestExpectEqualInteger(&outcome, flat.count, 3,
			"three well-formed page blocks must all survive flattening");

	NSDictionary *titleBlock = flat[0];
	TGTestExpectTrue(&outcome, [titleBlock[@"kind"] isEqualToString:@"title"],
			"the pageBlock type prefix must be stripped to just \"title\"");
	TGTestExpectTrue(&outcome, [titleBlock[@"text"] isEqualToString:@"Big Title"],
			"a title block's rich text must flatten into its text field");

	NSDictionary *photoBlock = flat[1];
	TGTestExpectTrue(&outcome, [photoBlock[@"kind"] isEqualToString:@"photo"],
			"a pageBlockPhoto must flatten to kind photo");
	TGTestExpectEqualLongLong(&outcome, [photoBlock[@"photoFileId"] longLongValue], 112,
			"a photo block must pick the largest available photo size, not the first one");
	TGTestExpectEqualInteger(&outcome, [photoBlock[@"width"] integerValue], 400,
			"the chosen photo size's width must be exposed on the block");
	TGTestExpectTrue(&outcome, [photoBlock[@"url"] isEqualToString:@"https://example.com/photo"],
			"a photo block's outbound url must be preserved");

	NSDictionary *collageBlock = flat[2];
	TGTestExpectTrue(&outcome, [collageBlock[@"kind"] isEqualToString:@"collage"],
			"a pageBlockCollage must flatten to kind collage");
	NSArray *nested = collageBlock[@"blocks"];
	TGTestExpectEqualInteger(&outcome, nested.count, 1,
			"a collage's nested blocks must be recursively flattened");
	TGTestExpectEqualLongLong(&outcome, [nested[0][@"photoFileId"] longLongValue], 222,
			"a nested photo block inside a collage must flatten just like a top-level one");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensPageBlocksSkipsMalformedEntries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *rawBlocks = @[
		@"not a block",
		@{
			@"@type" : @"pageBlockFooter",
			@"footer" : @{@"@type" : @"richTextPlain", @"text" : @"end"},
		},
		[NSNull null],
	];

	NSArray *flat = TGWLBlocks(rawBlocks);

	TGTestExpectEqualInteger(&outcome, flat.count, 1,
			"malformed entries in the raw blocks array must be dropped, not crash or produce placeholders");
	TGTestExpectTrue(&outcome, [flat[0][@"kind"] isEqualToString:@"footer"],
			"the one well-formed block must still flatten correctly despite its malformed neighbours");
	TGTestExpectTrue(&outcome, [flat[0][@"text"] isEqualToString:@"end"],
			"the surviving block's rich text must flatten as usual");

	return outcome;
}

TGTestOutcome TGFlattenWebLinksTestFlattensCoverHoistsInnerPhotoFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *rawBlocks = @[
		@{
			@"@type" : @"pageBlockCover",
			@"cover" : @{
				@"@type" : @"pageBlockPhoto",
				@"photo" : @{
					@"@type" : @"photo",
					@"sizes" : @[
						@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @555},
						  @"width" : @800, @"height" : @600},
					],
				},
				@"caption" : @{
					@"text" : @{@"@type" : @"richTextPlain", @"text" : @"Lead photo"},
				},
			},
		},
	];

	NSArray *flat = TGWLBlocks(rawBlocks);

	TGTestExpectEqualInteger(&outcome, flat.count, 1,
			"a pageBlockCover must flatten to exactly one row");

	NSDictionary *coverBlock = flat[0];
	TGTestExpectTrue(&outcome, [coverBlock[@"kind"] isEqualToString:@"cover"],
			"a pageBlockCover must keep its own kind, not the inner block's kind");
	TGTestExpectEqualLongLong(&outcome, [coverBlock[@"photoFileId"] longLongValue], 555,
			"the inner photo's file id must be hoisted onto the outer cover block, since the "
			"renderer reads photoFileId straight off the block it classifies as media");
	TGTestExpectEqualInteger(&outcome, [coverBlock[@"width"] integerValue], 800,
			"the inner photo's width must be hoisted the same way as its file id");
	TGTestExpectTrue(&outcome, [coverBlock[@"captionText"] isEqualToString:@"Lead photo"],
			"the inner photo's caption must be hoisted so the cover's own caption still renders");

	NSArray *nested = coverBlock[@"blocks"];
	TGTestExpectEqualInteger(&outcome, nested.count, 1,
			"the inner block must still be reachable in full under blocks, for any consumer that wants it");
	TGTestExpectTrue(&outcome, [nested[0][@"kind"] isEqualToString:@"photo"],
			"the nested block itself must still report its own real kind");

	return outcome;
}
