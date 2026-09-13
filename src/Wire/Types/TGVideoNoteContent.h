#import "TGMessageContent.h"

@class TGMinithumbnail;

@interface TGVideoNoteContent : TGMessageContent

@property (nonatomic, readonly) int64_t fileId;
@property (nonatomic, readonly) int64_t thumbnailFileId;
@property (nonatomic, readonly) NSInteger duration;
@property (nonatomic, readonly, strong) TGMinithumbnail *minithumbnail;

- (instancetype)initWithFileId:(int64_t)fileId
			   thumbnailFileId:(int64_t)thumbnailFileId
					  duration:(NSInteger)duration
				 minithumbnail:(TGMinithumbnail *)minithumbnail NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
