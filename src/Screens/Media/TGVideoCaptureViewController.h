#import <UIKit/UIKit.h>

@class TGVideoCaptureViewController;

@protocol TGVideoCaptureViewControllerDelegate <NSObject>
@optional
- (void)videoCaptureController:(TGVideoCaptureViewController *)controller
			 didFinishWithPath:(NSString *)path
					  duration:(NSTimeInterval)duration
					dimensions:(CGSize)dimensions
						 round:(BOOL)round;
- (void)videoCaptureControllerDidCancel:(TGVideoCaptureViewController *)controller;
@end

@interface TGVideoCaptureViewController : UIViewController

- (id)initWithRoundVideoNote:(BOOL)round;

@property (nonatomic, readonly) BOOL roundVideoNote;
@property (nonatomic, assign) NSTimeInterval maximumDuration;
@property (nonatomic, assign) NSTimeInterval minimumDuration;

@property (nonatomic, weak) id<TGVideoCaptureViewControllerDelegate> delegate;

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
