#import "TGCustomEmojiCache.h"
#import "TGStickerCatalogService.h"
#import "TGStickerThumbnailCache.h"

NSString *const TGCustomEmojiImagesDidChangeNotification = @"TGCustomEmojiImagesDidChangeNotification";

static const CGFloat kTGCustomEmojiSide = 24.0f;

static NSCache *TGCustomEmojiImageMemory(void) {
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
		[cache setCountLimit:256];
	});
	return cache;
}

static NSMutableSet *TGCustomEmojiPending(void) {
	static NSMutableSet *set = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		set = [[NSMutableSet alloc] init];
	});
	return set;
}

UIImage *TGCustomEmojiCachedImage(long long customEmojiId) {
	if (!customEmojiId)
		return nil;
	return [TGCustomEmojiImageMemory() objectForKey:@(customEmojiId)];
}

static void TGCustomEmojiNotifyChanged(void) {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGCustomEmojiImagesDidChangeNotification
					  object:nil];
}

void TGCustomEmojiRequestImage(long long customEmojiId) {
	if (!customEmojiId)
		return;
	NSNumber *key = @(customEmojiId);
	NSMutableSet *pending = TGCustomEmojiPending();
	if (TGCustomEmojiCachedImage(customEmojiId) || [pending containsObject:key])
		return;
	[pending addObject:key];

	[TGStickerCatalogService customEmojiStickersWithIds:@[ key ] completion:^(NSArray *stickers) {
		NSDictionary *sticker = [stickers isKindOfClass:[NSArray class]] && stickers.count
			? stickers[0]
			: nil;
		long long thumbId = [sticker[@"thumbId"] longLongValue];
		long long fileId = thumbId > 0 ? thumbId : [sticker[@"fileId"] longLongValue];
		NSString *uniqueId = thumbId > 0
			? (([sticker[@"thumbUniqueId"] isKindOfClass:[NSString class]])
					  ? sticker[@"thumbUniqueId"]
					  : nil)
			: (([sticker[@"uniqueId"] isKindOfClass:[NSString class]])
					  ? sticker[@"uniqueId"]
					  : nil);

		if (fileId <= 0) {
			[pending removeObject:key];
			return;
		}

		[TGStickerThumbnailCache thumbnailForFileId:fileId uniqueId:uniqueId
											   side:kTGCustomEmojiSide
										 completion:^(UIImage *image) {
											 [pending removeObject:key];
											 if (!image)
												 return;
											 [TGCustomEmojiImageMemory() setObject:image forKey:key];
											 TGCustomEmojiNotifyChanged();
										 }];
	}];
}
