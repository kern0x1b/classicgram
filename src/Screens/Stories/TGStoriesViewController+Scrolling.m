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

@implementation TGStoriesViewController (Scrolling)

#pragma mark - scrolling

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	(void)scrollView;
	[self layoutPages];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	(void)scrollView;
	[self updateTimeline];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	(void)scrollView;
	[self updateTimeline];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
	(void)scrollView;
	[self updateTimeline];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	(void)decelerate;
	[self updateTimeline];
	CGFloat width = scrollView.bounds.size.width;
	CGFloat maxOffset = MAX(0.0f, scrollView.contentSize.width - width);
	CGFloat offset = scrollView.contentOffset.x;

	if (offset > maxOffset + kStoryOverscroll)
		[self movePosterBy:1];
	else if (offset < -kStoryOverscroll)
		[self movePosterBy:-1];
}

@end
