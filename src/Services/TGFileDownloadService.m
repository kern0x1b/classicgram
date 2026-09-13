#import "TGFileDownloadService.h"
#import "TGClient+Files.h"

@implementation TGFileDownloadService

+ (void)downloadFile:(long long)fileId completion:(void (^)(NSString *path))completion {
	[[TGClient shared] downloadFile:fileId completion:completion];
}

+ (void)cancelDownloadOfFile:(long long)fileId onlyIfPending:(BOOL)onlyIfPending {
	[[TGClient shared] cancelDownloadOfFile:fileId onlyIfPending:onlyIfPending];
}

+ (void)reportAudioListened:(long long)fileId durationSeconds:(NSInteger)seconds {
	[[TGClient shared] reportAudioListened:fileId durationSeconds:seconds];
}

+ (void)fileInfo:(long long)fileId completion:(void (^)(NSDictionary *file))completion {
	[[TGClient shared] fileInfo:fileId completion:completion];
}

+ (void)resolveRemoteFileId:(NSString *)remoteId
					   type:(NSString *)type
				 completion:(void (^)(NSDictionary *file))completion {
	[[TGClient shared] resolveRemoteFileId:remoteId type:type completion:completion];
}

+ (void)startDownloadingFile:(long long)fileId
					priority:(NSInteger)priority
				  completion:(void (^)(NSDictionary *file))completion {
	[[TGClient shared] startDownloadingFile:fileId priority:priority completion:completion];
}

+ (void)downloadedPrefixSizeForFile:(long long)fileId
							 offset:(long long)offset
						 completion:(void (^)(long long size))completion {
	[[TGClient shared] downloadedPrefixSizeForFile:fileId offset:offset completion:completion];
}

+ (void)fileExtensionForMimeType:(NSString *)mimeType
					  completion:(void (^)(NSString *extension))completion {
	[[TGClient shared] fileExtensionForMimeType:mimeType completion:completion];
}

+ (void)readFile:(long long)fileId
		  offset:(long long)offset
		   count:(long long)count
	  completion:(void (^)(NSData *data))completion {
	[[TGClient shared] readFile:fileId offset:offset count:count completion:completion];
}

+ (void)streamFile:(long long)fileId
			offset:(long long)offset
			 count:(long long)count
		completion:(void (^)(NSData *data))completion {
	[[TGClient shared] streamFile:fileId offset:offset count:count completion:completion];
}

+ (NSData *)minithumbnailData:(NSDictionary *)minithumbnail {
	return [[TGClient shared] minithumbnailData:minithumbnail];
}

+ (NSString *)fileTypeDocument {
	return TGFileTypeDocument;
}

@end
