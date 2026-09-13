#import "TGDiskCache.h"
#include <sys/time.h>

static const unsigned long long TGDiskCacheImageCap = 24ULL * 1024 * 1024;
static const unsigned long long TGDiskCacheImageFloor = 18ULL * 1024 * 1024;
static const NSTimeInterval kDiskCacheTouchInterval = 3600.0;
static const NSTimeInterval kDiskCacheSweepInterval = 120.0;
static const NSUInteger kDiskCacheAccessTableCap = 4096;
static const NSUInteger kDiskCacheProtectSlice = 24;
static const NSTimeInterval kDiskCacheProtectPause = 0.2;
static const NSTimeInterval kDiskCacheProtectDelay = 20.0;

static NSString *const TGDiskCacheChatsSnapshotName = @"chatlist";
static NSString *const TGDiskCacheFoldersSnapshotName = @"folders";

static NSString *gTGDiskCacheAccountScope = nil;

static NSString *TGDiskCacheProtection(void) {
	return NSFileProtectionCompleteUntilFirstUserAuthentication;
}

static NSString *TGDiskCacheDatabaseProtection(void) {
	return NSFileProtectionNone;
}

static dispatch_queue_t TGDiskCacheQueue(void) {
	static dispatch_queue_t queue = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("TGDiskCache", NULL);
	});
	return queue;
}

static NSString *TGDiskCacheLibrarySubdirectory(NSSearchPathDirectory which,
	NSString *name,
	NSString *protection) {
	NSString *root = [NSSearchPathForDirectoriesInDomains(which, NSUserDomainMask, YES)
		objectAtIndex:0];
	NSString *path = [root stringByAppendingPathComponent:name];
	NSFileManager *files = [NSFileManager defaultManager];
	[files createDirectoryAtPath:path
		withIntermediateDirectories:YES
						 attributes:@{NSFileProtectionKey : protection}
							  error:NULL];
	return path;
}

static NSString *TGDiskCacheImageDirectory(void) {
	static NSString *dir = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		dir = TGDiskCacheLibrarySubdirectory(NSCachesDirectory, @"TGImageCache",
			TGDiskCacheProtection());
	});
	return dir;
}

static NSString *TGDiskCacheStateDirectory(void) {
	static NSString *dir = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		dir = TGDiskCacheLibrarySubdirectory(NSCachesDirectory, @"TGState",
			TGDiskCacheProtection());
	});
	return dir;
}

static NSString *TGDiskCacheSafeName(NSString *key) {
	NSMutableString *out = [NSMutableString stringWithCapacity:key.length];
	for (NSInteger i = 0; i < key.length; i++) {
		unichar c = [key characterAtIndex:i];
		BOOL plain = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
			(c >= '0' && c <= '9') || c == '_' || c == '-';
		if (plain)
			[out appendFormat:@"%C", c];
		else
			[out appendFormat:@"%%%04X", (unsigned int)c];
	}
	return out;
}

static NSString *TGDiskCacheImagePath(NSString *key) {
	return [TGDiskCacheImageDirectory() stringByAppendingPathComponent:
			[TGDiskCacheSafeName(key) stringByAppendingPathExtension:@"png"]];
}

static NSMutableDictionary *TGDiskCacheAccessTable(void) {
	static NSMutableDictionary *table = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		table = [[NSMutableDictionary alloc] initWithCapacity:256];
	});
	return table;
}

static void TGDiskCacheNoteAccess(NSString *name) {
	if (!name.length)
		return;
	NSMutableDictionary *table = TGDiskCacheAccessTable();
	@synchronized(table) {
		if (!table[name] && table.count >= kDiskCacheAccessTableCap)
			[table removeAllObjects];
		table[name] = @([NSDate timeIntervalSinceReferenceDate]);
	}
}

