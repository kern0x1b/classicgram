#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

extern NSString *const TGVideoRecorderErrorDomain;

typedef NS_ENUM(NSInteger, TGVideoRecorderErrorCode) {
	TGVideoRecorderErrorCameraAccessDenied = 1,
	TGVideoRecorderErrorMicrophoneAccessDenied = 2,
	TGVideoRecorderErrorNoCamera = 3,
	TGVideoRecorderErrorNotEnoughDiskSpace = 4,
	TGVideoRecorderErrorInterrupted = 5,
	TGVideoRecorderErrorEnteredBackground = 6,
	TGVideoRecorderErrorTooShort = 7,
	TGVideoRecorderErrorRecordingFailed = 8
};

typedef NS_ENUM(NSInteger, TGVideoRecorderMode) {
	TGVideoRecorderModeVideo = 0,
	TGVideoRecorderModeNote = 1
};

@class TGVideoRecorder;

@protocol TGVideoRecorderDelegate <NSObject>
@optional
- (void)videoRecorderDidBecomeReady:(TGVideoRecorder *)recorder;
- (void)videoRecorderDidStartRecording:(TGVideoRecorder *)recorder;
- (void)videoRecorder:(TGVideoRecorder *)recorder
	didUpdateDuration:(NSTimeInterval)duration
			 progress:(float)progress;
- (void)videoRecorder:(TGVideoRecorder *)recorder
	didFinishRecordingToPath:(NSString *)path
					duration:(NSTimeInterval)duration
				  dimensions:(CGSize)dimensions;
- (void)videoRecorder:(TGVideoRecorder *)recorder didFailWithError:(NSError *)error;
@end

@interface TGVideoRecorder : NSObject

- (instancetype)initWithMode:(TGVideoRecorderMode)mode;

@property (nonatomic, weak) id<TGVideoRecorderDelegate> delegate;

@property (nonatomic, readonly) TGVideoRecorderMode mode;
@property (nonatomic, readonly) BOOL ready;
@property (nonatomic, readonly) BOOL recording;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval maximumDuration;
@property (nonatomic, readonly) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, readonly) BOOL canSwitchCamera;
@property (nonatomic, readonly, strong) AVCaptureVideoPreviewLayer *previewLayer;

- (void)prepare;
- (void)startRecording;
- (void)stopRecording;
- (void)cancel;
- (void)switchCamera;
- (void)teardown;

@end
