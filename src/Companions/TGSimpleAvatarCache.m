#import "TGSimpleAvatarCache.h"
#import "TGStringTruncation.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGIcons.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"

@implementation TGSimpleAvatarCache {
	CGFloat _avatarSide;
	NSMutableDictionary *_avatarImages;
	NSMutableSet *_avatarsRequested;
	NSMutableSet *_avatarsWithPhoto;
	NSMutableDictionary *_placeholderTitles;
}

- (instancetype)initWithAvatarSide:(CGFloat)avatarSide {
	self = [super init];
	if (self) {
		_avatarSide = avatarSide;
		_avatarImages = [NSMutableDictionary dictionary];
		_avatarsRequested = [NSMutableSet set];
		_avatarsWithPhoto = [NSMutableSet set];
		_placeholderTitles = [NSMutableDictionary dictionary];
	}
	return self;
}

- (UIImage *)avatarForChatId:(int64_t)chatId title:(NSString *)title {
	NSNumber *key = @(chatId);
	NSString *safeTitle = title ?: @"";
	UIImage *cached = _avatarImages[key];
	if (cached && ([_avatarsWithPhoto containsObject:key] || [_placeholderTitles[key] isEqualToString:safeTitle]))
		return cached;

	NSString *initials = title.length ? TGSafeFirstCharacter(title).uppercaseString : @"?";
	UIImage *placeholder = [TGIcons avatarWithInitials:initials size:_avatarSide colourId:chatId];
	_avatarImages[key] = placeholder;
	_placeholderTitles[key] = safeTitle;

	if ([_avatarsRequested containsObject:key])
		return placeholder;
	[_avatarsRequested addObject:key];

	CGFloat side = _avatarSide;
	__weak typeof(self) weakSelf = self;
	void (^fetch)(NSNumber *) = ^(NSNumber *fileId) {
		if (!fileId || [fileId longLongValue] <= 0)
			return;
		[TGFileDownloadService downloadFile:[fileId longLongValue] completion:^(NSString *path) {
			if (!path.length)
				return;
			dispatch_async(TGImageDecodeQueue(), ^{
				UIImage *photo = TGDecodeSquareThumbnail(path, side);
				if (!photo)
					return;
				dispatch_async(dispatch_get_main_queue(), ^{
					TGSimpleAvatarCache *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					strongSelf->_avatarImages[key] = photo;
					[strongSelf->_avatarsWithPhoto addObject:key];
					[strongSelf.tableView reloadData];
				});
			});
		}];
	};

	NSNumber *cachedFile = [[TGClient shared] photoFileIdForChat:chatId];
	if (cachedFile && cachedFile.integerValue > 0) {
		fetch(cachedFile);
		return placeholder;
	}
	[[TGClient shared] photoFileIdForChat:chatId completion:fetch];
	return placeholder;
}

@end
