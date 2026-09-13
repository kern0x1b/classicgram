#import "TGVoiceNoteContent.h"

@implementation TGVoiceNoteContent

- (instancetype)initWithFileId:(int64_t)fileId
					  duration:(NSInteger)duration
					  waveform:(NSData *)waveform {
	self = [super init];
	if (self != nil) {
		_fileId = fileId;
		_duration = duration;
		_waveform = [waveform copy];
	}
	return self;
}

@end
