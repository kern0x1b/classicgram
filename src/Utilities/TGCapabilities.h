#import <Foundation/Foundation.h>
#import "TGDevice.h"

@interface TGCapability : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) BOOL available;
@property (nonatomic, strong) NSString *requirement;
@end

@interface TGCapabilities : NSObject

+ (void)setVideoEncoderProbe:(BOOL (^)(void))probe;

+ (double)systemVersion;

+ (BOOL)is64Bit;

+ (NSUInteger)memoryMB;

+ (BOOL)canRunWebApps;

+ (BOOL)canAnimateInline;

+ (BOOL)canHoldMultipleAccounts;

+ (BOOL)canEncodeVideoCall;

+ (BOOL)canPlayAnimatedStickers;

+ (BOOL)canShowWallpaper;

+ (NSArray *)all;

@end
