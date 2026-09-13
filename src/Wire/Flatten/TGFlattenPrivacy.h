#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGPrivacyReportReasonType(NSString * _Nullable reason);
BOOL TGPrivacyRuleIsModelled(NSString *type);
NSArray *TGPrivacyExceptionListRemoving(NSArray * _Nullable list, NSArray * _Nullable idsToExclude);

NSDictionary * _Nullable TGPrivacyRuleDictForType(NSString *type,
	NSArray * _Nullable allowedUserIds,
	NSArray * _Nullable restrictedUserIds,
	NSArray * _Nullable allowedChatIds,
	NSArray * _Nullable restrictedChatIds,
	BOOL allowBots,
	BOOL restrictBots,
	BOOL allowPremiumUsers);

NSArray *TGPrivacyRebuiltRules(NSArray * _Nullable currentRules,
	NSString *baseType,
	NSArray * _Nullable allowedUserIds,
	NSArray * _Nullable restrictedUserIds,
	NSArray * _Nullable allowedChatIds,
	NSArray * _Nullable restrictedChatIds,
	BOOL allowBots,
	BOOL restrictBots,
	BOOL allowPremiumUsers);

BOOL TGPrivacySettingSupportsExceptions(NSString *setting);

NS_ASSUME_NONNULL_END
