#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGDatabaseEncryptionKeyDecision) {
	TGDatabaseEncryptionKeyDecisionUseExistingKey,
	TGDatabaseEncryptionKeyDecisionGenerateNewKey,
	TGDatabaseEncryptionKeyDecisionLeaveUnset,
};

FOUNDATION_EXPORT TGDatabaseEncryptionKeyDecision TGDatabaseEncryptionKeyDecide(
	BOOL keyExistsInKeychain, BOOL databaseFileExists);

@interface TGDatabaseEncryptionKey : NSObject

+ (NSData *)obtainKeyForDatabaseDirectory:(NSString *)databaseDirectory scope:(NSString *)scope;
+ (void)deleteKeyForScope:(NSString *)scope;

@end
