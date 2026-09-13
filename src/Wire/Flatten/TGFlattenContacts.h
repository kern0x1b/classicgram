#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGFirstUsername(NSDictionary * _Nullable user);
NSDictionary * _Nullable TGFlatUser(NSDictionary * _Nullable u);
NSString * _Nullable TGProfileTabName(id _Nullable tab);
NSDictionary * _Nullable TGBirthdateInfo(id _Nullable value);
BOOL TGBirthdateIsToday(NSDictionary * _Nullable birthdate);

NS_ASSUME_NONNULL_END
