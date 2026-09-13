#import <CoreGraphics/CoreGraphics.h>
#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGFileTypePhoto;
extern NSString *const TGFileTypeVideo;
extern NSString *const TGFileTypeDocument;
extern NSString *const TGFileTypeSticker;
extern NSString *const TGFileTypeAudio;
extern NSString *const TGFileTypeVoiceNote;
extern NSString *const TGFileTypeAnimation;
extern NSString *const TGFileTypeThumbnail;

extern NSString *const TGNetworkTypeWiFi;
extern NSString *const TGNetworkTypeMobile;
extern NSString *const TGNetworkTypeMobileRoaming;
extern NSString *const TGNetworkTypeOther;
extern NSString *const TGNetworkTypeNone;

@interface TGClient (Files)

#pragma mark - file state

- (void)fileInfo:(long long)fileId completion:(void (^ _Nullable)(NSDictionary *file))completion;

- (void)resolveRemoteFileId:(NSString *)remoteId
					   type:(NSString *)type
				 completion:(void (^ _Nullable)(NSDictionary *file))completion;

#pragma mark - downloading

- (void)startDownloadingFile:(long long)fileId
					priority:(NSInteger)priority
				  completion:(nullable void (^)(NSDictionary *file))completion;

- (void)cancelDownloadOfFile:(long long)fileId onlyIfPending:(BOOL)onlyIfPending;

- (void)deleteCachedFile:(long long)fileId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)suggestedFileNameForFile:(long long)fileId
					  completion:(void (^ _Nullable)(NSString *name))completion;

#pragma mark - downloads list

- (void)addFileToDownloads:(long long)fileId
					inChat:(int64_t)chatId
				 messageId:(int64_t)messageId
				  priority:(NSInteger)priority
				completion:(void (^ _Nullable)(NSDictionary *file))completion;

- (void)searchDownloadsWithQuery:(NSString *)query
					  onlyActive:(BOOL)onlyActive
				   onlyCompleted:(BOOL)onlyCompleted
						  offset:(nullable NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^ _Nullable)(NSDictionary *page))completion;

#pragma mark - streaming and partial reads

- (void)downloadedPrefixSizeForFile:(long long)fileId
							 offset:(long long)offset
						 completion:(void (^ _Nullable)(long long size))completion;

- (void)downloadFile:(long long)fileId
			  offset:(long long)offset
			   limit:(long long)limit
		  completion:(void (^ _Nullable)(NSDictionary *file))completion;

- (void)readFile:(long long)fileId
		  offset:(long long)offset
		   count:(long long)count
	  completion:(void (^ _Nullable)(NSData *data))completion;

- (void)streamFile:(long long)fileId
			offset:(long long)offset
			 count:(long long)count
		completion:(void (^ _Nullable)(NSData *data))completion;

#pragma mark - thumbnails

- (void)downloadPhotoSizes:(NSArray *)sizes
				  forWidth:(CGFloat)width
					 scale:(CGFloat)scale
				completion:(void (^ _Nullable)(NSString *path, NSDictionary *size))completion;

- (NSData *)minithumbnailData:(NSDictionary *)minithumbnail;

#pragma mark - uploading

- (void)uploadFileAtPath:(NSString *)path
					type:(NSString *)type
				priority:(NSInteger)priority
			  completion:(void (^ _Nullable)(NSDictionary *file))completion;

- (void)cancelUploadOfFile:(long long)fileId;

#pragma mark - auto-download settings

- (void)setAutoDownloadSettings:(NSDictionary *)settings
					 forNetwork:(NSString *)networkType
					 completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - statistics

#pragma mark - small helpers

- (void)fileExtensionForMimeType:(NSString *)mimeType
					  completion:(void (^ _Nullable)(NSString *extension))completion;

- (void)downloadFile:(long long)fileId completion:(void (^ _Nullable)(NSString *path))completion;
- (void)reportAudioListened:(long long)fileId durationSeconds:(NSInteger)seconds;

@end

NS_ASSUME_NONNULL_END
