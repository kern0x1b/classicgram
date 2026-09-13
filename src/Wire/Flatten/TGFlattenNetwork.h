#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGNetNetworkTypeName(NSString * _Nullable kind);
NSDictionary *TGNetProxyTypeObject(NSDictionary * _Nullable proxy);
NSDictionary * _Nullable TGNetProxyDict(NSDictionary * _Nullable proxy, NSDictionary * _Nullable added);
NSDictionary * _Nullable TGNetAddedProxyDict(NSDictionary * _Nullable added);
NSDictionary * _Nullable TGNetSettingsDict(NSDictionary * _Nullable settings);
NSDictionary *TGNetSettingsObject(NSDictionary * _Nullable settings);

NS_ASSUME_NONNULL_END
