#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGCMStatusName(NSString *type);
NSDictionary *TGCMFlatRights(NSDictionary * _Nullable rights, BOOL isOwner,
	BOOL isAdministrator, NSString * _Nullable customTitle);
NSDictionary *TGCMFlatComposerPermissions(NSDictionary * _Nullable memberPermissions,
	BOOL isAdminOrOwner, BOOL isMember, NSInteger slowModeDelay, double slowModeSecondsRemaining);

NS_ASSUME_NONNULL_END
