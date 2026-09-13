#import <Foundation/Foundation.h>

@interface TGPhoneFormat : NSObject

+ (TGPhoneFormat *)instance;

+ (NSString *)strip:(NSString *)str;

- (id)init;
- (id)initWithDefaultCountry:(NSString *)countryCode;

- (NSString *)format:(NSString *)str implicitPlus:(bool)implicitPlus;

#ifdef DEBUG
#endif

@end
