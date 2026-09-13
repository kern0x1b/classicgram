#import "TGClient+UpdateHandling.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Files.h"
#import "TGMessageRowCell.h"
#import "TGMosaicTileView.h"
#import "TGImageDecode.h"
#import "AppDelegate.h"
#import "TGMusicPlayer.h"
#import "UIImage+WebP.h"
#import "TGAutoDownloadDecision.h"
#import "TGReachabilityMonitor.h"
#import "TGSettingsService.h"

static NSDictionary *TGChatCurrentAutoDownloadSettings(void) {
	NSString *liveKind = [TGReachabilityMonitor shared].currentNetworkTypeKind;
	if (![liveKind isKindOfClass:[NSString class]] || !liveKind.length)
		liveKind = @"other";
	if ([liveKind isEqualToString:@"mobile"]) {
		NSDictionary *mobile = [TGSettingsService autoDownloadSettingsForNetworkType:@"mobile"];
		NSDictionary *roaming = [TGSettingsService autoDownloadSettingsForNetworkType:@"roaming"];
		return TGAutoDownloadSettingsMergedForMobile(mobile, roaming);
	}
	if ([liveKind isEqualToString:@"none"])
		return [TGSettingsService autoDownloadSettingsForNetworkType:@"other"];
	return [TGSettingsService autoDownloadSettingsForNetworkType:liveKind];
}

@implementation TGChatViewController (Downloads)

- (void)beginDownloadHUDForFile:(long long)fileId {
	[self endDownloadHUD];
	self.downloadingFileId = fileId;

	if (!self.downloadHUD) {
		const CGFloat side = 100.0f;
		self.downloadHUD = [[UIView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
		self.downloadHUD.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7f];
		self.downloadHUD.layer.cornerRadius = 12;
		self.downloadHUD.userInteractionEnabled = NO;
		self.downloadHUD.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin |
			UIViewAutoresizingFlexibleTopMargin |
			UIViewAutoresizingFlexibleBottomMargin;

		self.downloadSpinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		self.downloadSpinner.center = CGPointMake(side / 2, side / 2 - 8);
		[self.downloadHUD addSubview:self.downloadSpinner];

		self.downloadPercent = [[UILabel alloc] initWithFrame:
				CGRectMake(0, side - 30, side, 20)];
		self.downloadPercent.textAlignment = NSTextAlignmentCenter;
		self.downloadPercent.font = [UIFont boldSystemFontOfSize:15];
		self.downloadPercent.textColor = [UIColor whiteColor];
		self.downloadPercent.backgroundColor = [UIColor clearColor];
		[self.downloadHUD addSubview:self.downloadPercent];
	}
	self.downloadPercent.text = @"0%";
	self.downloadHUD.center = CGPointMake(floorf(self.view.bounds.size.width / 2),
		floorf(self.view.bounds.size.height / 2));
	self.downloadHUD.alpha = 0.0f;
	self.downloadHUD.hidden = NO;
	[self.downloadSpinner startAnimating];
	[self.view addSubview:self.downloadHUD];
	[UIView animateWithDuration:0.3 delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{ self.downloadHUD.alpha = 1.0f; }
					 completion:nil];

	__weak typeof(self) weakSelf = self;
	self.fileProgressObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGFileProgressDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGChatViewController *strongSelf = weakSelf;
					long long updatedId = [note.userInfo[TGFileProgressFileIdKey] longLongValue];
					if (!strongSelf || updatedId != strongSelf.downloadingFileId)
						return;
					float progress = [note.userInfo[TGFileProgressValueKey] floatValue];
					strongSelf.downloadPercent.text = [NSString stringWithFormat:@"%d%%",
						(int)(progress * 100)];
				}];
}

- (void)endDownloadHUDForFile:(long long)fileId {
	if (fileId != self.downloadingFileId)
		return;
	[self endDownloadHUD];
}

- (void)endDownloadHUD {
	self.downloadingFileId = 0;
	if (self.fileProgressObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.fileProgressObserverToken];
		self.fileProgressObserverToken = nil;
	}
	if (!self.downloadHUD || self.downloadHUD.hidden)
		return;
	UIView *hud = self.downloadHUD;
	UIActivityIndicatorView *spinner = self.downloadSpinner;
	[UIView animateWithDuration:0.3 delay:0.0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{ hud.alpha = 0.0f; }
		completion:^(BOOL finished) {
			if (!finished || hud.alpha > 0.01f)
				return;
			[spinner stopAnimating];
			hud.hidden = YES;
			[hud removeFromSuperview];
		}];
}

