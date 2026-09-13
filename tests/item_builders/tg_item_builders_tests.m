#import "tg_item_builders_tests.h"
#import "../../src/Screens/Groups/Items/TGNewGroupMembersItemBuilder.h"
#import "../../src/Screens/Calls/Items/TGCallsItemBuilder.h"
#import "../../src/Screens/Groups/Items/TGGroupMembersItemBuilder.h"
#import "../../src/Screens/Groups/Items/TGSupergroupUsernamesItemBuilder.h"
#import "../../src/Screens/Settings/Items/TGAccountUsernamesItemBuilder.h"
#import "../../src/Screens/Settings/Items/TGConnectedWebsitesItemBuilder.h"
#import "../../src/Screens/Settings/Items/TGHiddenStoriesItemBuilder.h"
#import "../../src/Screens/Settings/Items/TGPrivacyContactPickerItemBuilder.h"
#import "../../src/Screens/Stars/Items/TGStarsListItemBuilder.h"
#import "../../src/Screens/Profile/Items/TGProfileDetailItemBuilder.h"
#import "../../src/Screens/Search/Items/TGSearchResultItemBuilder.h"
#import "../../src/Screens/Search/Items/TGSearchResultItem.h"
#import "../../src/Screens/Profile/Items/TGProfileDetailItem.h"
#import "../../src/Screens/Stickers/Items/TGOwnedSetsItemBuilder.h"
#import "../../src/Screens/Storage/Items/TGStorageDownloadsItemBuilder.h"
#import "../../src/Screens/Stories/Items/TGStoryViewersItemBuilder.h"

TGTestOutcome TGItemBuildersTestStorageDownloadsNamesAFileFromTheBestSourceItHas(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStorageDownloadsItem *named = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"name" : @"holiday.mp4", @"fileId" : @41}
		  suggestedNames:@{@41 : @"suggested.mp4"}];
	TGTestExpectTrue(&outcome, [named.titleText isEqualToString:@"holiday.mp4"],
			"the file's own name wins over a suggestion");

	TGStorageDownloadsItem *suggested = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"fileId" : @41}
		  suggestedNames:@{@41 : @"suggested.mp4"}];
	TGTestExpectTrue(&outcome, [suggested.titleText isEqualToString:@"suggested.mp4"],
			"a file with no name of its own takes the suggested name for its own file id");

	TGStorageDownloadsItem *empty = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"name" : @"", @"fileId" : @41}
		  suggestedNames:@{@41 : @"suggested.mp4"}];
	TGTestExpectTrue(&outcome, [empty.titleText isEqualToString:@"suggested.mp4"],
			"an empty name is treated as absent, not shown as a blank row");

	TGStorageDownloadsItem *wrongType = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"name" : @41, @"fileId" : @41}
		  suggestedNames:@{@41 : @"suggested.mp4"}];
	TGTestExpectTrue(&outcome, [wrongType.titleText isEqualToString:@"suggested.mp4"],
			"a name that is not a string off the wire must not reach the label");

	TGStorageDownloadsItem *numbered = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"fileId" : @41}
		  suggestedNames:@{}];
	TGTestExpectTrue(&outcome, [numbered.titleText isEqualToString:@"File 41"],
			"with no name anywhere the row is numbered by file id");

	TGStorageDownloadsItem *nothing = [TGStorageDownloadsItemBuilder itemForEntry:@{} suggestedNames:nil];
	TGTestExpectTrue(&outcome, [nothing.titleText isEqualToString:@"File 0"],
			"an empty entry must not crash the row");

	return outcome;
}

TGTestOutcome TGItemBuildersTestStorageDownloadsDetailReadsProgressCompletionAndPause(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStorageDownloadsItem *complete = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"fileId" : @1, @"size" : @2048, @"downloaded" : @2048, @"isComplete" : @YES}
		  suggestedNames:nil];
	TGTestExpectTrue(&outcome, [complete.detailText isEqualToString:@"2 KB"],
			"a finished download shows its size alone, no progress");

	TGStorageDownloadsItem *completeUnsized = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"fileId" : @1, @"downloaded" : @2048, @"isComplete" : @YES}
		  suggestedNames:nil];
	TGTestExpectTrue(&outcome, [completeUnsized.detailText isEqualToString:@"Downloaded"],
			"a finished download of unknown size says so in words");

	TGStorageDownloadsItem *running = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"fileId" : @1, @"size" : @2048, @"downloaded" : @1024}
		  suggestedNames:nil];
	TGTestExpectTrue(&outcome, [running.detailText isEqualToString:@"1 KB of 2 KB"],
			"a running download reads as done-of-total");

	TGStorageDownloadsItem *paused = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"fileId" : @1, @"size" : @2048, @"downloaded" : @1024, @"isPaused" : @YES}
		  suggestedNames:nil];
	TGTestExpectTrue(&outcome, [paused.detailText isEqualToString:@"paused, 1 KB of 2 KB"],
			"a paused download keeps its progress and says it is paused");

	TGStorageDownloadsItem *unsized = [TGStorageDownloadsItemBuilder
			itemForEntry:@{@"fileId" : @1, @"downloaded" : @512}
		  suggestedNames:nil];
	TGTestExpectTrue(&outcome, [unsized.detailText isEqualToString:@"512 B"],
			"a download with no known total shows only what has arrived");

	return outcome;
}

