#import "TGPasswordCheckOutcome.h"

TGPasswordCheckOutcome TGPasswordCheckOutcomeForError(NSString *errorMessage, BOOL gotAnswer) {
	if (gotAnswer)
		return TGPasswordCheckOutcomeAccepted;
	if (!errorMessage.length)
		return TGPasswordCheckOutcomeNotChecked;
	if ([errorMessage rangeOfString:@"PASSWORD_HASH_INVALID"].location != NSNotFound)
		return TGPasswordCheckOutcomeWrongPassword;
	if ([errorMessage rangeOfString:@"PASSWORD"].location != NSNotFound &&
			[errorMessage rangeOfString:@"INVALID"].location != NSNotFound)
		return TGPasswordCheckOutcomeWrongPassword;
	return TGPasswordCheckOutcomeNotChecked;
}
