#import "TGVoiceRecorder.h"
#import "TGLazyFramework.h"
#import "TGCall.h"
#import <AVFoundation/AVFoundation.h>
#include "opusenc/opusenc.h"
#include <math.h>

NSString *const TGVoiceRecorderErrorDomain = @"TGVoiceRecorderErrorDomain";

static const NSTimeInterval kVoiceRecorderMaxDuration = 60.0 * 60.0;
static const NSUInteger kVoiceWaveformMaxBars = 100;

@interface TGVoiceRecorder () <AVAudioRecorderDelegate>
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) NSString *pcmPath;
@property (nonatomic, strong) NSDate *startedAt;
@property (nonatomic, assign) NSTimeInterval capturedDuration;
@property (nonatomic, strong) NSData *pendingWaveform;
@end

static NSData *TGPackWaveform(NSArray *amplitudes) {
	NSInteger bars = MIN(amplitudes.count, kVoiceWaveformMaxBars);
	if (!bars)
		return [NSData data];

	double peak = 0;
	for (NSInteger i = 0; i < bars; i++) {
		NSInteger sourceIndex = i * amplitudes.count / bars;
		double value = [amplitudes[sourceIndex] doubleValue];
		if (value > peak)
			peak = value;
	}
	if (peak <= 0)
		peak = 1;

	NSInteger byteCount = (bars * 5 + 7) / 8;
	NSMutableData *packed = [NSMutableData dataWithLength:byteCount];
	uint8_t *out = packed.mutableBytes;
	for (NSInteger i = 0; i < bars; i++) {
		NSInteger sourceIndex = i * amplitudes.count / bars;
		double value = [amplitudes[sourceIndex] doubleValue];
		uint8_t sample = (uint8_t)MIN(31.0, round(value / peak * 31.0));

		NSInteger bit = i * 5;
		NSInteger byte = bit / 8;
		NSInteger shift = bit % 8;
		out[byte] |= (uint8_t)((sample << shift) & 0xFF);
		if (shift + 5 > 8)
			out[byte + 1] |= (uint8_t)(sample >> (8 - shift));
	}
	return packed;
}

@implementation TGVoiceRecorder

+ (instancetype)shared {
	static TGVoiceRecorder *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ s = [[TGVoiceRecorder alloc] init]; });
	return s;
}

- (BOOL)recording {
	return self.recorder != nil && self.recorder.isRecording;
}

- (NSTimeInterval)duration {
	if (self.startedAt)
		return self.capturedDuration - [self.startedAt timeIntervalSinceNow];
	return self.capturedDuration;
}

- (NSString *)temporaryPathWithExtension:(NSString *)ext {
	NSString *name = [NSString stringWithFormat:@"voice-%.0f-%u.%@",
		[[NSDate date] timeIntervalSince1970] * 1000.0, arc4random() % 100000, ext];
	return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

- (void)deactivateSession {
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	NSError *err = nil;
	[session setCategory:TGAVString(AVAudioSessionCategoryPlayback) error:&err];
	TGCallState call = [TGCall shared].state;
	if (call == TGCallStateNone || call == TGCallStateEnded || call == TGCallStateFailed) {
		err = nil;
		[session setActive:NO error:&err];
	}
}

- (void)failWithCode:(TGVoiceRecorderErrorCode)code {
	NSError *error = [NSError errorWithDomain:TGVoiceRecorderErrorDomain code:code userInfo:nil];
	id<TGVoiceRecorderDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(voiceRecorder:didFailWithError:)])
		[delegate voiceRecorder:self didFailWithError:error];
}

- (BOOL)microphoneAccessDenied {
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	if (![session respondsToSelector:@selector(recordPermission)])
		return NO;
	return session.recordPermission == AVAudioSessionRecordPermissionDenied;
}

- (BOOL)microphoneAccessUndetermined {
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	if (![session respondsToSelector:@selector(recordPermission)])
		return NO;
	return session.recordPermission == AVAudioSessionRecordPermissionUndetermined;
}

