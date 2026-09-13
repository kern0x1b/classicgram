#import "TGPhotoContent.h"

@implementation TGPhotoContent

- (instancetype)initWithFileId:(int64_t)fileId
						 width:(NSInteger)width
						height:(NSInteger)height
						 sizes:(NSArray<TGPhotoSize *> *)sizes
				 minithumbnail:(TGMinithumbnail *)minithumbnail {
	self = [super init];
	if (self != nil) {
		_fileId = fileId;
		_width = width;
		_height = height;
		_sizes = [sizes copy];
		_minithumbnail = minithumbnail;
	}
	return self;
}

@end