TGTestOutcome TGItemBuildersTestStorageDownloadsFixedRowsCarryTheirOwnKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStorageDownloadsItem *clear = [TGStorageDownloadsItemBuilder itemForClearRow];
	TGTestExpectTrue(&outcome, clear.kind == TGStorageDownloadsRowKindClear,
			"the clear row is its own kind");
	TGTestExpectTrue(&outcome, [clear.titleText isEqualToString:@"Clear Download List"],
			"the clear row is titled");
	TGTestExpectTrue(&outcome, clear.detailText == nil, "the clear row carries no detail");

	TGStorageDownloadsItem *loading = [TGStorageDownloadsItemBuilder itemForLoadingRow];
	TGTestExpectTrue(&outcome, loading.kind == TGStorageDownloadsRowKindLoading,
			"the loading row is its own kind");

	TGStorageDownloadsItem *emptyRow = [TGStorageDownloadsItemBuilder itemForEmptyRow];
	TGTestExpectTrue(&outcome, emptyRow.kind == TGStorageDownloadsRowKindEmpty &&
					[emptyRow.titleText isEqualToString:@"Nothing downloaded"],
			"the empty row says nothing has been downloaded");

	TGStorageDownloadsItem *more = [TGStorageDownloadsItemBuilder itemForMoreRowLoading:NO];
	TGStorageDownloadsItem *moreLoading = [TGStorageDownloadsItemBuilder itemForMoreRowLoading:YES];
	TGTestExpectTrue(&outcome, more.kind == TGStorageDownloadsRowKindMore &&
					moreLoading.kind == TGStorageDownloadsRowKindMore,
			"the more row keeps one kind whether or not it is loading");
	TGTestExpectTrue(&outcome, ![more.titleText isEqualToString:moreLoading.titleText],
			"the more row's text changes while a page is in flight");

	return outcome;
}

TGTestOutcome TGItemBuildersTestStarsListChoosesSubtitleOverValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStarsListItem *value = [TGStarsListItemBuilder
			itemFromRow:@{@"title" : @"Balance", @"value" : @"120"}];
	TGTestExpectTrue(&outcome, value.kind == TGStarsListRowKindValue,
			"a row with only a value is a value row");
	TGTestExpectTrue(&outcome, [value.detailText isEqualToString:@"120"],
			"a value row shows the value on the right");

	TGStarsListItem *subtitled = [TGStarsListItemBuilder
			itemFromRow:@{@"title" : @"Gift", @"value" : @"120", @"subtitle" : @"to Alice"}];
	TGTestExpectTrue(&outcome, subtitled.kind == TGStarsListRowKindSubtitle,
			"a subtitle turns the row into a subtitle row");
	TGTestExpectTrue(&outcome, [subtitled.detailText isEqualToString:@"to Alice"],
			"the subtitle replaces the value as the row's detail");

	TGStarsListItem *emptySubtitle = [TGStarsListItemBuilder
			itemFromRow:@{@"title" : @"Gift", @"value" : @"120", @"subtitle" : @""}];
	TGTestExpectTrue(&outcome, emptySubtitle.kind == TGStarsListRowKindValue &&
					[emptySubtitle.detailText isEqualToString:@"120"],
			"an empty subtitle is treated as absent");

	return outcome;
}

TGTestOutcome TGItemBuildersTestStarsListRefusesABadgeRowAndReadsTheFlags(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStarsListItemBuilder itemFromRow:(@{@"title" : @"Stars", @"badge" : @"99"})] == nil,
			"a badge row has no item, so the bridge leaves it to the legacy path");
	TGTestExpectTrue(&outcome,
			[TGStarsListItemBuilder itemFromRow:(@{@"title" : @"Stars", @"badge" : @""})] != nil,
			"an empty badge is not a badge row");

	TGStarsListItem *plain = [TGStarsListItemBuilder itemFromRow:@{@"title" : @"Stars"}];
	TGTestExpectTrue(&outcome, !plain.tappable && !plain.destructive,
			"a row with no block and no destructive flag is neither tappable nor destructive");
	TGTestExpectTrue(&outcome, !plain.statusIsLoading && !plain.statusIsMore,
			"a content row is never a status row");

	TGStarsListItem *tappable = [TGStarsListItemBuilder
			itemFromRow:@{@"title" : @"Stars", @"block" : ^{
			}, @"destructive" : @YES}];
	TGTestExpectTrue(&outcome, tappable.tappable && tappable.destructive,
			"a row with a block is tappable and keeps its destructive flag");

	return outcome;
}

