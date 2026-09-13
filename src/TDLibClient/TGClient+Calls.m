#import "TGClient+ChatState.h"
#import "TGTDLibInt64.h"
#import "TGClient+Calls.h"
#import "TGClient+Private.h"
#import "TGFlattenCalls.h"

static NSArray *TGCallsArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSString *TGCallsString(id value) {
	return [value isKindOfClass:NSString.class] ? value : nil;
}

static int64_t TGCallsLongLong(id value) {
	return TGTDLibInt64(value);
}

static NSDictionary *TGCallsDictionary(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

@implementation TGClient (Calls)

#pragma mark - call history

- (NSDictionary *)tgcalls_rowForMessage:(NSDictionary *)message {
	NSDictionary *content = TGCallsDictionary(message[@"content"]);
	if (![content[@"@type"] isEqualToString:@"messageCall"])
		return nil;

	int64_t chatId = TGCallsLongLong(message[@"chat_id"]);
	if (chatId <= 0)
		return nil;

	int64_t userId = chatId;
	NSDictionary *sender = TGCallsDictionary(message[@"sender_id"]);
	BOOL outgoing = [message[@"is_outgoing"] boolValue];
	if (!outgoing && [sender[@"@type"] isEqualToString:@"messageSenderUser"]) {
		int64_t senderId = TGCallsLongLong(sender[@"user_id"]);
		if (senderId != 0)
			userId = senderId;
	}

	NSString *reason = TGCallsString(TGCallsDictionary(content[@"discard_reason"])[@"@type"]);
	BOOL declined = [reason isEqualToString:@"callDiscardReasonDeclined"];
	BOOL missed = declined || [reason isEqualToString:@"callDiscardReasonMissed"];

	NSString *name = [self nameForUserId:userId];
	if (!name.length)
		name = TGCallsString(TGCallsDictionary(self.chatsById[@(chatId)])[@"title"]);

	return [NSDictionary dictionaryWithObjectsAndKeys:
			@(TGCallsLongLong(message[@"id"])), @"messageId",
		@(chatId), @"chatId",
		@(userId), @"userId",
		name ?: @"", @"name",
		@([message[@"date"] integerValue]), @"date",
		@(outgoing), @"outgoing",
		@([content[@"is_video"] boolValue]), @"video",
		@(missed), @"missed",
		@(declined), @"declined",
		@([content[@"duration"] integerValue]), @"duration",
		nil];
}

- (void)callHistoryOnlyMissed:(BOOL)onlyMissed
					   offset:(NSString *)offset
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *, NSString *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:[NSDictionary dictionaryWithObjectsAndKeys:
						  @"searchCallMessages", @"@type",
					  TGCallsString(offset) ?: @"", @"offset",
					  @(limit > 0 ? limit : 50), @"limit",
					  @(onlyMissed), @"only_missed",
					  nil]
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(result)) {
				completion(nil, nil, YES);
				return;
			}
			NSMutableArray *rows = [NSMutableArray array];
			for (id message in TGCallsArray(result[@"messages"])) {
				NSDictionary *row = [strongSelf tgcalls_rowForMessage:TGCallsDictionary(message)];
				if (row)
					[rows addObject:row];
			}
			completion(rows, TGCallsString(result[@"next_offset"]) ?: @"", NO);
		}];
}

- (void)clearCallHistoryForEveryone:(BOOL)forEveryone
						 completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"deleteAllCallMessages", @"revoke" : @(forEveryone)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - after a call: rating

- (void)tgcalls_rate:(NSDictionary *)inputCall
			  rating:(NSInteger)rating
			 comment:(NSString *)comment
			problems:(NSArray *)problems
		  completion:(void (^)(BOOL))completion {
	NSMutableArray *encoded = [NSMutableArray array];
	for (id name in TGCallsArray(problems)) {
		NSString *type = TGCallsProblemType(name);
		if (type)
			[encoded addObject:@{@"@type" : type}];
	}
	NSInteger clamped = rating < 1 ? 1 : (rating > 5 ? 5 : rating);

	[self request:@{
		@"@type" : @"sendCallRating",
		@"call_id" : inputCall,
		@"rating" : @((int)clamped),
		@"comment" : TGCallsString(comment) ?: @"",
		@"problems" : encoded,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)rateCallId:(int32_t)callId
			rating:(NSInteger)rating
		   comment:(NSString *)comment
		  problems:(NSArray *)problems
		completion:(void (^)(BOOL))completion {
	[self tgcalls_rate:@{@"@type" : @"inputCallDiscarded", @"call_id" : @(callId)}
				rating:rating
			   comment:comment
			  problems:problems
			completion:completion];
}

- (void)sendCallDebugInformation:(NSString *)information
					   forCallId:(int32_t)callId
					  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"sendCallDebugInformation",
		@"call_id" : @{@"@type" : @"inputCallDiscarded", @"call_id" : @(callId)},
		@"debug_information" : TGCallsString(information) ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

static NSDictionary *TGCallProtocol(void) {
	return @{
		@"@type" : @"callProtocol",
		@"udp_p2p" : @NO,
		@"udp_reflector" : @YES,
		@"min_layer" : @(65),
		@"max_layer" : @(92),
		@"library_versions" : @[ @"9.0.0", @"3.0.0", @"2.4.4" ],
	};
}

- (void)createCallToUserId:(int64_t)userId
					  video:(BOOL)video
				 completion:(void (^)(int32_t, BOOL))completion {
	[self request:@{
		@"@type" : @"createCall",
		@"user_id" : @(userId),
		@"protocol" : TGCallProtocol(),
		@"is_video" : @(video),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(0, NO);
			return;
		}
		completion([result[@"id"] intValue], YES);
	}];
}

- (void)acceptCallId:(int32_t)callId {
	[self send:@{
		@"@type" : @"acceptCall",
		@"call_id" : @(callId),
		@"protocol" : TGCallProtocol(),
	}];
}

- (void)discardCallId:(int32_t)callId
			 duration:(NSInteger)duration
				video:(BOOL)video
	   isDisconnected:(BOOL)isDisconnected
		 connectionId:(int64_t)connectionId {
	[self send:@{
		@"@type" : @"discardCall",
		@"call_id" : @(callId),
		@"is_disconnected" : @(isDisconnected),
		@"invite_link" : @"",
		@"duration" : @((int)duration),
		@"is_video" : @(video),
		@"connection_id" : @(connectionId),
	}];
}

- (void)sendSignalingData:(NSString *)base64Data forCallId:(int32_t)callId {
	if (!base64Data.length)
		return;
	[self send:@{
		@"@type" : @"sendCallSignalingData",
		@"call_id" : @(callId),
		@"data" : base64Data,
	}];
}

@end
