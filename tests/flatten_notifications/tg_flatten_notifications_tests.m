#import "tg_flatten_notifications_tests.h"
#import "../../src/Wire/Flatten/TGFlattenNotifications.h"
#import "../../src/TDLibClient/TGClient+Notifications.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenNotificationsTestScopeTypeMapsGroupsChannelsAndDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGNotifScopeType(@"groups") isEqualToString:@"notificationSettingsScopeGroupChats"],
			"\"groups\" must map to notificationSettingsScopeGroupChats");
	TGTestExpectTrue(&outcome,
			[TGNotifScopeType(@"channels") isEqualToString:@"notificationSettingsScopeChannelChats"],
			"\"channels\" must map to notificationSettingsScopeChannelChats");
	TGTestExpectTrue(&outcome,
			[TGNotifScopeType(@"users") isEqualToString:@"notificationSettingsScopePrivateChats"],
			"any other scope name must fall back to notificationSettingsScopePrivateChats");
	TGTestExpectTrue(&outcome,
			[TGNotifScopeType(nil) isEqualToString:@"notificationSettingsScopePrivateChats"],
			"a nil scope must fall back to notificationSettingsScopePrivateChats, not crash");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestReactionSourceMapsAllContactsAndDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGNotifReactionSource(@"all") isEqualToString:@"reactionNotificationSourceAll"],
			"\"all\" must map to reactionNotificationSourceAll");
	TGTestExpectTrue(&outcome,
			[TGNotifReactionSource(@"contacts") isEqualToString:@"reactionNotificationSourceContacts"],
			"\"contacts\" must map to reactionNotificationSourceContacts");
	TGTestExpectTrue(&outcome,
			[TGNotifReactionSource(@"none") isEqualToString:@"reactionNotificationSourceNone"],
			"any other reaction source name must fall back to reactionNotificationSourceNone");
	TGTestExpectTrue(&outcome,
			[TGNotifReactionSource(nil) isEqualToString:@"reactionNotificationSourceNone"],
			"a nil reaction source must fall back to reactionNotificationSourceNone, not crash");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestScopeSettingsFromComposesFullInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *s = @{
		@"mute_for" : @3600,
		@"show_preview" : @YES,
		@"sound_id" : @42,
		@"use_default_mute_stories" : @NO,
		@"mute_stories" : @YES,
		@"story_sound_id" : @7,
		@"show_story_poster" : @YES,
		@"disable_pinned_message_notifications" : @YES,
		@"disable_mention_notifications" : @YES,
	};

	NSDictionary *flat = TGNotifScopeSettingsFrom(s);

	TGTestExpectTrue(&outcome, [flat[@"muted"] boolValue],
			"a positive mute_for must flatten to muted = YES");
	TGTestExpectEqualInteger(&outcome, [flat[@"muteFor"] integerValue], 3600,
			"muteFor must round-trip from mute_for");
	TGTestExpectTrue(&outcome, [flat[@"showPreview"] boolValue],
			"showPreview must round-trip from show_preview");
	TGTestExpectEqualInteger(&outcome, [flat[@"soundId"] integerValue], 42,
			"soundId must round-trip from sound_id");
	TGTestExpectTrue(&outcome, ![flat[@"useDefaultMuteStories"] boolValue],
			"useDefaultMuteStories must round-trip from use_default_mute_stories");
	TGTestExpectTrue(&outcome, [flat[@"muteStories"] boolValue],
			"muteStories must round-trip from mute_stories");
	TGTestExpectEqualInteger(&outcome, [flat[@"storySoundId"] integerValue], 7,
			"storySoundId must round-trip from story_sound_id");
	TGTestExpectTrue(&outcome, [flat[@"showStoryPoster"] boolValue],
			"showStoryPoster must round-trip from show_story_poster");
	TGTestExpectTrue(&outcome, [flat[@"disablePinnedMessageNotifications"] boolValue],
			"disablePinnedMessageNotifications must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"disableMentionNotifications"] boolValue],
			"disableMentionNotifications must round-trip");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestScopeSettingsFromFillsDefaultsForEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGNotifScopeSettingsFrom(@{});

	TGTestExpectTrue(&outcome, ![flat[@"muted"] boolValue],
			"a missing mute_for must flatten to muted = NO");
	TGTestExpectEqualInteger(&outcome, [flat[@"muteFor"] integerValue], 0,
			"a missing mute_for must default muteFor to 0");
	TGTestExpectTrue(&outcome, ![flat[@"showPreview"] boolValue],
			"a missing show_preview must default to NO");
	TGTestExpectEqualInteger(&outcome, [flat[@"soundId"] integerValue], 0,
			"a missing sound_id must default soundId to 0");
	TGTestExpectTrue(&outcome, ![flat[@"disableMentionNotifications"] boolValue],
			"a missing disable_mention_notifications must default to NO");

	NSDictionary *flatFromNonDict = TGNotifScopeSettingsFrom((NSDictionary *)@"not a dictionary");
	TGTestExpectTrue(&outcome, ![flatFromNonDict[@"muted"] boolValue],
			"a non-dictionary input must not crash and must default muted to NO");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestChatSettingsFromComposesFullInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *s = @{
		@"mute_for" : @1800,
		@"use_default_mute_for" : @NO,
		@"show_preview" : @NO,
		@"use_default_show_preview" : @NO,
		@"sound_id" : @9,
		@"use_default_sound" : @NO,
		@"disable_pinned_message_notifications" : @YES,
		@"use_default_disable_pinned_message_notifications" : @NO,
		@"disable_mention_notifications" : @YES,
		@"use_default_disable_mention_notifications" : @NO,
	};

	NSDictionary *flat = TGNotifChatSettingsFrom(s, YES);

	TGTestExpectTrue(&outcome, [flat[@"muted"] boolValue],
			"a positive mute_for must flatten to muted = YES");
	TGTestExpectEqualInteger(&outcome, [flat[@"muteFor"] integerValue], 1800,
			"muteFor must round-trip from mute_for");
	TGTestExpectTrue(&outcome, ![flat[@"useDefaultMuteFor"] boolValue],
			"useDefaultMuteFor must round-trip from use_default_mute_for");
	TGTestExpectTrue(&outcome, ![flat[@"showPreview"] boolValue],
			"showPreview must round-trip from show_preview");
	TGTestExpectEqualInteger(&outcome, [flat[@"soundId"] integerValue], 9,
			"soundId must round-trip from sound_id");
	TGTestExpectTrue(&outcome, [flat[@"disablePinnedMessageNotifications"] boolValue],
			"disablePinnedMessageNotifications must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"disableMentionNotifications"] boolValue],
			"disableMentionNotifications must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"defaultDisableNotification"] boolValue],
			"defaultDisableNotification must come from the separate defaultSilent argument, not the settings dictionary");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestChatSettingsFromFillsDefaultsForEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGNotifChatSettingsFrom(@{}, NO);

	TGTestExpectTrue(&outcome, ![flat[@"muted"] boolValue],
			"a missing mute_for must flatten to muted = NO");
	TGTestExpectEqualInteger(&outcome, [flat[@"muteFor"] integerValue], 0,
			"a missing mute_for must default muteFor to 0");
	TGTestExpectTrue(&outcome, ![flat[@"useDefaultMuteFor"] boolValue],
			"a missing use_default_mute_for must default to NO");
	TGTestExpectTrue(&outcome, ![flat[@"defaultDisableNotification"] boolValue],
			"defaultDisableNotification must reflect the defaultSilent argument even when settings is empty");

	NSDictionary *flatFromNonDict = TGNotifChatSettingsFrom((NSDictionary *)@42, YES);
	TGTestExpectTrue(&outcome, ![flatFromNonDict[@"muted"] boolValue],
			"a non-dictionary settings input must not crash and must default muted to NO");
	TGTestExpectTrue(&outcome, [flatFromNonDict[@"defaultDisableNotification"] boolValue],
			"defaultDisableNotification must still reflect the defaultSilent argument for a non-dictionary settings input");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestPickPrefersChangesOverCurrentAndFallsBackToZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *current = @{@"soundId" : @5};
	NSDictionary *changesWithNumber = @{@"soundId" : @9};
	NSDictionary *changesWithoutKey = @{};

	TGTestExpectEqualInteger(&outcome,
			[TGNotifPick(changesWithNumber, current, @"soundId") integerValue], 9,
			"a numeric value present in changes must win over the current value");
	TGTestExpectEqualInteger(&outcome,
			[TGNotifPick(changesWithoutKey, current, @"soundId") integerValue], 5,
			"when changes has no value for the key, the current value must be kept");
	TGTestExpectEqualInteger(&outcome,
			[TGNotifPick(changesWithoutKey, @{}, @"soundId") integerValue], 0,
			"when neither changes nor current has the key, the result must default to 0");
	TGTestExpectEqualInteger(&outcome,
			[TGNotifPick(@{@"soundId" : @"not a number"}, current, @"soundId") integerValue], 5,
			"a non-numeric value in changes must not override the current value");
	TGTestExpectEqualInteger(&outcome,
			[TGNotifPick((NSDictionary *)@"not a dictionary", current, @"soundId") integerValue], 5,
			"a non-dictionary changes argument must not crash and must fall back to current");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestScopeMutedOverridesSetsMuteForWhenMutedTrueWithoutMuteFor(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *overrides = TGNotifScopeMutedOverrides(@{@"muted" : @YES});

	TGTestExpectEqualLongLong(&outcome, [overrides[@"muteFor"] longLongValue],
			kNotificationMuteForever,
			"muted = YES without an explicit muteFor must derive muteFor = forever");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestScopeMutedOverridesSetsZeroMuteForWhenMutedFalseWithoutMuteFor(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *overrides = TGNotifScopeMutedOverrides(@{@"muted" : @NO});

	TGTestExpectEqualLongLong(&outcome, [overrides[@"muteFor"] longLongValue], 0,
			"muted = NO without an explicit muteFor must derive muteFor = 0");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestScopeMutedOverridesDefersToExplicitMuteFor(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *overrides = TGNotifScopeMutedOverrides(@{@"muted" : @YES, @"muteFor" : @600});

	TGTestExpectEqualInteger(&outcome, overrides.count, 0,
			"when the caller supplies an explicit numeric muteFor alongside muted, the derivation must not override it");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestScopeMutedOverridesIsEmptyForNonDictionaryChanges(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGNotifScopeMutedOverrides(nil).count, 0,
			"a nil changes argument must produce no overrides, not crash");
	TGTestExpectEqualInteger(&outcome,
			TGNotifScopeMutedOverrides((NSDictionary *)@"not a dictionary").count, 0,
			"a non-dictionary changes argument must produce no overrides, not crash");
	TGTestExpectEqualInteger(&outcome, TGNotifScopeMutedOverrides(@{}).count, 0,
			"an empty changes dictionary with no \"muted\" key must produce no overrides");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestChatMutedOverridesSetsMuteForAndClearsUseDefaultWhenMutedTrue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *overrides = TGNotifChatMutedOverrides(@{@"muted" : @YES});

	TGTestExpectEqualLongLong(&outcome, [overrides[@"muteFor"] longLongValue],
			kNotificationMuteForever,
			"muted = YES without an explicit muteFor must derive muteFor = forever");
	TGTestExpectTrue(&outcome, ![overrides[@"useDefaultMuteFor"] boolValue],
			"deriving muteFor from muted must also clear useDefaultMuteFor");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestChatMutedOverridesSetsZeroMuteForWhenMutedFalse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *overrides = TGNotifChatMutedOverrides(@{@"muted" : @NO});

	TGTestExpectEqualLongLong(&outcome, [overrides[@"muteFor"] longLongValue], 0,
			"muted = NO without an explicit muteFor must derive muteFor = 0");
	TGTestExpectTrue(&outcome, ![overrides[@"useDefaultMuteFor"] boolValue],
			"deriving muteFor from muted = NO must also clear useDefaultMuteFor");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestChatMutedOverridesDefersToExplicitMuteFor(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *overrides = TGNotifChatMutedOverrides(@{
		@"muted" : @YES,
		@"muteFor" : @600,
		@"useDefaultMuteFor" : @YES,
	});

	TGTestExpectTrue(&outcome, overrides[@"muteFor"] == nil,
			"when the caller supplies an explicit numeric muteFor alongside muted, the derivation must not override it");
	TGTestExpectTrue(&outcome, overrides[@"useDefaultMuteFor"] == nil,
			"when the caller supplies an explicit useDefaultMuteFor alongside an explicit muteFor, neither must be overridden");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestChatMutedOverridesClearsUseDefaultFlagsWhenTheirValuesChange(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *overrides = TGNotifChatMutedOverrides(@{
		@"muteFor" : @600,
		@"showPreview" : @YES,
		@"soundId" : @3,
		@"disablePinnedMessageNotifications" : @YES,
		@"disableMentionNotifications" : @YES,
	});

	TGTestExpectTrue(&outcome, ![overrides[@"useDefaultMuteFor"] boolValue],
			"an explicit muteFor without an explicit useDefaultMuteFor must clear useDefaultMuteFor");
	TGTestExpectTrue(&outcome, ![overrides[@"useDefaultShowPreview"] boolValue],
			"an explicit showPreview without an explicit useDefaultShowPreview must clear useDefaultShowPreview");
	TGTestExpectTrue(&outcome, ![overrides[@"useDefaultSound"] boolValue],
			"an explicit soundId without an explicit useDefaultSound must clear useDefaultSound");
	TGTestExpectTrue(&outcome, ![overrides[@"useDefaultDisablePinnedMessageNotifications"] boolValue],
			"an explicit disablePinnedMessageNotifications without its useDefault flag must clear useDefaultDisablePinnedMessageNotifications");
	TGTestExpectTrue(&outcome, ![overrides[@"useDefaultDisableMentionNotifications"] boolValue],
			"an explicit disableMentionNotifications without its useDefault flag must clear useDefaultDisableMentionNotifications");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestChatMutedOverridesDoesNotOverrideWhenUseDefaultFlagsAreExplicit(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *overrides = TGNotifChatMutedOverrides(@{
		@"muteFor" : @600,
		@"useDefaultMuteFor" : @YES,
		@"showPreview" : @YES,
		@"useDefaultShowPreview" : @YES,
		@"soundId" : @3,
		@"useDefaultSound" : @YES,
		@"disablePinnedMessageNotifications" : @YES,
		@"useDefaultDisablePinnedMessageNotifications" : @YES,
		@"disableMentionNotifications" : @YES,
		@"useDefaultDisableMentionNotifications" : @YES,
	});

	TGTestExpectEqualInteger(&outcome, overrides.count, 0,
			"when the caller explicitly sets every useDefault companion flag, the derivation must not add any overrides of its own");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestChatMutedOverridesIsEmptyForNonDictionaryChanges(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGNotifChatMutedOverrides(nil).count, 0,
			"a nil changes argument must produce no overrides, not crash");
	TGTestExpectEqualInteger(&outcome,
			TGNotifChatMutedOverrides((NSDictionary *)@42).count, 0,
			"a non-dictionary changes argument must produce no overrides, not crash");
	TGTestExpectEqualInteger(&outcome, TGNotifChatMutedOverrides(@{}).count, 0,
			"an empty changes dictionary must produce no overrides");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestSoundIdsSurviveArrivingAsStrings(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *scope = TGNotifScopeSettingsFrom(@{
		@"mute_for" : @0,
		@"sound_id" : @"4916474540642132837",
		@"story_sound_id" : @"4916474540642132838"
	});
	TGTestExpectTrue(&outcome, [scope[@"soundId"] longLongValue] == 4916474540642132837LL,
			"an int64 sound id arrives as a string and must not be dropped");
	TGTestExpectTrue(&outcome, [scope[@"storySoundId"] longLongValue] == 4916474540642132838LL,
			"the story sound id is int64 too");

	NSDictionary *chat = TGNotifChatSettingsFrom(@{
		@"sound_id" : @"4916474540642132837",
		@"story_sound_id" : @"4916474540642132838",
		@"use_default_sound" : @NO
	}, NO);
	TGTestExpectTrue(&outcome, [chat[@"soundId"] longLongValue] == 4916474540642132837LL,
			"a chat's custom sound id must survive being read back for a settings save");
	TGTestExpectTrue(&outcome, [chat[@"storySoundId"] longLongValue] == 4916474540642132838LL,
			"a chat's custom story sound id must survive too");

	NSDictionary *numeric = TGNotifScopeSettingsFrom(@{@"sound_id" : @12345});
	TGTestExpectTrue(&outcome, [numeric[@"soundId"] longLongValue] == 12345,
			"a sound id that does arrive as a number still reads");

	NSDictionary *absent = TGNotifScopeSettingsFrom(@{});
	TGTestExpectTrue(&outcome, [absent[@"soundId"] longLongValue] == 0 &&
					[absent[@"storySoundId"] longLongValue] == 0,
			"no sound id at all reads as zero, the default sound");
	TGTestExpectTrue(&outcome,
			[TGNotifScopeSettingsFrom(@{@"sound_id" : @[]})[@"soundId"] longLongValue] == 0,
			"a sound id of a type that cannot be a number reads as zero rather than crashing");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestReactionSettingsReadBackFromTheWire(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGNotifReactionSettingsFrom(@{
		@"@type" : @"reactionNotificationSettings",
		@"message_reaction_source" : @{@"@type" : @"reactionNotificationSourceAll"},
		@"story_reaction_source" : @{@"@type" : @"reactionNotificationSourceContacts"},
		@"poll_vote_source" : @{@"@type" : @"reactionNotificationSourceNone"},
		@"sound_id" : @"4916474540642132837",
		@"show_preview" : @NO
	});
	TGTestExpectTrue(&outcome, [flat[@"messageSource"] isEqualToString:@"all"],
			"each source reads back as the name the screens use");
	TGTestExpectTrue(&outcome, [flat[@"storySource"] isEqualToString:@"contacts"],
			"the story source is read, not assumed");
	TGTestExpectTrue(&outcome, [flat[@"pollVoteSource"] isEqualToString:@"none"],
			"a source of none reads as none");
	TGTestExpectTrue(&outcome, [flat[@"soundId"] longLongValue] == 4916474540642132837LL,
			"the reaction sound id is int64 and arrives as a string");
	TGTestExpectTrue(&outcome, ![flat[@"showPreview"] boolValue], "the preview flag is read");

	NSDictionary *empty = TGNotifReactionSettingsFrom(nil);
	TGTestExpectTrue(&outcome, [empty[@"messageSource"] isEqualToString:@"none"] &&
					[empty[@"soundId"] longLongValue] == 0,
			"an update with nothing in it reads as the quietest setting, never as a crash");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestReactionSettingsMergeKeepsUntouchedFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *current = @{@"messageSource" : @"all", @"storySource" : @"contacts",
		@"pollVoteSource" : @"all", @"soundId" : @99, @"showPreview" : @NO};

	NSDictionary *storyOnly = TGNotifReactionSettingsMerged(current, @{@"storySource" : @"none"});
	TGTestExpectTrue(&outcome, [storyOnly[@"storySource"] isEqualToString:@"none"],
			"the field the user changed changes");
	TGTestExpectTrue(&outcome, [storyOnly[@"messageSource"] isEqualToString:@"all"] &&
					[storyOnly[@"pollVoteSource"] isEqualToString:@"all"] &&
					[storyOnly[@"soundId"] longLongValue] == 99 &&
					![storyOnly[@"showPreview"] boolValue],
			"every field the user did not touch survives the save");

	NSDictionary *messageOnly = TGNotifReactionSettingsMerged(current,
			@{@"messageSource" : @"contacts", @"pollVoteSource" : @"none", @"showPreview" : @YES});
	TGTestExpectTrue(&outcome, [messageOnly[@"storySource"] isEqualToString:@"contacts"] &&
					[messageOnly[@"soundId"] longLongValue] == 99,
			"changing the reaction sources must not silence story reactions or drop the sound");

	NSDictionary *fromNothing = TGNotifReactionSettingsMerged(nil, nil);
	TGTestExpectTrue(&outcome, [fromNothing[@"messageSource"] isEqualToString:@"none"] &&
					[fromNothing[@"soundId"] longLongValue] == 0 &&
					[fromNothing[@"showPreview"] boolValue],
			"with nothing known, every field still has a value the payload can carry");
	TGTestExpectTrue(&outcome,
			[TGNotifReactionSettingsMerged(@{@"messageSource" : @""}, nil)[@"messageSource"]
					isEqualToString:@"none"],
			"an empty source name is not a source name");

	return outcome;
}

TGTestOutcome TGFlattenNotificationsTestReactionSettingsPayloadRoundTrips(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *wire = @{
		@"@type" : @"reactionNotificationSettings",
		@"message_reaction_source" : @{@"@type" : @"reactionNotificationSourceAll"},
		@"story_reaction_source" : @{@"@type" : @"reactionNotificationSourceContacts"},
		@"poll_vote_source" : @{@"@type" : @"reactionNotificationSourceNone"},
		@"sound_id" : @"77",
		@"show_preview" : @YES
	};
	NSDictionary *payload = TGNotifReactionSettingsPayload(TGNotifReactionSettingsFrom(wire));

	TGTestExpectTrue(&outcome, [payload[@"@type"] isEqualToString:@"reactionNotificationSettings"],
			"the payload is the whole object TDLib expects");
	TGTestExpectTrue(&outcome,
			[payload[@"message_reaction_source"][@"@type"] isEqualToString:@"reactionNotificationSourceAll"] &&
			[payload[@"story_reaction_source"][@"@type"] isEqualToString:@"reactionNotificationSourceContacts"] &&
			[payload[@"poll_vote_source"][@"@type"] isEqualToString:@"reactionNotificationSourceNone"],
			"every source survives a read followed by a write unchanged");
	TGTestExpectTrue(&outcome, [payload[@"sound_id"] longLongValue] == 77,
			"the sound the user chose elsewhere is sent back, not zeroed");
	TGTestExpectTrue(&outcome, [payload[@"show_preview"] boolValue],
			"the preview flag survives the round trip");

	return outcome;
}
