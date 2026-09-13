#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGDeviceTier) {
	TGDeviceTierVintage = 0,
	TGDeviceTierLegacy = 1,
	TGDeviceTierModern = 2,
	TGDeviceTierFull = 3
};

@interface TGDevice : NSObject

+ (NSString *)machine;

+ (NSDictionary *)tableEntryForMachine:(NSString *)machine;

+ (NSString *)modelName;

+ (NSString *)chip;

+ (NSUInteger)memoryMB;

+ (double)maximumIOS;

+ (TGDeviceTier)tier;
+ (NSString *)tierName;

+ (NSString *)summary;

+ (BOOL)isPadIdiom;

@end