TGTestOutcome TGItemBuildersTestStarsListStatusRowTextFollowsTheState(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStarsListItem *loading = [TGStarsListItemBuilder itemForStatusLoading:YES isMoreRow:NO emptyText:@"No stars"];
	TGTestExpectTrue(&outcome, loading.kind == TGStarsListRowKindStatus && loading.statusIsLoading,
			"a loading status row is a status row that knows it is loading");
	TGTestExpectTrue(&outcome, [loading.titleText isEqualToString:@"Loading…"],
			"a loading row says so rather than showing the empty text");

	TGStarsListItem *more = [TGStarsListItemBuilder itemForStatusLoading:NO isMoreRow:YES emptyText:@"No stars"];
	TGTestExpectTrue(&outcome, more.statusIsMore && [more.titleText isEqualToString:@"Show more"],
			"a more row offers the next page");

	TGStarsListItem *emptyRow = [TGStarsListItemBuilder itemForStatusLoading:NO isMoreRow:NO emptyText:@"No stars"];
	TGTestExpectTrue(&outcome, [emptyRow.titleText isEqualToString:@"No stars"],
			"with nothing loading and nothing more, the caller's empty text is the row");
	TGTestExpectTrue(&outcome, emptyRow.detailText == nil && !emptyRow.tappable,
			"a status row carries no detail and is not tappable");

	TGTestExpectTrue(&outcome,
			[[TGStarsListItemBuilder itemForStatusLoading:YES isMoreRow:YES emptyText:@"No stars"].titleText
					isEqualToString:@"Loading…"],
			"a more row that is already loading says loading, not show more");

	return outcome;
}

TGTestOutcome TGItemBuildersTestConnectedWebsitesTitleFallsBackToDomainThenWebsite(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGConnectedWebsitesItem *named = [TGConnectedWebsitesItemBuilder
			itemFromSite:@{@"botName" : @"ExampleBot", @"domain" : @"example.org"}];
	TGTestExpectTrue(&outcome, [named.titleText isEqualToString:@"ExampleBot"],
			"the bot's name titles the row when there is one");

	TGConnectedWebsitesItem *domainOnly = [TGConnectedWebsitesItemBuilder
			itemFromSite:@{@"botName" : @"", @"domain" : @"example.org"}];
	TGTestExpectTrue(&outcome, [domainOnly.titleText isEqualToString:@"example.org"],
			"an empty bot name falls back to the domain");

	TGConnectedWebsitesItem *bare = [TGConnectedWebsitesItemBuilder itemFromSite:@{}];
	TGTestExpectTrue(&outcome, [bare.titleText isEqualToString:@"Website"],
			"with neither name nor domain the row is titled generically");

	TGConnectedWebsitesItem *identified = [TGConnectedWebsitesItemBuilder
			itemFromSite:@{@"id" : @7734, @"domain" : @"example.org"}];
	TGTestExpectTrue(&outcome, identified.siteId == 7734,
			"the site id is carried so the row can be revoked");
	TGTestExpectTrue(&outcome,
			[TGConnectedWebsitesItemBuilder itemFromSite:@{@"id" : @"7734"}].siteId == 0,
			"an id that is not a number off the wire is not trusted as one");

	return outcome;
}

