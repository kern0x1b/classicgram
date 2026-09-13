#import "tg_flatten_chat_state_tests.h"
#import "../../src/Wire/Flatten/TGFlattenChatState.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenChatStateTestScopeTypeMapsGroupsChannelsAndDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGScopeType(@"groups") isEqualToString:@"notificationSettingsScopeGroupChats"],
			"\"groups\" must map to notificationSettingsScopeGroupChats");
	TGTestExpectTrue(&outcome,
			[TGScopeType(@"channels") isEqualToString:@"notificationSettingsScopeChannelChats"],
			"\"channels\" must map to notificationSettingsScopeChannelChats");
	TGTestExpectTrue(&outcome,
			[TGScopeType(@"users") isEqualToString:@"notificationSettingsScopePrivateChats"],
			"any other scope name must fall back to notificationSettingsScopePrivateChats");
	TGTestExpectTrue(&outcome,
			[TGScopeType(nil) isEqualToString:@"notificationSettingsScopePrivateChats"],
			"a nil scope must fall back to notificationSettingsScopePrivateChats, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChatStateTestScopeNameMapsGroupsChannelsAndDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGScopeName(@"notificationSettingsScopeGroupChats") isEqualToString:@"groups"],
			"notificationSettingsScopeGroupChats must map back to \"groups\"");
	TGTestExpectTrue(&outcome,
			[TGScopeName(@"notificationSettingsScopeChannelChats") isEqualToString:@"channels"],
			"notificationSettingsScopeChannelChats must map back to \"channels\"");
	TGTestExpectTrue(&outcome,
			[TGScopeName(@"notificationSettingsScopePrivateChats") isEqualToString:@"private"],
			"notificationSettingsScopePrivateChats must map back to \"private\"");
	TGTestExpectTrue(&outcome,
			[TGScopeName(nil) isEqualToString:@"private"],
			"a nil scope type must fall back to \"private\", not crash");

	return outcome;
}

TGTestOutcome TGFlattenChatStateTestScopeForChatFlagsMapsChannelGroupAndPrivate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGScopeForChatFlags(YES, YES) isEqualToString:@"channels"],
			"a broadcast channel must use the channels scope even though it is also a group");
	TGTestExpectTrue(&outcome,
			[TGScopeForChatFlags(NO, YES) isEqualToString:@"groups"],
			"a basic group or non-channel supergroup must use the groups scope");
	TGTestExpectTrue(&outcome,
			[TGScopeForChatFlags(NO, NO) isEqualToString:@"private"],
			"a private or secret chat must use the private scope");

	return outcome;
}

TGTestOutcome TGFlattenChatStateTestEffectiveChatMutedUsesScopeDefaultWhenUseDefaultIsTrue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGEffectiveChatMuted(YES, 0, 3600),
			"when use_default_mute_for is true, a muted scope default must make the chat muted "
			"even though the chat's own mute_for is 0");
	TGTestExpectTrue(&outcome, !TGEffectiveChatMuted(YES, 3600, 0),
			"when use_default_mute_for is true, an unmuted scope default must leave the chat "
			"unmuted even though the chat's own stale mute_for is positive");

	return outcome;
}

TGTestOutcome TGFlattenChatStateTestEffectiveChatMutedUsesChatOwnMuteForWhenUseDefaultIsFalse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGEffectiveChatMuted(NO, 3600, 0),
			"when use_default_mute_for is false, a positive chat mute_for must make the chat muted");
	TGTestExpectTrue(&outcome, !TGEffectiveChatMuted(NO, 0, 3600),
			"when use_default_mute_for is false, the scope default must be ignored");

	return outcome;
}

TGTestOutcome TGFlattenChatStateTestFileObjectStateFlattensFullFileDict(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *file = @{
		@"id" : @17,
		@"size" : @2048,
		@"expected_size" : @4096,
		@"local" : @{
			@"path" : @"/tmp/cache/17.jpg",
			@"downloaded_size" : @2048,
			@"is_downloading_completed" : @YES,
			@"is_downloading_active" : @NO,
		},
	};

	NSDictionary *state = TGFlattenFileObjectState(file);

	TGTestExpectEqualInteger(&outcome, [state[@"fileId"] integerValue], 17,
			"fileId must round-trip from id");
	TGTestExpectEqualLongLong(&outcome, [state[@"size"] longLongValue], 2048,
			"size must be taken from size when it is positive");
	TGTestExpectEqualLongLong(&outcome, [state[@"downloaded"] longLongValue], 2048,
			"downloaded must round-trip from local.downloaded_size");
	TGTestExpectTrue(&outcome, [state[@"complete"] boolValue],
			"complete must round-trip from local.is_downloading_completed");
	TGTestExpectTrue(&outcome, ![state[@"active"] boolValue],
			"active must round-trip from local.is_downloading_active");
	TGTestExpectTrue(&outcome, [state[@"path"] isEqualToString:@"/tmp/cache/17.jpg"],
			"path must round-trip from local.path");

	return outcome;
}

TGTestOutcome TGFlattenChatStateTestFileObjectStateFallsBackToExpectedSizeWhenSizeIsZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *file = @{
		@"id" : @5,
		@"size" : @0,
		@"expected_size" : @9999,
		@"local" : @{},
	};

	NSDictionary *state = TGFlattenFileObjectState(file);

	TGTestExpectEqualLongLong(&outcome, [state[@"size"] longLongValue], 9999,
			"a non-positive size must fall back to expected_size");

	return outcome;
}

TGTestOutcome TGFlattenChatStateTestFileObjectStateFillsDefaultsForMissingLocalAndFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = TGFlattenFileObjectState(@{});

	TGTestExpectEqualInteger(&outcome, [state[@"fileId"] integerValue], 0,
			"a missing id must default fileId to 0");
	TGTestExpectEqualLongLong(&outcome, [state[@"size"] longLongValue], 0,
			"a missing size and expected_size must default size to 0");
	TGTestExpectEqualLongLong(&outcome, [state[@"downloaded"] longLongValue], 0,
			"a missing local dictionary must default downloaded to 0");
	TGTestExpectTrue(&outcome, ![state[@"complete"] boolValue],
			"a missing local dictionary must default complete to NO");
	TGTestExpectTrue(&outcome, ![state[@"active"] boolValue],
			"a missing local dictionary must default active to NO");
	TGTestExpectTrue(&outcome, [state[@"path"] isEqualToString:@""],
			"a missing local dictionary must default path to an empty string");

	NSDictionary *stateWithNonDictLocal = TGFlattenFileObjectState(@{@"id" : @3, @"local" : @"not a dictionary"});
	TGTestExpectTrue(&outcome, [stateWithNonDictLocal[@"path"] isEqualToString:@""],
			"a non-dictionary local value must not crash and must default path to an empty string");

	return outcome;
}

TGTestOutcome TGFlattenChatStateTestFileObjectStateReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFlattenFileObjectState(nil) == nil,
			"a nil file argument must return nil, not crash");
	TGTestExpectTrue(&outcome, TGFlattenFileObjectState((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary file argument must return nil, not crash");

	return outcome;
}
