#import <UIKit/UIKit.h>

@interface UIImage (WebP)

+ (UIImage *)convertFromWebP:(NSString *)filePath compressedData:(__autoreleasing NSData **)compressedData error:(NSError **)error;

@end