TGTestOutcome TGItemBuildersTestConnectedWebsitesDetailJoinsOnlyThePartsThatApply(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGConnectedWebsitesItem *full = [TGConnectedWebsitesItemBuilder itemFromSite:@{
		@"botName" : @"ExampleBot",
		@"domain" : @"example.org",
		@"browser" : @"Safari",
		@"platform" : @"iOS",
		@"ip" : @"10.0.0.1",
		@"location" : @"Warsaw"
	}];
	TGTestExpectTrue(&outcome,
			[full.detailText isEqualToString:@"example.org, Safari, iOS\n10.0.0.1, Warsaw"],
			"where and what go on the first line, who and from where on the second");

	TGConnectedWebsitesItem *sparse = [TGConnectedWebsitesItemBuilder
			itemFromSite:@{@"botName" : @"ExampleBot", @"platform" : @"iOS"}];
	TGTestExpectTrue(&outcome, [sparse.detailText isEqualToString:@"iOS"],
			"missing parts leave no separators behind");

	TGConnectedWebsitesItem *nothing = [TGConnectedWebsitesItemBuilder itemFromSite:@{}];
	TGTestExpectTrue(&outcome, [nothing.detailText isEqualToString:@""],
			"a site with nothing to say has an empty detail rather than a stray newline");

	TGConnectedWebsitesItem *dated = [TGConnectedWebsitesItemBuilder
			itemFromSite:@{@"ip" : @"10.0.0.1", @"loginDate" : @1000000000, @"lastActive" : @1200000000}];
	TGTestExpectTrue(&outcome, [dated.detailText rangeOfString:@"Logged in "].location != NSNotFound,
			"a login date is labelled");
	TGTestExpectTrue(&outcome, [dated.detailText rangeOfString:@"Last active "].location != NSNotFound,
			"a last-active date is labelled");
	TGTestExpectTrue(&outcome,
			[[TGConnectedWebsitesItemBuilder itemFromSite:(@{@"ip" : @"10.0.0.1", @"loginDate" : @0})].detailText
					isEqualToString:@"10.0.0.1"],
			"a zero timestamp is no timestamp, not the epoch");

	return outcome;
}

TGTestOutcome TGItemBuildersTestHiddenStoriesNamesADeletedAccount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGHiddenStoriesItem *named = [TGHiddenStoriesItemBuilder
			itemFromPoster:@{@"name" : @"Alice", @"id" : @55, @"isChat" : @YES}];
	TGTestExpectTrue(&outcome, [named.titleText isEqualToString:@"Alice"], "a named poster keeps its name");
	TGTestExpectTrue(&outcome, named.posterId == 55 && named.posterIsChat,
			"the poster's id and whether it is a chat are carried for the avatar");

	TGHiddenStoriesItem *nameless = [TGHiddenStoriesItemBuilder itemFromPoster:@{@"id" : @55}];
	TGTestExpectTrue(&outcome, [nameless.titleText isEqualToString:@"Deleted Account"],
			"a poster with no name reads as a deleted account, not as a blank row");
	TGTestExpectTrue(&outcome, !nameless.posterIsChat, "an absent isChat is not a chat");

	TGHiddenStoriesItem *wrongTypes = [TGHiddenStoriesItemBuilder
			itemFromPoster:@{@"name" : @55, @"id" : @"55"}];
	TGTestExpectTrue(&outcome, [wrongTypes.titleText isEqualToString:@"Deleted Account"] &&
					wrongTypes.posterId == 0,
			"values of the wrong type off the wire are treated as absent");

	return outcome;
}

TGTestOutcome TGItemBuildersTestPrivacyContactPickerComposesAName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[[TGPrivacyContactPickerItemBuilder
					 itemFromUser:(@{@"first_name" : @"Ada", @"last_name" : @"Lovelace"})
						   chosen:nil].titleText isEqualToString:@"Ada Lovelace"],
			"both names are joined by one space");
	TGTestExpectTrue(&outcome,
			[[TGPrivacyContactPickerItemBuilder itemFromUser:@{@"first_name" : @"Ada"} chosen:nil].titleText
					isEqualToString:@"Ada"],
			"a first name alone carries no trailing space");
	TGTestExpectTrue(&outcome,
			[[TGPrivacyContactPickerItemBuilder itemFromUser:@{@"last_name" : @"Lovelace"} chosen:nil].titleText
					isEqualToString:@"Lovelace"],
			"a last name alone carries no leading space");
	TGTestExpectTrue(&outcome,
			[[TGPrivacyContactPickerItemBuilder
					 itemFromUser:(@{@"first_name" : @"", @"last_name" : @"", @"username" : @"ada"})
						   chosen:nil].titleText isEqualToString:@"ada"],
			"a nameless contact falls back to its username");
	TGTestExpectTrue(&outcome,
			[[TGPrivacyContactPickerItemBuilder itemFromUser:@{} chosen:nil].titleText
					isEqualToString:@"Unknown"],
			"a contact with nothing to show reads as unknown");

	return outcome;
}

