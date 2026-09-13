#import "TGMediaFullscreenControllerInternal.h"
#import "TGMediaViewControllerInternal.h"
#import "TGMediaPageView.h"
#import "TGClient+Files.h"
#import "TGFlattenFiles.h"
#import "TGImageDecode.h"

@implementation TGMediaFullscreenController (Paging)

#pragma mark - paging

- (CGFloat)pageWidth {
	return self.view.bounds.size.width + kMediaPageGap;
}

- (void)layoutPagesPreservingIndex:(NSInteger)index {
	CGRect bounds = self.view.bounds;
	if (bounds.size.width < 1 || _dismissing)
		return;

	BOOL sizeChanged = !CGSizeEqualToSize(bounds.size, _validSize);
	_validSize = bounds.size;

	_pagingView.frame = CGRectMake(-kMediaPageGap / 2.0f, 0,
		bounds.size.width + kMediaPageGap, bounds.size.height);
	_pagingView.contentSize = CGSizeMake([self pageWidth] * _items.count, bounds.size.height);

	if (sizeChanged) {
		for (NSNumber *key in _visiblePages.allKeys) {
			TGMediaPageView *page = _visiblePages[key];
			page.frame = [self frameForPageAtIndex:[key integerValue]];
			[page layoutImage];
		}

		CGFloat wanted = index * [self pageWidth];
		if (!_pagingView.isDragging && !_pagingView.isDecelerating &&
			fabs(_pagingView.contentOffset.x - wanted) > 0.5f)
			_pagingView.contentOffset = CGPointMake(wanted, 0);
	}

	[self updateVisiblePages];
}

- (CGRect)frameForPageAtIndex:(NSInteger)index {
	CGRect bounds = self.view.bounds;
	return CGRectMake(index * [self pageWidth] + kMediaPageGap / 2.0f, 0,
		bounds.size.width, bounds.size.height);
}

- (TGMediaPageView *)takePage {
	TGMediaPageView *page = [_pagePool lastObject];
	if (page) {
		[_pagePool removeLastObject];
		return page;
	}
	page = [[TGMediaPageView alloc] initWithFrame:self.view.bounds];
	if (_dismissPan)
		[page.panGestureRecognizer requireGestureRecognizerToFail:_dismissPan];
	return page;
}

- (void)recyclePage:(TGMediaPageView *)page forKey:(NSNumber *)key {
	[page setPageImage:nil];
	page.loadingFileId = nil;
	page.pageIndex = -1;
	[page removeFromSuperview];
	[_visiblePages removeObjectForKey:key];
	if (_pagePool.count < 3)
		[_pagePool addObject:page];
}

- (void)trimImageCache {
	for (NSNumber *key in _imageCache.allKeys) {
		if (labs((long)([key integerValue] - _currentIndex)) > 3)
			[_imageCache removeObjectForKey:key];
	}
}

- (void)updateVisiblePages {
	if (_items.count == 0)
		return;

	NSInteger first = _currentIndex - 1;
	NSInteger last = _currentIndex + 1;
	if (first < 0)
		first = 0;
	if (last > (NSInteger)_items.count - 1)
		last = (NSInteger)_items.count - 1;

	for (NSNumber *key in _visiblePages.allKeys) {
		NSInteger index = [key integerValue];
		if (index < first || index > last) {
			[self recyclePage:_visiblePages[key] forKey:key];
			[_failedPages removeObject:key];
		}
	}

	[self trimImageCache];
	[self cancelDownloadsOutsideWindow];

	for (NSInteger index = first; index <= last; index++) {
		NSNumber *key = @(index);
		TGMediaPageView *page = _visiblePages[key];
		if (page) {
			if (index != _currentIndex && [page isZoomed])
				[page resetZoom];
			continue;
		}

		page = [self takePage];
		page.pageIndex = index;
		page.frame = [self frameForPageAtIndex:index];
		[_pagingView addSubview:page];
		_visiblePages[key] = page;

		UIImage *cached = _imageCache[key];
		if (cached) {
			[page setPageImage:cached];
			[self prefetchNeighboursOfIndex:index];
		} else {
			[page resetZoom];
			[self loadImageForPageAtIndex:index];
		}
	}
}

