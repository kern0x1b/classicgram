#import "TGVideoNoteContent.h"

@implementation TGVideoNoteContent

- (instancetype)initWithFileId:(int64_t)fileId
			   thumbnailFileId:(int64_t)thumbnailFileId
					  duration:(NSInteger)duration
				 minithumbnail:(TGMinithumbnail *)minithumbnail {
	self = [super init];
	if (self != nil) {
		_fileId = fileId;
		_thumbnailFileId = thumbnailFileId;
		_duration = duration;
		_minithumbnail = minithumbnail;
	}
	return self;
}

@end
