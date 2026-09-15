#import "TGStoryAudience.h"

BOOL TGStoryAudienceAllowsExceptions(NSString *privacy) {
	if (![privacy isKindOfClass:NSString.class])
		return NO;
	return [privacy isEqualToString:@"everyone"] || [privacy isEqualToString:@"contacts"];
}

NSArray *TGStoryAudienceExceptionsAfterChange(NSString *fromPrivacy,
	NSString *toPrivacy,
	NSArray *userIds) {
	if (!TGStoryAudienceAllowsExceptions(toPrivacy))
		return nil;
	if (!TGStoryAudienceAllowsExceptions(fromPrivacy))
		return nil;
	if (![userIds isKindOfClass:NSArray.class] || userIds.count == 0)
		return nil;
	return userIds;
}
