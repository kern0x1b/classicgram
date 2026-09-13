#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGClient+Messages.h"
#import "TGMessageReadSource.h"

@implementation TGChatViewController (ReadState)

- (void)markVisibleMessagesRead {
	NSArray *visible = [self.table indexPathsForVisibleRows];
	NSMutableArray *fresh = [NSMutableArray array];
	NSMutableSet *currentlyVisibleChannelPostIds = [NSMutableSet set];
	for (NSIndexPath *path in visible) {
		CGRect rowFrame = [self.table rectForRowAtIndexPath:path];
		CGRect visiblePortion = CGRectIntersection(rowFrame, self.table.bounds);
		for (NSDictionary *m in [self messagesAtRow:path.row]) {
			if (![m[@"id"] isKindOfClass:NSNumber.class])
				continue;
			if (![m[@"outgoing"] boolValue] && ![self.readMessageIds containsObject:m[@"id"]]) {
				[self.readMessageIds addObject:m[@"id"]];
				[fresh addObject:m[@"id"]];
			}
			if ([m[@"channelPost"] boolValue]) {
				NSNumber *messageId = m[@"id"];
				[currentlyVisibleChannelPostIds addObject:messageId];
				int32_t seenRatio = rowFrame.size.height > 0
					? (int32_t)MIN(1000.0, 1000.0 * visiblePortion.size.height / rowFrame.size.height)
					: 1000;
				NSArray *existing = self.channelViewMetricsStart[messageId];
				if (!existing) {
					CGFloat viewportHeight = self.table.bounds.size.height;
					int32_t heightToViewportRatio = viewportHeight > 0
						? (int32_t)MIN(1000.0, 1000.0 * rowFrame.size.height / viewportHeight)
						: 1000;
					self.channelViewMetricsStart[messageId] =
						@[ [NSDate date], @(heightToViewportRatio), @(seenRatio) ];
				} else {
					self.channelViewMetricsStart[messageId] =
						@[ existing[0], existing[1], @(seenRatio) ];
				}
			}
		}
	}
	[self flushChannelViewMetricsExceptForIds:currentlyVisibleChannelPostIds];
	if (fresh.count) {
		BOOL chatIsForum = [[[TGClient shared] chatInfoForId:self.chatId][@"isForum"] boolValue];
		[[TGClient shared] markRead:fresh inChat:self.chatId
							  source:TGMessageReadSource(self.threadId != 0, chatIsForum)];
		[self updateScrollDownButton];
	}
}

- (NSInteger)unreadMessagesStillBelow {
	if (self.lastReadInboxOnOpen == 0)
		return 0;

	NSInteger unread = 0;
	for (NSDictionary *m in self.messages) {
		if ([m[@"outgoing"] boolValue] || [m[@"service"] boolValue])
			continue;
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (!messageId || [messageId longLongValue] <= self.lastReadInboxOnOpen)
			continue;
		if ([self.readMessageIds containsObject:messageId])
			continue;
		unread++;
	}
	return unread;
}

- (void)flushChannelViewMetricsExceptForIds:(NSSet *)keepIds {
	NSMutableArray *stoppedIds = [NSMutableArray array];
	for (NSNumber *messageId in self.channelViewMetricsStart.allKeys)
		if (!keepIds || ![keepIds containsObject:messageId])
			[stoppedIds addObject:messageId];
	for (NSNumber *messageId in stoppedIds)
		[self flushChannelViewMetricsForMessageId:messageId];
}

- (void)flushChannelViewMetricsForMessageId:(NSNumber *)messageId {
	NSArray *tracked = self.channelViewMetricsStart[messageId];
	if (!tracked)
		return;
	[self.channelViewMetricsStart removeObjectForKey:messageId];
	NSDate *start = tracked[0];
	int32_t heightToViewportRatio = [tracked[1] intValue];
	int32_t seenRatio = [tracked[2] intValue];
	NSTimeInterval elapsed = -[start timeIntervalSinceNow];
	int32_t ms = (int32_t)MIN(elapsed * 1000.0, (NSTimeInterval)INT32_MAX);
	if (ms < 200)
		return;
	[[TGClient shared] sendViewMetricsForMessage:messageId.longLongValue
										  inChat:self.chatId
									timeInViewMs:ms
							  activeTimeInViewMs:ms
							 heightRatioPerMille:heightToViewportRatio
							   seenRangePerMille:seenRatio];
}

@end
