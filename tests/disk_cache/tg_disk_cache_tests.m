#import "tg_disk_cache_tests.h"
#import "TGDiskCache.h"
#import <Foundation/Foundation.h>
#include <unistd.h>

static BOOL TGTestWaitForDiskCacheCondition(BOOL (^condition)(void)) {
	for (int i = 0; i < 400; i++) {
		if (condition())
			return YES;
		usleep(5000);
	}
	return NO;
}

static NSString *TGTestUniqueScope(NSString *label) {
	return [NSString stringWithFormat:@"hosttest-%@-%d", label, (int)getpid()];
}

static NSString *TGTestTemporaryProtectedPath(NSString *label) {
	return [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"tg-disk-cache-host-test-%@-%d.bin", label, (int)getpid()]];
}

TGTestOutcome TGDiskCacheTestDatabaseDirectoryDiffersByScope(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *scopeA = TGTestUniqueScope(@"a");
	NSString *scopeB = TGTestUniqueScope(@"b");
	NSString *pathA = [TGDiskCache databaseDirectoryForScope:scopeA];
	NSString *pathB = [TGDiskCache databaseDirectoryForScope:scopeB];

	TGTestExpectTrue(&outcome, ![pathA isEqualToString:pathB],
			"two different account scopes must resolve to two different database directories");
	TGTestExpectTrue(&outcome, [pathA rangeOfString:scopeA].location != NSNotFound,
			"the scoped database path must be derived from the scope name");

	[TGDiskCache discardDatabaseForScope:scopeA];
	[TGDiskCache discardDatabaseForScope:scopeB];

	return outcome;
}

TGTestOutcome TGDiskCacheTestDatabaseDirectoryWithNoScopeIsPrimary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	[TGDiskCache setAccountScope:nil];
	NSString *primary = [TGDiskCache databaseDirectory];
	NSString *primaryAgain = [TGDiskCache databaseDirectoryForScope:nil];

	TGTestExpectTrue(&outcome, [primary isEqualToString:primaryAgain],
			"with no account scope set, databaseDirectory must match databaseDirectoryForScope:nil");

	return outcome;
}

TGTestOutcome TGDiskCacheTestDatabaseDirectoryForScopeCreatesTheDirectory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *scope = TGTestUniqueScope(@"created");
	NSString *path = [TGDiskCache databaseDirectoryForScope:scope];

	BOOL isDirectory = NO;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
	TGTestExpectTrue(&outcome, exists && isDirectory,
			"asking for a scope's database directory must create it on disk");

	[TGDiskCache discardDatabaseForScope:scope];

	return outcome;
}

TGTestOutcome TGDiskCacheTestDiscardDatabaseForScopeRemovesItsDirectory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *scope = TGTestUniqueScope(@"discard");
	NSString *path = [TGDiskCache databaseDirectoryForScope:scope];
	TGTestExpectTrue(&outcome, [[NSFileManager defaultManager] fileExistsAtPath:path],
			"sanity: the directory must exist before it is discarded");

	[TGDiskCache discardDatabaseForScope:scope];

	TGTestExpectTrue(&outcome, ![[NSFileManager defaultManager] fileExistsAtPath:path],
			"discarding a scope's database must remove its directory from disk");

	return outcome;
}

TGTestOutcome TGDiskCacheTestDiscardDatabaseForScopeIgnoresEmptyScope(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	[TGDiskCache setAccountScope:nil];
	NSString *primaryBefore = [TGDiskCache databaseDirectory];
	[TGDiskCache discardDatabaseForScope:nil];
	[TGDiskCache discardDatabaseForScope:@""];
	NSString *primaryAfter = [TGDiskCache databaseDirectory];

	TGTestExpectTrue(&outcome,
			[[NSFileManager defaultManager] fileExistsAtPath:primaryBefore],
			"discarding a nil or empty scope must never touch the primary database");
	TGTestExpectTrue(&outcome, [primaryBefore isEqualToString:primaryAfter],
			"the primary database path must be unaffected by a no-op discard");

	return outcome;
}

TGTestOutcome TGDiskCacheTestSnapshotPathVariesByScope(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	[TGDiskCache setAccountScope:TGTestUniqueScope(@"snap-a")];
	NSString *pathA = [TGDiskCache snapshotPathForName:@"chatlist"];
	[TGDiskCache setAccountScope:TGTestUniqueScope(@"snap-b")];
	NSString *pathB = [TGDiskCache snapshotPathForName:@"chatlist"];
	[TGDiskCache setAccountScope:nil];
	NSString *pathNoScope = [TGDiskCache snapshotPathForName:@"chatlist"];

	TGTestExpectTrue(&outcome, ![pathA isEqualToString:pathB],
			"the snapshot path for the same name must differ across account scopes");
	TGTestExpectTrue(&outcome, ![pathA isEqualToString:pathNoScope],
			"a scoped snapshot path must differ from the unscoped one");

	return outcome;
}

