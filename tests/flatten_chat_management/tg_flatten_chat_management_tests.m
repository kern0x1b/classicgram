#import "tg_flatten_chat_management_tests.h"
#import "../../src/Wire/Flatten/TGFlattenChatManagement.h"
#import <Foundation/Foundation.h>

static NSArray *TGFlattenChatManagementTestRightKeys(void) {
	return @[ @"canManageChat", @"canChangeInfo", @"canPostMessages", @"canEditMessages",
		@"canDeleteMessages", @"canInviteUsers", @"canRestrictMembers", @"canPinMessages",
		@"canManageTopics", @"canPromoteMembers", @"canManageVideoChats", @"canPostStories",
		@"canEditStories", @"canDeleteStories" ];
}

TGTestOutcome TGFlattenChatManagementTestStatusNameMapsCreatorAndAdministrator(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCMStatusName(@"chatMemberStatusCreator") isEqualToString:@"creator"],
			"chatMemberStatusCreator must map to the short display string creator");
	TGTestExpectTrue(&outcome,
			[TGCMStatusName(@"chatMemberStatusAdministrator") isEqualToString:@"administrator"],
			"chatMemberStatusAdministrator must map to the short display string administrator");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestStatusNameFallsBackToMemberForOtherKnownStatuses(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *knownFallbackStatuses = @[ @"chatMemberStatusMember", @"chatMemberStatusRestricted",
		@"chatMemberStatusLeft", @"chatMemberStatusBanned" ];
	for (NSString *type in knownFallbackStatuses)
		TGTestExpectTrue(&outcome, [TGCMStatusName(type) isEqualToString:@"member"],
				"every TDLib chat-member status other than creator or administrator must map to member");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestStatusNameFallsBackToMemberForUnknownType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCMStatusName(@"chatMemberStatusSomeFutureStatus") isEqualToString:@"member"],
			"a status type unknown to this build of the client must fall back to member, not crash");
	TGTestExpectTrue(&outcome, [TGCMStatusName(@"") isEqualToString:@"member"],
			"an empty status type must fall back to member");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestFlatRightsOwnerGrantsAllRightsExceptAnonymousWhichReadsRawDict(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *rightsWithAnonymousTrue = @{
		@"can_pin_messages" : @NO,
		@"can_invite_users" : @NO,
		@"is_anonymous" : @YES,
	};
	NSDictionary *flatAnonymousTrue =
		TGCMFlatRights(rightsWithAnonymousTrue, YES, NO, @"Owner");
	for (NSString *key in TGFlattenChatManagementTestRightKeys())
		TGTestExpectTrue(&outcome, [flatAnonymousTrue[key] boolValue] == YES,
				"an owner must be granted every right regardless of what the raw rights dict says");
	TGTestExpectTrue(&outcome, [flatAnonymousTrue[@"isAnonymous"] boolValue] == YES,
			"isAnonymous is special-cased for owners: it must still read the raw dict value");
	TGTestExpectTrue(&outcome, [flatAnonymousTrue[@"isOwner"] boolValue] == YES,
			"isOwner must reflect the isOwner argument");
	TGTestExpectTrue(&outcome, [flatAnonymousTrue[@"isAdministrator"] boolValue] == YES,
			"an owner must always be reported as an administrator too");
	TGTestExpectTrue(&outcome, [flatAnonymousTrue[@"isMember"] boolValue] == YES,
			"an owner must always be reported as a member too");

	NSDictionary *rightsWithAnonymousFalse = @{@"is_anonymous" : @NO};
	NSDictionary *flatAnonymousFalse =
		TGCMFlatRights(rightsWithAnonymousFalse, YES, NO, @"Owner");
	TGTestExpectTrue(&outcome, [flatAnonymousFalse[@"isAnonymous"] boolValue] == NO,
			"when the raw dict says an owner is not anonymous, isAnonymous must be false");
	for (NSString *key in TGFlattenChatManagementTestRightKeys())
		TGTestExpectTrue(&outcome, [flatAnonymousFalse[key] boolValue] == YES,
				"every other right must still be granted true for an owner even when isAnonymous is false");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestFlatRightsAdministratorReflectsPartialRightsDict(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *partialRights = @{
		@"can_pin_messages" : @YES,
		@"can_invite_users" : @YES,
		@"is_anonymous" : @YES,
	};
	NSDictionary *flat = TGCMFlatRights(partialRights, NO, YES, @"Mod");

	TGTestExpectTrue(&outcome, [flat[@"canPinMessages"] boolValue] == YES,
			"a right present and true in the raw dict must flatten to true for an administrator");
	TGTestExpectTrue(&outcome, [flat[@"canInviteUsers"] boolValue] == YES,
			"a right present and true in the raw dict must flatten to true for an administrator");
	TGTestExpectTrue(&outcome, [flat[@"isAnonymous"] boolValue] == YES,
			"isAnonymous for a non-owner administrator must also read the raw dict");
	TGTestExpectTrue(&outcome, [flat[@"canManageChat"] boolValue] == NO,
			"a right absent from the raw dict must flatten to false for a non-owner");
	TGTestExpectTrue(&outcome, [flat[@"canDeleteStories"] boolValue] == NO,
			"a right absent from the raw dict must flatten to false for a non-owner");
	TGTestExpectTrue(&outcome, [flat[@"isOwner"] boolValue] == NO,
			"isOwner must be false for a plain administrator");
	TGTestExpectTrue(&outcome, [flat[@"isAdministrator"] boolValue] == YES,
			"isAdministrator must reflect the isAdministrator argument");
	TGTestExpectTrue(&outcome, [flat[@"isMember"] boolValue] == YES,
			"an administrator must also be reported as a member");
	TGTestExpectTrue(&outcome, [flat[@"customTitle"] isEqualToString:@"Mod"],
			"the custom title must round-trip for an administrator");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestFlatRightsPlainMemberIsAllFalse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGCMFlatRights(nil, NO, NO, @"");

	for (NSString *key in TGFlattenChatManagementTestRightKeys())
		TGTestExpectTrue(&outcome, [flat[key] boolValue] == NO,
				"a plain member with no rights dict must have every right false");
	TGTestExpectTrue(&outcome, [flat[@"isAnonymous"] boolValue] == NO,
			"a plain member must not be anonymous");
	TGTestExpectTrue(&outcome, [flat[@"isOwner"] boolValue] == NO,
			"isOwner must be false for a plain member");
	TGTestExpectTrue(&outcome, [flat[@"isAdministrator"] boolValue] == NO,
			"isAdministrator must be false for a plain member");
	TGTestExpectTrue(&outcome, [flat[@"isMember"] boolValue] == NO,
			"isMember must reflect the isOwner/isAdministrator arguments, not default true");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestFlatRightsMissingRightsDictDoesNotCrash(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flatOwnerNilRights = TGCMFlatRights(nil, YES, YES, @"Owner");
	for (NSString *key in TGFlattenChatManagementTestRightKeys())
		TGTestExpectTrue(&outcome, [flatOwnerNilRights[key] boolValue] == YES,
				"an owner with a nil rights dict must still be granted every ordinary right");
	TGTestExpectTrue(&outcome, [flatOwnerNilRights[@"isAnonymous"] boolValue] == NO,
			"an owner with a nil rights dict must read isAnonymous as false rather than crash");

	NSDictionary *flatAdminNilRights = TGCMFlatRights(nil, NO, YES, @"Mod");
	for (NSString *key in TGFlattenChatManagementTestRightKeys())
		TGTestExpectTrue(&outcome, [flatAdminNilRights[key] boolValue] == NO,
				"a non-owner administrator with a nil rights dict must have every right false");

	NSDictionary *flatWrongTypeRights = TGCMFlatRights((id)@"not a dictionary", NO, YES, @"Mod");
	for (NSString *key in TGFlattenChatManagementTestRightKeys())
		TGTestExpectTrue(&outcome, [flatWrongTypeRights[key] boolValue] == NO,
				"a rights argument that is not a dictionary must be treated like a missing one");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestFlatRightsCustomTitleHandling(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flatWithTitle = TGCMFlatRights(nil, NO, YES, @"Founder");
	TGTestExpectTrue(&outcome, [flatWithTitle[@"customTitle"] isEqualToString:@"Founder"],
			"a present custom title string must round-trip unchanged");

	NSDictionary *flatWithNilTitle = TGCMFlatRights(nil, NO, YES, nil);
	TGTestExpectTrue(&outcome, [flatWithNilTitle[@"customTitle"] isEqualToString:@""],
			"a nil custom title must flatten to an empty string, not nil or NSNull");

	NSDictionary *flatWithWrongTypeTitle = TGCMFlatRights(nil, NO, YES, (id)@42);
	TGTestExpectTrue(&outcome, [flatWithWrongTypeTitle[@"customTitle"] isEqualToString:@""],
			"a custom title argument of the wrong type must flatten to an empty string");

	return outcome;
}

static NSArray *TGFlattenChatManagementTestComposerKeys(void) {
	return @[ @"canSendPhotos", @"canSendVideos", @"canSendVideoNotes", @"canSendVoiceNotes",
		@"canSendAudios", @"canSendDocuments", @"canSendPolls", @"canSendOtherMessages" ];
}

TGTestOutcome TGFlattenChatManagementTestFlatComposerPermissionsAdminOrOwnerGrantsEverythingAndClearsSlowMode(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *memberPermissionsAllFalse = @{
		@"can_send_photos" : @NO,
		@"can_send_polls" : @NO,
	};
	NSDictionary *flat = TGCMFlatComposerPermissions(memberPermissionsAllFalse, YES, NO, 30, 12.0);

	for (NSString *key in TGFlattenChatManagementTestComposerKeys())
		TGTestExpectTrue(&outcome, [flat[key] boolValue] == YES,
				"an admin or owner must bypass every per-type restriction regardless of the raw permissions dict");
	TGTestExpectEqualInteger(&outcome, [flat[@"slowModeDelay"] integerValue], 0,
			"an admin or owner must never be reported as subject to slow mode");
	TGTestExpectEqualInteger(&outcome, [flat[@"slowModeSecondsRemaining"] integerValue], 0,
			"an admin or owner must never be reported as currently blocked by slow mode");
	TGTestExpectTrue(&outcome, [flat[@"isMember"] boolValue] == YES,
			"an admin or owner must be reported as a member even when the raw isMember argument is false");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestFlatComposerPermissionsPlainMemberReadsEachKeyFromTheRawDict(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *memberPermissions = @{
		@"can_send_photos" : @YES,
		@"can_send_videos" : @NO,
		@"can_send_video_notes" : @YES,
		@"can_send_voice_notes" : @NO,
		@"can_send_audios" : @YES,
		@"can_send_documents" : @NO,
		@"can_send_polls" : @YES,
		@"can_send_other_messages" : @NO,
	};
	NSDictionary *flat = TGCMFlatComposerPermissions(memberPermissions, NO, YES, 30, 12.4);

	TGTestExpectTrue(&outcome, [flat[@"canSendPhotos"] boolValue] == YES,
			"a plain member's canSendPhotos must read can_send_photos from the raw dict");
	TGTestExpectTrue(&outcome, [flat[@"canSendVideos"] boolValue] == NO,
			"a plain member's canSendVideos must read can_send_videos from the raw dict");
	TGTestExpectTrue(&outcome, [flat[@"canSendVideoNotes"] boolValue] == YES,
			"a plain member's canSendVideoNotes must read can_send_video_notes from the raw dict");
	TGTestExpectTrue(&outcome, [flat[@"canSendVoiceNotes"] boolValue] == NO,
			"a plain member's canSendVoiceNotes must read can_send_voice_notes from the raw dict");
	TGTestExpectTrue(&outcome, [flat[@"canSendAudios"] boolValue] == YES,
			"a plain member's canSendAudios must read can_send_audios from the raw dict");
	TGTestExpectTrue(&outcome, [flat[@"canSendDocuments"] boolValue] == NO,
			"a plain member's canSendDocuments must read can_send_documents from the raw dict");
	TGTestExpectTrue(&outcome, [flat[@"canSendPolls"] boolValue] == YES,
			"a plain member's canSendPolls must read can_send_polls from the raw dict");
	TGTestExpectTrue(&outcome, [flat[@"canSendOtherMessages"] boolValue] == NO,
			"a plain member's canSendOtherMessages must read can_send_other_messages from the raw dict");
	TGTestExpectEqualInteger(&outcome, [flat[@"slowModeDelay"] integerValue], 30,
			"a plain member's slowModeDelay must round-trip the given delay");
	TGTestExpectTrue(&outcome, [flat[@"isMember"] boolValue] == YES,
			"a plain member's isMember must round-trip the given membership flag");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestFlatComposerPermissionsMissingOrNilMemberPermissionsIsAllFalse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flatNil = TGCMFlatComposerPermissions(nil, NO, NO, 0, 0);
	for (NSString *key in TGFlattenChatManagementTestComposerKeys())
		TGTestExpectTrue(&outcome, [flatNil[key] boolValue] == NO,
				"a nil member permissions dict for a non-admin must flatten every per-type flag to false");
	TGTestExpectTrue(&outcome, [flatNil[@"isMember"] boolValue] == NO,
			"a non-admin who is not a member must flatten to isMember false");

	NSDictionary *flatWrongType = TGCMFlatComposerPermissions((id)@"not a dictionary", NO, NO, 0, 0);
	for (NSString *key in TGFlattenChatManagementTestComposerKeys())
		TGTestExpectTrue(&outcome, [flatWrongType[key] boolValue] == NO,
				"a member permissions argument of the wrong type must be treated like a missing one");

	return outcome;
}

TGTestOutcome TGFlattenChatManagementTestFlatComposerPermissionsSlowModeSecondsRemainingIsRoundedUpAndClamped(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *fractional = TGCMFlatComposerPermissions(nil, NO, YES, 30, 4.2);
	TGTestExpectEqualInteger(&outcome, [fractional[@"slowModeSecondsRemaining"] integerValue], 5,
			"a fractional seconds-remaining value must be rounded up so the user never sees zero while still blocked");

	NSDictionary *negative = TGCMFlatComposerPermissions(nil, NO, YES, -5, -3.0);
	TGTestExpectEqualInteger(&outcome, [negative[@"slowModeDelay"] integerValue], 0,
			"a negative slow mode delay must be clamped to zero rather than reported as negative");
	TGTestExpectEqualInteger(&outcome, [negative[@"slowModeSecondsRemaining"] integerValue], 0,
			"a negative seconds-remaining value must be clamped to zero rather than reported as negative");

	return outcome;
}
