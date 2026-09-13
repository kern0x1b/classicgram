#import "tg_composer_state_tests.h"
#import "../../src/Model/TGChatComposerState.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGComposerStateTestNilPermissionsFallBackToCanSendForEveryAttachmentFlag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatComposerState *blocked = [TGChatComposerState stateWithCanSend:NO isChannel:NO permissions:nil];
	TGTestExpectTrue(&outcome, blocked.canSendPhotos == NO,
			"with no permissions dict, every attachment flag must fall back to canSend");
	TGTestExpectTrue(&outcome, blocked.canSendVideos == NO,
			"with no permissions dict, every attachment flag must fall back to canSend");
	TGTestExpectTrue(&outcome, blocked.canSendVideoNotes == NO,
			"with no permissions dict, every attachment flag must fall back to canSend");
	TGTestExpectTrue(&outcome, blocked.canSendVoiceNotes == NO,
			"with no permissions dict, every attachment flag must fall back to canSend");
	TGTestExpectTrue(&outcome, blocked.canSendAudios == NO,
			"with no permissions dict, every attachment flag must fall back to canSend");
	TGTestExpectTrue(&outcome, blocked.canSendDocuments == NO,
			"with no permissions dict, every attachment flag must fall back to canSend");
	TGTestExpectTrue(&outcome, blocked.canSendPolls == NO,
			"with no permissions dict, every attachment flag must fall back to canSend");
	TGTestExpectTrue(&outcome, blocked.canSendOtherMessages == NO,
			"with no permissions dict, every attachment flag must fall back to canSend");

	TGChatComposerState *allowed = [TGChatComposerState stateWithCanSend:YES isChannel:NO permissions:nil];
	TGTestExpectTrue(&outcome, allowed.canSendPhotos == YES,
			"with no permissions dict and canSend true, every attachment flag must default to true");
	TGTestExpectTrue(&outcome, allowed.canSendOtherMessages == YES,
			"with no permissions dict and canSend true, every attachment flag must default to true");
	TGTestExpectTrue(&outcome, allowed.slowModeBlocked == NO,
			"with no permissions dict, slow mode must never be reported as blocking");

	return outcome;
}

TGTestOutcome TGComposerStateTestExplicitPermissionsOverrideTheCanSendFallback(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *permissions = @{
		@"canSendPhotos" : @NO,
		@"canSendVideos" : @YES,
		@"canSendPolls" : @NO,
		@"canSendOtherMessages" : @YES,
	};
	TGChatComposerState *state = [TGChatComposerState stateWithCanSend:YES isChannel:NO permissions:permissions];

	TGTestExpectTrue(&outcome, state.canSendPhotos == NO,
			"an explicit false in the permissions dict must override a true canSend fallback");
	TGTestExpectTrue(&outcome, state.canSendVideos == YES,
			"an explicit true in the permissions dict must be honoured");
	TGTestExpectTrue(&outcome, state.canSendPolls == NO,
			"an explicit false in the permissions dict must override a true canSend fallback");
	TGTestExpectTrue(&outcome, state.canSendOtherMessages == YES,
			"an explicit true in the permissions dict must be honoured");
	TGTestExpectTrue(&outcome, state.canSendVideoNotes == YES,
			"a key missing from the permissions dict must still fall back to canSend");
	TGTestExpectTrue(&outcome, state.canSendAudios == YES,
			"a key missing from the permissions dict must still fall back to canSend");

	return outcome;
}

TGTestOutcome TGComposerStateTestSlowModeBlockedReflectsSecondsRemaining(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *stillWaiting = @{@"slowModeDelay" : @30, @"slowModeSecondsRemaining" : @12};
	TGChatComposerState *waiting = [TGChatComposerState stateWithCanSend:YES isChannel:NO permissions:stillWaiting];
	TGTestExpectTrue(&outcome, waiting.slowModeDelay == 30,
			"slowModeDelay must round-trip from the permissions dict");
	TGTestExpectEqualInteger(&outcome, waiting.slowModeSecondsRemaining, 12,
			"slowModeSecondsRemaining must round-trip from the permissions dict");
	TGTestExpectTrue(&outcome, waiting.slowModeBlocked == YES,
			"a positive slowModeSecondsRemaining must report slowModeBlocked as true");

	NSDictionary *notWaiting = @{@"slowModeDelay" : @30, @"slowModeSecondsRemaining" : @0};
	TGChatComposerState *clear = [TGChatComposerState stateWithCanSend:YES isChannel:NO permissions:notWaiting];
	TGTestExpectTrue(&outcome, clear.slowModeBlocked == NO,
			"a zero slowModeSecondsRemaining must report slowModeBlocked as false even though slow mode is enabled");

	return outcome;
}

TGTestOutcome TGComposerStateTestTopicClosedReflectsThePermissionsDict(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatComposerState *withoutTopic = [TGChatComposerState stateWithCanSend:YES isChannel:NO permissions:nil];
	TGTestExpectTrue(&outcome, withoutTopic.topicClosed == NO,
			"with no permissions dict, topicClosed must default to false");

	NSDictionary *closed = @{@"topicClosed" : @YES};
	TGChatComposerState *closedState = [TGChatComposerState stateWithCanSend:NO isChannel:NO permissions:closed];
	TGTestExpectTrue(&outcome, closedState.topicClosed == YES,
			"an explicit true topicClosed in the permissions dict must be honoured");

	NSDictionary *open = @{@"topicClosed" : @NO};
	TGChatComposerState *openState = [TGChatComposerState stateWithCanSend:YES isChannel:NO permissions:open];
	TGTestExpectTrue(&outcome, openState.topicClosed == NO,
			"an explicit false topicClosed in the permissions dict must be honoured");

	return outcome;
}

TGTestOutcome TGComposerStateTestNonNumberPermissionValuesDoNotCrashAndFallBack(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *wrongTypes = @{
		@"canSendPhotos" : @"not a bool",
		@"slowModeSecondsRemaining" : @"not a number",
	};
	TGChatComposerState *state = [TGChatComposerState stateWithCanSend:YES isChannel:YES permissions:wrongTypes];

	TGTestExpectTrue(&outcome, state.canSendPhotos == YES,
			"a permissions value of the wrong type must be treated like a missing key and fall back to canSend");
	TGTestExpectEqualInteger(&outcome, state.slowModeSecondsRemaining, 0,
			"a permissions value of the wrong type must be treated like a missing key and default to zero");
	TGTestExpectTrue(&outcome, state.channel == YES,
			"the channel flag must round-trip regardless of the permissions dict contents");

	return outcome;
}

TGTestOutcome TGComposerStateTestIsMemberDefaultsTrueButHonoursExplicitFalse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatComposerState *withoutPermissions = [TGChatComposerState stateWithCanSend:NO isChannel:YES permissions:nil];
	TGTestExpectTrue(&outcome, withoutPermissions.isMember == YES,
			"with no permissions dict, isMember must default to true so an unrelated caller never sees a false Join affordance");

	NSDictionary *notAMember = @{@"isMember" : @NO};
	TGChatComposerState *visitor = [TGChatComposerState stateWithCanSend:NO isChannel:YES permissions:notAMember];
	TGTestExpectTrue(&outcome, visitor.isMember == NO,
			"an explicit false isMember in the permissions dict must be honoured");

	NSDictionary *aMember = @{@"isMember" : @YES};
	TGChatComposerState *member = [TGChatComposerState stateWithCanSend:NO isChannel:YES permissions:aMember];
	TGTestExpectTrue(&outcome, member.isMember == YES,
			"an explicit true isMember in the permissions dict must be honoured");

	return outcome;
}