TGTestOutcome TGDiskCacheTestSnapshotPathIsStableForSameNameAndScope(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *scope = TGTestUniqueScope(@"stable");
	[TGDiskCache setAccountScope:scope];
	NSString *first = [TGDiskCache snapshotPathForName:@"folders"];
	NSString *second = [TGDiskCache snapshotPathForName:@"folders"];
	[TGDiskCache setAccountScope:nil];

	TGTestExpectTrue(&outcome, [first isEqualToString:second],
			"asking for the same snapshot name under the same scope must be stable across calls");

	return outcome;
}

TGTestOutcome TGDiskCacheTestWriteDataToProtectedPathRoundTrips(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *path = TGTestTemporaryProtectedPath(@"roundtrip");
	NSData *payload = [@"tg-disk-cache-host-test-payload" dataUsingEncoding:NSUTF8StringEncoding];

	BOOL wrote = [TGDiskCache writeData:payload toProtectedPath:path];
	NSData *readBack = [NSData dataWithContentsOfFile:path];

	TGTestExpectTrue(&outcome, wrote, "writing real data to a real path must report success");
	TGTestExpectTrue(&outcome, [readBack isEqualToData:payload],
			"the bytes read back from disk must equal the bytes written");

	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];

	return outcome;
}

TGTestOutcome TGDiskCacheTestWriteDataToProtectedPathFailsForNilData(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *path = TGTestTemporaryProtectedPath(@"nildata");
	BOOL wrote = [TGDiskCache writeData:nil toProtectedPath:path];

	TGTestExpectTrue(&outcome, !wrote, "writing nil data must fail rather than create an empty file");
	TGTestExpectTrue(&outcome, ![[NSFileManager defaultManager] fileExistsAtPath:path],
			"no file must be created when the data to write is nil");

	return outcome;
}

TGTestOutcome TGDiskCacheTestImageForKeyMissingFileReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *key = [NSString stringWithFormat:@"host-test-missing-%d", (int)getpid()];
	UIImage *image = [TGDiskCache imageForKey:key scale:1.0f];

	TGTestExpectTrue(&outcome, image == nil, "a key that was never stored must return nil");

	return outcome;
}

TGTestOutcome TGDiskCacheTestImageForKeyEmptyKeyReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UIImage *image = [TGDiskCache imageForKey:@"" scale:1.0f];

	TGTestExpectTrue(&outcome, image == nil, "an empty key must never resolve to an image");

	return outcome;
}

TGTestOutcome TGDiskCacheTestStoreThenFetchImageRoundTrips(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *key = [NSString stringWithFormat:@"host-test-roundtrip-%d", (int)getpid()];
	NSData *pixels = [@"host-test-pixels" dataUsingEncoding:NSUTF8StringEncoding];
	UIImage *stored = [UIImage tgHostImageWithPixelData:pixels];

	[TGDiskCache storeImage:stored forKey:key];

	__block UIImage *fetched = nil;
	BOOL appeared = TGTestWaitForDiskCacheCondition(^BOOL{
		fetched = [TGDiskCache imageForKey:key scale:1.0f];
		return fetched != nil;
	});

	TGTestExpectTrue(&outcome, appeared, "a stored image must eventually be fetchable by its key");
	TGTestExpectTrue(&outcome, [fetched.tgHostPixelData isEqualToData:pixels],
			"the fetched image must carry the same bytes that were stored");

	[TGDiskCache clearImages];
	TGTestWaitForDiskCacheCondition(^BOOL{
		return [TGDiskCache imageForKey:key scale:1.0f] == nil;
	});

	return outcome;
}

