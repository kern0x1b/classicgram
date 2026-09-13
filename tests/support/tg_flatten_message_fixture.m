#import "tg_flatten_message_fixture.h"

TGFlattenContext *TGFlattenMessageFixtureContext(void) {
	TGFlattenContext *context = [TGFlattenContext new];
	context.myUserId = 1001;
	context.ignoresSensitiveContentRestrictions = NO;
	context.chatsById = @{
		@2001 : @{@"title" : @"Test Group", @"isChannel" : @NO},
		@3001 : @{@"title" : @"News Channel", @"isChannel" : @YES},
		@4001 : @{@"title" : @"Secret Peer", @"isChannel" : @NO, @"isSecretChat" : @YES},
	};
	context.userName = ^NSString *(int64_t userId){
		if (userId == 1001) return @"Alice";
		if (userId == 1002) return @"Bob";
		return nil;
	};
	context.botServiceText = ^NSString *(NSDictionary *message){
		return nil;
	};
	context.secretServiceText = ^NSString *(NSDictionary *message){
		NSString *kind = message[@"content"][@"@type"];
		if ([kind isEqualToString:@"messageScreenshotTaken"])
			return @"Secret wording: screenshot taken";
		if ([kind isEqualToString:@"messageChatSetMessageAutoDeleteTime"])
			return @"Secret wording: self-destruct timer changed";
		return nil;
	};
	context.localizedFallback = ^NSString *(NSString *key, NSString *fallback){
		return fallback;
	};
	context.rememberFileState = ^(NSDictionary *file){
	};
	context.fileState = ^NSDictionary *(NSDictionary *file){
		if (![file isKindOfClass:NSDictionary.class])
			return nil;
		NSDictionary *local = [file[@"local"] isKindOfClass:NSDictionary.class]
				? file[@"local"] : @{};
		long long size = [file[@"size"] longLongValue];
		if (size <= 0)
			size = [file[@"expected_size"] longLongValue];
		return @{
			@"fileId"     : file[@"id"] ?: @0,
			@"size"       : @(size),
			@"downloaded" : local[@"downloaded_size"] ?: @0,
			@"complete"   : @([local[@"is_downloading_completed"] boolValue]),
			@"active"     : @([local[@"is_downloading_active"] boolValue]),
			@"path"       : [local[@"path"] isKindOfClass:NSString.class] ? local[@"path"] : @"",
		};
	};
	context.reactionChips = ^NSArray *(NSDictionary *interactionInfo, int64_t __unused chatId){
		NSArray *reactions = interactionInfo[@"reactions"][@"reactions"];
		if (![reactions isKindOfClass:NSArray.class])
			return @[];
		NSMutableArray *chips = [NSMutableArray array];
		for (NSDictionary *r in reactions){
			[chips addObject:@{
				@"emoji"  : r[@"type"][@"emoji"] ?: @"",
				@"count"  : r[@"total_count"] ?: @0,
				@"chosen" : @([r[@"is_chosen"] boolValue]),
			}];
		}
		return chips;
	};
	context.reactionSummary = ^NSString *(NSArray *chips){
		NSMutableArray *parts = [NSMutableArray array];
		for (NSDictionary *chip in chips)
			[parts addObject:[NSString stringWithFormat:@"%@ %ld",
					chip[@"emoji"], (long)[chip[@"count"] integerValue]]];
		return [parts componentsJoinedByString:@"  "];
	};
	context.flattenedPageBlocks = ^NSArray *(NSArray *rawBlocks){
		return @[];
	};
	return context;
}
