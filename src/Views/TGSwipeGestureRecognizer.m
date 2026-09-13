#import "TGSwipeGestureRecognizer.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

@interface TGSwipeGestureRecognizer () {
	CGPoint _tapPoint;
	int _lockedDirection;
	NSTimeInterval _touchStartTime;
	bool _matchedVelocity;
}

@end

@implementation TGSwipeGestureRecognizer

- (id)initWithTarget:(id)target action:(SEL)action {
	self = [super initWithTarget:target action:action];
	if (self != nil) {
		self.directionLockThreshold = 6;
		self.horizontalThreshold = 10;
		self.verticalThreshold = 20;
		self.velocityThreshold = 0;
		self.velocityFailDistance = 4;
		self.direction = TGSwipeGestureRecognizerDirectionLeft | TGSwipeGestureRecognizerDirectionRight;
	}
	return self;
}

- (void)failGesture {
	self.state = UIGestureRecognizerStateFailed;
}

- (void)endGesture {
	self.state = UIGestureRecognizerStateRecognized;
}

- (void)reset {
	_tapPoint = CGPointZero;
	_matchedVelocity = false;
	_lockedDirection = 0;
	[super reset];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesBegan:touches withEvent:event];

	if ([self numberOfTouches] > 1) {
		[self failGesture];
		return;
	}

	UITouch *touch = [touches anyObject];
	_tapPoint = [touch locationInView:self.view];
	_touchStartTime = touch.timestamp;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint currentPoint = [touch locationInView:self.view];
	CGSize translation = CGSizeMake(currentPoint.x - _tapPoint.x, currentPoint.y - _tapPoint.y);

	float translationSquared = translation.width * translation.width + translation.height * translation.height;

	if (_lockedDirection == 0) {
		if (translationSquared >= self.directionLockThreshold * self.directionLockThreshold)
			_lockedDirection = ABS(translation.width) > ABS(translation.height) ? 1 : 2;
	}

	if (_lockedDirection == 2)
		translation.width = 0;

	float adjustedTranslation = translation.width + (translation.width < -4 ? 4 : (translation.width > 4 ? -4 : 0));
	if (ABS(adjustedTranslation) > FLT_EPSILON &&
		((adjustedTranslation < 0 && (self.direction & TGSwipeGestureRecognizerDirectionLeft) == 0) ||
			(adjustedTranslation > 0 && (self.direction & TGSwipeGestureRecognizerDirectionRight) == 0))) {
		[self failGesture];
		return;
	}

	if (ABS(translation.height) > self.verticalThreshold) {
		[self failGesture];
		return;
	} else if (ABS(translation.width) > self.horizontalThreshold) {
		[self endGesture];
		return;
	} else if (!_matchedVelocity && self.velocityThreshold > FLT_EPSILON && translationSquared >= self.velocityFailDistance * self.velocityFailDistance) {
		float velocity = (float)(sqrtf(translationSquared) / (touch.timestamp - _touchStartTime));
		if (velocity < self.velocityThreshold) {
			[self failGesture];
			return;
		}
		_matchedVelocity = true;
	}

	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)__unused touches withEvent:(UIEvent *)__unused event {
	[self failGesture];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesCancelled:touches withEvent:event];
	[self failGesture];
}

@end
