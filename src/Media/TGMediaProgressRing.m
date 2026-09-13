#import "TGMediaProgressRing.h"

@implementation TGMediaProgressRing

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		self.userInteractionEnabled = NO;
		_progress = 0.0f;
	}
	return self;
}

- (void)setProgress:(CGFloat)progress {
	CGFloat clamped = MAX(0.0f, MIN(1.0f, progress));
	if (fabs(clamped - _progress) < 0.005f)
		return;
	_progress = clamped;
	[self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect box = self.bounds;

	CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 0.5f);
	CGContextFillEllipseInRect(ctx, box);

	CGFloat lineWidth = 2.0f;
	CGRect ring = CGRectInset(box, 8.0f + lineWidth / 2.0f, 8.0f + lineWidth / 2.0f);
	CGPoint centre = CGPointMake(CGRectGetMidX(ring), CGRectGetMidY(ring));
	CGFloat radius = ring.size.width / 2.0f;

	CGContextSetLineWidth(ctx, lineWidth);
	CGContextSetLineCap(ctx, kCGLineCapRound);

	CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 0.25f);
	CGContextAddArc(ctx, centre.x, centre.y, radius, 0.0f, (CGFloat)(2.0 * M_PI), 0);
	CGContextStrokePath(ctx);

	if (_progress <= 0.001f)
		return;

	CGFloat start = (CGFloat)(-M_PI / 2.0);
	CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
	CGContextAddArc(ctx, centre.x, centre.y, radius, start,
		start + (CGFloat)(2.0 * M_PI) * _progress, 0);
	CGContextStrokePath(ctx);
}

@end
