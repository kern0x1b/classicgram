#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

long long TGPayStars(id _Nullable starAmount);
long long TGPayStarsNanos(id _Nullable starAmount);
NSString *TGPayDecimalAmount(long long minorUnitsAmount, NSString * _Nullable currencyCode);
NSNumber * _Nullable TGPayPhotoFileId(id _Nullable photo);
NSString *TGPayShortType(NSString * _Nullable type, NSString *prefix);
NSString *TGPayHumanType(NSString * _Nullable shortType);

NS_ASSUME_NONNULL_END
