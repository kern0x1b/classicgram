#import "TGStoriesViewController.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "TGClient+Stories.h"
#import "TGClient+Files.h"
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

@implementation TGStoriesViewController (Paging)

#pragma mark - paging

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_navigationBarWasHidden = self.navigationController.navigationBarHidden;
	[self.navigationController setNavigationBarHidden:YES animated:animated];
	if (_openStoryId == 0) {
		NSInteger storyId = [self currentStoryId];
		if (storyId != 0) {
			_openStoryId = storyId;
			[[TGClient shared] openStory:storyId inChat:_chatId];
		}
	}
	_onScreen = YES;
	_elapsed = 0.0;
	[self retryFailedPages];
	[self updateTimeline];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	_onScreen = YES;
	[self updateTimeline];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.navigationController setNavigationBarHidden:_navigationBarWasHidden animated:animated];
	_onScreen = NO;
	[self updateTimeline];
	[TGReactionPickerView dismiss];
	[self closeCurrent];

	BOOL leaving = YES;
	if ([self respondsToSelector:@selector(isMovingFromParentViewController)])
		leaving = self.isMovingFromParentViewController || self.isBeingDismissed;
	if (leaving)
		[self cancelAllPhotoLoads];
}

- (void)tearDownPaging {
	[_timer invalidate];
	_timer = nil;
	for (TGStoryPage *page in _visiblePages) {
		NSNumber *fileId = page.photoFileId;
		if (fileId == nil)
			continue;
		page.photoFileId = nil;
		[[TGClient shared] cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:NO];
	}
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];

	[_pageQueue removeAllObjects];

	for (NSInteger i = (NSInteger)_visiblePages.count - 1; i >= 0; i--) {
		TGStoryPage *page = [_visiblePages objectAtIndex:(NSUInteger)i];
		if (page.pageIndex == _index)
			continue;
		[self cancelPhotoForPage:page];
		[page prepareForReuse];
		[page removeFromSuperview];
		[_visiblePages removeObjectAtIndex:(NSUInteger)i];
	}

	NSNumber *key = [self currentStoryKey];
	NSDictionary *keep = key != nil ? [_stories objectForKey:key] : nil;
	[_stories removeAllObjects];
	if (keep != nil)
		[_stories setObject:keep forKey:key];
}

- (void)closeCurrent {
	if (_openStoryId != 0) {
		[[TGClient shared] closeStory:_openStoryId inChat:_chatId];
		_openStoryId = 0;
	}
}

- (CGRect)frameForPageIndex:(NSInteger)index {
	CGRect bounds = _pagingView.bounds;
	return CGRectMake(index * bounds.size.width + kStoryPageGap / 2.0f, 0,
		bounds.size.width - kStoryPageGap, bounds.size.height);
}

- (TGStoryPage *)dequeuePage {
	if (_pageQueue.count != 0) {
		TGStoryPage *page = [_pageQueue objectAtIndex:0];
		[_pageQueue removeObjectAtIndex:0];
		return page;
	}
	return [[TGStoryPage alloc] initWithFrame:_pagingView.bounds];
}

- (void)recycleSparePage:(TGStoryPage *)page {
	[self cancelPhotoForPage:page];
	[page prepareForReuse];
	[page removeFromSuperview];
	if (_pageQueue.count < kStoryPageQueueLimit)
		[_pageQueue addObject:page];
}

- (TGStoryPage *)pageForIndex:(NSInteger)index {
	for (TGStoryPage *page in _visiblePages) {
		if (page.pageIndex == index)
			return page;
	}
	return nil;
}

- (void)resetPagingGeometry {
	CGFloat width = _pagingView.bounds.size.width;
	if (width < 1.0f)
		return;

	for (TGStoryPage *page in _visiblePages)
		page.frame = [self frameForPageIndex:page.pageIndex];

	_pagingView.contentSize = CGSizeMake(width * (CGFloat)_storyIds.count,
		_pagingView.bounds.size.height);
	_pagingView.contentOffset = CGPointMake(width * (CGFloat)_index, 0);
	[self layoutPages];
}

