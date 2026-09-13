#import <UIKit/UIKit.h>

@interface TGStickerImagePreparer : NSObject

+ (NSString *)stickerFilePathFromImage:(UIImage *)image error:(NSError **)error;

@end