TGTestOutcome TGDiskCacheTestDifferentKeysDoNotClobberEachOther(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int pid = (int)getpid();
	NSString *keyOne = [NSString stringWithFormat:@"host-test-distinct-one-%d", pid];
	NSString *keyTwo = [NSString stringWithFormat:@"host-test-distinct-two-%d", pid];
	NSData *pixelsOne = [@"pixels-one" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *pixelsTwo = [@"pixels-two" dataUsingEncoding:NSUTF8StringEncoding];

	[TGDiskCache storeImage:[UIImage tgHostImageWithPixelData:pixelsOne] forKey:keyOne];
	[TGDiskCache storeImage:[UIImage tgHostImageWithPixelData:pixelsTwo] forKey:keyTwo];

	__block UIImage *fetchedOne = nil;
	__block UIImage *fetchedTwo = nil;
	BOOL bothAppeared = TGTestWaitForDiskCacheCondition(^BOOL{
		fetchedOne = [TGDiskCache imageForKey:keyOne scale:1.0f];
		fetchedTwo = [TGDiskCache imageForKey:keyTwo scale:1.0f];
		return fetchedOne != nil && fetchedTwo != nil;
	});

	TGTestExpectTrue(&outcome, bothAppeared, "storing two different keys must not make either one disappear");
	TGTestExpectTrue(&outcome, [fetchedOne.tgHostPixelData isEqualToData:pixelsOne],
			"the first key must keep its own bytes");
	TGTestExpectTrue(&outcome, [fetchedTwo.tgHostPixelData isEqualToData:pixelsTwo],
			"the second key must keep its own bytes, not the first key's");

	[TGDiskCache clearImages];
	TGTestWaitForDiskCacheCondition(^BOOL{
		return [TGDiskCache imageForKey:keyOne scale:1.0f] == nil &&
			[TGDiskCache imageForKey:keyTwo scale:1.0f] == nil;
	});

	return outcome;
}

TGTestOutcome TGDiskCacheTestKeysWithSpecialCharactersDoNotCollide(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int pid = (int)getpid();
	NSString *keySlash = [NSString stringWithFormat:@"host-test-special-%d/segment", pid];
	NSString *keyPercent = [NSString stringWithFormat:@"host-test-special-%d%%2Fsegment", pid];
	NSData *pixelsSlash = [@"slash-key-pixels" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *pixelsPercent = [@"percent-key-pixels" dataUsingEncoding:NSUTF8StringEncoding];

	[TGDiskCache storeImage:[UIImage tgHostImageWithPixelData:pixelsSlash] forKey:keySlash];
	[TGDiskCache storeImage:[UIImage tgHostImageWithPixelData:pixelsPercent] forKey:keyPercent];

	__block UIImage *fetchedSlash = nil;
	__block UIImage *fetchedPercent = nil;
	BOOL bothAppeared = TGTestWaitForDiskCacheCondition(^BOOL{
		fetchedSlash = [TGDiskCache imageForKey:keySlash scale:1.0f];
		fetchedPercent = [TGDiskCache imageForKey:keyPercent scale:1.0f];
		return fetchedSlash != nil && fetchedPercent != nil;
	});

	TGTestExpectTrue(&outcome, bothAppeared,
			"a key containing a slash and a visually similar percent-encoded key must both be storable");
	TGTestExpectTrue(&outcome, [fetchedSlash.tgHostPixelData isEqualToData:pixelsSlash],
			"the slash key must keep its own bytes");
	TGTestExpectTrue(&outcome, [fetchedPercent.tgHostPixelData isEqualToData:pixelsPercent],
			"the percent-encoded key must not collide with the slash key's file name");

	[TGDiskCache clearImages];
	TGTestWaitForDiskCacheCondition(^BOOL{
		return [TGDiskCache imageForKey:keySlash scale:1.0f] == nil &&
			[TGDiskCache imageForKey:keyPercent scale:1.0f] == nil;
	});

	return outcome;
}

TGTestOutcome TGDiskCacheTestClearImagesRemovesStoredImage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *key = [NSString stringWithFormat:@"host-test-clear-%d", (int)getpid()];
	[TGDiskCache storeImage:[UIImage tgHostImageWithPixelData:[@"clear-me" dataUsingEncoding:NSUTF8StringEncoding]]
					 forKey:key];

	BOOL appeared = TGTestWaitForDiskCacheCondition(^BOOL{
		return [TGDiskCache imageForKey:key scale:1.0f] != nil;
	});
	TGTestExpectTrue(&outcome, appeared, "sanity: the image must be stored before clearing it");

	[TGDiskCache clearImages];

	BOOL gone = TGTestWaitForDiskCacheCondition(^BOOL{
		return [TGDiskCache imageForKey:key scale:1.0f] == nil;
	});
	TGTestExpectTrue(&outcome, gone, "clearImages must eventually remove every previously stored image");

	return outcome;
}

TGTestOutcome TGDiskCacheTestImageForKeyWithCorruptFileRemovesIt(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int pid = (int)getpid();
	NSString *corruptKey = [NSString stringWithFormat:@"host-test-corrupt-%d", pid];
	NSString *markerKey = [NSString stringWithFormat:@"host-test-corrupt-marker-%d", pid];

	[TGDiskCache storeImage:[UIImage tgHostUndecodableImage] forKey:corruptKey];
	[TGDiskCache storeImage:[UIImage tgHostImageWithPixelData:[@"marker" dataUsingEncoding:NSUTF8StringEncoding]]
					 forKey:markerKey];

	BOOL markerAppeared = TGTestWaitForDiskCacheCondition(^BOOL{
		return [TGDiskCache imageForKey:markerKey scale:1.0f] != nil;
	});
	TGTestExpectTrue(&outcome, markerAppeared,
			"sanity: the marker written right after the corrupt file must eventually land on disk");

	UIImage *decoded = [TGDiskCache imageForKey:corruptKey scale:1.0f];
	TGTestExpectTrue(&outcome, decoded == nil,
			"a file whose bytes cannot be decoded as an image must be treated as a cache miss");

	[TGDiskCache clearImages];
	TGTestWaitForDiskCacheCondition(^BOOL{
		return [TGDiskCache imageForKey:markerKey scale:1.0f] == nil;
	});

	return outcome;
}
