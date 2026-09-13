#import <Foundation/Foundation.h>

extern NSString *const TGVoiceRecorderErrorDomain;

typedef NS_ENUM(NSInteger, TGVoiceRecorderErrorCode) {
	TGVoiceRecorderErrorMicrophoneAccessDenied = 1,
	TGVoiceRecorderErrorInterrupted = 2,
};

@class TGVoiceRecorder;

@protocol TGVoiceRecorderDelegate <NSObject>
@optional
- (void)voiceRecorder:(TGVoiceRecorder *)recorder didFailWithError:(NSError *)error;
- (void)voiceRecorderWasInterrupted:(TGVoiceRecorder *)recorder;
@end

@interface TGVoiceRecorder : NSObject

+ (instancetype)shared;

@property (nonatomic, weak) id<TGVoiceRecorderDelegate> delegate;

@property (nonatomic, readonly) BOOL recording;

@property (nonatomic, readonly) NSTimeInterval duration;

- (BOOL)microphoneAccessDenied;
- (BOOL)microphoneAccessUndetermined;

- (BOOL)start;

- (void)stopWithCompletion:(void (^)(NSString *path, NSTimeInterval duration, NSData *waveform))completion;
- (void)cancel;

@end
