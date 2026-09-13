#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGAccountCodeDescription(NSDictionary * _Nullable type, NSString * _Nullable phone);
NSString *TGAccountNextTitle(NSDictionary * _Nullable type);
NSDictionary * _Nullable TGAccountCodeInfoDict(NSDictionary * _Nullable codeInfo);
NSDictionary * _Nullable TGAccountEmailCodeInfo(NSDictionary * _Nullable codeInfo);
NSDictionary * _Nullable TGAccountSessionDict(NSDictionary * _Nullable session);

NS_ASSUME_NONNULL_END
