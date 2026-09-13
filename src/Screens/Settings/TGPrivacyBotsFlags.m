#import "TGPrivacyBotsFlags.h"

void TGPrivacyEffectiveBotsFlags(NSString *value, BOOL allowBots, BOOL restrictBots,
	BOOL *effectiveAllowBots, BOOL *effectiveRestrictBots) {
	BOOL baseIsEverybody = [value isKindOfClass:[NSString class]] &&
		[value isEqualToString:@"everybody"];
	if (effectiveAllowBots)
		*effectiveAllowBots = baseIsEverybody ? NO : allowBots;
	if (effectiveRestrictBots)
		*effectiveRestrictBots = baseIsEverybody ? restrictBots : NO;
}
