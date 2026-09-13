#import "TGProgressIndicatorView.h"

static const NSTimeInterval kProgressIndicatorTurn = 0.8;

static NSArray *TGProgressIndicatorFrames(UIActivityIndicatorViewStyle style) {
	static NSMutableDictionary *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ cache = [[NSMutableDictionary alloc] init]; });

	NSString *stem = nil;
	NSInteger first = 1;
	NSInteger last = 24;
	if (style == UIActivityIndicatorViewStyleWhiteLarge) {
		stem = @"navbar_big_progress_";
		first = 0;
		last = 23;
	} else if (style == UIActivityIndicatorViewStyleWhite) {
		stem = @"RProgress";
	} else {
		stem = @"grayProgress";
	}

	NSArray *cached = cache[stem];
	if (cached)
		return cached.count ? cached : nil;

	NSMutableArray *frames = [[NSMutableArray alloc] init];
	for (NSInteger i = first; i <= last; i++) {
		UIImage *frame = [UIImage imageNamed:
				[NSString stringWithFormat:@"%@%lu.png", stem, (unsigned long)i]];
		if (!frame) {
			frames = nil;
			break;
		}
		[frames addObject:frame];
	}

	cache[stem] = frames ?: [NSArray array];
	return frames.count ? frames : nil;
}

@implementation TGProgressIndicatorView {
	UIImageView *_frameView;
	BOOL _running;
}

- (id)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style {
	self = [super initWithActivityIndicatorStyle:style];
	if (!self)
		return nil;

	NSArray *frames = TGProgressIndicatorFrames(style);
	if (!frames.count)
		return self;

	self.color = [UIColor clearColor];

	UIImage *first = frames[0];
	CGRect box = CGRectMake(0, 0, first.size.width, first.size.height);

	_frameView = [[UIImageView alloc] initWithFrame:box];
	_frameView.image = first;
	_frameView.animationImages = frames;
	_frameView.animationDuration = kProgressIndicatorTurn;
	_frameView.animationRepeatCount = 0;
	_frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	CGPoint centre = self.center;
	self.bounds = box;
	self.center = centre;
	[self addSubview:_frameView];

	if (self.hidesWhenStopped)
		self.hidden = YES;
	return self;
}

- (void)startAnimating {
	if (!_frameView) {
		[super startAnimating];
		return;
	}
	_running = YES;
	self.hidden = NO;
	[_frameView startAnimating];
}

- (void)stopAnimating {
	if (!_frameView) {
		[super stopAnimating];
		return;
	}
	_running = NO;
	[_frameView stopAnimating];
	if (self.hidesWhenStopped)
		self.hidden = YES;
}

- (BOOL)isAnimating {
	if (!_frameView)
		return [super isAnimating];
	return _running;
}

- (void)setHidesWhenStopped:(BOOL)hidesWhenStopped {
	[super setHidesWhenStopped:hidesWhenStopped];
	if (_frameView)
		self.hidden = hidesWhenStopped && !_running;
}

@end
