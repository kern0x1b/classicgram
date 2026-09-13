#import "TGAudioContent.h"

@implementation TGAudioContent

- (instancetype)initWithFileId:(int64_t)fileId
					  fileName:(NSString *)fileName
					  mimeType:(NSString *)mimeType
			  albumCoverFileId:(int64_t)albumCoverFileId
						  size:(long long)size
					   isLocal:(BOOL)isLocal
						 title:(NSString *)title
					 performer:(NSString *)performer
					  duration:(NSInteger)duration {
	self = [super init];
	if (self != nil) {
		_fileId = fileId;
		_fileName = [fileName copy];
		_mimeType = [mimeType copy];
		_albumCoverFileId = albumCoverFileId;
		_size = size;
		_local = isLocal;
		_title = [title copy];
		_performer = [performer copy];
		_duration = duration;
	}
	return self;
}

@end