- (NSRange)visiblePictureWindow {
	NSInteger count = [self displayRowCount];
	if (count <= 0)
		return NSMakeRange(0, 0);

	NSInteger first = NSNotFound;
	NSInteger last = NSNotFound;
	for (NSIndexPath *path in [self.table indexPathsForVisibleRows]) {
		if (path.row < 0 || path.row >= count)
			continue;
		if (first == NSNotFound || path.row < first)
			first = path.row;
		if (last == NSNotFound || path.row > last)
			last = path.row;
	}
	if (first == NSNotFound) {
		first = MAX(0, count - 12);
		last = count - 1;
	}
	first = MAX(0, first - 3);
	last = MIN(count - 1, last + 3);
	if (last < first)
		return NSMakeRange(0, 0);
	return NSMakeRange((NSUInteger)first, (NSUInteger)(last - first + 1));
}

- (void)fetchVisiblePictures {
	if (![self displayRowCount])
		return;
	NSRange window = [self visiblePictureWindow];
	if (window.location == self.photoWindow.location &&
		window.length == self.photoWindow.length)
		return;
	self.photoWindow = window;

	NSMutableSet *wanted = [NSMutableSet set];
	NSMutableArray *byProximity = [NSMutableArray array];
	NSMutableDictionary *limits = [NSMutableDictionary dictionary];
	NSMutableDictionary *kinds = [NSMutableDictionary dictionary];
	NSMutableDictionary *messagesByFileId = [NSMutableDictionary dictionary];
	NSInteger centre = window.location + window.length / 2;
	for (NSInteger step = (NSInteger)window.length; step >= 0; step--) {
		for (NSInteger side = 0; side < 2; side++) {
			NSInteger row = (NSInteger)centre + (side ? step : -step);
			if (row < (NSInteger)window.location ||
				row >= (NSInteger)(window.location + window.length))
				continue;
			for (NSDictionary *m in [self messagesAtRow:row]) {
				NSNumber *fileId = [self pictureFileIdFor:m];
				if (!fileId)
					continue;
				CGFloat limit = [self decodeLimitFor:m];
				if (limit > [limits[fileId] floatValue])
					limits[fileId] = @(limit);
				kinds[fileId] = m[@"kind"];
				messagesByFileId[fileId] = m;
				if ([wanted containsObject:fileId])
					continue;
				[wanted addObject:fileId];
				[byProximity addObject:fileId];
			}
			if (!step)
				break;
		}
	}
	for (NSDictionary *quoted in [self.quotes allValues]) {
		NSNumber *fileId = [self pictureFileIdFor:quoted];
		if (!fileId)
			continue;
		CGFloat limit = [self decodeLimitFor:quoted];
		if (limit > [limits[fileId] floatValue])
			limits[fileId] = @(limit);
		kinds[fileId] = quoted[@"kind"];
		if (![wanted containsObject:fileId]) {
			[wanted addObject:fileId];
			[byProximity insertObject:fileId atIndex:0];
		}
	}

	if (byProximity.count > kMaxLivePictures) {
		NSRange far = NSMakeRange(0, byProximity.count - kMaxLivePictures);
		[wanted minusSet:[NSSet setWithArray:[byProximity subarrayWithRange:far]]];
		[byProximity removeObjectsInRange:far];
	}

	for (NSNumber *fileId in [self.photoFilesInFlight allObjects]) {
		if ([wanted containsObject:fileId])
			continue;
		if ([fileId longLongValue] == self.downloadingFileId)
			continue;
		[[TGClient shared] cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:NO];
		[self.photoFilesInFlight removeObject:fileId];
		[self.photoFilesCancelled addObject:fileId];
		[self.imagesRequested removeObject:fileId];
	}

	NSDictionary *autoDownloadSettings = TGChatCurrentAutoDownloadSettings();
	for (NSNumber *fileId in wanted) {
		if (self.images[fileId])
			continue;
		if ([self.photoFilesFailed containsObject:fileId])
			continue;
		if ([self.imagesRequested containsObject:fileId])
			continue;
		NSString *kind = kinds[fileId];
		NSString *category = TGAutoDownloadCategoryForKind(kind);
		long long knownSize = [[[TGClient shared] knownStateOfFile:[fileId longLongValue]][@"size"] longLongValue];
		if (!TGShouldAutoDownloadFile(autoDownloadSettings, category, knownSize)) {
			if ([kind isEqualToString:@"messagePhoto"]) {
				[self.photoFilesFailed addObject:fileId];
				[self refreshRowsShowingFile:fileId withImage:nil];
			}
			continue;
		}
		CGFloat limit = [limits[fileId] floatValue];
		[self startPictureDownload:fileId
					   decodeLimit:limit >= 1 ? limit : [self pictureDecodeLimit]];
		if ([kind isEqualToString:@"messagePhoto"]) {
			NSDictionary *m = messagesByFileId[fileId];
			if (m)
				[self autosaveMessageIfNeeded:m];
		}
	}

	[self prunePicturesInUseOrder:byProximity];
}

