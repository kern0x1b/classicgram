#import "tg_chat_history_cache_tests.h"
#import "TGChatHistoryCache.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <unistd.h>

static NSString *TGTestChatHistoryCachePath(void) {
	NSString *caches = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	return [caches stringByAppendingPathComponent:@"chat-history.plist"];
}

static void TGTestRemoveChatHistoryCacheFile(void) {
	[[NSFileManager defaultManager] removeItemAtPath:TGTestChatHistoryCachePath() error:NULL];
}

static BOOL TGTestWaitForCondition(BOOL (^condition)(void)) {
	for (int i = 0; i < 400; i++) {
		if (condition())
			return YES;
		usleep(5000);
	}
	return NO;
}

TGTestOutcome TGChatHistoryCacheTestMissingChatReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	NSArray *messages = [cache messagesForChat:999 thread:0];

	TGTestExpectTrue(&outcome, messages == nil, "a chat that was never stored must return nil");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestSetThenGetReturnsSameMessages(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	NSArray *stored = @[ @{@"id" : @1}, @{@"id" : @2} ];
	[cache setMessages:stored forChat:100 thread:0];
	NSArray *fetched = [cache messagesForChat:100 thread:0];

	TGTestExpectTrue(&outcome, [fetched isEqualToArray:stored],
			"the messages fetched back must equal the messages stored");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestSettingEmptyArrayRemovesEntry(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	[cache setMessages:@[ @{@"id" : @1} ] forChat:100 thread:0];
	[cache setMessages:@[] forChat:100 thread:0];
	NSArray *fetched = [cache messagesForChat:100 thread:0];

	TGTestExpectTrue(&outcome, fetched == nil, "setting an empty array must remove the entry entirely");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestDifferentThreadsSameChatAreDistinctKeys(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	[cache setMessages:@[ @{@"id" : @1} ] forChat:5 thread:0];
	[cache setMessages:@[ @{@"id" : @2} ] forChat:5 thread:7];

	NSArray *mainThread = [cache messagesForChat:5 thread:0];
	NSArray *otherThread = [cache messagesForChat:5 thread:7];

	TGTestExpectEqualInteger(&outcome, [mainThread.firstObject[@"id"] integerValue], 1,
			"the main thread of a chat must keep its own messages");
	TGTestExpectEqualInteger(&outcome, [otherThread.firstObject[@"id"] integerValue], 2,
			"a different thread of the same chat must not share the main thread's entry");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestOverCapacityEvictsOldestEntry(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	[cache setMessages:@[ @{@"id" : @1} ] forChat:1 thread:0];
	[cache setMessages:@[ @{@"id" : @2} ] forChat:2 thread:0];
	[cache setMessages:@[ @{@"id" : @3} ] forChat:3 thread:0];
	[cache setMessages:@[ @{@"id" : @4} ] forChat:4 thread:0];

	TGTestExpectTrue(&outcome, [cache messagesForChat:1 thread:0] == nil,
			"the oldest chat must be evicted once the cache holds more than its limit");
	TGTestExpectTrue(&outcome, [cache messagesForChat:2 thread:0] != nil,
			"the second-oldest chat must survive");
	TGTestExpectTrue(&outcome, [cache messagesForChat:3 thread:0] != nil,
			"the third chat must survive");
	TGTestExpectTrue(&outcome, [cache messagesForChat:4 thread:0] != nil,
			"the newest chat must survive");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestReinsertingKeyMovesItToNewest(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	[cache setMessages:@[ @{@"id" : @1} ] forChat:1 thread:0];
	[cache setMessages:@[ @{@"id" : @2} ] forChat:2 thread:0];
	[cache setMessages:@[ @{@"id" : @3} ] forChat:3 thread:0];
	[cache setMessages:@[ @{@"id" : @11} ] forChat:1 thread:0];
	[cache setMessages:@[ @{@"id" : @4} ] forChat:4 thread:0];

	TGTestExpectTrue(&outcome, [cache messagesForChat:2 thread:0] == nil,
			"re-touching chat 1 must make chat 2 the oldest, so chat 2 is the one evicted");
	NSArray *chatOne = [cache messagesForChat:1 thread:0];
	TGTestExpectEqualInteger(&outcome, [chatOne.firstObject[@"id"] integerValue], 11,
			"chat 1 must carry the value it was re-set to, not its original value");
	TGTestExpectTrue(&outcome, [cache messagesForChat:3 thread:0] != nil,
			"chat 3 must survive");
	TGTestExpectTrue(&outcome, [cache messagesForChat:4 thread:0] != nil,
			"chat 4 must survive");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestClearRemovesEveryEntry(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	[cache setMessages:@[ @{@"id" : @1} ] forChat:1 thread:0];
	[cache setMessages:@[ @{@"id" : @2} ] forChat:2 thread:0];
	[cache clear];

	TGTestExpectTrue(&outcome, [cache messagesForChat:1 thread:0] == nil, "clear must drop chat 1");
	TGTestExpectTrue(&outcome, [cache messagesForChat:2 thread:0] == nil, "clear must drop chat 2");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestMemoryWarningNotificationClearsCache(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	[cache setMessages:@[ @{@"id" : @1} ] forChat:1 thread:0];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:UIApplicationDidReceiveMemoryWarningNotification
					  object:nil];

	TGTestExpectTrue(&outcome, [cache messagesForChat:1 thread:0] == nil,
			"a memory warning must clear every cached chat's history");

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestPersistThenFreshInstanceLoadsSameMessages(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestRemoveChatHistoryCacheFile();

	@autoreleasepool {
		TGChatHistoryCache *writer = [[TGChatHistoryCache alloc] init];
		[writer setMessages:@[ @{@"id" : @1, @"text" : @"hello"} ] forChat:42 thread:0];
		[writer persist];

		BOOL wroteFile = TGTestWaitForCondition(^BOOL{
			return [[NSFileManager defaultManager] fileExistsAtPath:TGTestChatHistoryCachePath()];
		});
		TGTestExpectTrue(&outcome, wroteFile, "persist must eventually write the cache file to disk");
	}

	TGChatHistoryCache *reader = [[TGChatHistoryCache alloc] init];
	NSArray *reloaded = [reader messagesForChat:42 thread:0];

	TGTestExpectEqualInteger(&outcome, reloaded.count, 1, "a fresh instance must load the persisted chat");
	TGTestExpectTrue(&outcome, [reloaded.firstObject[@"text"] isEqualToString:@"hello"],
			"the reloaded message must carry the same fields that were persisted");

	TGTestRemoveChatHistoryCacheFile();

	return outcome;
}

TGTestOutcome TGChatHistoryCacheTestPersistWithNoMessagesRemovesStaleFile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestRemoveChatHistoryCacheFile();

	TGChatHistoryCache *cache = [[TGChatHistoryCache alloc] init];
	[cache setMessages:@[ @{@"id" : @1} ] forChat:7 thread:0];
	[cache persist];
	TGTestWaitForCondition(^BOOL{
		return [[NSFileManager defaultManager] fileExistsAtPath:TGTestChatHistoryCachePath()];
	});

	[cache clear];
	[cache persist];
	BOOL fileGone = TGTestWaitForCondition(^BOOL{
		return ![[NSFileManager defaultManager] fileExistsAtPath:TGTestChatHistoryCachePath()];
	});

	TGTestExpectTrue(&outcome, fileGone, "persisting an empty cache must remove the stale file on disk");

	return outcome;
}
