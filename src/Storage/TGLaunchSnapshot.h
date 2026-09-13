#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGLaunchSnapshot : NSObject

+ (void)restoreShippedImage:(NSString *)reason;

+ (NSString *)describe;

@end

NS_ASSUME_NONNULL_END
