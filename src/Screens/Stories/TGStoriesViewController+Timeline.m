#import "TGStoriesViewController.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

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

@implementation TGStoriesViewController (Timeline)

#pragma mark - timeline

- (BOOL)timelineShouldRun {
	if (!_onScreen || _dismissing || _holdPaused || _modalPaused)
		return NO;
	if ([_pagingView isDragging] || [_pagingView isDecelerating])
		return NO;
	TGStoryPage *page = [self pageForIndex:_index];
	return page.image != nil || page.failed;
}

- (void)updateTimeline {
	BOOL run = [self timelineShouldRun];
	if (run && _timer == nil) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:kStoryTick
												  target:self
												selector:@selector(timelineTick)
												userInfo:nil
												 repeats:YES];
	} else if (!run && _timer != nil) {
		[_timer invalidate];
		_timer = nil;
	}
}

- (void)resetTimeline {
	_elapsed = 0.0;
	[self updateStrip];
	[self updateTimeline];
}

- (NSTimeInterval)currentStoryDuration {
	NSDictionary *story = [self currentStory];
	if ([TGStoryString(story, @"kind") isEqualToString:@"video"]) {
		NSTimeInterval videoDuration = [[story objectForKey:@"duration"] doubleValue];
		if (videoDuration > 0.0)
			return videoDuration;
	}
	return kStoryDuration;
}

- (void)updateVideoPlaybackForPauseState {
	TGStoryPage *page = [self pageForIndex:_index];
	if (_holdPaused || _modalPaused)
		[page pauseVideo];
	else
		[page resumeVideo];
}

- (void)setHoldPaused:(BOOL)paused {
	if (_holdPaused == paused)
		return;
	_holdPaused = paused;
	[self updateTimeline];
	[self updateVideoPlaybackForPauseState];
}

- (void)setModalPaused:(BOOL)paused {
	if (_modalPaused == paused)
		return;
	_modalPaused = paused;
	[self updateTimeline];
	[self updateVideoPlaybackForPauseState];
}

- (void)timelineTick {
	if (![self timelineShouldRun]) {
		[self updateTimeline];
		return;
	}

	_elapsed += kStoryTick;
	if (_elapsed < [self currentStoryDuration]) {
		[self updateStrip];
		return;
	}

	_elapsed = 0.0;
	if (_index + 1 < (NSInteger)_storyIds.count)
		[self showIndex:_index + 1 animated:YES];
	else
		[self movePosterBy:1];
}

@end
