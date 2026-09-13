#import "TGAuthErrorMessage.h"
#import "TGLocalization.h"

NSString *TGAuthErrorMessage(NSString *rawMessage) {
	NSString *raw = [rawMessage isKindOfClass:[NSString class]] ? rawMessage : @"";
	NSString *code = [[raw stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

	if ([code isEqualToString:@"PHONE_CODE_INVALID"] || [code isEqualToString:@"PHONE_CODE_EMPTY"] ||
		[code isEqualToString:@"CODE_INVALID"])
		return TGL(@"Login.InvalidCodeError", @"Invalid code, please try again.");
	if ([code isEqualToString:@"PHONE_CODE_EXPIRED"])
		return TGL(@"Login.CodeExpiredError", @"That code has expired. Please request a new one.");
	if ([code isEqualToString:@"PHONE_NUMBER_INVALID"])
		return TGL(@"Login.InvalidPhoneError", @"That phone number is not valid.");
	if ([code isEqualToString:@"PHONE_NUMBER_BANNED"] || [code isEqualToString:@"USER_DEACTIVATED_BAN"])
		return TGL(@"Login.PhoneBannedError", @"This phone number is banned.");
	if ([code isEqualToString:@"PASSWORD_HASH_INVALID"] || [code isEqualToString:@"PASSWORD_INVALID"])
		return TGL(@"TwoStepAuth.ThatPasswordIsWrong", @"That password is wrong.");
	if ([code isEqualToString:@"PHONE_NUMBER_OCCUPIED"])
		return TGL(@"Login.PhoneNumberOccupiedError", @"That phone number is already in use.");
	if ([code isEqualToString:@"FIRSTNAME_INVALID"] || [code isEqualToString:@"LASTNAME_INVALID"])
		return TGL(@"Login.InvalidNameError", @"Please enter your name.");

	return TGL(@"Login.UnknownError", @"An error occurred, please try again later.");
}
