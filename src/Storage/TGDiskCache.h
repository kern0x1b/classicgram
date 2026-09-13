#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGDiskCache : NSObject

+ (void)setAccountScope:(NSString *)scope;

+ (NSString *)databaseDirectory;
+ (NSString *)databaseDirectoryForScope:(NSString *)scope;
+ (void)discardDatabaseForScope:(NSString *)scope;
+ (NSString *)snapshotPathForName:(NSString *)name;

+ (UIImage *)imageForKey:(NSString *)key scale:(CGFloat)scale;
+ (void)storeImage:(UIImage *)image forKey:(NSString *)key;
+ (void)clearImages;

+ (void)protectPath:(NSString *)path;
+ (void)applyProtection:(NSString *)protection toPath:(NSString *)path;
+ (void)applyProtection:(NSString *)protection toTreeAtPath:(NSString *)path;
+ (void)releaseDatabaseProtectionAtPath:(NSString *)path;
+ (void)reassertDatabaseProtectionAtPath:(NSString *)path;
+ (BOOL)writeData:(NSData *)data toProtectedPath:(NSString *)path;

+ (void)sweep;
+ (unsigned long long)imageBytesOnDisk;

@end

NS_ASSUME_NONNULL_END
