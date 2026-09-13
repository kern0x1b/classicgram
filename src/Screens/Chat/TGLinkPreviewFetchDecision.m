#import "TGLinkPreviewFetchDecision.h"

NSString *const TGLinkPreviewOptionURL = @"url";
NSString *const TGLinkPreviewOptionForceSmallMedia = @"forceSmallMedia";
NSString *const TGLinkPreviewOptionForceLargeMedia = @"forceLargeMedia";
NSString *const TGLinkPreviewOptionShowAboveText = @"showAboveText";

BOOL TGLinkPreviewFetchCandidateText(NSString *text) {
	return text.length > 0;
}

BOOL TGLinkPreviewOptionsAreDisabled(NSDictionary *linkPreviewOptions) {
	if (![linkPreviewOptions isKindOfClass:[NSDictionary class]])
		return NO;
	return [linkPreviewOptions[@"is_disabled"] boolValue];
}

NSDictionary *TGLinkPreviewOptionValuesFromMessage(NSDictionary *linkPreviewOptions) {
	if (![linkPreviewOptions isKindOfClass:[NSDictionary class]]) {
		return @{
			TGLinkPreviewOptionURL : @"",
			TGLinkPreviewOptionForceSmallMedia : @NO,
			TGLinkPreviewOptionForceLargeMedia : @NO,
			TGLinkPreviewOptionShowAboveText : @NO,
		};
	}
	NSString *url = [linkPreviewOptions[@"url"] isKindOfClass:[NSString class]] ? linkPreviewOptions[@"url"] : @"";
	return @{
		TGLinkPreviewOptionURL : url,
		TGLinkPreviewOptionForceSmallMedia : @([linkPreviewOptions[@"force_small_media"] boolValue]),
		TGLinkPreviewOptionForceLargeMedia : @([linkPreviewOptions[@"force_large_media"] boolValue]),
		TGLinkPreviewOptionShowAboveText : @([linkPreviewOptions[@"show_above_text"] boolValue]),
	};
}
