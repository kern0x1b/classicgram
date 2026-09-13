#import "tg_chat_history_cache_scope_tests.h"

#import "../../src/Stores/TGChatHistoryCache.h"
#import "../../src/Stores/TGChatHistoryCacheFileName.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGChatHistoryCacheScopeTestPrimaryAccountKeepsTheOldFile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGChatHistoryCacheFileName(nil) isEqualToString:@"chat-history.plist"],
			"the first account keeps the file it already has, so nothing is lost on update");
	TGTestExpectTrue(&outcome,
			[TGChatHistoryCacheFileName(@"") isEqualToString:@"chat-history.plist"],
			"and an empty scope means the same account");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheScopeTestEverySlotHasItsOwnFile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *second = TGChatHistoryCacheFileName(@"1");
	NSString *third = TGChatHistoryCacheFileName(@"2");

	TGTestExpectTrue(&outcome, [second isEqualToString:@"chat-history-1.plist"],
			"a second account caches under its own name, where before both accounts wrote "
			"one file keyed by chat id - and a chat id means a different conversation "
			"in each account");
	TGTestExpectTrue(&outcome, ![second isEqualToString:third],
			"and no two accounts share a file");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheScopeTestScopeCannotEscapeTheFileName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGChatHistoryCacheFileName(@"../../etc") isEqualToString:@"chat-history-------etc.plist"],
			"a scope is never allowed to carry path separators into the file name");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheScopeTestSwitchingAccountsDropsTheMessages(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	NSArray *messages = @[ @{@"id" : @7, @"text" : @"only the first account saw this"} ];
	[cache setMessages:messages forChat:4242 thread:0];

	TGTestExpectTrue(&outcome, [[cache messagesForChat:4242 thread:0] count] == 1,
			"the first account has its history cached");

	[cache setAccountScope:@"1"];

	TGTestExpectTrue(&outcome, [cache messagesForChat:4242 thread:0] == nil,
			"after switching accounts the same chat id must not answer with the other "
			"account's messages");

	[cache setAccountScope:nil];
	[cache clear];

	return outcome;
}
