#import "TGMessageContent.h"

@class TGMinithumbnail;

@interface TGDocumentContent : TGMessageContent

@property (nonatomic, readonly) int64_t fileId;
@property (nonatomic, readonly) int64_t thumbnailFileId;
@property (nonatomic, readonly, copy) NSString *fileName;
@property (nonatomic, readonly, copy) NSString *mimeType;
@property (nonatomic, readonly, copy) NSString *fileExtension;
@property (nonatomic, readonly) long long size;
@property (nonatomic, readonly) long long downloadedSize;
@property (nonatomic, readonly) BOOL downloaded;
@property (nonatomic, readonly) BOOL downloading;
@property (nonatomic, readonly, copy) NSString *localPath;
@property (nonatomic, readonly, strong) TGMinithumbnail *minithumbnail;

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
				 minithumbnail:(TGMinithumbnail *)minithumbnail NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