static NSTimeInterval TGDiskCacheAccessTime(NSString *name) {
	NSMutableDictionary *table = TGDiskCacheAccessTable();
	@synchronized(table) {
		NSNumber *stamp = table[name];
		return stamp ? stamp.doubleValue : 0.0;
	}
}

static void TGDiskCacheForgetAccess(NSString *name) {
	NSMutableDictionary *table = TGDiskCacheAccessTable();
	@synchronized(table) {
		[table removeObjectForKey:name];
	}
}

static void TGDiskCacheStamp(NSString *path, NSTimeInterval when) {
	NSTimeInterval seconds = when + NSTimeIntervalSince1970;
	struct timeval stamps[2];
	stamps[0].tv_sec = (time_t)seconds;
	stamps[0].tv_usec = 0;
	stamps[1] = stamps[0];
	utimes(path.fileSystemRepresentation, stamps);
}

@interface TGDiskCache ()
+ (NSString *)primaryDatabaseDirectory;
+ (NSString *)snapshotPathForName:(NSString *)name scope:(NSString *)scope;
+ (void)sweepIfDue;
+ (void)sweepNow;
+ (NSDirectoryEnumerator *)imageEnumerator;
+ (void)discardStrayTemporariesIn:(NSString *)directory;
+ (void)discardLegacyCaches;
+ (void)protectSliceOf:(NSDirectoryEnumerator *)walk
				  root:(NSString *)root
			protection:(NSString *)protection
				  flag:(NSString *)flag
				  seen:(NSUInteger)seen
			   written:(NSUInteger)written;
@end

@implementation TGDiskCache

+ (void)setAccountScope:(NSString *)scope {
	NSString *next = scope.length ? [scope copy] : nil;
	if (next == gTGDiskCacheAccountScope || [next isEqualToString:gTGDiskCacheAccountScope])
		return;
	gTGDiskCacheAccountScope = next;
	NSLog(@"TGDiskCache: account scope is now %@", next ?: @"primary");
}

+ (NSString *)databaseDirectory {
	return [self databaseDirectoryForScope:gTGDiskCacheAccountScope];
}

+ (NSString *)databaseDirectoryForScope:(NSString *)scope {
	if (!scope.length)
		return [self primaryDatabaseDirectory];

	NSString *path = TGDiskCacheLibrarySubdirectory(NSApplicationSupportDirectory,
		[@"tdlib-" stringByAppendingString:TGDiskCacheSafeName(scope)],
		TGDiskCacheDatabaseProtection());
	[self reassertDatabaseProtectionAtPath:path];
	NSURL *url = [NSURL fileURLWithPath:path];
	[url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:NULL];
	return path;
}

+ (void)discardDatabaseForScope:(NSString *)scope {
	if (!scope.length)
		return;
	NSString *path = [self databaseDirectoryForScope:scope];
	NSError *error = nil;
	if ([[NSFileManager defaultManager] removeItemAtPath:path error:&error])
		NSLog(@"TGDiskCache: removed the database of account %@", scope);
	else
		NSLog(@"TGDiskCache: could not remove the database of account %@: %@", scope, error);

	NSFileManager *files = [NSFileManager defaultManager];
	for (NSString *name in @[ TGDiskCacheChatsSnapshotName, TGDiskCacheFoldersSnapshotName ]) {
		NSString *snapshotPath = [self snapshotPathForName:name scope:scope];
		[files removeItemAtPath:snapshotPath error:NULL];
	}
}

