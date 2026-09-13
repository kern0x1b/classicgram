#import <Foundation/Foundation.h>

@interface TGVideoLoopback : NSObject

+ (BOOL)isRunning;
+ (void)runAtWidth:(unsigned int)width height:(unsigned int)height seconds:(NSTimeInterval)seconds;

@end
