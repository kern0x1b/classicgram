#import "TGMessageContent.h"

@interface TGVoiceNoteContent : TGMessageContent

@property (nonatomic, readonly) int64_t fileId;
@property (nonatomic, readonly) NSInteger duration;
@property (nonatomic, readonly, copy) NSData *waveform;

- (instancetype)initWithFileId:(int64_t)fileId
					  duration:(NSInteger)duration
					  waveform:(NSData *)waveform NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