- (void)layoutPages {
	CGRect bounds = _pagingView.bounds;
	CGFloat width = bounds.size.width;
	if (width < 1.0f)
		return;

	CGFloat offset = _pagingView.contentOffset.x;
	CGFloat minX = offset - width;
	CGFloat maxX = offset + width * 2.0f;

	for (NSInteger i = (NSInteger)_visiblePages.count - 1; i >= 0; i--) {
		TGStoryPage *page = [_visiblePages objectAtIndex:(NSUInteger)i];
		CGRect frame = page.frame;
		if (CGRectGetMaxX(frame) <= minX || frame.origin.x > maxX) {
			[self recycleSparePage:page];
			[_visiblePages removeObjectAtIndex:(NSUInteger)i];
		}
	}

	NSInteger count = (NSInteger)_storyIds.count;
	if (count == 0)
		return;

	NSInteger start = (NSInteger)floorf(offset / width) - 1;
	NSInteger end = start + 2;
	if (start < 0)
		start = 0;
	if (end > count - 1)
		end = count - 1;

	for (NSInteger i = start; i <= end; i++) {
		if ([self pageForIndex:i] != nil)
			continue;

		TGStoryPage *page = [self dequeuePage];
		page.pageIndex = i;
		page.captionBottomInset = _footerView.frame.origin.y > 0.0f
			? (bounds.size.height - _footerView.frame.origin.y + kStoryFooterBottom)
			: 0.0f;
		page.frame = [self frameForPageIndex:i];
		page.itemId = [_storyIds objectAtIndex:(NSUInteger)i];
		[_visiblePages addObject:page];
		[_pagingView addSubview:page];
		[self loadPage:page];
	}

	NSInteger current = (NSInteger)((offset + width / 2.0f) / width);
	if (current > count - 1)
		current = count - 1;
	if (current < 0)
		current = 0;
	[self setCurrentIndex:current];
}

- (void)setCurrentIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)_storyIds.count)
		return;

	NSNumber *key = [_storyIds objectAtIndex:(NSUInteger)index];
	if (index == _index && _openStoryId != 0) {
		if (![_seen containsObject:key]) {
			[_seen addObject:key];
			[self updateStrip];
		}
		return;
	}

	[self closeCurrent];
	_index = index;

	[_seen addObject:key];
	_openStoryId = [key integerValue];
	[[TGClient shared] openStory:_openStoryId inChat:_chatId];

	[self resetTimeline];
	[self updateChrome];
}

- (void)loadPage:(TGStoryPage *)page {
	NSNumber *key = page.itemId;
	if (key == nil)
		return;

	NSDictionary *known = [_stories objectForKey:key];
	if (known != nil) {
		[page setCaption:TGStoryString(known, @"caption")];
		[page setAreas:[known objectForKey:@"areas"]];
		[self loadPhotoForPage:page story:known];
		[self loadVideoForPage:page story:known];
		return;
	}

	int64_t chatId = _chatId;
	__weak TGStoriesViewController *weakSelf = self;
	__weak TGStoryPage *weakPage = page;
	[[TGClient shared] storyWithId:[key integerValue]
							inChat:chatId
						completion:^(NSDictionary *story) {
							TGStoriesViewController *strongSelf = weakSelf;
							TGStoryPage *strongPage = weakPage;
							if (strongSelf == nil || strongSelf->_chatId != chatId)
								return;
							if (![story isKindOfClass:[NSDictionary class]]) {
								if (strongPage != nil && [strongPage.itemId isEqual:key])
									[strongPage showFailure];
								return;
							}
							[strongSelf->_stories setObject:story forKey:key];
							if ([key isEqual:[strongSelf currentStoryKey]])
								[strongSelf updateChrome];
							if (strongPage == nil || ![strongPage.itemId isEqual:key])
								return;
							[strongPage setCaption:TGStoryString(story, @"caption")];
							[strongPage setAreas:[story objectForKey:@"areas"]];
							[strongSelf loadPhotoForPage:strongPage story:story];
							[strongSelf loadVideoForPage:strongPage story:story];
						}];
}

- (NSNumber *)currentStoryKey {
	if (_index < 0 || _index >= (NSInteger)_storyIds.count)
		return nil;
	return [_storyIds objectAtIndex:(NSUInteger)_index];
}

- (UIImage *)currentImage {
	return [self pageForIndex:_index].image;
}

