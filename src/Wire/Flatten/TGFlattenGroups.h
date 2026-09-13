#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGGroupProfileTabName(id _Nullable tab);
NSDictionary *TGUserSender(int64_t userId);
NSDictionary *TGFlattenMemberIdentity(NSDictionary * _Nullable memberId);
NSArray *TGPermissionKeys(void);
NSArray *TGAdminRightKeys(void);
NSDictionary *TGBuildFlags(NSDictionary * _Nullable source, NSArray *keys, NSString *type);
NSDictionary *TGReadFlags(NSDictionary * _Nullable source, NSArray *keys);
NSString *TGStatusName(NSString * _Nullable type);
NSDictionary *TGFlattenMemberRestriction(id _Nullable status);
NSDictionary *TGSupergroupFilter(NSString * _Nullable filter, NSString * _Nullable query);
NSDictionary *TGChatMembersFilter(NSString * _Nullable filter);
NSDictionary * _Nullable TGFlattenInviteLink(NSDictionary * _Nullable link);
NSString *TGTitleForAdministratorRightKey(NSString * _Nullable key);
NSString *TGTitleForMemberPermissionKey(NSString * _Nullable key);
NSDictionary *TGMentionCandidate(int64_t userId, NSString * _Nullable username,
	NSString * _Nullable firstName, NSString * _Nullable lastName,
	NSString * _Nullable fallbackName);

NS_ASSUME_NONNULL_END
