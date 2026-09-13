#import "TGFileStatusView.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const kFileStatusSpinKey = @"tgFileStatusSpin";

@implementation TGFileStatusView {
	CAShapeLayer *_ring;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	self.backgroundColor = [UIColor clearColor];
	self.opaque = NO;
	self.userInteractionEnabled = NO;
	_kind = TGFileStatusKindNone;
	_progress = 0.0f;
	_discColour = [UIColor colorWithRed:0.06f green:0.58f blue:0.93f alpha:1.0f];
	_glyphColour = [UIColor whiteColor];
	_ring = [CAShapeLayer layer];
	_ring.fillColor = [UIColor clearColor].CGColor;
	_ring.lineCap = kCALineCapRound;
	_ring.hidden = YES;
	[self.layer addSublayer:_ring];
	return self;
}

- (void)setKind:(TGFileStatusKind)kind progress:(CGFloat)progress {
	CGFloat clamped = MAX(0.027f, MIN(1.0f, progress));
	BOOL sameRing = (_kind == kind) && fabsf(_progress - clamped) < 0.004f;
	_kind = kind;
	_progress = clamped;
	if (!sameRing)
		[self setNeedsDisplay];
	[self layoutRing];
}

- (void)setDiscColour:(UIColor *)discColour {
	if ([_discColour isEqual:discColour])
		return;
	_discColour = discColour;
	[self setNeedsDisplay];
}

- (void)setGlyphColour:(UIColor *)glyphColour {
	if ([_glyphColour isEqual:glyphColour])
		return;
	_glyphColour = glyphColour;
	[self setNeedsDisplay];
	[self layoutRing];
}

- (void)setExtensionText:(NSString *)extensionText {
	if ([_extensionText isEqualToString:extensionText])
		return;
	_extensionText = [extensionText copy];
	[self setNeedsDisplay];
}

- (void)setFrame:(CGRect)frame {
	BOOL resized = !CGSizeEqualToSize(frame.size, self.frame.size);
	[super setFrame:frame];
	if (resized) {
		[self setNeedsDisplay];
		[self layoutRing];
	}
}

- (void)layoutRing {
	CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
	if (self.kind != TGFileStatusKindProgress || side < 8) {
		_ring.hidden = YES;
		[_ring removeAnimationForKey:kFileStatusSpinKey];
		return;
	}

	CGFloat inset = 2.5f;
	CGRect circle = CGRectInset(CGRectMake(0, 0, side, side), inset, inset);
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathAddEllipseInRect(path, NULL, circle);
	_ring.path = path;
	CGPathRelease(path);

	_ring.frame = CGRectMake(0, 0, side, side);
	_ring.strokeColor = self.glyphColour.CGColor;
	_ring.lineWidth = 2.0f;
	_ring.strokeStart = 0.0f;
	_ring.strokeEnd = self.progress;
	_ring.hidden = NO;
	_ring.affineTransform = CGAffineTransformMakeRotation((CGFloat)(-M_PI_2));

	if (![_ring animationForKey:kFileStatusSpinKey]) {
		CABasicAnimation *spin =
			[CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
		spin.fromValue = @(0.0f);
		spin.toValue = @(2 * M_PI);
		spin.duration = 2.0;
		spin.repeatCount = HUGE_VALF;
		[_ring addAnimation:spin forKey:kFileStatusSpinKey];
	}
}

- (void)drawGlyphInContext:(CGContextRef)ctx side:(CGFloat)side {
	CGFloat mid = side / 2;
	CGContextSetFillColorWithColor(ctx, self.glyphColour.CGColor);
	CGContextSetStrokeColorWithColor(ctx, self.glyphColour.CGColor);

	if (self.kind == TGFileStatusKindProgress) {
		CGFloat arm = side * 0.15f;
		CGContextSetLineWidth(ctx, 2.0f);
		CGContextSetLineCap(ctx, kCGLineCapRound);
		CGContextMoveToPoint(ctx, mid - arm, mid - arm);
		CGContextAddLineToPoint(ctx, mid + arm, mid + arm);
		CGContextMoveToPoint(ctx, mid + arm, mid - arm);
		CGContextAddLineToPoint(ctx, mid - arm, mid + arm);
		CGContextStrokePath(ctx);
		return;
	}

	if (self.kind == TGFileStatusKindDownload) {
		CGFloat stem = side * 0.20f;
		CGFloat wing = side * 0.15f;
		CGContextSetLineWidth(ctx, 2.0f);
		CGContextSetLineCap(ctx, kCGLineCapRound);
		CGContextMoveToPoint(ctx, mid, mid - stem);
		CGContextAddLineToPoint(ctx, mid, mid + stem * 0.6f);
		CGContextStrokePath(ctx);
		CGContextMoveToPoint(ctx, mid - wing, mid + stem * 0.6f - wing);
		CGContextAddLineToPoint(ctx, mid, mid + stem * 0.6f);
		CGContextAddLineToPoint(ctx, mid + wing, mid + stem * 0.6f - wing);
		CGContextStrokePath(ctx);
		return;
	}

	if (self.kind == TGFileStatusKindPlay) {
		CGFloat h = side * 0.36f;
		CGFloat w = side * 0.31f;
		CGFloat left = mid - w / 2 + side * 0.035f;
		CGContextMoveToPoint(ctx, left, mid - h / 2);
		CGContextAddLineToPoint(ctx, left + w, mid);
		CGContextAddLineToPoint(ctx, left, mid + h / 2);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
		return;
	}

	if (self.kind == TGFileStatusKindPause) {
		CGFloat h = side * 0.32f;
		CGFloat w = side * 0.09f;
		CGFloat gap = side * 0.085f;
		CGContextFillRect(ctx, CGRectMake(mid - gap / 2 - w, mid - h / 2, w, h));
		CGContextFillRect(ctx, CGRectMake(mid + gap / 2, mid - h / 2, w, h));
		return;
	}

	if (self.kind != TGFileStatusKindFile)
		return;

	CGFloat l = side * 0.34f, r = side * 0.66f;
	CGFloat t = side * 0.26f, b = side * 0.74f;
	CGFloat fold = side * 0.12f;
	CGContextMoveToPoint(ctx, l, t);
	CGContextAddLineToPoint(ctx, r - fold, t);
	CGContextAddLineToPoint(ctx, r, t + fold);
	CGContextAddLineToPoint(ctx, r, b);
	CGContextAddLineToPoint(ctx, l, b);
	CGContextClosePath(ctx);
	CGContextFillPath(ctx);

	CGContextSetFillColorWithColor(ctx, self.discColour.CGColor);
	CGContextMoveToPoint(ctx, r - fold, t);
	CGContextAddLineToPoint(ctx, r, t + fold);
	CGContextAddLineToPoint(ctx, r - fold, t + fold);
	CGContextClosePath(ctx);
	CGContextFillPath(ctx);

	if (!self.extensionText.length)
		return;

	UIFont *font = [UIFont boldSystemFontOfSize:MAX(7.0f, side * 0.19f)];
	CGSize text = [self.extensionText sizeWithFont:font];
	if (text.width > r - l - 2)
		return;
	CGContextSetFillColorWithColor(ctx, self.discColour.CGColor);
	[self.extensionText drawAtPoint:CGPointMake(mid - text.width / 2,
										b - text.height - side * 0.05f)
						   withFont:font];
}

- (void)drawRect:(CGRect)rect {
	(void)rect;
	CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
	if (side < 4 || self.kind == TGFileStatusKindNone)
		return;

	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(ctx, self.discColour.CGColor);
	CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, side, side));
	[self drawGlyphInContext:ctx side:side];
}

@end
