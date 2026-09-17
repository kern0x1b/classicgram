#import <UIKit/UIKit.h>

@interface TGVideoCaptureViewController : UIViewController

- (id)initWithRoundVideoNote:(BOOL)round;

@property (nonatomic, readonly) BOOL roundVideoNote;
@property (nonatomic, assign) NSTimeInterval maximumDuration;
@property (nonatomic, assign) NSTimeInterval minimumDuration;

@property (nonatomic, copy) void (^onFinish)(NSString *path, NSTimeInterval duration, CGSize dimensions);
@property (nonatomic, copy) void (^onCancel)(void);

- (void)presentOverParent:(UIViewController *)parent controlsFrame:(CGRect)controlsFrame;

- (void)beginHold;
- (void)holdMovedBy:(CGPoint)offset;
- (void)endHold;
- (void)cancelHold;
- (void)beginLockedRecording;

@property (nonatomic, readonly) BOOL locked;

@end