+ (NSString *)primaryDatabaseDirectory {
	static NSString *dir = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *support = TGDiskCacheLibrarySubdirectory(NSApplicationSupportDirectory, @"tdlib",
			TGDiskCacheDatabaseProtection());
		NSString *legacy = [[NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
			stringByAppendingPathComponent:@"tdlib"];

		BOOL legacyIsDirectory = NO;
		BOOL hasLegacy = [fm fileExistsAtPath:legacy isDirectory:&legacyIsDirectory] && legacyIsDirectory;
		BOOL supportIsEmpty = [fm contentsOfDirectoryAtPath:support error:NULL].count == 0;
		if (hasLegacy && supportIsEmpty) {
			[fm removeItemAtPath:support error:NULL];
			NSError *moveError = nil;
			if ([fm moveItemAtPath:legacy toPath:support error:&moveError])
				NSLog(@"TGDiskCache: moved the database out of Documents");
			else
				NSLog(@"TGDiskCache: database move failed: %@", moveError);
			[fm createDirectoryAtPath:support
				withIntermediateDirectories:YES
								 attributes:@{NSFileProtectionKey : TGDiskCacheDatabaseProtection()}
									  error:NULL];
		}

		[self reassertDatabaseProtectionAtPath:support];
		NSURL *url = [NSURL fileURLWithPath:support];
		[url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:NULL];
		dir = support;
	});
	return dir;
}

+ (NSString *)snapshotPathForName:(NSString *)name {
	return [self snapshotPathForName:name scope:gTGDiskCacheAccountScope];
}

+ (NSString *)snapshotPathForName:(NSString *)name scope:(NSString *)scope {
	NSString *scoped = scope.length
		? [NSString stringWithFormat:@"%@-%@", name, scope]
		: name;
	return [TGDiskCacheStateDirectory() stringByAppendingPathComponent:
			[TGDiskCacheSafeName(scoped) stringByAppendingPathExtension:@"plist"]];
}

+ (void)protectPath:(NSString *)path {
	[self applyProtection:TGDiskCacheProtection() toPath:path];
}

+ (void)applyProtection:(NSString *)protection toPath:(NSString *)path {
	if (!path.length)
		return;
	[[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey : protection}
									 ofItemAtPath:path
											error:NULL];
}

+ (void)releaseDatabaseProtectionAtPath:(NSString *)path {
	[self applyProtection:TGDiskCacheDatabaseProtection() toTreeAtPath:path];
}

+ (void)reassertDatabaseProtectionAtPath:(NSString *)path {
	if (!path.length)
		return;
	NSString *wanted = TGDiskCacheDatabaseProtection();
	NSFileManager *fm = [NSFileManager defaultManager];
	NSInteger rewritten = 0;
	if (![[fm attributesOfItemAtPath:path error:NULL][NSFileProtectionKey] isEqual:wanted]) {
		[self applyProtection:wanted toPath:path];
		rewritten++;
	}
	for (NSString *entry in [fm contentsOfDirectoryAtPath:path error:NULL]) {
		NSString *item = [path stringByAppendingPathComponent:entry];
		if ([[fm attributesOfItemAtPath:item error:NULL][NSFileProtectionKey] isEqual:wanted])
			continue;
		[self applyProtection:wanted toPath:item];
		rewritten++;
	}
	if (rewritten)
		NSLog(@"TGDiskCache: database protection drifted, %lu items reset to %@",
			(unsigned long)rewritten, wanted);
}

+ (void)applyProtection:(NSString *)protection toTreeAtPath:(NSString *)path {
	if (!path.length)
		return;
	NSString *done = [NSString stringWithFormat:@"TGDiskCacheProtected-%@-%@",
		TGDiskCacheSafeName(protection), TGDiskCacheSafeName(path)];
	if ([NSUserDefaults.standardUserDefaults boolForKey:done])
		return;
	dispatch_time_t after = dispatch_time(DISPATCH_TIME_NOW,
		(int64_t)(kDiskCacheProtectDelay * NSEC_PER_SEC));
	dispatch_after(after, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[self applyProtection:protection toPath:path];
		[self protectSliceOf:[[NSFileManager defaultManager] enumeratorAtPath:path]
						root:path
				  protection:protection
						flag:done
						seen:0
					 written:0];
	});
}

