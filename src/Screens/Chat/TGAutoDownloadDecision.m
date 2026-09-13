#import "TGAutoDownloadDecision.h"

NSString *const TGAutoDownloadCategoryPhoto = @"photo";
NSString *const TGAutoDownloadCategoryVideo = @"video";
NSString *const TGAutoDownloadCategoryOther = @"other";

NSString *TGAutoDownloadCategoryForKind(NSString *kind) {
	if ([kind isEqualToString:@"messagePhoto"])
		return TGAutoDownloadCategoryPhoto;
	if ([kind isEqualToString:@"messageVideo"] || [kind isEqualToString:@"messageVideoNote"])
		return TGAutoDownloadCategoryVideo;
	return TGAutoDownloadCategoryOther;
}

static long long TGAutoDownloadCapForCategory(NSDictionary *settings, NSString *category) {
	if ([category isEqualToString:TGAutoDownloadCategoryPhoto])
		return [settings[@"maxPhotoSize"] longLongValue];
	if ([category isEqualToString:TGAutoDownloadCategoryVideo])
		return [settings[@"maxVideoSize"] longLongValue];
	return [settings[@"maxOtherSize"] longLongValue];
}

BOOL TGShouldAutoDownloadFile(NSDictionary *settings, NSString *category, long long fileSize) {
	if (![settings isKindOfClass:[NSDictionary class]])
		return YES;
	if (![settings[@"enabled"] boolValue])
		return NO;
	long long cap = TGAutoDownloadCapForCategory(settings, category);
	if (cap <= 0)
		return NO;
	if (fileSize > 0 && fileSize > cap)
		return NO;
	return YES;
}

NSDictionary *TGAutoDownloadSettingsMergedForMobile(NSDictionary *mobile, NSDictionary *roaming) {
	if (![mobile isKindOfClass:[NSDictionary class]])
		return roaming;
	if (![roaming isKindOfClass:[NSDictionary class]])
		return mobile;
	return @{
		@"enabled" : @([mobile[@"enabled"] boolValue] && [roaming[@"enabled"] boolValue]),
		@"maxPhotoSize" : @(MIN([mobile[@"maxPhotoSize"] longLongValue], [roaming[@"maxPhotoSize"] longLongValue])),
		@"maxVideoSize" : @(MIN([mobile[@"maxVideoSize"] longLongValue], [roaming[@"maxVideoSize"] longLongValue])),
		@"maxOtherSize" : @(MIN([mobile[@"maxOtherSize"] longLongValue], [roaming[@"maxOtherSize"] longLongValue])),
	};
}
