#import <Foundation/Foundation.h>

@interface TGFileDownloadService : NSObject

+ (void)downloadFile:(long long)fileId completion:(void (^)(NSString *path))completion;

+ (void)cancelDownloadOfFile:(long long)fileId onlyIfPending:(BOOL)onlyIfPending;

+ (void)reportAudioListened:(long long)fileId durationSeconds:(NSInteger)seconds;

+ (void)fileInfo:(long long)fileId completion:(void (^)(NSDictionary *file))completion;

+ (void)resolveRemoteFileId:(NSString *)remoteId
					   type:(NSString *)type
				 completion:(void (^)(NSDictionary *file))completion;

+ (void)startDownloadingFile:(long long)fileId
					priority:(NSInteger)priority
				  completion:(void (^)(NSDictionary *file))completion;

+ (void)downloadedPrefixSizeForFile:(long long)fileId
							 offset:(long long)offset
						 completion:(void (^)(long long size))completion;

+ (void)fileExtensionForMimeType:(NSString *)mimeType
					  completion:(void (^)(NSString *extension))completion;

+ (void)readFile:(long long)fileId
		  offset:(long long)offset
		   count:(long long)count
	  completion:(void (^)(NSData *data))completion;

+ (void)streamFile:(long long)fileId
			offset:(long long)offset
			 count:(long long)count
		completion:(void (^)(NSData *data))completion;

+ (NSData *)minithumbnailData:(NSDictionary *)minithumbnail;

+ (NSString *)fileTypeDocument;

@end
