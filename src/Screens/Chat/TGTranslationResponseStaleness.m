#import "TGTranslationResponseStaleness.h"

BOOL TGTranslationResponseIsStale(NSDictionary<NSNumber *, NSNumber *> *pendingTranslationGenerations, NSNumber *messageKey, NSNumber *requestGeneration) {
	if (!messageKey || !requestGeneration)
		return YES;
	if (![pendingTranslationGenerations isKindOfClass:[NSDictionary class]])
		return YES;
	return ![pendingTranslationGenerations[messageKey] isEqual:requestGeneration];
}
