#import "TGChatComposerState.h"

static BOOL TGCSBool(id value, BOOL fallback) {
	return [value isKindOfClass:NSNumber.class] ? [value boolValue] : fallback;
}

static NSInteger TGCSInteger(id value) {
	return [value isKindOfClass:NSNumber.class] ? [value integerValue] : 0;
}

@implementation TGChatComposerState

+ (instancetype)stateWithCanSend:(BOOL)canSend
						isChannel:(BOOL)isChannel
					  permissions:(NSDictionary *)permissions {
	TGChatComposerState *state = [[self alloc] init];
	state->_canPost = canSend;
	state->_channel = isChannel;
	state->_canSendPhotos = TGCSBool(permissions[@"canSendPhotos"], canSend);
	state->_canSendVideos = TGCSBool(permissions[@"canSendVideos"], canSend);
	state->_canSendVideoNotes = TGCSBool(permissions[@"canSendVideoNotes"], canSend);
	state->_canSendVoiceNotes = TGCSBool(permissions[@"canSendVoiceNotes"], canSend);
	state->_canSendAudios = TGCSBool(permissions[@"canSendAudios"], canSend);
	state->_canSendDocuments = TGCSBool(permissions[@"canSendDocuments"], canSend);
	state->_canSendPolls = TGCSBool(permissions[@"canSendPolls"], canSend);
	state->_canSendOtherMessages = TGCSBool(permissions[@"canSendOtherMessages"], canSend);
	state->_slowModeDelay = TGCSInteger(permissions[@"slowModeDelay"]);
	state->_slowModeSecondsRemaining = TGCSInteger(permissions[@"slowModeSecondsRemaining"]);
	state->_slowModeBlocked = state->_slowModeSecondsRemaining > 0;
	state->_topicClosed = TGCSBool(permissions[@"topicClosed"], NO);
	state->_isMember = TGCSBool(permissions[@"isMember"], YES);
	return state;
}

@end
