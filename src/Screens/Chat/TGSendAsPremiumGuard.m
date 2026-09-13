#import "TGSendAsPremiumGuard.h"

BOOL TGSendAsSenderRequiresPremiumUpgrade(NSDictionary *sender, BOOL accountIsPremium) {
	if (![sender isKindOfClass:[NSDictionary class]])
		return NO;
	if (accountIsPremium)
		return NO;
	return [sender[@"needsPremium"] boolValue];
}
