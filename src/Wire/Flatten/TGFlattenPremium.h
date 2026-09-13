#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGPremiumHumanize(NSString * _Nullable tag);
NSString *TGPremiumTag(NSDictionary * _Nullable object, NSString * _Nullable prefix);
NSString * _Nullable TGPremiumFullType(NSString * _Nullable tag, NSString *prefix);
BOOL TGPremiumFeatureSupported(NSString * _Nullable tag);
NSString *TGPremiumFeatureTitle(NSString * _Nullable tag);
NSString *TGPremiumBusinessTitle(NSString * _Nullable tag);
NSString *TGPremiumLimitTitle(NSString * _Nullable tag);
NSString *TGPremiumFeatureSubtitle(NSString * _Nullable tag);
NSString *TGPremiumBusinessSubtitle(NSString * _Nullable tag);

NS_ASSUME_NONNULL_END