- (BOOL)microphoneAccessAllowedRequestingIfNeeded {
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	if (![session respondsToSelector:@selector(recordPermission)])
		return YES;

	AVAudioSessionRecordPermission permission = session.recordPermission;
	if (permission == AVAudioSessionRecordPermissionGranted)
		return YES;

	if (permission == AVAudioSessionRecordPermissionUndetermined &&
		[session respondsToSelector:@selector(requestRecordPermission:)]) {
		__weak typeof(self) weakSelf = self;
		[session requestRecordPermission:^(BOOL granted) {
			if (granted)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				[weakSelf failWithCode:TGVoiceRecorderErrorMicrophoneAccessDenied];
			});
		}];
	}

	return NO;
}

- (BOOL)start {
	if (self.recording)
		return YES;

	[self teardownRecorderKeepingFile:NO];

	if (![self microphoneAccessAllowedRequestingIfNeeded])
		return NO;

	NSError *err = nil;
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	if (![session setCategory:TGAVString(AVAudioSessionCategoryPlayAndRecord) error:&err]) {
		NSLog(@"TGVoiceRecorder: audio session category: %@", err);
		return NO;
	}
	err = nil;
	if (![session setActive:YES error:&err]) {
		NSLog(@"TGVoiceRecorder: audio session activate: %@", err);
		return NO;
	}

	if ([session respondsToSelector:@selector(inputIsAvailable)] && !session.inputIsAvailable) {
		NSLog(@"TGVoiceRecorder: no audio input available");
		[self deactivateSession];
		return NO;
	}

	self.pcmPath = [self temporaryPathWithExtension:@"caf"];
	[[NSFileManager defaultManager] removeItemAtPath:self.pcmPath error:nil];

	NSDictionary *settings = @{
		TGAVString(AVFormatIDKey) : @(kAudioFormatLinearPCM),
		TGAVString(AVSampleRateKey) : @(48000.0),
		TGAVString(AVNumberOfChannelsKey) : @(1),
		TGAVString(AVLinearPCMBitDepthKey) : @(16),
		TGAVString(AVLinearPCMIsFloatKey) : @NO,
		TGAVString(AVLinearPCMIsBigEndianKey) : @NO,
	};

	err = nil;
	NSURL *pcmURL = [NSURL fileURLWithPath:self.pcmPath];
	self.recorder = [[TGAVClass(AVAudioRecorder) alloc] initWithURL:pcmURL settings:settings error:&err];
	if (!self.recorder || err) {
		NSLog(@"TGVoiceRecorder: %@", err);
		self.recorder = nil;
		self.pcmPath = nil;
		[self deactivateSession];
		return NO;
	}

	self.recorder.delegate = self;
	if (![self.recorder prepareToRecord]) {
		NSLog(@"TGVoiceRecorder: prepareToRecord failed");
		[self teardownRecorderKeepingFile:NO];
		[self deactivateSession];
		return NO;
	}

	self.capturedDuration = 0;
	self.startedAt = [NSDate date];

	BOOL started = [self.recorder recordForDuration:kVoiceRecorderMaxDuration];
	if (!started) {
		NSLog(@"TGVoiceRecorder: record failed to start");
		[self teardownRecorderKeepingFile:NO];
		[self deactivateSession];
		return NO;
	}

	return YES;
}

- (void)teardownRecorderKeepingFile:(BOOL)keepFile {
	AVAudioRecorder *recorder = self.recorder;
	self.recorder = nil;
	recorder.delegate = nil;
	if (recorder.isRecording)
		[recorder stop];

	self.startedAt = nil;
	if (!keepFile) {
		if (self.pcmPath)
			[[NSFileManager defaultManager] removeItemAtPath:self.pcmPath error:nil];
		self.pcmPath = nil;
		self.capturedDuration = 0;
	}
}

- (void)cancel {
	[self teardownRecorderKeepingFile:NO];
	[self deactivateSession];
}

