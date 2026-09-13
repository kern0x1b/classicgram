#import "TGAutosaveDecision.h"

NSString *const TGAutosaveCategoryPhoto = @"photo";
NSString *const TGAutosaveCategoryVideo = @"video";

static const long long TGAutosaveDefaultMaxVideoBytes = 10 * 1024 * 1024;

NSString *TGAutosaveCategoryForKind(NSString *kind) {
	if ([kind isEqualToString:@"messagePhoto"])
		return TGAutosaveCategoryPhoto;
	if ([kind isEqualToString:@"messageVideo"])
		return TGAutosaveCategoryVideo;
	return nil;
}

BOOL TGShouldAutosaveFile(NSDictionary *scopeSettings, NSDictionary *chatException,
		NSString *category, long long fileSize) {
	NSDictionary *settings = [chatException isKindOfClass:[NSDictionary class]]
		? chatException
		: scopeSettings;
	if (![settings isKindOfClass:[NSDictionary class]])
		return NO;
	if ([category isEqualToString:TGAutosaveCategoryPhoto])
		return [settings[@"photos"] boolValue];
	if (![category isEqualToString:TGAutosaveCategoryVideo])
		return NO;
	if (![settings[@"videos"] boolValue])
		return NO;
	long long cap = [settings[@"maxVideoBytes"] longLongValue];
	if (cap <= 0)
		cap = TGAutosaveDefaultMaxVideoBytes;
	return fileSize <= 0 || fileSize <= cap;
}
