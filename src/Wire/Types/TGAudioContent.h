#import "TGMessageContent.h"

@interface TGAudioContent : TGMessageContent

@property (nonatomic, readonly) int64_t fileId;
@property (nonatomic, readonly, copy) NSString *fileName;
@property (nonatomic, readonly, copy) NSString *mimeType;
@property (nonatomic, readonly) int64_t albumCoverFileId;
@property (nonatomic, readonly) long long size;
@property (nonatomic, readonly) BOOL local;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *performer;
@property (nonatomic, readonly) NSInteger duration;

- (instancetype)initWithFileId:(int64_t)fileId
					  fileName:(NSString *)fileName
					  mimeType:(NSString *)mimeType
			  albumCoverFileId:(int64_t)albumCoverFileId
						  size:(long long)size
					   isLocal:(BOOL)isLocal
						 title:(NSString *)title
					 performer:(NSString *)performer
					  duration:(NSInteger)duration NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