- (void)prunePicturesInUseOrder:(NSArray *)nearestLast {
	for (NSNumber *fileId in nearestLast) {
		[self.imageOrder removeObject:fileId];
		[self.imageOrder addObject:fileId];
	}

	NSInteger budget = 0;
	NSMutableSet *keep = [NSMutableSet set];
	for (NSNumber *fileId in [self.imageOrder reverseObjectEnumerator]) {
		UIImage *image = self.images[fileId];
		if (!image)
			continue;
		NSInteger cost = TGImageBitmapBytes(image);
		if (keep.count && budget + cost > kPictureMemoryBudget)
			continue;
		budget += cost;
		[keep addObject:fileId];
	}

	for (NSNumber *fileId in [self.images allKeys]) {
		if ([keep containsObject:fileId])
			continue;
		[self.images removeObjectForKey:fileId];
		[self.imagesRequested removeObject:fileId];
		[self.imageOrder removeObject:fileId];
	}
	[self dropTileBitmapsOutside:keep];

	if (!TGPerfLogging())
		return;
	NSInteger tiles = 0;
	for (UIImage *image in [self.tileBitmaps allValues])
		tiles += TGImageBitmapBytes(image);
	NSInteger thumbs = 0;
	for (id image in [self.minithumbnails allValues])
		if ([image isKindOfClass:[UIImage class]])
			thumbs += TGImageBitmapBytes(image);
	NSInteger avatars = 0;
	for (UIImage *image in [self.senderAvatars allValues])
		avatars += TGImageBitmapBytes(image);
	NSLog(@"PERF chatmem pictures=%u/%.2f MB tiles=%u/%.2f MB thumbs=%u/%.2f MB avatars=%.2f MB",
		(unsigned)self.images.count, budget / 1048576.0,
		(unsigned)self.tileBitmaps.count, tiles / 1048576.0,
		(unsigned)self.minithumbnails.count, thumbs / 1048576.0,
		avatars / 1048576.0);
}

- (void)dropTileBitmapsOutside:(NSSet *)keep {
	if (!self.tileBitmaps.count)
		return;
	NSMutableSet *live = [NSMutableSet set];
	for (NSNumber *fileId in keep)
		[live addObject:[fileId stringValue]];
	for (NSString *key in [self.tileBitmaps allKeys]) {
		NSRange at = [key rangeOfString:@"@"];
		if (at.location == NSNotFound)
			continue;
		if (![live containsObject:[key substringToIndex:at.location]])
			[self.tileBitmaps removeObjectForKey:key];
	}
}

- (CGFloat)pictureDecodeLimit {
	CGFloat scale = [UIScreen mainScreen].scale;
	if (scale < 1.0f)
		scale = 1.0f;
	return MAX(kImageMax, [self bubbleWidthBudget]) * scale;
}

- (void)pictureFailed:(NSNumber *)fileId {
	[self.imagesRequested removeObject:fileId];
	[self.photoFilesFailed addObject:fileId];
	[self refreshRowsShowingFile:fileId withImage:nil];
}

- (void)startPictureDownload:(NSNumber *)fileId decodeLimit:(CGFloat)limit {
	if (!fileId)
		return;
	[self.imagesRequested addObject:fileId];
	[self.photoFilesInFlight addObject:fileId];
	[self.photoFilesCancelled removeObject:fileId];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:[fileId longLongValue] completion:^(NSString *path) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.photoFilesInFlight removeObject:fileId];
		if ([strongSelf.photoFilesCancelled containsObject:fileId]) {
			[strongSelf.photoFilesCancelled removeObject:fileId];
			[strongSelf.imagesRequested removeObject:fileId];
			return;
		}
		if (!path.length) {
			[strongSelf pictureFailed:fileId];
			return;
		}

		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *img = nil;
			@autoreleasepool {
				img = TGDecodeThumbnail(path, limit);
				if (!img && [path.pathExtension.lowercaseString isEqualToString:@"webp"])
					img = TGImageWithinPixelLimit(
						[UIImage convertFromWebP:path compressedData:nil error:nil], limit);
			}
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *innerSelf = weakSelf;
				if (!innerSelf)
					return;
				if ([innerSelf.photoFilesCancelled containsObject:fileId]) {
					[innerSelf.photoFilesCancelled removeObject:fileId];
					[innerSelf.imagesRequested removeObject:fileId];
					return;
				}
				if (!img) {
					[innerSelf pictureFailed:fileId];
					return;
				}
				[innerSelf.photoFilesFailed removeObject:fileId];
				[innerSelf storeImage:img forFile:fileId];
				[innerSelf applyArrivedImage:img forFile:fileId];
			});
		});
	}];
}

