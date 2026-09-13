#import "TGMediaPageView.h"

@implementation TGMediaPageView

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.showsHorizontalScrollIndicator = NO;
		self.showsVerticalScrollIndicator = NO;
		self.scrollsToTop = NO;
		self.bouncesZoom = YES;
		self.bounces = YES;
		self.alwaysBounceHorizontal = NO;
		self.alwaysBounceVertical = NO;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.minimumZoomScale = 1.0f;
		self.maximumZoomScale = 1.0f;
		self.delegate = self;
		self.pageIndex = -1;
		_imageSize = CGSizeZero;

		_imageView = [[UIImageView alloc] initWithFrame:self.bounds];
		_imageView.contentMode = UIViewContentModeScaleToFill;
		[self addSubview:_imageView];
	}
	return self;
}

- (void)setPageImage:(UIImage *)image {
	_imageView.image = image;
	_imageSize = image ? image.size : CGSizeZero;
	_showingMinithumb = NO;
	[self resetZoom];
}

- (void)setPageImage:(UIImage *)image crossfade:(BOOL)crossfade {
	if (!crossfade || !image || !_imageView.image) {
		[self setPageImage:image];
		return;
	}

	UIImageView *view = _imageView;
	[UIView transitionWithView:view
					  duration:0.15
					   options:UIViewAnimationOptionTransitionCrossDissolve
					animations:^{ view.image = image; }
					completion:nil];
	_imageSize = image.size;
	_showingMinithumb = NO;
	[self resetZoom];
}

- (void)resetZoom {
	[self layoutImage];
}

- (void)updateZoomLimits {
	CGSize bounds = self.bounds.size;
	if (_imageSize.width < 1.0f || _imageSize.height < 1.0f ||
		bounds.width < 1.0f || bounds.height < 1.0f) {
		self.minimumZoomScale = 1.0f;
		self.maximumZoomScale = 1.0f;
		return;
	}

	CGFloat scaleWidth = bounds.width / _imageSize.width;
	CGFloat scaleHeight = bounds.height / _imageSize.height;
	CGFloat minScale = MIN(scaleWidth, scaleHeight);
	CGFloat maxScale = MAX(MAX(scaleWidth, scaleHeight), minScale * 3.0f);
	if (fabs(maxScale - minScale) < 0.01f)
		maxScale = minScale;

	self.minimumZoomScale = minScale;
	self.maximumZoomScale = maxScale;
}

- (void)layoutImage {
	CGSize bounds = self.bounds.size;

	if (_imageSize.width < 1.0f || _imageSize.height < 1.0f) {
		self.minimumZoomScale = 1.0f;
		self.maximumZoomScale = 1.0f;
		self.zoomScale = 1.0f;
		self.contentSize = bounds;
		self.scrollEnabled = NO;
		_imageView.frame = CGRectMake(0, 0, bounds.width, bounds.height);
		return;
	}

	self.minimumZoomScale = 1.0f;
	self.maximumZoomScale = 1.0f;
	self.zoomScale = 1.0f;
	_imageView.frame = CGRectMake(0, 0, _imageSize.width, _imageSize.height);
	self.contentSize = _imageSize;

	[self updateZoomLimits];
	self.zoomScale = self.minimumZoomScale;
	self.scrollEnabled = NO;

	[self centerContents];

	CGSize contentSize = self.contentSize;
	self.contentOffset = CGPointMake(
		MAX(0.0f, floorf((contentSize.width - bounds.width) / 2.0f)),
		MAX(0.0f, floorf((contentSize.height - bounds.height) / 2.0f)));
}

- (void)centerContents {
	CGSize bounds = self.bounds.size;
	CGRect frame = _imageView.frame;

	frame.origin.x = bounds.width > frame.size.width
		? floorf((bounds.width - frame.size.width) / 2.0f)
		: 0.0f;
	frame.origin.y = bounds.height > frame.size.height
		? floorf((bounds.height - frame.size.height) / 2.0f)
		: 0.0f;

	_imageView.frame = frame;
}

- (BOOL)isZoomed {
	return self.zoomScale > self.minimumZoomScale + 0.0001f;
}

- (BOOL)canZoom {
	return self.maximumZoomScale > self.minimumZoomScale + 0.0001f;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return _imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
	[self centerContents];
	self.scrollEnabled = [self isZoomed];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView
					   withView:(UIView *)view
						atScale:(float)scale {
	[self centerContents];
	self.scrollEnabled = [self isZoomed];
}

@end
