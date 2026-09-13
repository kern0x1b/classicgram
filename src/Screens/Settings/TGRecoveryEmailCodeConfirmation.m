#import "TGRecoveryEmailCodeConfirmation.h"

BOOL TGRecoveryEmailCodeWasConfirmed(NSDictionary *state) {
	if (![state isKindOfClass:[NSDictionary class]])
		return NO;
	id pattern = state[@"recoveryEmailPattern"];
	if ([pattern isKindOfClass:[NSString class]] && [pattern length])
		return NO;
	return YES;
}
