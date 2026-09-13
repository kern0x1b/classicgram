#import <UIKit/UIKit.h>

@interface TGStickerThumbnailCache : NSObject

+ (UIImage *)cachedThumbnailForUniqueId:(NSString *)uniqueId side:(CGFloat)side;

+ (id)thumbnailForFileId:(long long)fileId
				uniqueId:(NSString *)uniqueId
					side:(CGFloat)side
			  completion:(void (^)(UIImage *image))completion;

+ (void)cancelRequest:(id)token;

+ (void)purgeMemory;

+ (void)resetStatistics;
+ (NSString *)statisticsSummary;

@end