- (void)stopWithCompletion:(void (^)(NSString *, NSTimeInterval, NSData *))completion {
	NSTimeInterval seconds = self.duration;
	self.capturedDuration = seconds;

	NSString *pcmPath = self.pcmPath;
	[self teardownRecorderKeepingFile:YES];
	self.pcmPath = nil;
	self.capturedDuration = 0;
	[self deactivateSession];

	if (!pcmPath || seconds < 0.3) {
		if (pcmPath)
			[[NSFileManager defaultManager] removeItemAtPath:pcmPath error:nil];
		if (completion)
			completion(nil, 0, nil);
		return;
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSString *oga = nil;
		self.pendingWaveform = nil;
		@try {
			oga = [self encodePCMAtPath:pcmPath];
		} @catch (NSException *exception) {
			NSLog(@"TGVoiceRecorder: encode exception %@", exception);
			oga = nil;
		}
		NSData *waveform = self.pendingWaveform;
		self.pendingWaveform = nil;
		[[NSFileManager defaultManager] removeItemAtPath:pcmPath error:nil];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (completion)
				completion(oga, seconds, waveform);
		});
	});
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
	NSLog(@"TGVoiceRecorder: encode error %@", error);
	if (recorder == self.recorder)
		[self cancel];
}

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder {
	if (recorder != self.recorder)
		return;
	self.capturedDuration = self.duration;
	[self teardownRecorderKeepingFile:YES];
	[self deactivateSession];
	id<TGVoiceRecorderDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(voiceRecorderWasInterrupted:)])
		[delegate voiceRecorderWasInterrupted:self];
}

- (NSString *)encodePCMAtPath:(NSString *)path {
	if (!path)
		return nil;

	NSData *caf = [NSData dataWithContentsOfFile:path
										 options:NSDataReadingMappedIfSafe
										   error:nil];
	if (caf.length < 64) {
		NSLog(@"TGVoiceRecorder: nothing recorded");
		return nil;
	}

	const uint8_t *bytes = caf.bytes;
	NSInteger offset = 0, dataLength = 0;

	NSInteger p = 8;
	while (p + 12 <= caf.length) {
		char type[5] = {0};
		memcpy(type, bytes + p, 4);
		uint64_t size = 0;
		for (NSInteger i = 0; i < 8; i++)
			size = (size << 8) | bytes[p + 4 + i];

		if (!strcmp(type, "data")) {
			offset = p + 12 + 4;
			if (offset >= caf.length)
				break;
			if (size == (uint64_t)-1 || size < 4 || p + 12 + size > caf.length)
				dataLength = caf.length - offset;
			else
				dataLength = (NSUInteger)size - 4;
			if (dataLength > caf.length - offset)
				dataLength = caf.length - offset;
			break;
		}

		if (size == 0 || size > caf.length)
			break;
		p += 12 + (NSUInteger)size;
	}

	if (!offset || dataLength < 2) {
		NSLog(@"TGVoiceRecorder: no data chunk");
		return nil;
	}

	NSString *out = [self temporaryPathWithExtension:@"oga"];
	[[NSFileManager defaultManager] removeItemAtPath:out error:nil];

	int error = 0;
	OggOpusComments *comments = ope_comments_create();
	OggOpusEnc *enc = ope_encoder_create_file(out.UTF8String, comments, 48000, 1, 0, &error);
	if (!enc) {
		NSLog(@"TGVoiceRecorder: encoder create failed (%d)", error);
		ope_comments_destroy(comments);
		return nil;
	}

	const short *samples = (const short *)(bytes + offset);
	NSInteger total = dataLength / sizeof(short);
	NSInteger chunk = 960;
	NSMutableArray *amplitudes = [NSMutableArray arrayWithCapacity:(total + chunk - 1) / chunk];

	for (NSInteger i = 0; i < total; i += chunk) {
		NSInteger count = (int)MIN(chunk, total - i);
		double sumSquares = 0;
		for (NSInteger j = 0; j < count; j++)
			sumSquares += (double)samples[i + j] * (double)samples[i + j];
		[amplitudes addObject:@(count ? sqrt(sumSquares / count) : 0)];

		if (ope_encoder_write(enc, samples + i, count) != 0) {
			NSLog(@"TGVoiceRecorder: write failed at %lu", (unsigned long)i);
			break;
		}
	}

	ope_encoder_drain(enc);
	ope_encoder_destroy(enc);
	ope_comments_destroy(comments);
	self.pendingWaveform = TGPackWaveform(amplitudes);

	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:out error:nil];
	unsigned long long size = attrs ? [attrs fileSize] : 0;
	NSLog(@"TGVoiceRecorder: encoded %llu bytes", size);
	if (size == 0) {
		[[NSFileManager defaultManager] removeItemAtPath:out error:nil];
		return nil;
	}
	return out;
}

@end