+ (void)protectSliceOf:(NSDirectoryEnumerator *)walk
				  root:(NSString *)root
			protection:(NSString *)protection
				  flag:(NSString *)flag
				  seen:(NSUInteger)seen
			   written:(NSUInteger)written {
	BOOL finished = NO;
	@autoreleasepool {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *wanted = protection;
		NSInteger inSlice = 0;
		while (inSlice < kDiskCacheProtectSlice) {
			NSString *relative = [walk nextObject];
			if (!relative) {
				finished = YES;
				break;
			}
			inSlice++;
			seen++;
			NSString *item = [root stringByAppendingPathComponent:relative];
			id current = [fm attributesOfItemAtPath:item error:NULL][NSFileProtectionKey];
			if ([current isEqual:wanted])
				continue;
			[self applyProtection:protection toPath:item];
			written++;
		}
	}
	if (finished) {
		NSLog(@"TGDiskCache: %@ written to %lu of %lu items under %@",
			protection, (unsigned long)written, (unsigned long)seen, root.lastPathComponent);
		[NSUserDefaults.standardUserDefaults setBool:YES forKey:flag];
		return;
	}
	dispatch_time_t after = dispatch_time(DISPATCH_TIME_NOW,
		(int64_t)(kDiskCacheProtectPause * NSEC_PER_SEC));
	dispatch_after(after, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[self protectSliceOf:walk
						root:root
				  protection:protection
						flag:flag
						seen:seen
					 written:written];
	});
}

+ (BOOL)writeData:(NSData *)data toProtectedPath:(NSString *)path {
	if (!data || !path.length)
		return NO;
	BOOL ok = [data writeToFile:path atomically:YES];
	if (ok)
		[self protectPath:path];
	return ok;
}

+ (UIImage *)imageForKey:(NSString *)key scale:(CGFloat)scale {
	if (!key.length)
		return nil;
	NSString *path = TGDiskCacheImagePath(key);
	NSData *data = [NSData dataWithContentsOfFile:path
										  options:NSDataReadingMappedIfSafe
											error:NULL];
	if (!data.length)
		return nil;

	UIImage *image = [UIImage imageWithData:data scale:(scale > 0 ? scale : 1.0f)];
	if (!image) {
		NSString *name = [path lastPathComponent];
		TGDiskCacheForgetAccess(name);
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		return nil;
	}

	TGDiskCacheNoteAccess([path lastPathComponent]);
	return image;
}

+ (void)storeImage:(UIImage *)image forKey:(NSString *)key {
	if (!image || !key.length)
		return;
	NSString *path = TGDiskCacheImagePath(key);
	dispatch_async(TGDiskCacheQueue(), ^{
		@autoreleasepool {
			NSData *data = UIImagePNGRepresentation(image);
			if (!data.length)
				return;
			[self writeData:data toProtectedPath:path];
		}
		[self sweepIfDue];
	});
}

+ (void)clearImages {
	NSString *dir = TGDiskCacheImageDirectory();
	NSMutableDictionary *table = TGDiskCacheAccessTable();
	@synchronized(table) {
		[table removeAllObjects];
	}
	dispatch_async(TGDiskCacheQueue(), ^{
		@autoreleasepool {
			NSFileManager *fm = [NSFileManager defaultManager];
			NSInteger removed = 0;
			for (NSString *name in [fm contentsOfDirectoryAtPath:dir error:NULL]) {
				if ([fm removeItemAtPath:[dir stringByAppendingPathComponent:name]
								   error:NULL])
					removed++;
			}
			NSLog(@"TGDiskCache: discarded %lu cached images", (unsigned long)removed);
		}
	});
}

+ (void)sweepIfDue {
	static NSTimeInterval last = 0;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - last < kDiskCacheSweepInterval)
		return;
	last = now;
	[self sweepNow];
}

+ (void)sweep {
	dispatch_async(TGDiskCacheQueue(), ^{
		[self discardLegacyCaches];
		[self discardStrayTemporariesIn:TGDiskCacheStateDirectory()];
		[self discardStrayTemporariesIn:TGDiskCacheImageDirectory()];
		[self sweepNow];
	});
}

