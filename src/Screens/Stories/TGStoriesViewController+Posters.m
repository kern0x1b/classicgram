#import "TGStoriesViewController.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "TGClient+Stories.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGDateUtils.h"
#import "TGImageDecode.h"
#import "TGReactionPickerView.h"
#import "RootViewController.h"
#import "TGStoryAreaEditorViewController.h"
#import "TGStoryHelpers.h"
#import "TGStoryTextViewController.h"

#import "TGStoryContactPicker.h"
#import "TGStoryViewersViewController.h"
#import "TGStoryListViewController.h"

#import "TGStoryPage.h"
#import "TGStoryPostOptions.h"
#import "TGStoryComposer.h"
#import "TGStoryStatisticsViewController.h"
#import "TGStoriesViewControllerInternal.h"

@implementation TGStoriesViewController (Posters)

#pragma mark - posters

- (NSDictionary *)posterEntryForCurrentChat {
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithLongLong:_chatId], @"chatId",
		[self resolvedPosterName], @"title",
		_storyIds, @"ids", nil];
}

- (void)discoverPosters {
	if (_postersRequested)
		return;
	_postersRequested = YES;

	_posterList = [[NSMutableArray alloc] init];
	[_posterList addObject:[self posterEntryForCurrentChat]];
	_posterIndex = 0;

	NSArray *chats = [[TGClient shared] chats];
	if (![chats isKindOfClass:[NSArray class]] || chats.count == 0)
		return;
	if (chats.count > 25)
		chats = [chats subarrayWithRange:NSMakeRange(0, 25)];

	NSMutableArray *found = [[NSMutableArray alloc] init];
	__block NSInteger pending = 0;
	__weak TGStoriesViewController *weakSelf = self;

	for (NSDictionary *chat in chats) {
		if (![chat isKindOfClass:[NSDictionary class]])
			continue;
		int64_t chatId = TGStoryChatId(chat, @"id");
		if (chatId == 0 || chatId == _chatId)
			continue;

		NSString *title = TGStoryString(chat, @"title");
		pending++;
		[[TGClient shared] activeStoriesForChat:chatId completion:^(NSDictionary *active) {
			TGStoriesViewController *strongSelf = weakSelf;
			pending--;
			if (strongSelf == nil)
				return;

			NSDictionary *entry = TGStoryPosterEntry(chatId, title, active);
			if (entry != nil)
				[found addObject:entry];

			if (pending > 0)
				return;

			[strongSelf appendDiscoveredPosters:found];
		}];
	}
}

- (void)appendDiscoveredPosters:(NSMutableArray *)found {
	[found sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		long long left = [[a objectForKey:@"order"] longLongValue];
		long long right = [[b objectForKey:@"order"] longLongValue];
		if (left == right)
			return NSOrderedSame;
		return left > right ? NSOrderedAscending : NSOrderedDescending;
	}];
	[_posterList addObjectsFromArray:found];
}

- (void)movePosterBy:(NSInteger)delta {
	NSInteger target = _posterIndex + delta;
	if (_posterList == nil || target < 0 || target >= (NSInteger)_posterList.count) {
		if (delta > 0)
			[self dismissViewer];
		return;
	}

	NSDictionary *poster = [_posterList objectAtIndex:(NSUInteger)target];
	NSArray *ids = [poster objectForKey:@"ids"];
	if (![ids isKindOfClass:[NSArray class]] || ids.count == 0)
		return;

	[self closeCurrent];

	_posterIndex = target;
	_chatId = TGStoryChatId(poster, @"chatId");
	self.posterName = TGStoryString(poster, @"title");
	_storyIds = [ids copy];
	[_stories removeAllObjects];
	[_seen removeAllObjects];
	_index = (delta > 0) ? 0 : (NSInteger)_storyIds.count - 1;

	for (TGStoryPage *page in _visiblePages)
		[self recycleSparePage:page];
	[_visiblePages removeAllObjects];

	_elapsed = 0.0;
	[self layoutStrip];
	[self updateChrome];
	[self updateTimeline];

	UIScrollView *paging = _pagingView;
	[UIView transitionWithView:paging
					  duration:0.2
					   options:UIViewAnimationOptionTransitionCrossDissolve
					animations:^{ [self resetPagingGeometry]; }
					completion:nil];
}

@end