- (void)showMinithumbOnPage:(TGMediaPageView *)page forItem:(NSDictionary *)item {
	if (page.imageView.image)
		return;
	NSData *tiny = [[TGClient shared] minithumbnailData:item[@"minithumb"]];
	if (tiny.length == 0)
		return;
	UIImage *blurred = [UIImage imageWithData:tiny];
	if (!blurred)
		return;
	[page setPageImage:blurred];
	page.showingMinithumb = YES;
}

- (NSNumber *)downloadFileIdForItem:(NSDictionary *)item {
	if ([item[@"isVideo"] boolValue])
		return item[@"thumbId"];

	NSArray *sizes = item[@"sizes"];
	if ([sizes isKindOfClass:NSArray.class] && sizes.count > 0) {
		NSDictionary *chosen = TGBestPhotoSizeInSizesForWidthScale(sizes,
			self.view.bounds.size.width, [UIScreen mainScreen].scale);
		if ([chosen[@"fileId"] isKindOfClass:NSNumber.class])
			return chosen[@"fileId"];
	}
	return item[@"fullId"];
}

- (void)loadImageForPageAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)_items.count)
		return;

	NSDictionary *item = _items[index];
	NSNumber *fileId = [self downloadFileIdForItem:item];
	if (![fileId isKindOfClass:NSNumber.class])
		fileId = item[@"thumbId"];
	if (![fileId isKindOfClass:NSNumber.class])
		return;

	NSNumber *key = @(index);
	TGMediaPageView *page = _visiblePages[key];
	if (!page)
		return;
	if ([page.loadingFileId isEqual:fileId])
		return;
	page.loadingFileId = fileId;
	[_failedPages removeObject:key];
	[self updateLoadingChrome];

	[self showMinithumbOnPage:page forItem:item];

	NSNumber *thumbId = item[@"thumbId"];
	if ([thumbId isKindOfClass:NSNumber.class] && ![thumbId isEqual:fileId] &&
		(!page.imageView.image || page.showingMinithumb))
		[self loadThumbnailForPageAtIndex:index fileId:thumbId];

	CGFloat maxSidePixels = [self fullImageMaxSidePixels];

	[_prefetchedFiles addObject:fileId];
	[[TGClient shared] startDownloadingFile:[fileId longLongValue]
								   priority:(index == _currentIndex ? 32 : 8)
								 completion:nil];

	void (^handlePath)(NSString *) = [self pathHandlerForPageKey:key fileId:fileId maxSidePixels:maxSidePixels];

	NSArray *sizes = item[@"sizes"];
	if ([sizes isKindOfClass:NSArray.class] && sizes.count > 0 &&
		![item[@"isVideo"] boolValue]) {
		CGFloat wanted = self.view.bounds.size.width;
		[[TGClient shared] downloadPhotoSizes:sizes
									 forWidth:wanted
										scale:[UIScreen mainScreen].scale
								   completion:^(NSString *path, NSDictionary *size) {
									   handlePath(path);
								   }];
	} else {
		[[TGClient shared] downloadFile:[fileId longLongValue] completion:handlePath];
	}

	[self prefetchNeighboursOfIndex:index];
}

- (CGFloat)fullImageMaxSidePixels {
	CGFloat maxSidePixels = MAX(self.view.bounds.size.width, self.view.bounds.size.height) * [UIScreen mainScreen].scale;
	if (maxSidePixels > 960.0f)
		maxSidePixels = 960.0f;
	return maxSidePixels;
}

