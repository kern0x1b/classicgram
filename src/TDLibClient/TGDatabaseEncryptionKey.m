#import "TGDatabaseEncryptionKey.h"
#import <Security/Security.h>

static NSString *const TGDatabaseEncryptionKeychainService = @"kuzm.ig.telegram.dbkey";
static NSString *const TGDatabaseEncryptionKeychainAccount = @"local";
static NSString *const TGDatabaseEncryptionBinlogName = @"td.binlog";
enum { kDatabaseEncryptionKeyLength = 32 };

TGDatabaseEncryptionKeyDecision TGDatabaseEncryptionKeyDecide(
	BOOL keyExistsInKeychain, BOOL databaseFileExists) {
	if (keyExistsInKeychain)
		return TGDatabaseEncryptionKeyDecisionUseExistingKey;
	if (databaseFileExists)
		return TGDatabaseEncryptionKeyDecisionLeaveUnset;
	return TGDatabaseEncryptionKeyDecisionGenerateNewKey;
}

static NSString *TGDatabaseEncryptionKeychainAccountForScope(NSString *scope) {
	if (!scope.length)
		return TGDatabaseEncryptionKeychainAccount;
	return [TGDatabaseEncryptionKeychainAccount stringByAppendingFormat:@".%@", scope];
}

static NSMutableDictionary *TGDatabaseEncryptionKeychainQuery(NSString *scope) {
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
	query[(__bridge id)kSecAttrService] = TGDatabaseEncryptionKeychainService;
	query[(__bridge id)kSecAttrAccount] = TGDatabaseEncryptionKeychainAccountForScope(scope);
	return query;
}

static NSData *TGDatabaseEncryptionKeychainRead(NSString *scope) {
	NSMutableDictionary *query = TGDatabaseEncryptionKeychainQuery(scope);
	query[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
	query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

	CFTypeRef found = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &found);
	if (status != errSecSuccess) {
		if (status != errSecItemNotFound)
			NSLog(@"database encryption: keychain read failed (%d)", (int)status);
		if (found)
			CFRelease(found);
		return nil;
	}

	NSData *data = (__bridge_transfer NSData *)found;
	return data.length ? data : nil;
}

static BOOL TGDatabaseEncryptionKeychainWrite(NSString *scope, NSData *key) {
	if (!key.length)
		return NO;

	NSDictionary *changes = @{(__bridge id)kSecValueData : key,
		(__bridge id)kSecAttrAccessible :
			(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
	OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)TGDatabaseEncryptionKeychainQuery(scope),
		(__bridge CFDictionaryRef)changes);
	if (status == errSecSuccess)
		return YES;
	if (status != errSecItemNotFound) {
		NSLog(@"database encryption: keychain update failed (%d)", (int)status);
		return NO;
	}

	NSMutableDictionary *item = TGDatabaseEncryptionKeychainQuery(scope);
	item[(__bridge id)kSecValueData] = key;
	item[(__bridge id)kSecAttrAccessible] =
		(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;

	status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
	if (status == errSecDuplicateItem) {
		SecItemDelete((__bridge CFDictionaryRef)TGDatabaseEncryptionKeychainQuery(scope));
		status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
	}
	if (status == errSecSuccess)
		return YES;
	NSLog(@"database encryption: keychain write failed (%d)", (int)status);
	return NO;
}

static void TGDatabaseEncryptionKeychainDelete(NSString *scope) {
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)TGDatabaseEncryptionKeychainQuery(scope));
	if (status != errSecSuccess && status != errSecItemNotFound)
		NSLog(@"database encryption: keychain delete failed (%d)", (int)status);
}

static NSData *TGDatabaseEncryptionGenerateKey(void) {
	uint8_t bytes[kDatabaseEncryptionKeyLength];
	if (SecRandomCopyBytes(kSecRandomDefault, kDatabaseEncryptionKeyLength, bytes) != 0)
		for (NSUInteger i = 0; i < kDatabaseEncryptionKeyLength; i++)
			bytes[i] = (uint8_t)arc4random();
	return [NSData dataWithBytes:bytes length:kDatabaseEncryptionKeyLength];
}

@implementation TGDatabaseEncryptionKey

+ (NSData *)obtainKeyForDatabaseDirectory:(NSString *)databaseDirectory scope:(NSString *)scope {
	NSString *binlogPath =
		[databaseDirectory stringByAppendingPathComponent:TGDatabaseEncryptionBinlogName];
	BOOL databaseFileExists = [[NSFileManager defaultManager] fileExistsAtPath:binlogPath];
	NSData *existingKey = TGDatabaseEncryptionKeychainRead(scope);

	switch (TGDatabaseEncryptionKeyDecide(existingKey != nil, databaseFileExists)) {
		case TGDatabaseEncryptionKeyDecisionUseExistingKey:
			return existingKey;
		case TGDatabaseEncryptionKeyDecisionLeaveUnset:
			return nil;
		case TGDatabaseEncryptionKeyDecisionGenerateNewKey: {
			NSData *generated = TGDatabaseEncryptionGenerateKey();
			if (!TGDatabaseEncryptionKeychainWrite(scope, generated))
				return nil;
			return generated;
		}
	}
	return nil;
}

+ (void)deleteKeyForScope:(NSString *)scope {
	TGDatabaseEncryptionKeychainDelete(scope);
}

@end
