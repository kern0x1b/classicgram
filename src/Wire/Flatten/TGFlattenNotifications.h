#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGNotifScopeType(NSString * _Nullable scope);
NSString *TGNotifReactionSource(NSString * _Nullable name);
NSString *TGNotifReactionSourceName(NSDictionary * _Nullable source);
NSDictionary *TGNotifReactionSettingsFrom(NSDictionary * _Nullable settings);
NSDictionary *TGNotifReactionSettingsMerged(NSDictionary * _Nullable current,
		NSDictionary * _Nullable changes);
NSDictionary *TGNotifReactionSettingsPayload(NSDictionary * _Nullable settings);

NSDictionary *TGNotifScopeSettingsFrom(NSDictionary * _Nullable s);
NSDictionary *TGNotifChatSettingsFrom(NSDictionary * _Nullable s, BOOL defaultSilent);

id TGNotifPick(NSDictionary * _Nullable changes, NSDictionary * _Nullable current, NSString *key);

NSDictionary *TGNotifScopeMutedOverrides(NSDictionary * _Nullable changes);
NSDictionary *TGNotifChatMutedOverrides(NSDictionary * _Nullable changes);

NS_ASSUME_NONNULL_END
