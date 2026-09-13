#import "TGMediaFullscreenControllerInternal.h"
#import "TGMediaPageView.h"

#import <QuartzCore/QuartzCore.h>

@implementation TGMediaFullscreenController (Gestures)

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateRecognized)
		return;
	if ([_failedPages containsObject:@(_currentIndex)]) {
		[self retryTapped];
		return;
	}
	[self setChromeHidden:!_chromeHidden animated:YES];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateRecognized)
		return;

	TGMediaPageView *page = _visiblePages[@(_currentIndex)];
	if (!page || ![page canZoom])
		return;

	if ([page isZoomed]) {
		[page setZoomScale:page.minimumZoomScale animated:YES];
		return;
	}

	CGPoint point = [recognizer locationInView:page.imageView];
	CGFloat scale = page.maximumZoomScale;
	CGSize size = page.bounds.size;
	CGFloat width = size.width / scale;
	CGFloat height = size.height / scale;
	CGRect target = CGRectMake(point.x - width / 2.0f, point.y - height / 2.0f, width, height);
	[page zoomToRect:target animated:YES];
}

#pragma mark - drag to dismiss

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
	if (![recognizer isKindOfClass:[UIPanGestureRecognizer class]])
		return YES;

	TGMediaPageView *page = _visiblePages[@(_currentIndex)];
	if (page && [page isZoomed])
		return NO;
	if (_pagingView.isDragging || _pagingView.isDecelerating)
		return NO;

	CGPoint translation = [(UIPanGestureRecognizer *)recognizer translationInView:self.view];
	if (fabs(translation.y) < 1.0f)
		return NO;
	return fabs(translation.y) > fabs(translation.x);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
	shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
	return NO;
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
	CGPoint translation = [recognizer translationInView:self.view];

	if (recognizer.state == UIGestureRecognizerStateBegan) {
		_dismissing = YES;
		[self setChromeHidden:YES animated:YES];
		return;
	}

	if (recognizer.state == UIGestureRecognizerStateChanged) {
		CGFloat fade = MIN(1.0f, fabs(translation.y) / 80.0f);
		CGFloat shrink = 1.0f - MIN(0.2f, fabs(translation.y) / 1000.0f);
		_pagingView.transform = CGAffineTransformScale(
			CGAffineTransformMakeTranslation(0, translation.y), shrink, shrink);
		self.view.backgroundColor = [UIColor colorWithWhite:0.0f alpha:1.0f - fade];
		_progressRing.alpha = _progressRing.hidden ? 0.0f : 1.0f - fade;
		return;
	}

	if (recognizer.state == UIGestureRecognizerStateEnded ||
		recognizer.state == UIGestureRecognizerStateCancelled) {
		CGPoint velocity = [recognizer velocityInView:self.view];
		BOOL shouldClose = fabs(translation.y) > 100.0f || fabs(velocity.y) > 700.0f;

		if (shouldClose) {
			CGFloat target = translation.y < 0 ? -self.view.bounds.size.height
											   : self.view.bounds.size.height;
			[UIView animateWithDuration:0.2 animations:^{
				self.pagingView.transform = CGAffineTransformMakeTranslation(0, target);
				self.view.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.0f];
				self.progressRing.alpha = 0.0f;
			} completion:^(BOOL finished) {
				[self dismissViewControllerAnimated:NO completion:nil];
			}];
			return;
		}

		[UIView animateWithDuration:0.25 animations:^{
			self.pagingView.transform = CGAffineTransformIdentity;
			self.view.backgroundColor = [UIColor blackColor];
			self.progressRing.alpha = self.progressRing.hidden ? 0.0f : 1.0f;
		} completion:^(BOOL finished) {
			self.dismissing = NO;
			[self setChromeHidden:NO animated:YES];
		}];
	}
}

@end
