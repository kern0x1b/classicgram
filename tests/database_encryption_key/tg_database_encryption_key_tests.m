#import "tg_database_encryption_key_tests.h"
#import "TGDatabaseEncryptionKey.h"

TGTestOutcome TGDatabaseEncryptionKeyTestDecideGeneratesNewKeyOnFreshInstall(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGDatabaseEncryptionKeyDecision decision = TGDatabaseEncryptionKeyDecide(NO, NO);

	TGTestExpectEqualInteger(&outcome, decision, TGDatabaseEncryptionKeyDecisionGenerateNewKey,
		"a fresh install with no key and no database must generate a new key");

	return outcome;
}

TGTestOutcome TGDatabaseEncryptionKeyTestDecideLeavesUnsetWhenDatabaseExistsWithoutKey(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGDatabaseEncryptionKeyDecision decision = TGDatabaseEncryptionKeyDecide(NO, YES);

	TGTestExpectEqualInteger(&outcome, decision, TGDatabaseEncryptionKeyDecisionLeaveUnset,
		"an existing unencrypted database with no key yet must be left unencrypted, never encrypted after the fact");

	return outcome;
}

TGTestOutcome TGDatabaseEncryptionKeyTestDecideReusesExistingKeyWhenDatabaseExists(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGDatabaseEncryptionKeyDecision decision = TGDatabaseEncryptionKeyDecide(YES, YES);

	TGTestExpectEqualInteger(&outcome, decision, TGDatabaseEncryptionKeyDecisionUseExistingKey,
		"a database that was already encrypted on a previous launch must keep using the same key");

	return outcome;
}

TGTestOutcome TGDatabaseEncryptionKeyTestDecideReusesExistingKeyEvenWithoutDatabase(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGDatabaseEncryptionKeyDecision decision = TGDatabaseEncryptionKeyDecide(YES, NO);

	TGTestExpectEqualInteger(&outcome, decision, TGDatabaseEncryptionKeyDecisionUseExistingKey,
		"a key already in the keychain must never be regenerated, even if the database file is not there yet");

	return outcome;
}