TGTestOutcome TGItemBuildersTestPrivacyContactPickerMarksOnlyTheChosenIds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *chosen = @[ @11, @13 ];
	TGTestExpectTrue(&outcome,
			[TGPrivacyContactPickerItemBuilder itemFromUser:@{@"id" : @11} chosen:chosen].chosen,
			"a listed id is chosen");
	TGTestExpectTrue(&outcome,
			![TGPrivacyContactPickerItemBuilder itemFromUser:@{@"id" : @12} chosen:chosen].chosen,
			"an unlisted id is not chosen");
	TGTestExpectTrue(&outcome,
			![TGPrivacyContactPickerItemBuilder itemFromUser:@{} chosen:chosen].chosen,
			"a user with no id is never chosen, however long the list");
	TGTestExpectTrue(&outcome,
			[TGPrivacyContactPickerItemBuilder itemFromUser:@{@"id" : @11} chosen:chosen].userId == 11,
			"the user id is carried for the tap");

	return outcome;
}

TGTestOutcome TGItemBuildersTestNewGroupMembersMarksOnlyTheSelectedIds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *selected = @[ @21 ];
	TGNewGroupMembersItem *picked = [TGNewGroupMembersItemBuilder itemFromUser:@{@"id" : @21}
																	 titleText:@"Ada"
																	  selected:selected];
	TGTestExpectTrue(&outcome, picked.selected && picked.userId == 21 &&
					[picked.titleText isEqualToString:@"Ada"],
			"a selected contact keeps its id, its caller-supplied title and its tick");
	TGTestExpectTrue(&outcome,
			![TGNewGroupMembersItemBuilder itemFromUser:(@{@"id" : @22}) titleText:@"Bob" selected:selected].selected,
			"an unselected contact has no tick");
	TGTestExpectTrue(&outcome,
			![TGNewGroupMembersItemBuilder itemFromUser:(@{@"id" : @"21"}) titleText:@"Ada" selected:selected].selected,
			"an id that arrived as a string matches nothing and marks nothing");

	return outcome;
}

TGTestOutcome TGItemBuildersTestUsernameRowsPrefixTheHandle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountUsernamesItem *mine = [TGAccountUsernamesItemBuilder itemFromUsername:@"ada"
															   showsEditableBadge:YES];
	TGTestExpectTrue(&outcome, [mine.displayText isEqualToString:@"@ada"],
			"the row shows the handle with its at sign");
	TGTestExpectTrue(&outcome, [mine.username isEqualToString:@"ada"],
			"the bare username is kept for the edit screen");
	TGTestExpectTrue(&outcome, mine.showsEditableBadge, "the editable badge is carried through");
	TGTestExpectTrue(&outcome,
			![TGAccountUsernamesItemBuilder itemFromUsername:@"ada" showsEditableBadge:NO].showsEditableBadge,
			"a row without the badge does not gain one");
	TGTestExpectTrue(&outcome,
		[[TGAccountUsernamesItemBuilder itemFromUsername:@"ada.bot"
									  showsEditableBadge:NO]
				.displayText isEqualToString:@"@ada.bot"],
		"a handle with a dot is shown as it is, not reformatted");
	TGTestExpectTrue(&outcome,
		[[TGAccountUsernamesItemBuilder itemFromUsername:@""
									  showsEditableBadge:NO]
				.displayText isEqualToString:@"@"],
		"an empty handle still builds a row rather than returning nothing to draw");

	TGSupergroupUsernamesItem *group = [TGSupergroupUsernamesItemBuilder itemFromUsername:@"club"
																			   badgeText:@"active"];
	TGTestExpectTrue(&outcome, [group.displayText isEqualToString:@"@club"] &&
					[group.username isEqualToString:@"club"],
			"a group username row is shaped the same way");
	TGTestExpectTrue(&outcome, [group.badgeText isEqualToString:@"active"],
			"the badge text is the caller's, not invented by the builder");
	TGTestExpectTrue(&outcome,
			[TGSupergroupUsernamesItemBuilder itemFromUsername:@"club" badgeText:nil].badgeText == nil,
			"a row with no badge keeps none");

	return outcome;
}

