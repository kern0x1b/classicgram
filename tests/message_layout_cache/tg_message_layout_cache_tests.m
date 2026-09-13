#import "tg_message_layout_cache_tests.h"
#import "TGMessageItem.h"
#import "TGMessageItemBuilder.h"
#import "TGMessageItemResolvedInputs.h"
#import "TGChatLayoutContext.h"
#import "TGMessageLayoutCache.h"
#import "TGMessageLayout.h"
#import <UIKit/UIKit.h>

static TGChatLayoutContext *TGCacheTestContext(NSInteger generation) {
	return [[TGChatLayoutContext alloc] initWithTableWidth:320
											  baseFontSize:16
											   screenScale:1
												   isGroup:NO
											  isWideLayout:NO
											   isSelecting:NO
												generation:generation];
}

static TGMessageItem *TGCacheTestItem(int64_t messageId) {
	NSDictionary *flat = @{
		@"id"       : @(messageId),
		@"kind"     : @"messageText",
		@"outgoing" : @NO,
		@"date"     : @1700000000,
	};
	TGMessageItemResolvedInputs *resolved = [[TGMessageItemResolvedInputs alloc] init];
	resolved.bodyText = @"A line of text in a bubble.";
	resolved.stampText = @"19:38";
	return [TGMessageItemBuilder itemFromFlatMessage:flat
											  chatId:7
									 reuseIdentifier:@"TGBubbleCell.Text"
										albumMembers:nil
											resolved:resolved];
}

TGTestOutcome TGMessageLayoutCacheTestASecondLookIsTheSameLayout(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageLayoutCache *cache = [[TGMessageLayoutCache alloc] initWithCapacity:8];
	TGChatLayoutContext *context = TGCacheTestContext(1);
	TGMessageItem *item = TGCacheTestItem(1);

	TGMessageLayout *first = [cache layoutForItem:item context:context];
	TGMessageLayout *second = [cache layoutForItem:item context:context];
	TGTestExpectTrue(&outcome, first == second,
			"a row measured twice in a row must not be measured twice");

	TGMessageLayout *afterChange = [cache layoutForItem:item context:TGCacheTestContext(2)];
	TGTestExpectTrue(&outcome, afterChange != first,
			"a context that changed under the row must throw its measurement away");

	[cache invalidateMessageId:1];
	TGMessageLayout *afterInvalidate = [cache layoutForItem:item context:TGCacheTestContext(2)];
	TGTestExpectTrue(&outcome, afterInvalidate != afterChange,
			"an invalidated row is measured again");

	return outcome;
}

TGTestOutcome TGMessageLayoutCacheTestAFullCacheKeepsWhatWasReadLast(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGMessageLayoutCache *cache = [[TGMessageLayoutCache alloc] initWithCapacity:8];
	TGChatLayoutContext *context = TGCacheTestContext(1);

	NSMutableArray *items = [NSMutableArray array];
	for (int64_t messageId = 1; messageId <= 20; messageId++)
		[items addObject:TGCacheTestItem(messageId)];

	TGMessageItem *first = items[0];
	TGMessageLayout *firstLayout = [cache layoutForItem:first context:context];

	for (NSUInteger index = 1; index < 8; index++)
		[cache layoutForItem:items[index] context:context];

	TGTestExpectTrue(&outcome, [cache layoutForItem:first context:context] == firstLayout,
			"a cache at its capacity has thrown nothing away yet");

	for (NSUInteger index = 8; index < items.count; index++)
		[cache layoutForItem:items[index] context:context];

	TGMessageLayout *lastLayout = [cache layoutForItem:items.lastObject context:context];
	TGTestExpectTrue(&outcome,
			[cache layoutForItem:items.lastObject context:context] == lastLayout,
			"the row read last is still measured after the cache filled up");
	TGTestExpectTrue(&outcome, [cache layoutForItem:first context:context] != firstLayout,
			"the row nobody has looked at for a long time is the one that goes");

	return outcome;
}
