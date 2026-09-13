#import <UIKit/UIKit.h>

extern NSString *const TGAudioMetadataChangedNotification;
extern NSString *const TGAudioMetadataFileIdKey;

@interface TGAudioMetadata : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *performer;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, strong) UIImage *artwork;

+ (TGAudioMetadata *)cachedForFileId:(int64_t)fileId;

+ (void)readForFileId:(int64_t)fileId path:(NSString *)path;

+ (void)requestForFileId:(int64_t)fileId;

+ (UIImage *)artworkTileOfSide:(CGFloat)side forMetadata:(TGAudioMetadata *)metadata;

+ (UIImage *)artworkTileOfSide:(CGFloat)side
				  cornerRadius:(CGFloat)cornerRadius
						 scrim:(BOOL)scrim
				   forMetadata:(TGAudioMetadata *)metadata;

+ (void)flush;

@end
