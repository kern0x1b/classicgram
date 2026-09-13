#import "TGClient+ChatState.h"
#import "TGTDLibInt64.h"
#import "TGClient+GroupCalls.h"
#import "TGClient+Private.h"

static NSDictionary *TGGroupCallDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGGroupCallArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSString *TGGroupCallString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static int64_t TGGroupCallLongLong(id value) {
	return TGTDLibInt64(value);
}

@implementation TGClient (GroupCalls)

- (NSDictionary *)tggroupcall_speaker:(NSDictionary *)speaker {
	NSDictionary *sender = TGGroupCallDict(speaker[@"participant_id"]);
	BOOL isChat = [TGGroupCallString(sender[@"@type"]) isEqualToString:@"messageSenderChat"];
	int64_t senderId = isChat ? TGGroupCallLongLong(sender[@"chat_id"])
							  : TGGroupCallLongLong(sender[@"user_id"]);
	NSString *name = isChat
		? TGGroupCallString(self.chatsById[@(senderId)][@"title"])
		: ([self nameForUserId:senderId] ?: @"");
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@(senderId), @"senderId",
		@(isChat), @"isChat",
		name, @"name",
		@([speaker[@"is_speaking"] boolValue]), @"isSpeaking",
		nil];
}

- (void)groupCallInfo:(int32_t)groupCallId completion:(void (^)(NSDictionary *))completion {
	if (groupCallId == 0) {
		if (completion)
			completion(nil);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getGroupCall", @"group_call_id" : @(groupCallId)}
		completion:^(NSDictionary *call) {
			TGClient *strongSelf = weakSelf;
			if (!completion || !strongSelf)
				return;
			if (TGResultIsError(call)) {
				completion(nil);
				return;
			}
			NSMutableArray *speakers = [NSMutableArray array];
			for (id speaker in TGGroupCallArray(call[@"recent_speakers"])) {
				NSDictionary *row = [strongSelf tggroupcall_speaker:TGGroupCallDict(speaker)];
				if (row)
					[speakers addObject:row];
			}
			completion([NSDictionary dictionaryWithObjectsAndKeys:
					@(groupCallId), @"id",
				TGGroupCallString(call[@"title"]), @"title",
				@([call[@"is_active"] boolValue]), @"isActive",
				@([call[@"is_video_chat"] boolValue]), @"isVideoChat",
				@([call[@"participant_count"] integerValue]), @"participantCount",
				speakers, @"recentSpeakers",
				@([call[@"duration"] integerValue]), @"duration",
				nil]);
		}];
}

@end