TGTestOutcome TGItemBuildersTestOwnedSetsCountsStickersAndPicksACover(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGOwnedSetsItem *create = [TGOwnedSetsItemBuilder itemForCreateRow];
	TGTestExpectTrue(&outcome, create.kind == TGOwnedSetsRowKindCreate && create.thumbnailKey == nil &&
					create.thumbnailFileId == 0,
			"the create row has no artwork to load");

	TGOwnedSetsItem *one = [TGOwnedSetsItemBuilder itemFromSet:@{@"title" : @"Cats", @"count" : @1}];
	TGTestExpectTrue(&outcome, [one.countText isEqualToString:@"1 sticker"],
			"one sticker reads in the singular");
	TGOwnedSetsItem *many = [TGOwnedSetsItemBuilder itemFromSet:@{@"title" : @"Cats", @"count" : @12}];
	TGTestExpectTrue(&outcome, [many.countText isEqualToString:@"12 stickers"],
			"more than one reads in the plural with the count substituted");

	TGOwnedSetsItem *thumbed = [TGOwnedSetsItemBuilder itemFromSet:@{
		@"title" : @"Cats",
		@"covers" : @[ @{@"thumbId" : @9, @"thumbUniqueId" : @"thumb", @"fileId" : @8, @"uniqueId" : @"full"} ]
	}];
	TGTestExpectTrue(&outcome, thumbed.thumbnailFileId == 9 && [thumbed.thumbnailKey isEqualToString:@"thumb"],
			"a cover with a thumbnail loads the thumbnail, keyed by the thumbnail's unique id");

	TGOwnedSetsItem *fullSized = [TGOwnedSetsItemBuilder itemFromSet:@{
		@"title" : @"Cats",
		@"covers" : @[ @{@"fileId" : @8, @"uniqueId" : @"full"} ]
	}];
	TGTestExpectTrue(&outcome, fullSized.thumbnailFileId == 8 && [fullSized.thumbnailKey isEqualToString:@"full"],
			"a cover with no thumbnail falls back to the sticker itself, keyed by its own unique id");

	TGOwnedSetsItem *coverless = [TGOwnedSetsItemBuilder itemFromSet:@{@"title" : @"Cats", @"covers" : @[]}];
	TGTestExpectTrue(&outcome, coverless.thumbnailFileId == 0 && coverless.thumbnailKey == nil,
			"a set with no covers asks for no file");
	TGTestExpectTrue(&outcome, coverless.thumbnailPlaceholder != nil,
			"every set row still has a placeholder to draw while nothing is loaded");

	return outcome;
}

TGTestOutcome TGItemBuildersTestStoryViewersJoinsTheReactionEmoji(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStoryViewersItem *reacted = [TGStoryViewersItemBuilder
			itemFromRow:@{@"name" : @"Ada", @"emoji" : @"\U0001F44D", @"date" : @1}];
	TGTestExpectTrue(&outcome, [reacted.titleText isEqualToString:@"Ada  \U0001F44D"],
			"a viewer who reacted has the reaction beside the name");

	TGStoryViewersItem *plain = [TGStoryViewersItemBuilder itemFromRow:@{@"name" : @"Ada", @"date" : @1}];
	TGTestExpectTrue(&outcome, [plain.titleText isEqualToString:@"Ada"],
			"a viewer who only looked carries no trailing spaces");

	TGStoryViewersItem *nameless = [TGStoryViewersItemBuilder itemFromRow:@{}];
	TGTestExpectTrue(&outcome, [nameless.titleText isEqualToString:@""] &&
					[nameless.detailText isEqualToString:@""],
			"an empty row must not crash and must not print null");

	return outcome;
}

TGTestOutcome TGItemBuildersTestCallsGroupReadsCountKindAndDirection(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *single = @{
		@"userId" : @7,
		@"date" : @1700000000,
		@"outgoing" : @YES,
		@"calls" : @[ @{ @"id" : @1, @"outgoing" : @YES, @"duration" : @21 } ],
	};
	TGCallsItem *singleItem = [TGCallsItemBuilder itemFromGroup:single];

	TGTestExpectTrue(&outcome, singleItem.countText == nil,
			"a group holding one call shows no count in brackets");
	TGTestExpectTrue(&outcome, singleItem.dateText.length > 0,
			"the row carries a list date");
	TGTestExpectTrue(&outcome, [singleItem.avatarKey isEqualToNumber:@7],
			"the avatar is keyed by the other party's user id");
	TGTestExpectTrue(&outcome, singleItem.avatarPlaceholder != nil,
			"an initials placeholder is always built, so a row never draws empty");

	NSMutableDictionary *grouped = [single mutableCopy];
	grouped[@"calls"] = @[ @{ @"id" : @1 }, @{ @"id" : @2 }, @{ @"id" : @3 } ];
	TGCallsItem *groupedItem = [TGCallsItemBuilder itemFromGroup:grouped];
	TGTestExpectTrue(&outcome, [groupedItem.countText isEqualToString:@"(3)"],
			"three calls to the same person collapse into one row counted as (3)");

	NSMutableDictionary *missed = [single mutableCopy];
	missed[@"outgoing"] = @NO;
	missed[@"calls"] = @[ @{ @"id" : @1, @"outgoing" : @NO, @"isMissed" : @YES } ];
	TGCallsItem *missedItem = [TGCallsItemBuilder itemFromGroup:missed];
	TGTestExpectTrue(&outcome, missedItem.nameColour != nil,
			"a missed call still resolves a name colour rather than leaving it nil");

	return outcome;
}