- (BOOL)heightDependsOnBitmapForFile:(NSNumber *)fileId {
	for (NSDictionary *m in self.messages) {
		NSNumber *pictureId = [self pictureFileIdFor:m];
		if (!pictureId || ![pictureId isEqualToNumber:fileId])
			continue;
		CGSize declared = [self declaredPixelSizeFor:m];
		if (declared.width < 1 || declared.height < 1)
			return YES;
	}
	return NO;
}

- (void)storeImage:(UIImage *)image forFile:(NSNumber *)fileId {
	if (!image || ![fileId isKindOfClass:NSNumber.class])
		return;
	self.images[fileId] = image;
	[self.imageOrder removeObject:fileId];
	[self.imageOrder addObject:fileId];
}

- (void)applyArrivedImage:(UIImage *)img forFile:(NSNumber *)fileId {
	if ([self heightDependsOnBitmapForFile:fileId]) {
		[self setNeedsTableReloadKeepingBottom];
		return;
	}
	[self refreshRowsShowingFile:fileId withImage:img];
	[self refreshQuotesShowingFile:fileId];
}

- (void)refreshQuotesShowingFile:(NSNumber *)fileId {
	BOOL matched = NO;
	for (NSDictionary *original in [self.quotes allValues]) {
		NSNumber *photoId = [original[@"photoId"] isKindOfClass:NSNumber.class]
			? original[@"photoId"]
			: nil;
		if (!photoId || ![photoId isEqualToNumber:fileId])
			continue;
		NSNumber *originalId = [original[@"id"] isKindOfClass:NSNumber.class]
			? original[@"id"]
			: nil;
		if (!originalId)
			continue;
		[self tg_invalidateLayoutForRepliesToMessageId:originalId.longLongValue];
		matched = YES;
	}
	if (matched)
		[self setNeedsTableReload];
}

- (void)refreshRowsShowingFile:(NSNumber *)fileId withImage:(UIImage *)img {
	NSMutableArray *stale = [NSMutableArray array];
	for (NSIndexPath *path in [self.table indexPathsForVisibleRows]) {
		NSArray *album = [self albumAtRow:path.row];
		if (album) {
			for (NSDictionary *member in album) {
				NSNumber *tileId = [self pictureFileIdFor:member];
				if (tileId && [tileId isEqualToNumber:fileId]) {
					[stale addObject:path];
					break;
				}
			}
			continue;
		}
		NSDictionary *m = [self messageAtRow:path.row];
		NSNumber *pictureId = m ? [self pictureFileIdFor:m] : nil;
		if (!pictureId || ![pictureId isEqualToNumber:fileId])
			continue;
		UITableViewCell *raw = [self.table cellForRowAtIndexPath:path];
		if (!img) {
			[stale addObject:path];
			continue;
		}
		if ([raw isKindOfClass:[TGMessageRowCell class]])
			[self configureBitmapsForCell:(TGMessageRowCell *)raw atRow:path.row];
		else
			[stale addObject:path];
	}
	if (stale.count && !self.tableReloadPending)
		[self.table reloadRowsAtIndexPaths:stale
						  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)fileStateChanged:(NSNotification *)note {
	NSNumber *fileId = [note.userInfo[TGFileStateFileIdKey] isKindOfClass:NSNumber.class]
		? note.userInfo[TGFileStateFileIdKey]
		: nil;
	if (!fileId)
		return;
	[self refreshFileStatusForFile:fileId];

	for (NSDictionary *m in self.messages) {
		if (![m[@"kind"] isEqualToString:@"messageVoiceNote"])
			continue;
		NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
		if (!docId || ![docId isEqualToNumber:fileId])
			continue;
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (messageId)
			[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	}
	[self setNeedsTableReload];
}

- (void)refreshFileStatusForFile:(NSNumber *)fileId {
	for (NSIndexPath *path in [self.table indexPathsForVisibleRows]) {
		NSDictionary *m = [self messageAtRow:path.row];
		NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
		if (!docId || ![docId isEqualToNumber:fileId])
			continue;
		UITableViewCell *raw = [self.table cellForRowAtIndexPath:path];
		if ([raw isKindOfClass:[TGMessageRowCell class]])
			[self configureBitmapsForCell:(TGMessageRowCell *)raw atRow:path.row];
	}
}

@end
