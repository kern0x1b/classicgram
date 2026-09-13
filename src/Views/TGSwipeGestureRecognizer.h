#import <UIKit/UIKit.h>

typedef enum {
	TGSwipeGestureRecognizerDirectionRight = 1,
	TGSwipeGestureRecognizerDirectionLeft = 2
} TGSwipeGestureRecognizerDirection;

@interface TGSwipeGestureRecognizer : UIGestureRecognizer

@property (nonatomic) float directionLockThreshold;
@property (nonatomic) float horizontalThreshold;
@property (nonatomic) float verticalThreshold;

@property (nonatomic) float velocityThreshold;
@property (nonatomic) float velocityFailDistance;

@property (nonatomic) int direction;

- (void)failGesture;

@end
