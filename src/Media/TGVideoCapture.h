#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>

@class AVCaptureVideoPreviewLayer;

@interface TGVideoCapture : NSObject

@property (nonatomic, copy) void (^onPixelBuffer)(CVPixelBufferRef pixelBuffer, int64_t presentationTimeUs);
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, readonly, getter=isFrontFacing) BOOL frontFacing;
@property (nonatomic, readonly) BOOL isRunning;

+ (BOOL)isCameraAvailable;

- (BOOL)start;
- (void)stop;
- (void)setPaused:(BOOL)paused;
- (BOOL)canSwitchCamera;
- (void)switchCamera;

@end
