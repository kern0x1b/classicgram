#import "TGReplySwipeRecognizer.h"

static const CGFloat kReplySwipeDirectionSlop = 2.0f;

@implementation TGReplySwipeRecognizer {
	BOOL _validated;
	CGPoint _firstTouch;
}

- (id)initWithTarget:(id)target action:(SEL)action {
	self = [super initWithTarget:target action:action];
	if (!self)
		return nil;
	self.maximumNumberOfTouches = 1;
	return self;
}

- (void)reset {
	[super reset];
	_validated = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesBegan:touches withEvent:event];
	if (self.shouldBegin && !self.shouldBegin()) {
		self.state = UIGestureRecognizerStateFailed;
		return;
	}
	_firstTouch = [[touches anyObject] locationInView:self.view];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	CGPoint here = [[touches anyObject] locationInView:self.view];
	CGFloat dx = here.x - _firstTouch.x;
	CGFloat dy = here.y - _firstTouch.y;

	if (!_validated) {
		if (dx > kReplySwipeDirectionSlop)
			self.state = UIGestureRecognizerStateFailed;
		else if (fabs(dy) > kReplySwipeDirectionSlop && fabs(dy) > fabs(dx) * 2.0f)
			self.state = UIGestureRecognizerStateFailed;
		else if (fabs(dx) > kReplySwipeDirectionSlop && fabs(dy) * 2.0f < fabs(dx))
			_validated = YES;
	}

	if (_validated)
		[super touchesMoved:touches withEvent:event];
}

@end
