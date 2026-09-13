#import "TGStoryChartView.h"
#import "TGTheme.h"

@implementation TGStoryChartView

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.backgroundColor = [UIColor clearColor];
		self.contentMode = UIViewContentModeRedraw;
		self.points = @[];
	}
	return self;
}

- (void)setPoints:(NSArray *)points {
	_points = points ?: @[];
	[self setNeedsDisplay];
}

- (void)scanMaximum:(double *)maximum minimum:(double *)minimum {
	double high = 0, low = 0;
	BOOL first = YES;
	for (id point in self.points) {
		if (![point isKindOfClass:[NSNumber class]])
			continue;
		double value = [point doubleValue];
		if (first) {
			high = low = value;
			first = NO;
			continue;
		}
		if (value > high)
			high = value;
		if (value < low)
			low = value;
	}
	if (maximum)
		*maximum = high;
	if (minimum)
		*minimum = low;
}

- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context)
		return;
	CGFloat width = self.bounds.size.width;
	CGFloat height = self.bounds.size.height;
	CGFloat inset = 8;
	CGFloat pixel = [UIScreen mainScreen].scale > 1.5f ? 0.5f : 1.0f;

	CGContextSetLineWidth(context, pixel);
	CGContextSetStrokeColorWithColor(context, [[TGTheme shared] separatorColour].CGColor);
	CGContextBeginPath(context);
	CGContextMoveToPoint(context, inset, height - inset);
	CGContextAddLineToPoint(context, width - inset, height - inset);
	CGContextStrokePath(context);

	NSInteger count = self.points.count;
	if (count < 2)
		return;

	double maximum = 0, minimum = 0;
	[self scanMaximum:&maximum minimum:&minimum];
	double span = maximum - minimum;
	if (span <= 0)
		span = 1;

	CGFloat plotWidth = width - inset * 2;
	CGFloat plotHeight = height - inset * 2;
	CGContextSetLineWidth(context, 1.5f);
	CGContextSetLineJoin(context, kCGLineJoinRound);
	CGContextSetStrokeColorWithColor(context, [[TGTheme shared] accentColour].CGColor);
	CGContextBeginPath(context);
	for (NSInteger i = 0; i < count; i++) {
		id point = self.points[i];
		double value = [point isKindOfClass:[NSNumber class]] ? [point doubleValue] : 0;
		CGFloat x = inset + plotWidth * i / (CGFloat)(count - 1);
		CGFloat y = inset + plotHeight * (1.0f - (CGFloat)((value - minimum) / span));
		if (i == 0)
			CGContextMoveToPoint(context, x, y);
		else
			CGContextAddLineToPoint(context, x, y);
	}
	CGContextStrokePath(context);
}

@end
