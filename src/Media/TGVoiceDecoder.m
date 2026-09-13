#import "TGVoiceDecoder.h"
#include "opusfile/opusfile.h"
#include <stdio.h>
#include <string.h>

static void put32(unsigned char *p, uint32_t v) {
	p[0] = v & 0xff;
	p[1] = (v >> 8) & 0xff;
	p[2] = (v >> 16) & 0xff;
	p[3] = (v >> 24) & 0xff;
}
static void put16(unsigned char *p, uint16_t v) {
	p[0] = v & 0xff;
	p[1] = (v >> 8) & 0xff;
}

@implementation TGVoiceDecoder

static void TGVoiceDecoderFillHeader(unsigned char *header, int rate, int channels,
	uint32_t dataSize) {
	uint32_t byteRate = (uint32_t)(rate * channels * 2);
	memcpy(header, "RIFF", 4);
	put32(header + 4, 36 + dataSize);
	memcpy(header + 8, "WAVEfmt ", 8);
	put32(header + 16, 16);
	put16(header + 20, 1);
	put16(header + 22, (uint16_t)channels);
	put32(header + 24, (uint32_t)rate);
	put32(header + 28, byteRate);
	put16(header + 32, (uint16_t)(channels * 2));
	put16(header + 34, 16);
	memcpy(header + 36, "data", 4);
	put32(header + 40, dataSize);
}

+ (NSString *)cacheNameForOpusPath:(NSString *)opusPath {
	NSString *base = opusPath.lastPathComponent.stringByDeletingPathExtension;
	NSMutableString *safe = [NSMutableString stringWithCapacity:base.length];
	for (NSInteger i = 0; i < base.length; i++) {
		unichar c = [base characterAtIndex:i];
		if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_')
			[safe appendFormat:@"%C", c];
		else
			[safe appendString:@"_"];
	}
	if (!safe.length)
		[safe appendString:@"note"];
	return [NSString stringWithFormat:@"tgvoice-%@.wav", safe];
}

+ (void)removeCachedWavExcept:(NSString *)keepName {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *dir = NSTemporaryDirectory();
	NSArray *names = [fm contentsOfDirectoryAtPath:dir error:nil];
	for (NSString *name in names) {
		if (![name hasPrefix:@"tgvoice-"] || ![name.pathExtension isEqualToString:@"wav"])
			continue;
		if (keepName && [name isEqualToString:keepName])
			continue;
		[fm removeItemAtPath:[dir stringByAppendingPathComponent:name] error:nil];
	}
}

+ (NSString *)wavFromOpusFile:(NSString *)opusPath {
	if (!opusPath.length)
		return nil;

	NSString *name = [self cacheNameForOpusPath:opusPath];
	NSString *out = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	[self removeCachedWavExcept:name];

	int err = 0;
	OggOpusFile *of = op_open_file(opusPath.UTF8String, &err);
	if (!of) {
		NSLog(@"TGVoiceDecoder: op_open_file failed (%d)", err);
		return nil;
	}

	const int rate = 48000;
	int sourceChannels = op_channel_count(of, -1);
	int channels = (sourceChannels == 1) ? 1 : 2;

	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *staging = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"tgvoice-tmp-%u.part", arc4random()]];
	[fm removeItemAtPath:staging error:nil];
	if (![fm createFileAtPath:staging contents:nil attributes:nil]) {
		NSLog(@"TGVoiceDecoder: cannot create %@", staging);
		op_free(of);
		return nil;
	}

	NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:staging];
	if (!handle) {
		NSLog(@"TGVoiceDecoder: cannot open %@", staging);
		[fm removeItemAtPath:staging error:nil];
		op_free(of);
		return nil;
	}

	unsigned char header[44];
	TGVoiceDecoderFillHeader(header, rate, channels, 0);

	BOOL failed = NO;
	unsigned long long dataBytes = 0;
	@try {
		[handle writeData:[NSData dataWithBytes:header length:sizeof(header)]];

		opus_int16 buffer[5760 * 2];
		NSInteger capacity = (int)(sizeof(buffer) / sizeof(buffer[0]));
		if (channels == 1)
			capacity = 5760;

		for (;;) {
			int link = -1;
			NSInteger samples = (channels == 1)
				? op_read(of, buffer, capacity, &link)
				: op_read_stereo(of, buffer, capacity);
			if (channels == 1 && samples > 0 && op_channel_count(of, link) != 1) {
				NSLog(@"TGVoiceDecoder: unexpected channel change");
				failed = YES;
				break;
			}
			if (samples < 0) {
				NSLog(@"TGVoiceDecoder: op_read failed (%d)", samples);
				failed = YES;
				break;
			}
			if (samples == 0)
				break;
			NSInteger length = (NSUInteger)samples * (NSUInteger)channels * sizeof(opus_int16);
			NSData *chunk = [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:NO];
			[handle writeData:chunk];
			dataBytes += length;
			if (dataBytes > 0xf0000000ull) {
				NSLog(@"TGVoiceDecoder: stream too long");
				failed = YES;
				break;
			}
		}

		if (!failed && dataBytes > 0) {
			TGVoiceDecoderFillHeader(header, rate, channels, (uint32_t)dataBytes);
			[handle seekToFileOffset:0];
			[handle writeData:[NSData dataWithBytes:header length:sizeof(header)]];
		}
	} @catch (NSException *exception) {
		NSLog(@"TGVoiceDecoder: write failed %@", exception);
		failed = YES;
	}

	[handle closeFile];
	op_free(of);

	if (failed || dataBytes == 0) {
		if (!failed)
			NSLog(@"TGVoiceDecoder: decoded nothing");
		[fm removeItemAtPath:staging error:nil];
		return nil;
	}

	[fm removeItemAtPath:out error:nil];
	NSError *moveError = nil;
	if (![fm moveItemAtPath:staging toPath:out error:&moveError]) {
		NSLog(@"TGVoiceDecoder: cannot move to %@ (%@)", out, moveError);
		[fm removeItemAtPath:staging error:nil];
		return nil;
	}
	return out;
}

@end
