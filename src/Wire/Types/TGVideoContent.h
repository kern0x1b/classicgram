#import "TGMessageContent.h"

@class TGMinithumbnail;

@interface TGVideoContent : TGMessageContent

@property (nonatomic, readonly) int64_t fileId;
@property (nonatomic, readonly) int64_t thumbnailFileId;
@property (nonatomic, readonly, copy) NSString *fileName;
@property (nonatomic, readonly, copy) NSString *mimeType;
@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;
@property (nonatomic, readonly) NSInteger duration;
@property (nonatomic, readonly, strong) TGMinithumbnail *minithumbnail;
@property (nonatomic, readonly) BOOL supportsStreaming;

- (instancetype)initWithFileId:(int64_t)fileId
			   thumbnailFileId:(int64_t)thumbnailFileId
					  fileName:(NSString *)fileName
					  mimeType:(NSString *)mimeType
						 width:(NSInteger)width
						height:(NSInteger)height
					  duration:(NSInteger)duration
				 minithumbnail:(TGMinithumbnail *)minithumbnail
			 supportsStreaming:(BOOL)supportsStreaming NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
