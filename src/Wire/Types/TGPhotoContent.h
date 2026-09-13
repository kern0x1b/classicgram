#import "TGMessageContent.h"

@class TGPhotoSize;
@class TGMinithumbnail;

@interface TGPhotoContent : TGMessageContent

@property (nonatomic, readonly) int64_t fileId;
@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;
@property (nonatomic, readonly, copy) NSArray<TGPhotoSize *> *sizes;
@property (nonatomic, readonly, strong) TGMinithumbnail *minithumbnail;

- (instancetype)initWithFileId:(int64_t)fileId
						 width:(NSInteger)width
						height:(NSInteger)height
						 sizes:(NSArray<TGPhotoSize *> *)sizes
				 minithumbnail:(TGMinithumbnail *)minithumbnail NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
