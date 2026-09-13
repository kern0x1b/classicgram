#import "TGFlattenAccount.h"
#import "TGLocalization.h"

static NSDictionary *TGFADict(id value) {
	if (![value isKindOfClass:[NSDictionary class]])
		return nil;
	return value;
}

static NSString *TGFAString(id value) {
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return value;
}

static NSNumber *TGFANumber(id value) {
	if (![value isKindOfClass:[NSNumber class]])
		return @0;
	return value;
}

static NSNumber *TGFABool(id value) {
	if (![value isKindOfClass:[NSNumber class]])
		return @NO;
	return [value boolValue] ? @YES : @NO;
}

NSString *TGAccountCodeDescription(NSDictionary *type, NSString *phone) {
	NSString *name = TGFAString(type[@"@type"]);
	if ([name isEqualToString:@"authenticationCodeTypeTelegramMessage"])
		return [NSString stringWithFormat:TGL(@"Login.EnterCodeTelegramText", @"We've sent the code to the Telegram app for %@ on your other device."),
			phone.length ? phone : TGL(@"Login.Account.YourPhone", @"your phone")];
	if ([name isEqualToString:@"authenticationCodeTypeSms"] ||
		[name isEqualToString:@"authenticationCodeTypeSmsWord"] ||
		[name isEqualToString:@"authenticationCodeTypeSmsPhrase"] ||
		[name isEqualToString:@"authenticationCodeTypeFirebaseAndroid"] ||
		[name isEqualToString:@"authenticationCodeTypeFirebaseIos"])
		return [NSString stringWithFormat:TGL(@"Login.EnterCodeSMSText", @"We've sent an SMS with an activation code to your phone %@."),
			phone.length ? phone : TGL(@"Login.Account.YourPhone", @"your phone")];
	if ([name isEqualToString:@"authenticationCodeTypeCall"])
		return TGL(@"Login.CodeSentCall", @"We are calling your phone to dictate a code.");
	if ([name isEqualToString:@"authenticationCodeTypeMissedCall"])
		return TGL(@"Login.CodePhonePatternInfoText", @"Please enter the last digits\nof the number that called.");
	if ([name isEqualToString:@"authenticationCodeTypeFlashCall"])
		return TGL(@"Login.Account.FlashCallNotice", @"We are calling your phone. Do not answer.");
	if ([name isEqualToString:@"authenticationCodeTypeFragment"])
		return [NSString stringWithFormat:TGL(@"Login.EnterCodeFragmentText", @"Get the code for %@ in the Anonymous Numbers section on Fragment."),
			phone.length ? phone : TGL(@"Login.Account.YourPhone", @"your phone")];
	if (name.length)
		return TGL(@"Login.Account.EnterCodeReceived", @"Enter the code you received.");
	return @"";
}

NSString *TGAccountNextTitle(NSDictionary *type) {
	NSString *name = TGFAString(type[@"@type"]);
	if ([name isEqualToString:@"authenticationCodeTypeCall"] ||
		[name isEqualToString:@"authenticationCodeTypeMissedCall"] ||
		[name isEqualToString:@"authenticationCodeTypeFlashCall"])
		return TGL(@"Login.SendCodeViaCall", @"Call me to dictate the code");
	if ([name isEqualToString:@"authenticationCodeTypeSms"] ||
		[name isEqualToString:@"authenticationCodeTypeSmsWord"] ||
		[name isEqualToString:@"authenticationCodeTypeSmsPhrase"])
		return TGL(@"Login.SendCodeViaSms", @"Send the code as an SMS");
	if ([name isEqualToString:@"authenticationCodeTypeFragment"])
		return TGL(@"Login.GetCodeViaFragment", @"Get a code via Fragment");
	if ([name isEqualToString:@"authenticationCodeTypeTelegramMessage"])
		return TGL(@"Login.Account.SendCodeViaTelegram", @"Send code via Telegram");
	if (name.length)
		return TGL(@"Login.Account.SendCodeAgain", @"Send code again");
	return @"";
}

static NSInteger TGAccountCodeLength(NSDictionary *type) {
	NSDictionary *safe = TGFADict(type);
	if (!safe)
		return 0;
	return [TGFANumber(safe[@"length"]) integerValue];
}

NSDictionary *TGAccountCodeInfoDict(NSDictionary *codeInfo) {
	NSDictionary *info = TGFADict(codeInfo);
	if (!info)
		return nil;
	NSString *phone = TGFAString(info[@"phone_number"]);
	NSDictionary *type = TGFADict(info[@"type"]);
	NSDictionary *next = TGFADict(info[@"next_type"]);
	return @{
		@"phone" : phone,
		@"type" : TGFAString(type[@"@type"]),
		@"description" : TGAccountCodeDescription(type, phone),
		@"length" : @(TGAccountCodeLength(type)),
		@"timeout" : TGFANumber(info[@"timeout"]),
		@"nextType" : TGFAString(next[@"@type"]),
		@"nextDescription" : TGAccountNextTitle(next),
	};
}

NSDictionary *TGAccountEmailCodeInfo(NSDictionary *codeInfo) {
	NSDictionary *info = TGFADict(codeInfo);
	if (!info)
		return nil;
	return @{
		@"pattern" : TGFAString(info[@"email_address_pattern"]),
		@"codeLength" : TGFANumber(info[@"length"]),
	};
}

NSDictionary *TGAccountSessionDict(NSDictionary *session) {
	NSDictionary *safe = TGFADict(session);
	if (!safe)
		return nil;
	return @{
		@"id" : safe[@"id"] ?: @0,
		@"appName" : TGFAString(safe[@"application_name"]),
		@"deviceModel" : TGFAString(safe[@"device_model"]),
		@"platform" : [NSString stringWithFormat:@"%@ %@",
			TGFAString(safe[@"platform"]),
			TGFAString(safe[@"system_version"])],
		@"ip" : TGFAString(safe[@"ip_address"]),
		@"location" : TGFAString(safe[@"location"]),
		@"isPasswordPending" : TGFABool(safe[@"is_password_pending"]),
		@"isUnconfirmed" : TGFABool(safe[@"is_unconfirmed"]),
	};
}