- (void (^)(NSString *))pathHandlerForPageKey:(NSNumber *)key
									   fileId:(NSNumber *)fileId
								maxSidePixels:(CGFloat)maxSidePixels {
	__weak typeof(self) weakSelf = self;
	return ^(NSString *path) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (path.length == 0) {
			TGMediaPageView *failedPage = strongSelf.visiblePages[key];
			if (failedPage && [failedPage.loadingFileId isEqual:fileId]) {
				failedPage.loadingFileId = nil;
				[strongSelf.failedPages addObject:key];
				[strongSelf updateLoadingChrome];
			}
			return;
		}
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *image = TGDecodeThumbnail(path, maxSidePixels);
			dispatch_async(dispatch_get_main_queue(), ^{
				typeof(self) innerSelf = weakSelf;
				if (!innerSelf)
					return;
				TGMediaPageView *target = innerSelf.visiblePages[key];
				if (!target || ![target.loadingFileId isEqual:fileId])
					return;
				if (!image) {
					target.loadingFileId = nil;
					[innerSelf.failedPages addObject:key];
					[innerSelf updateLoadingChrome];
					return;
				}
				innerSelf.imageCache[key] = image;
				[target setPageImage:image crossfade:(target.imageView.image != nil)];
				[innerSelf updateLoadingChrome];
			});
		});
	};
}

- (void)loadThumbnailForPageAtIndex:(NSInteger)index fileId:(NSNumber *)thumbId {
	NSNumber *key = @(index);
	CGFloat sidePixels = kMediaTileSide * 4.0f;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:[thumbId longLongValue] completion:^(NSString *path) {
		if (path.length == 0)
			return;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *image = TGDecodeThumbnail(path, sidePixels);
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				typeof(self) strongSelf = weakSelf;
				if (!strongSelf)
					return;
				TGMediaPageView *target = strongSelf.visiblePages[key];
				if (!target || strongSelf.imageCache[key])
					return;
				if (index >= (NSInteger)strongSelf.items.count ||
					![strongSelf.items[index][@"thumbId"] isEqual:thumbId])
					return;
				if (target.imageView.image && !target.showingMinithumb)
					return;
				[target setPageImage:image crossfade:target.showingMinithumb];
			});
		});
	}];
}

- (void)cancelDownloadsOutsideWindow {
	if (_prefetchedFiles.count == 0 || _spinner.isAnimating)
		return;

	NSMutableSet *wanted = [NSMutableSet set];
	for (NSInteger index = _currentIndex - 1; index <= _currentIndex + 1; index++) {
		if (index < 0 || index >= (NSInteger)_items.count)
			continue;
		NSDictionary *item = _items[index];
		NSNumber *fullId = [self downloadFileIdForItem:item];
		NSNumber *thumbId = item[@"thumbId"];
		if ([fullId isKindOfClass:NSNumber.class])
			[wanted addObject:fullId];
		if ([thumbId isKindOfClass:NSNumber.class])
			[wanted addObject:thumbId];
	}

	for (NSNumber *fileId in [_prefetchedFiles copy]) {
		if ([wanted containsObject:fileId])
			continue;
		[[TGClient shared] cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:NO];
		[_prefetchedFiles removeObject:fileId];
	}
}

- (void)prefetchNeighboursOfIndex:(NSInteger)index {
	NSInteger neighbours[2] = {index - 1, index + 1};
	for (NSInteger i = 0; i < 2; i++) {
		NSInteger at = neighbours[i];
		if (at < 0 || at >= (NSInteger)_items.count)
			continue;

		NSDictionary *item = _items[at];
		if ([item[@"isVideo"] boolValue])
			continue;

		NSNumber *fileId = item[@"fullId"];
		if (![fileId isKindOfClass:NSNumber.class] || [fileId longLongValue] <= 0)
			continue;
		if ([_prefetchedFiles containsObject:fileId])
			continue;

		[_prefetchedFiles addObject:fileId];
		[[TGClient shared] startDownloadingFile:[fileId longLongValue]
									   priority:1
									 completion:nil];
	}
}

