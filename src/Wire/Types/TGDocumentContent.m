#import "TGDocumentContent.h"

@implementation TGDocumentContent

- (instancetype)initWithFileId:(int64_t)fileId
			   thumbnailFileId:(int64_t)thumbnailFileId
					  fileName:(NSString *)fileName
					  mimeType:(NSString *)mimeType
				 fileExtension:(NSString *)fileExtension
						  size:(long long)size
				downloadedSize:(long long)downloadedSize
				  isDownloaded:(BOOL)isDownloaded
				 isDownloading:(BOOL)isDownloading
					 localPath:(NSString *)localPath
				 minithumbnail:(TGMinithumbnail *)minithumbnail {
	self = [super init];
	if (self != nil) {
		_fileId = fileId;
		_thumbnailFileId = thumbnailFileId;
		_fileName = [fileName copy];
		_mimeType = [mimeType copy];
		_fileExtension = [fileExtension copy];
		_size = size;
		_downloadedSize = downloadedSize;
		_downloaded = isDownloaded;
		_downloading = isDownloading;
		_localPath = [localPath copy];
		_minithumbnail = minithumbnail;
	}
	return self;
}

@end