TGTestOutcome TGItemBuildersTestGroupMemberFallsBackToUnknownName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGGroupMembersItem *named = [TGGroupMembersItemBuilder itemFromMember:@{
		@"name" : @"Ada Lovelace",
		@"id" : @42,
		@"status" : @"administrator",
	}];
	TGTestExpectTrue(&outcome, [named.titleText isEqualToString:@"Ada Lovelace"],
			"a member with a name shows it");
	TGTestExpectTrue(&outcome, named.roleText.length > 0,
			"an administrator carries a role label");
	TGTestExpectTrue(&outcome, named.avatarPlaceholder != nil,
			"an initials placeholder is built for every member");

	TGGroupMembersItem *nameless = [TGGroupMembersItemBuilder itemFromMember:@{ @"id" : @43 }];
	TGTestExpectTrue(&outcome, nameless.titleText.length > 0,
			"a member the client has no name for still gets a title rather than an empty row");
	TGTestExpectTrue(&outcome, !nameless.subtitleIsOnline,
			"a member with no status is not reported as online");

	return outcome;
}

TGTestOutcome TGItemBuildersTestEveryBuilderNamesItsCellAndKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *items = @[
		[TGStorageDownloadsItemBuilder itemForEntry:@{@"fileId" : @1} suggestedNames:nil],
		[TGStorageDownloadsItemBuilder itemForClearRow],
		[TGStarsListItemBuilder itemFromRow:@{@"title" : @"Stars"}],
		[TGStarsListItemBuilder itemForStatusLoading:NO isMoreRow:YES emptyText:@"none"],
		[TGConnectedWebsitesItemBuilder itemFromSite:@{@"domain" : @"example.org"}],
		[TGHiddenStoriesItemBuilder itemFromPoster:@{@"name" : @"Ada"}],
		[TGPrivacyContactPickerItemBuilder itemFromUser:@{@"id" : @1} chosen:nil],
		[TGNewGroupMembersItemBuilder itemFromUser:@{@"id" : @1} titleText:@"Ada" selected:nil],
		[TGCallsItemBuilder itemFromGroup:@{@"userId" : @3, @"calls" : @[ @{ @"id" : @9 } ]}],
		[TGGroupMembersItemBuilder itemFromMember:@{@"id" : @4, @"name" : @"Ada"}],
		[TGAccountUsernamesItemBuilder itemFromUsername:@"ada" showsEditableBadge:NO],
		[TGSupergroupUsernamesItemBuilder itemFromUsername:@"club" badgeText:nil],
		[TGOwnedSetsItemBuilder itemForCreateRow],
		[TGOwnedSetsItemBuilder itemFromSet:@{@"title" : @"Cats"}],
		[TGStoryViewersItemBuilder itemFromRow:@{@"name" : @"Ada"}]
	];

	for (id item in items) {
		NSString *identifier = [item reuseIdentifier];
		TGTestExpectTrue(&outcome, identifier.length > 0,
				"every item names the cell it is to be rendered by");
		TGTestExpectTrue(&outcome, [item cellClass] != Nil,
				"every item names the class of that cell");
	}

	return outcome;
}

TGTestOutcome TGItemBuildersTestProfileDetailMarksWhatARowCanDo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGProfileDetailItem *username = [TGProfileDetailItemBuilder
		 itemFromPair:@[ @"username", @"@natali" ]
		isSongPlaying:NO];
	TGTestExpectTrue(&outcome, username.showsDisclosure && username.selectable,
		"a username opens a screen, so it shows a chevron and can be tapped");
	TGTestExpectTrue(&outcome, [username.labelText isEqualToString:@"username"],
		"the label column carries the translated kind, not the raw key");

	TGProfileDetailItem *contact = [TGProfileDetailItemBuilder
		 itemFromPair:@[ @"contact", @"Mutual contact" ]
		isSongPlaying:NO];
	TGTestExpectTrue(&outcome, !contact.showsDisclosure && !contact.selectable,
		"a row that opens nothing is neither tappable nor chevroned");

	TGProfileDetailItem *phone = [TGProfileDetailItemBuilder
		 itemFromPair:@[ @"mobile", @"+48 123 456 789" ]
		isSongPlaying:NO];
	TGTestExpectTrue(&outcome, phone.selectable && phone.interactionEnabled,
		"a visible phone number can be tapped to call it");

	TGProfileDetailItem *hidden = [TGProfileDetailItemBuilder
		 itemFromPair:@[ @"mobile", @"+48 123 456 789", @YES ]
		isSongPlaying:NO];
	TGTestExpectTrue(&outcome, !hidden.selectable && !hidden.interactionEnabled,
		"a phone number hidden by privacy must not be tappable");
	TGTestExpectTrue(&outcome, ![hidden.valueTextColor isEqual:phone.valueTextColor],
		"a hidden number is greyed out rather than shown in the link colour");

	TGTestExpectTrue(&outcome, [TGProfileDetailItemBuilder itemFromPair:@[ @"gift" ] isSongPlaying:NO] == nil,
		"a pair without a value builds no item, so the caller can fall back");

	return outcome;
}