- (void)updateLoadingChrome {
	if (_busyPageIndex == _currentIndex)
		return;

	NSNumber *key = @(_currentIndex);
	TGMediaPageView *page = _visiblePages[key];

	BOOL failed = page && !_imageCache[key] && [_failedPages containsObject:key];
	BOOL loading = page && !_imageCache[key] && page.loadingFileId && !failed;

	if (loading || failed) {
		_progressLabel.text = @"";
		[_progressLabel sizeToFit];

		CGFloat panelWidth = _bottomBar.frame.size.width;
		CGFloat labelWidth = _progressLabel.frame.size.width;
		CGFloat labelHeight = _progressLabel.frame.size.height;
		CGFloat labelLeft = (CGFloat)floorf((panelWidth - labelWidth) / 2.0f) + (failed ? 0.0f : 10.0f);
		CGFloat labelTop = _authorLabel.text.length > 0 ? 23.0f : 14.0f;
		CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;

		_progressLabel.frame = CGRectMake(labelLeft, labelTop, labelWidth, labelHeight);
		_progressSpinner.center = CGPointMake(labelLeft - 19.0f + 7.5f,
			labelTop + 1.0f + retinaPixel + 7.5f);
		if (loading)
			[_progressSpinner startAnimating];
		else
			[_progressSpinner stopAnimating];
	} else {
		[_progressSpinner stopAnimating];
	}

	BOOL busy = loading || failed;
	[UIView animateWithDuration:0.2 animations:^{
		self.progressContainer.alpha = busy ? 1.0f : 0.0f;
		self.controlsContainer.alpha = busy ? 0.0f : 1.0f;
	}];

	[self updateProgressRingLoading:loading page:page];
}

- (void)updateProgressRingLoading:(BOOL)loading page:(TGMediaPageView *)page {
	if (!loading) {
		_ringFileId = nil;
		if (!_progressRing.hidden) {
			[UIView animateWithDuration:0.2 animations:^{
				self.progressRing.alpha = 0.0f;
			} completion:^(BOOL finished) {
				self.progressRing.hidden = YES;
				self.progressRing.progress = 0.0f;
			}];
		}
		return;
	}

	_ringFileId = page.loadingFileId;

	NSDictionary *item = [self currentItem];
	NSArray *sizes = item[@"sizes"];
	if ([sizes isKindOfClass:NSArray.class] && sizes.count > 0 &&
		![item[@"isVideo"] boolValue]) {
		NSDictionary *chosen = TGBestPhotoSizeInSizesForWidthScale(sizes,
			self.view.bounds.size.width, [UIScreen mainScreen].scale);
		if ([chosen[@"fileId"] isKindOfClass:NSNumber.class])
			_ringFileId = chosen[@"fileId"];
	}

	if (_progressRing.hidden) {
		_progressRing.progress = 0.0f;
		_progressRing.alpha = 0.0f;
		_progressRing.hidden = NO;
		[UIView animateWithDuration:0.2 animations:^{
			self.progressRing.alpha = 1.0f;
		}];
	}
}

- (void)retryTapped {
	NSNumber *key = @(_currentIndex);
	[_failedPages removeObject:key];
	TGMediaPageView *page = _visiblePages[key];
	page.loadingFileId = nil;
	[self loadImageForPageAtIndex:_currentIndex];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != _pagingView || _dismissing)
		return;

	CGFloat width = [self pageWidth];
	if (width < 1)
		return;

	NSInteger index = (NSInteger)((scrollView.contentOffset.x + width / 2.0f) / width);
	if (index < 0)
		index = 0;
	if (index > (NSInteger)_items.count - 1)
		index = (NSInteger)_items.count - 1;

	if (index != _currentIndex) {
		_currentIndex = index;
		[self updateVisiblePages];
		[self updateChromeForCurrentItem];
	}
}

@end
