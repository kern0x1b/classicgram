#import "TGResultIsError.h"

BOOL TGResultIsError(NSDictionary *result) {
	if (![result isKindOfClass:NSDictionary.class])
		return YES;
	id type = result[@"@type"];
	return [type isKindOfClass:NSString.class] && [type isEqualToString:@"error"];
}
