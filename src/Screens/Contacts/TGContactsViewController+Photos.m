#import "TGContactsViewController.h"
#import "TGContactsViewControllerInternal.h"
#import "TGContactPhotoMatch.h"
#import "TGFlatActionCell.h"
#import "TGContactRowCell.h"
#import "TGInviteFriendsViewController.h"
#import "TGContactsService.h"
#import "TGFileDownloadService.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGImageDecode.h"
#import "TGNewContactViewController.h"
#import "RootViewController.h"
#import "UIView+SafeTint.h"
#import "TGEmoji.h"
#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>
#import <dlfcn.h>
#import "TGAlertView.h"

@implementation TGContactsViewController (Photos)

- (void)showLoadedPhoto:(UIImage *)photo forFileId:(NSNumber *)fileId {
	if (!photo || !fileId)
		return;
	for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows]) {
		if (!TGContactRowWantsPhotoFileId([self userAtIndexPath:path], fileId))
			continue;
		UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
		if ([cell isKindOfClass:[TGContactRowCell class]])
			((TGContactRowCell *)cell).avatarView.image = photo;
	}
}

- (NSString *)thumbCacheDirectory {
	static NSString *dir = nil;
	if (!dir) {
		dir = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES)
				.firstObject
			stringByAppendingPathComponent:@"ContactThumbs"];
		[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	return dir;
}

- (NSString *)thumbCachePathForKey:(NSString *)key {
	return [[self thumbCacheDirectory] stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@.png", key]];
}

- (NSString *)thumbCacheKeyForUser:(NSDictionary *)u {
	NSString *uniqueId = u[@"photoUniqueId"];
	if ([uniqueId isKindOfClass:NSString.class] && uniqueId.length)
		return uniqueId;
	return nil;
}

- (void)diskThumbAtPath:(NSString *)path scale:(CGFloat)scale completion:(void (^)(UIImage *photo))completion {
	dispatch_async(TGImageDecodeQueue(), ^{
		UIImage *result = nil;
		@autoreleasepool {
			NSFileManager *fm = [NSFileManager defaultManager];
			if ([fm fileExistsAtPath:path]) {
				UIImage *stored = [UIImage imageWithContentsOfFile:path];
				CGImageRef bitmap = stored.CGImage;
				if (bitmap && fabs((CGFloat)CGImageGetWidth(bitmap) - kContactAvatar * scale) < 0.5f && fabs((CGFloat)CGImageGetHeight(bitmap) - kContactAvatar * scale) < 0.5f) {
					result = [UIImage imageWithCGImage:bitmap scale:scale
										   orientation:UIImageOrientationUp];
				} else {
					[fm removeItemAtPath:path error:nil];
				}
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(result);
		});
	});
}

- (void)requestPhotoForUser:(NSDictionary *)u {
	NSNumber *fileId = [u[@"photoFileId"] isKindOfClass:NSNumber.class]
		? u[@"photoFileId"]
		: nil;
	if (!fileId)
		return;
	if ([self.photos objectForKey:fileId])
		return;
	if ([self.photosRequested containsObject:fileId] ||
		[self.photosFailed containsObject:fileId] ||
		[self.photosLoading containsObject:fileId])
		return;

	NSString *cacheKey = [self thumbCacheKeyForUser:u];
	NSString *cachePath = cacheKey ? [self thumbCachePathForKey:cacheKey] : nil;
	if (!cachePath) {
		[self requestPhotoForFileId:fileId cachePath:cachePath];
		return;
	}

	[self.photosLoading addObject:fileId];
	CGFloat scale = [UIScreen mainScreen].scale;
	__weak typeof(self) weakSelf = self;
	[self diskThumbAtPath:cachePath scale:scale completion:^(UIImage *photo) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.photosLoading removeObject:fileId];
		if (photo) {
			[strongSelf.photos setObject:photo forKey:fileId cost:TGContactPhotoCost(photo)];
			[strongSelf showLoadedPhoto:photo forFileId:fileId];
			return;
		}
		[strongSelf requestPhotoForFileId:fileId cachePath:cachePath];
	}];
}

- (void)requestPhotoForFileId:(NSNumber *)fileId cachePath:(NSString *)cachePath {
	if (!fileId || [self.photosRequested containsObject:fileId] || [self.photosFailed containsObject:fileId])
		return;
	[self.photosRequested addObject:fileId];
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId.longLongValue completion:^(NSString *path) {
		if (!path) {
			TGContactsViewController *strongSelf = weakSelf;
			[strongSelf.photosRequested removeObject:fileId];
			[strongSelf.photosFailed addObject:fileId];
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			@autoreleasepool {
				UIImage *thumb = TGDecodeSquareThumbnail(path, kContactAvatar);
				if (thumb && cachePath.length)
					[UIImagePNGRepresentation(thumb) writeToFile:cachePath atomically:YES];
				dispatch_async(dispatch_get_main_queue(), ^{
					TGContactsViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf.photosRequested removeObject:fileId];
					if (!thumb) {
						[strongSelf.photosFailed addObject:fileId];
						return;
					}
					[strongSelf.photos setObject:thumb forKey:fileId
									cost:TGContactPhotoCost(thumb)];
					[strongSelf showLoadedPhoto:thumb forFileId:fileId];
				});
			}
		});
	}];
}

- (void)fetchMissingPhotos {
	NSMutableSet *liveKeys = [NSMutableSet set];
	for (NSDictionary *u in self.users) {
		NSString *key = [self thumbCacheKeyForUser:u];
		if (key)
			[liveKeys addObject:key];
	}
	[self pruneThumbCacheKeeping:liveKeys];
	[self.photosFailed removeAllObjects];
}

- (BOOL)isPhotoFileVisible:(NSNumber *)fileId {
	for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows]) {
		NSDictionary *u = [self userAtIndexPath:path];
		NSNumber *other = [u[@"photoFileId"] isKindOfClass:NSNumber.class]
			? u[@"photoFileId"]
			: nil;
		if (other && [other isEqualToNumber:fileId])
			return YES;
	}
	return NO;
}

- (void)tableView:(UITableView *)tableView
	didEndDisplayingCell:(UITableViewCell *)cell
	   forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *u = [self userAtIndexPath:indexPath];
	NSNumber *fileId = [u[@"photoFileId"] isKindOfClass:NSNumber.class]
		? u[@"photoFileId"]
		: nil;
	if (!fileId || ![self.photosRequested containsObject:fileId])
		return;
	if ([self.photos objectForKey:fileId] || [self isPhotoFileVisible:fileId])
		return;
	[self.photosRequested removeObject:fileId];
	[TGFileDownloadService cancelDownloadOfFile:fileId.longLongValue onlyIfPending:NO];
}

- (void)pruneThumbCacheKeeping:(NSSet *)liveKeys {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES)
			.firstObject
		stringByAppendingPathComponent:@"ContactThumbs"];
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *file in [fm contentsOfDirectoryAtPath:dir error:nil]) {
		NSString *stem = [file stringByDeletingPathExtension];
		if (![liveKeys containsObject:stem])
			[fm removeItemAtPath:[dir stringByAppendingPathComponent:file] error:nil];
	}
}

@end
