#import "TGFlattenCalls.h"

NSString *TGCallsProblemType(NSString *name) {
	static NSDictionary *map = nil;
	if (!map) {
		map = [[NSDictionary alloc] initWithObjectsAndKeys:
				@"callProblemEcho", @"echo",
			@"callProblemNoise", @"noise",
			@"callProblemInterruptions", @"interruptions",
			@"callProblemDistortedSpeech", @"distortedSpeech",
			@"callProblemSilentLocal", @"silentLocal",
			@"callProblemSilentRemote", @"silentRemote",
			@"callProblemDropped", @"dropped",
			@"callProblemDistortedVideo", @"distortedVideo",
			@"callProblemPixelatedVideo", @"pixelatedVideo",
			nil];
	}
	if (![name isKindOfClass:NSString.class])
		return nil;
	return map[name];
}
