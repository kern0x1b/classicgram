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

@implementation TGStoriesViewController

- (void)dealloc {
	[self tearDownPaging];
}

@synthesize chatId = _chatId;

- (instancetype)initWithChatId:(int64_t)chatId
					  storyIds:(NSArray *)storyIds
					startIndex:(NSInteger)startIndex {
	self = [super init];
	if (self != nil) {
		_chatId = chatId;
		_storyIds = [storyIds isKindOfClass:[NSArray class]] ? [storyIds copy] : [NSArray array];
		_index = startIndex;
		if (_index < 0 || _index >= (NSInteger)_storyIds.count)
			_index = 0;
		_stories = [[NSMutableDictionary alloc] init];
		_seen = [[NSMutableSet alloc] init];
	}
	return self;
}

+ (void)pushMyStoriesFrom:(UIViewController *)controller {
	if (controller.navigationController == nil)
		return;
	UIViewController *list = [self myStoriesController];
	if (!list)
		return;
	[controller.navigationController pushViewController:list animated:YES];
}

+ (UIViewController *)myStoriesController {
	NSDictionary *me = [[TGClient shared] me];
	if (me == nil)
		return nil;
	TGStoryListViewController *list = [[TGStoryListViewController alloc] init];
	list.mode = TGStoryListMenu;
	list.chatId = TGStoryChatId(me, @"id");
	list.title = TGL(@"Settings.MyStories", @"My Stories");
	return list;
}

+ (void)pushStoriesOfChat:(int64_t)chatId
					 name:(NSString *)name
					 from:(UIViewController *)controller {
	[TGStoryListViewController pushMode:TGStoryListProfile
								 chatId:chatId
								  title:name.length ? name : TGL(@"PeerInfo.PaneStories", @"Stories")
								   from:controller];
}

+ (void)openStoriesForChat:(int64_t)chatId
					  name:(NSString *)name
					  from:(UIViewController *)controller {
	if (controller.navigationController == nil)
		return;
	UINavigationController *navigation = controller.navigationController;
	[[TGClient shared] activeStoriesForChat:chatId completion:^(NSDictionary *active) {
		NSArray *stories = [active objectForKey:@"stories"];
		if (![stories isKindOfClass:[NSArray class]] || stories.count == 0) {
			[[[TGAlertView alloc] initWithTitle:nil
										message:TGL(@"Stories.StatusEmpty", @"No stories")
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  okButtonTitle:nil
								completionBlock:nil] show];
			return;
		}

		NSInteger maxRead = TGStoryNumber(active, @"maxReadStoryId");
		NSMutableArray *ids = [[NSMutableArray alloc] init];
		NSInteger start = 0;
		for (NSDictionary *story in stories) {
			if (![story isKindOfClass:[NSDictionary class]])
				continue;
			NSInteger storyId = TGStoryNumber(story, @"id");
			if (storyId <= maxRead)
				start = (NSInteger)ids.count + 1;
			[ids addObject:[NSNumber numberWithInteger:storyId]];
		}
		if (start >= (NSInteger)ids.count)
			start = 0;

		TGStoriesViewController *viewer = [TGStoriesViewController alloc];
		viewer = [viewer initWithChatId:chatId storyIds:ids startIndex:start];
		viewer.posterName = name;
		[navigation pushViewController:viewer animated:YES];
	}];
}

- (NSString *)resolvedPosterName {
	if (self.posterName.length > 0)
		return self.posterName;
	for (NSDictionary *chat in [[TGClient shared] chats]) {
		if (![chat isKindOfClass:[NSDictionary class]])
			continue;
		if (TGStoryChatId(chat, @"id") == _chatId)
			return TGStoryString(chat, @"title");
	}
	return TGL(@"Message.Story", @"Story");
}

- (BOOL)isOwnStory {
	NSDictionary *me = [[TGClient shared] me];
	if (me == nil)
		return NO;
	return TGStoryChatId(me, @"id") == _chatId;
}

- (NSDictionary *)currentStory {
	if (_index < 0 || _index >= (NSInteger)_storyIds.count)
		return nil;
	return [_stories objectForKey:[_storyIds objectAtIndex:(NSUInteger)_index]];
}

- (NSInteger)currentStoryId {
	if (_index < 0 || _index >= (NSInteger)_storyIds.count)
		return 0;
	return [[_storyIds objectAtIndex:(NSUInteger)_index] integerValue];
}

@end