- (void)cancelPhotoForPage:(TGStoryPage *)page {
	NSNumber *fileId = page.photoFileId;
	if (fileId == nil)
		return;
	page.photoFileId = nil;
	[[TGClient shared] cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:NO];
}

- (void)cancelAllPhotoLoads {
	for (TGStoryPage *page in _visiblePages)
		[self cancelPhotoForPage:page];
}

- (void)loadPhotoForPage:(TGStoryPage *)page story:(NSDictionary *)story {
	NSNumber *photoId = [story objectForKey:@"photoId"];
	if (![photoId isKindOfClass:[NSNumber class]]) {
		[self cancelPhotoForPage:page];
		[page setStoryImage:nil animated:NO];
		return;
	}

	if (page.photoFileId != nil && [page.photoFileId isEqualToNumber:photoId] &&
		page.image != nil) {
		return;
	}

	[self cancelPhotoForPage:page];
	page.photoFileId = photoId;
	[page beginLoading];

	NSNumber *key = page.itemId;
	__weak TGStoryPage *weakPage = page;
	__weak TGStoriesViewController *weakSelf = self;
	[[TGClient shared] downloadFile:[photoId longLongValue]
							 offset:0
							  limit:0
						 completion:^(NSDictionary *file) {
							 TGStoryPage *page1 = weakPage;
							 if (page1 == nil || ![page1.itemId isEqual:key] ||
								 ![page1.photoFileId isEqualToNumber:photoId]) {
								 return;
							 }
							 NSString *path = TGStoryString(file, @"path");
							 if (path.length == 0) {
								 page1.photoFileId = nil;
								 [page1 showFailure];
								 return;
							 }
							 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
								 @autoreleasepool {
									 TGStoryPage *page2 = weakPage;
									 if (page2 == nil || ![page2.itemId isEqual:key] ||
										 ![page2.photoFileId isEqualToNumber:photoId]) {
										 return;
									 }
									 UIImage *image = TGDecodeThumbnail(path, kStoryPhotoPixels);
									 dispatch_async(dispatch_get_main_queue(), ^{
										 TGStoryPage *inner = weakPage;
										 if (inner == nil || ![inner.itemId isEqual:key] ||
											 ![inner.photoFileId isEqualToNumber:photoId]) {
											 return;
										 }
										 if (image == nil) {
											 inner.photoFileId = nil;
											 [inner showFailure];
											 return;
										 }
										 [inner setStoryImage:image animated:YES];
										 [weakSelf updateTimeline];
									 });
								 }
							 });
						 }];
}

- (void)loadVideoForPage:(TGStoryPage *)page story:(NSDictionary *)story {
	if (![TGStoryString(story, @"kind") isEqualToString:@"video"]) {
		[page stopVideo];
		page.videoFileId = nil;
		return;
	}

	NSNumber *videoId = [story objectForKey:@"videoId"];
	if (![videoId isKindOfClass:[NSNumber class]])
		return;

	if (page.videoFileId != nil && [page.videoFileId isEqualToNumber:videoId])
		return;

	page.videoFileId = videoId;
	NSNumber *key = page.itemId;
	__weak TGStoryPage *weakPage = page;
	[[TGClient shared] downloadFile:[videoId longLongValue]
							 offset:0
							  limit:0
						 completion:^(NSDictionary *file) {
							 TGStoryPage *strongPage = weakPage;
							 if (strongPage == nil || ![strongPage.itemId isEqual:key] ||
								 ![strongPage.videoFileId isEqualToNumber:videoId]) {
								 return;
							 }
							 NSString *path = TGStoryString(file, @"path");
							 if (path.length == 0)
								 return;
							 [strongPage playVideoAtPath:path];
						 }];
}

- (void)retryFailedPages {
	for (TGStoryPage *page in _visiblePages) {
		if (page.image != nil || page.photoFileId != nil)
			continue;
		[self loadPage:page];
	}
}

- (void)showIndex:(NSInteger)index animated:(BOOL)animated {
	if (index < 0 || index >= (NSInteger)_storyIds.count)
		return;

	CGFloat width = _pagingView.bounds.size.width;
	if (width < 1.0f) {
		_index = index;
		return;
	}

	[_pagingView setContentOffset:CGPointMake(width * (CGFloat)index, 0) animated:animated];
	if (!animated)
		[self layoutPages];
}

@end
