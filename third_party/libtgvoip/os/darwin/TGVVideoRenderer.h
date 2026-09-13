#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

namespace tgvoip{
namespace video{
class VideoRenderer;
}
}

typedef NS_ENUM(int, TGVStreamPauseReason){
	TGVStreamPauseReasonBackground,
	TGVStreamPauseReasonPoorConnection
};

typedef NS_ENUM(int, TGVStreamStopReason){
	TGVStreamStopReasonUser,
	TGVStreamStopReasonPoorConnection
};

@protocol TGVVideoRendererDelegate <NSObject>

- (void)incomingVideoRotationDidChange: (int)rotation;
- (void)incomingVideoStreamWillStartWithFrameSize: (CGSize)size;
- (void)incomingVideoStreamDidStopWithReason: (TGVStreamStopReason)reason;
- (void)incomingVideoStreamDidPauseWithReason: (TGVStreamPauseReason)reason;
- (void)incomingVideoStreamWillResume;

@end

@interface TGVVideoRenderer : NSObject

- (instancetype)initWithDisplayLayer: (AVSampleBufferDisplayLayer *)layer delegate: (id<TGVVideoRendererDelegate>)delegate;
- (tgvoip::video::VideoRenderer*)nativeVideoRenderer;

- (void)_enqueueBuffer: (CMSampleBufferRef)buffer reset: (BOOL)reset;

@end
