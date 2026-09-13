#import "tg_flatten_chat_list_tests.h"
#import "../../src/Wire/Flatten/TGFlattenChatList.h"
#import <Foundation/Foundation.h>

static id TGFCLNestedFormattedText(NSString *leaf, NSInteger depth) {
	id nested = leaf;
	for (NSInteger i = 0; i < depth; i++)
		nested = @{@"text" : nested};
	return nested;
}

TGTestOutcome TGFlattenChatListTestPlainTextReturnsFlatStringUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPlainText(@"hello world") isEqualToString:@"hello world"],
			"a plain NSString input must pass through TGPlainText unchanged");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestPlainTextUnwrapsOneLevelOfNesting(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *formatted = @{@"text" : @"hello world"};

	TGTestExpectTrue(&outcome, [TGPlainText(formatted) isEqualToString:@"hello world"],
			"a single level of {text: string} nesting must unwrap to the inner string");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestPlainTextUnwrapsMultipleLevelsOfNesting(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	id threeDeep = TGFCLNestedFormattedText(@"hello world", 3);

	TGTestExpectTrue(&outcome, [TGPlainText(threeDeep) isEqualToString:@"hello world"],
			"three levels of {text: {text: {text: string}}} nesting must recurse down to the leaf string");

	id fiveDeep = TGFCLNestedFormattedText(@"nested five", 5);

	TGTestExpectTrue(&outcome, [TGPlainText(fiveDeep) isEqualToString:@"nested five"],
			"five levels of nesting must still recurse down to the leaf string");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestPlainTextReturnsEmptyForNilAndEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPlainText(nil) isEqualToString:@""],
			"a nil formatted-text input must flatten to an empty string, not crash");
	TGTestExpectTrue(&outcome, [TGPlainText(@{}) isEqualToString:@""],
			"an empty dictionary with no text key must flatten to an empty string");
	TGTestExpectTrue(&outcome, [TGPlainText(@{@"text" : @(42)}) isEqualToString:@""],
			"a text key whose value is neither a string nor a dictionary must flatten to an empty string, not crash");
	TGTestExpectTrue(&outcome, [TGPlainText(@(7)) isEqualToString:@""],
			"a formatted-text input that is neither a string nor a dictionary must flatten to an empty string");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestPlainTextSurvivesDeepRecursion(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	id deep = TGFCLNestedFormattedText(@"still here", 500);

	TGTestExpectTrue(&outcome, [TGPlainText(deep) isEqualToString:@"still here"],
			"500 levels of {text: ...} nesting must still terminate at the leaf string without crashing");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestChatListObjectRoundTripsMain(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *object = TGChatListObject(TGChatListMain);

	TGTestExpectTrue(&outcome, [object[@"@type"] isEqualToString:@"chatListMain"],
			"TGChatListMain must serialise to a chatListMain TDLib object");
	TGTestExpectEqualInteger(&outcome, TGChatListIdFromObject(object), TGChatListMain,
			"a chatListMain object must round-trip back to TGChatListMain");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestChatListObjectRoundTripsArchive(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *object = TGChatListObject(TGChatListArchive);

	TGTestExpectTrue(&outcome, [object[@"@type"] isEqualToString:@"chatListArchive"],
			"TGChatListArchive must serialise to a chatListArchive TDLib object");
	TGTestExpectEqualInteger(&outcome, TGChatListIdFromObject(object), TGChatListArchive,
			"a chatListArchive object must round-trip back to TGChatListArchive");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestChatListObjectRoundTripsFolder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatListId folderId = 5;
	NSDictionary *object = TGChatListObject(folderId);

	TGTestExpectTrue(&outcome, [object[@"@type"] isEqualToString:@"chatListFolder"],
			"a positive chat list id must serialise to a chatListFolder TDLib object");
	TGTestExpectEqualInteger(&outcome, [object[@"chat_folder_id"] integerValue], folderId,
			"the chatListFolder object must carry the folder id verbatim");
	TGTestExpectEqualInteger(&outcome, TGChatListIdFromObject(object), folderId,
			"a chatListFolder object must round-trip back to its original folder id");

	NSDictionary *unknown = @{@"@type" : @"chatListSomethingElse"};

	TGTestExpectEqualInteger(&outcome, TGChatListIdFromObject(unknown), TGChatListMain,
			"an unrecognised chat list object must fall back to TGChatListMain");
	TGTestExpectEqualInteger(&outcome, TGChatListIdFromObject(nil), TGChatListMain,
			"a nil chat list object must fall back to TGChatListMain, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestUnreadContributionReturnsRawCountWhenPositive(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *unmarked = @{@"unread" : @(5), @"markedUnread" : @(NO)};
	TGTestExpectEqualInteger(&outcome, TGUnreadContributionForChatRow(unmarked), 5,
			"a chat with a genuine positive unread count must contribute that count unchanged");

	NSDictionary *markedAndUnread = @{@"unread" : @(3), @"markedUnread" : @(YES)};
	TGTestExpectEqualInteger(&outcome, TGUnreadContributionForChatRow(markedAndUnread), 3,
			"a chat that is both marked-unread and has a real unread count must contribute the real count, not 1");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestUnreadContributionReturnsOneForMarkedUnreadZeroCount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *markedZero = @{@"unread" : @(0), @"markedUnread" : @(YES)};
	TGTestExpectEqualInteger(&outcome, TGUnreadContributionForChatRow(markedZero), 1,
			"a chat marked as unread with zero real unread messages must still contribute 1, like a genuinely-unread chat would");

	NSDictionary *missingUnreadKey = @{@"markedUnread" : @(YES)};
	TGTestExpectEqualInteger(&outcome, TGUnreadContributionForChatRow(missingUnreadKey), 1,
			"a marked-unread chat with no unread key at all must be treated the same as an explicit zero count");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestUnreadContributionReturnsZeroWhenNeitherUnreadNorMarked(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *quiet = @{@"unread" : @(0), @"markedUnread" : @(NO)};
	TGTestExpectEqualInteger(&outcome, TGUnreadContributionForChatRow(quiet), 0,
			"a chat with no real unread messages and no manual mark must contribute nothing");

	NSDictionary *empty = @{};
	TGTestExpectEqualInteger(&outcome, TGUnreadContributionForChatRow(empty), 0,
			"a row missing both keys entirely must contribute nothing, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestUnreadContributionHandlesNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGUnreadContributionForChatRow(nil), 0,
			"a nil chat row must contribute nothing, not crash");
	TGTestExpectEqualInteger(&outcome, TGUnreadContributionForChatRow((id)@"not a dictionary"), 0,
			"a chat row that is not a dictionary must contribute nothing, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestFolderExclusionExcludesMutedChatWithNoUnreadMention(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *folder = @{@"excludeMuted" : @(YES)};
	NSDictionary *chat = @{@"isMuted" : @(YES), @"unreadMentionCount" : @(0)};

	TGTestExpectTrue(&outcome, !TGChatFolderExclusionAllowsChat(folder, chat),
			"a muted chat with no unread mention must be excluded when excludeMuted is set");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestFolderExclusionKeepsMutedChatWithUnreadMention(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *folder = @{@"excludeMuted" : @(YES)};
	NSDictionary *chat = @{@"isMuted" : @(YES), @"unreadMentionCount" : @(1)};

	TGTestExpectTrue(&outcome, TGChatFolderExclusionAllowsChat(folder, chat),
			"a muted chat with an unread mention must not be excluded, matching TDLib's has_unread_mentions_ override");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestFolderExclusionExcludesReadChatWithNoUnreadMention(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *folder = @{@"excludeRead" : @(YES)};
	NSDictionary *chat = @{@"unread" : @(0), @"markedUnread" : @(NO), @"unreadMentionCount" : @(0)};

	TGTestExpectTrue(&outcome, !TGChatFolderExclusionAllowsChat(folder, chat),
			"a read chat with no unread mention must be excluded when excludeRead is set");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestFolderExclusionKeepsReadChatWithUnreadMention(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *folder = @{@"excludeRead" : @(YES)};
	NSDictionary *chat = @{@"unread" : @(0), @"markedUnread" : @(NO), @"unreadMentionCount" : @(2)};

	TGTestExpectTrue(&outcome, TGChatFolderExclusionAllowsChat(folder, chat),
			"a read chat with an unread mention must not be excluded, matching TDLib's has_unread_mentions_ override");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestFolderExclusionArchivedIsNeverOverriddenByUnreadMention(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *folder = @{@"excludeArchived" : @(YES)};
	NSDictionary *chat = @{@"archiveOrder" : @(1), @"unreadMentionCount" : @(5)};

	TGTestExpectTrue(&outcome, !TGChatFolderExclusionAllowsChat(folder, chat),
			"excludeArchived must still exclude an archived chat even when it has an unread mention, "
			"since TDLib's has_unread_mentions_ override applies only to exclude_muted and exclude_read");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestFolderExclusionAllowsNonExcludedChat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *folder = @{@"excludeMuted" : @(YES), @"excludeRead" : @(YES), @"excludeArchived" : @(YES)};
	NSDictionary *chat = @{@"isMuted" : @(NO), @"unread" : @(3), @"markedUnread" : @(NO),
		@"archiveOrder" : @(0), @"unreadMentionCount" : @(0)};

	TGTestExpectTrue(&outcome, TGChatFolderExclusionAllowsChat(folder, chat),
			"a chat that trips none of the exclusion rules must be allowed");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestFolderExclusionHandlesNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatFolderExclusionAllowsChat(nil, nil),
			"a nil folder and chat must not be excluded, not crash");
	TGTestExpectTrue(&outcome, TGChatFolderExclusionAllowsChat((id)@"not a dictionary", @{}),
			"a non-dictionary folder must not be excluded, not crash");
	TGTestExpectTrue(&outcome, TGChatFolderExclusionAllowsChat(@{}, (id)@"not a dictionary"),
			"a non-dictionary chat must not be excluded, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestFolderNamePayloadKeepsTheServersEntities(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *wireName = @{@"@type" : @"chatFolderName",
		@"text" : @{@"@type" : @"formattedText",
			@"text" : @"Work",
			@"entities" : @[ @{@"@type" : @"textEntity", @"offset" : @0, @"length" : @1} ]},
		@"animate_custom_emoji" : @YES};

	NSDictionary *unchanged = TGChatFolderNamePayload(wireName, @"Work");
	TGTestExpectTrue(&outcome, unchanged == wireName,
			"a title the user did not retype is sent back exactly as the server sent it, custom "
			"emoji entities and animation flag included");

	NSDictionary *renamed = TGChatFolderNamePayload(wireName, @"Office");
	TGTestExpectTrue(&outcome,
			[renamed[@"text"][@"text"] isEqualToString:@"Office"],
			"a retyped title is what gets sent");
	TGTestExpectTrue(&outcome, [renamed[@"text"][@"entities"] count] == 0,
			"entities of the old name do not survive a rename, their offsets no longer mean anything");
	TGTestExpectTrue(&outcome, ![renamed[@"animate_custom_emoji"] boolValue],
			"a renamed folder carries no animation flag, having no custom emoji left to animate");

	NSDictionary *fresh = TGChatFolderNamePayload(nil, @"New");
	TGTestExpectTrue(&outcome, [fresh[@"@type"] isEqualToString:@"chatFolderName"] &&
					[fresh[@"text"][@"text"] isEqualToString:@"New"],
			"a folder being created has no server name to preserve");
	TGTestExpectTrue(&outcome,
			[TGChatFolderNamePayload(nil, nil)[@"text"][@"text"] isEqualToString:@""],
			"no title at all is an empty name, not nil in the payload");
	TGTestExpectTrue(&outcome,
			[TGChatFolderNamePayload((NSDictionary *)@"x", @"Work")[@"text"][@"text"]
					isEqualToString:@"Work"],
			"a name of the wrong type off the wire must not be sent back as one");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestTheBadgeCountsWhatTheSettingsSay(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *chats = @[
		@{ @"unread" : @(3) },
		@{ @"unread" : @(7), @"isMuted" : @YES },
		@{ @"unread" : @(0), @"markedUnread" : @YES },
		@{ @"unread" : @(0) },
		@"not a chat at all",
	];

	TGTestExpectEqualInteger(&outcome, TGUnreadBadgeCountInChatRows(chats, YES, NO), 2,
			"counting chats without the muted ones: the one with three unread and the one marked "
			"unread by hand");
	TGTestExpectEqualInteger(&outcome, TGUnreadBadgeCountInChatRows(chats, YES, YES), 3,
			"including muted adds the muted chat, still as one chat");
	TGTestExpectEqualInteger(&outcome, TGUnreadBadgeCountInChatRows(chats, NO, NO), 4,
			"counting messages: three unread plus the one a hand-marked chat contributes");
	TGTestExpectEqualInteger(&outcome, TGUnreadBadgeCountInChatRows(chats, NO, YES), 11,
			"counting messages including muted adds that chat's seven");

	TGTestExpectEqualInteger(&outcome, TGUnreadBadgeCountInChatRows(@[], YES, YES), 0,
			"no chats, no badge");
	TGTestExpectEqualInteger(&outcome, TGUnreadBadgeCountInChatRows(nil, YES, YES), 0,
			"nothing to count is not a crash");

	return outcome;
}

TGTestOutcome TGFlattenChatListTestChatCountUpdateFeedsTheBadge(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *update = @{
		@"@type" : @"updateUnreadChatCount",
		@"total_count" : @40,
		@"unread_count" : @7,
		@"unread_unmuted_count" : @3,
		@"marked_as_unread_count" : @2,
		@"marked_as_unread_unmuted_count" : @1,
	};

	TGTestExpectEqualLongLong(&outcome, TGUnreadChatCountFromUpdate(update, YES), 9,
			"counting chats with muted ones included adds the chats marked unread by hand to "
			"the chats that have unread messages");
	TGTestExpectEqualLongLong(&outcome, TGUnreadChatCountFromUpdate(update, NO), 4,
			"and the unmuted pair does the same among unmuted chats");
	TGTestExpectEqualLongLong(&outcome, TGUnreadChatCountFromUpdate(@{}, YES), 0,
			"an update with no counts is zero rather than a stale number");
	TGTestExpectEqualLongLong(&outcome, TGUnreadChatCountFromUpdate(nil, NO), 0,
			"and so is no update at all");
	TGTestExpectEqualLongLong(&outcome,
			TGUnreadChatCountFromUpdate(@{@"unread_count" : @(-3),
				@"marked_as_unread_count" : @2}, YES), 2,
			"a negative count cannot subtract from the badge");

	return outcome;
}
