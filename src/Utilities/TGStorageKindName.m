#import "TGStorageKindName.h"
#import "TGLocalization.h"

NSString *TGStorageKindName(NSString *kind) {
	if ([kind isEqualToString:@"fileTypePhoto"])
		return TGL(@"Cache.Photos", @"Photos");
	if ([kind isEqualToString:@"fileTypeVideo"])
		return TGL(@"Cache.Videos", @"Videos");
	if ([kind isEqualToString:@"fileTypeVideoNote"])
		return TGL(@"AutoDownloadSettings.VideoMessagesTitle", @"Video Messages");
	if ([kind isEqualToString:@"fileTypeAnimation"])
		return TGL(@"Stickers.Gifs", @"GIFs");
	if ([kind isEqualToString:@"fileTypeDocument"])
		return TGL(@"StorageManagement.SectionFiles", @"Files");
	if ([kind isEqualToString:@"fileTypeAudio"])
		return TGL(@"Cache.Music", @"Music");
	if ([kind isEqualToString:@"fileTypeVoiceNote"])
		return TGL(@"AutoDownloadSettings.VoiceMessagesTitle", @"Voice Messages");
	if ([kind isEqualToString:@"fileTypeSticker"])
		return TGL(@"StorageManagement.SectionStickers", @"Stickers");
	if ([kind isEqualToString:@"fileTypeProfilePhoto"])
		return TGL(@"Cache.ProfilePhotos", @"Profile photos");
	if ([kind isEqualToString:@"fileTypeThumbnail"])
		return TGL(@"Cache.Thumbnails", @"Thumbnails");
	if ([kind isEqualToString:@"fileTypeWallpaper"])
		return TGL(@"Cache.Wallpapers", @"Wallpapers");
	if ([kind isEqualToString:@"fileTypeSecret"])
		return TGL(@"Cache.SecretMedia", @"Secret media");
	if ([kind isEqualToString:@"fileTypeSecretThumbnail"])
		return TGL(@"Cache.SecretThumbnails", @"Secret thumbnails");
	if ([kind isEqualToString:@"fileTypePhotoStory"] ||
		[kind isEqualToString:@"fileTypeSelfDestructingPhoto"])
		return TGL(@"Cache.Photos", @"Photos");
	if ([kind isEqualToString:@"fileTypeVideoStory"] ||
		[kind isEqualToString:@"fileTypeLivePhotoVideo"] ||
		[kind isEqualToString:@"fileTypeSelfDestructingVideo"] ||
		[kind isEqualToString:@"fileTypeSelfDestructingLivePhotoVideo"])
		return TGL(@"Cache.Videos", @"Videos");
	if ([kind isEqualToString:@"fileTypeSelfDestructingVideoNote"])
		return TGL(@"AutoDownloadSettings.VideoMessagesTitle", @"Video Messages");
	if ([kind isEqualToString:@"fileTypeSelfDestructingVoiceNote"])
		return TGL(@"AutoDownloadSettings.VoiceMessagesTitle", @"Voice Messages");
	if ([kind isEqualToString:@"fileTypeNotificationSound"])
		return TGL(@"Notifications.SoundsSection", @"Sounds");
	if ([kind hasPrefix:@"fileType"])
		return TGL(@"Storage.OtherFiles", @"Other files");
	return kind;
}