+ (void)discardLegacyCaches {
	NSString *caches = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *legacy = [caches stringByAppendingPathComponent:@"RemoteImageCache"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:legacy])
		return;
	if ([[NSFileManager defaultManager] removeItemAtPath:legacy error:NULL])
		NSLog(@"TGDiskCache: removed the unprotected RemoteImageCache folder");
}

+ (void)discardStrayTemporariesIn:(NSString *)directory {
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *name in [fm contentsOfDirectoryAtPath:directory error:NULL]) {
		if (![name hasPrefix:@"."])
			continue;
		[fm removeItemAtPath:[directory stringByAppendingPathComponent:name] error:NULL];
	}
}

+ (NSDirectoryEnumerator *)imageEnumerator {
	NSArray *wanted = @[ NSURLNameKey, NSURLFileSizeKey, NSURLContentModificationDateKey ];
	NSURL *directory = [NSURL fileURLWithPath:TGDiskCacheImageDirectory() isDirectory:YES];
	return [[NSFileManager defaultManager]
				   enumeratorAtURL:directory
		includingPropertiesForKeys:wanted
						   options:(NSDirectoryEnumerationSkipsSubdirectoryDescendants |
									   NSDirectoryEnumerationSkipsPackageDescendants)
					  errorHandler:NULL];
}

+ (void)sweepNow {
	@autoreleasepool {
		NSDirectoryEnumerator *walk = [self imageEnumerator];
		if (!walk)
			return;

		NSMutableArray *urls = [NSMutableArray arrayWithCapacity:256];
		unsigned long long total = 0;
		for (NSURL *url in walk) {
			NSNumber *size = nil;
			if (![url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL] || !size)
				continue;
			total += size.unsignedLongLongValue;
			[urls addObject:url];
		}
		if (total <= TGDiskCacheImageCap)
			return;

		NSMutableArray *entries = [NSMutableArray arrayWithCapacity:urls.count];
		for (NSURL *url in urls) {
			NSNumber *size = nil;
			NSDate *modified = nil;
			NSString *name = nil;
			[url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
			[url getResourceValue:&modified forKey:NSURLContentModificationDateKey error:NULL];
			[url getResourceValue:&name forKey:NSURLNameKey error:NULL];
			if (!name)
				name = [url lastPathComponent];
			NSTimeInterval written = modified ? modified.timeIntervalSinceReferenceDate : 0.0;
			NSTimeInterval used = TGDiskCacheAccessTime(name);
			if (used > written + kDiskCacheTouchInterval) {
				TGDiskCacheStamp(url.path, used);
				written = used;
			}
			[entries addObject:@{@"path" : url.path,
				@"name" : name,
				@"size" : size ?: @0,
				@"age" : @(MAX(written, used))}];
		}

		[entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
			double first = [a[@"age"] doubleValue], second = [b[@"age"] doubleValue];
			if (first == second)
				return NSOrderedSame;
			return first < second ? NSOrderedAscending : NSOrderedDescending;
		}];

		NSFileManager *fm = [NSFileManager defaultManager];
		NSInteger removed = 0;
		for (NSDictionary *entry in entries) {
			if (total <= TGDiskCacheImageFloor)
				break;
			if (![fm removeItemAtPath:entry[@"path"] error:NULL])
				continue;
			TGDiskCacheForgetAccess(entry[@"name"]);
			total -= [entry[@"size"] unsignedLongLongValue];
			removed++;
		}
		NSLog(@"TGDiskCache: evicted %lu images, %llu KB left",
			(unsigned long)removed, total / 1024);
	}
}

+ (unsigned long long)imageBytesOnDisk {
	NSDirectoryEnumerator *walk = [self imageEnumerator];
	unsigned long long total = 0;
	for (NSURL *url in walk) {
		NSNumber *size = nil;
		if ([url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL] && size)
			total += size.unsignedLongLongValue;
	}
	return total;
}

@end
