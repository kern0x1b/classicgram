#import "TGAnimationContent.h"

@implementation TGAnimationContent

- (instancetype)initWithFileId:(int64_t)fileId
			   thumbnailFileId:(int64_t)thumbnailFileId
					  fileName:(NSString *)fileName
					  mimeType:(NSString *)mimeType
						 width:(NSInteger)width
						height:(NSInteger)height
					  duration:(NSInteger)duration
				 minithumbnail:(TGMinithumbnail *)minithumbnail {
	self = [super init];
	if (self != nil) {
		_fileId = fileId;
		_thumbnailFileId = thumbnailFileId;
		_fileName = [fileName copy];
		_mimeType = [mimeType copy];
		_width = width;
		_height = height;
		_duration = duration;
		_minithumbnail = minithumbnail;
	}
	return self;
}

@end