TGTestOutcome TGItemBuildersTestProfileDetailSongCarriesItsPlaybackGlyph(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGProfileDetailItem *paused = [TGProfileDetailItemBuilder
		 itemFromPair:@[ @"song", @"Wolves" ]
		isSongPlaying:NO];
	TGProfileDetailItem *playing = [TGProfileDetailItemBuilder
		 itemFromPair:@[ @"song", @"Wolves" ]
		isSongPlaying:YES];

	TGTestExpectTrue(&outcome, [paused.valueText hasPrefix:@"\u25b6"],
		"a song that is not playing offers the play glyph");
	TGTestExpectTrue(&outcome, [playing.valueText hasPrefix:@"\u23f8"],
		"a song that is playing offers the pause glyph");
	TGTestExpectTrue(&outcome,
		[paused.valueText rangeOfString:@"Wolves"].location != NSNotFound &&
			[playing.valueText rangeOfString:@"Wolves"].location != NSNotFound,
		"either way the song's own title is still there");
	TGTestExpectTrue(&outcome, paused.selectable,
		"a song row is tappable, since tapping it starts or stops playback");

	return outcome;
}

TGTestOutcome TGItemBuildersTestSearchResultSplitsAContactName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGSearchResultItem *both = [TGSearchResultItemBuilder
		itemFromRow:@{@"title" : @"Nikolai Orlov",
			@"firstName" : @"Nikolai",
			@"lastName" : @"Orlov",
			@"userId" : @1001}
		  isMessage:NO];
	TGTestExpectTrue(&outcome, [both.titleFirst isEqualToString:@"Nikolai"] && [both.titleSecond isEqualToString:@"Orlov"],
		"a contact's two names are carried apart, so the cell can weight them differently");

	TGSearchResultItem *lastOnly = [TGSearchResultItemBuilder
		itemFromRow:@{@"title" : @"Orlov", @"lastName" : @"Orlov"}
		  isMessage:NO];
	TGTestExpectTrue(&outcome, [lastOnly.titleFirst isEqualToString:@"Orlov"] && lastOnly.titleSecond == nil,
		"a surname on its own becomes the first half rather than an empty first half");

	TGSearchResultItem *chat = [TGSearchResultItemBuilder
		itemFromRow:@{@"title" : @"Україна 24/7",
			@"chatId" : @(-1001)}
		  isMessage:NO];
	TGTestExpectTrue(&outcome, [chat.titleFirst isEqualToString:@"Україна 24/7"] && chat.titleSecond == nil,
		"a chat has one title, not a split name");
	TGTestExpectEqualLongLong(&outcome, chat.avatarColourId, -1001,
		"the avatar colour follows the chat id");

	return outcome;
}

TGTestOutcome TGItemBuildersTestSearchResultMessageAndHashtagRows(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGSearchResultItem *message = [TGSearchResultItemBuilder
		itemFromRow:@{@"title" : @"Україна 24/7",
			@"author" : @"Nikolai Orlov",
			@"subtitle" : @"При это такая шутка",
			@"date" : @"4 Sep",
			@"chatId" : @(-1001)}
		  isMessage:YES];
	TGTestExpectTrue(&outcome, message.kind == TGSearchRowKindMessage,
		"a message hit is its own row kind, since it is drawn by a taller cell");
	TGTestExpectTrue(&outcome, [message.authorText isEqualToString:@"Nikolai Orlov"],
		"a message hit carries the author line the chat hit has no room for");
	TGTestExpectTrue(&outcome, [message.dateText isEqualToString:@"4 Sep"],
		"the date is carried as the text the client already formatted");
	TGTestExpectTrue(&outcome, !message.avatarIsPrecomputed,
		"a message hit asks its owner for the avatar rather than carrying one");

	TGSearchResultItem *hashtag = [TGSearchResultItemBuilder
		itemFromRow:@{@"title" : @"#kyiv", @"hashtag" : @"#kyiv"}
		  isMessage:NO];
	TGTestExpectTrue(&outcome, hashtag.avatarIsPrecomputed && hashtag.avatarPrecomputed != nil,
		"a hashtag row draws its own initial, so it carries the image with it");
	TGTestExpectEqualLongLong(&outcome, hashtag.avatarColourId, 0,
		"a hashtag row has no chat to take a colour from");

	return outcome;
}
