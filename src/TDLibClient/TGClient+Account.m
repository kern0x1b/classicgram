#import "TGClient+Private.h"
#import "TGDateUtils.h"
#import "TGClient+ChatState.h"
#import "TGClient+Account.h"
#import "TGClient+Storage.h"
#import "TGClient+WebLinks.h"
#import "TGInternalLinkUsername.h"
#import "TGFlattenAccount.h"
#import "TGFlattenMessageContent.h"
#import "TGLocalization.h"

static NSArray *TGAccountArray(id value) {
	if (![value isKindOfClass:[NSArray class]])
		return [NSArray array];
	return value;
}

static NSDictionary *TGAccountDict(id value) {
	if (![value isKindOfClass:[NSDictionary class]])
		return nil;
	return value;
}

static NSString *TGAccountString(id value) {
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return value;
}

static NSNumber *TGAccountNumber(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if ([value isKindOfClass:[NSString class]])
		return [NSNumber numberWithLongLong:[value longLongValue]];
	return @0;
}

static NSNumber *TGAccountBool(id value) {
	if (![value isKindOfClass:[NSNumber class]])
		return @NO;
	return [value boolValue] ? @YES : @NO;
}

static NSDictionary *TGAccountPhoneSettings(BOOL isCurrentNumber) {
	return @{
		@"@type" : @"phoneNumberAuthenticationSettings",
		@"allow_flash_call" : @NO,
		@"allow_missed_call" : @NO,
		@"is_current_phone_number" : isCurrentNumber ? @YES : @NO,
		@"has_unknown_phone_number" : @NO,
		@"allow_sms_retriever_api" : @NO,
		@"authentication_tokens" : [NSArray array],
	};
}

@interface TGClient (AccountInternal)
- (void)authorizationStateOfType:(NSString *)type
					  completion:(void (^)(NSDictionary *state))completion;
@end

NSString *const TGFreezeStateDidChangeNotification = @"TGFreezeStateDidChangeNotification";
NSString *const TGAgeVerificationParametersDidChangeNotification =
	@"TGAgeVerificationParametersDidChangeNotification";
NSString *const TGTermsOfServiceDidChangeNotification = @"TGTermsOfServiceDidChangeNotification";

@implementation TGClient (Account)

#pragma mark - frozen account

- (void)handleUpdateFreezeState:(NSDictionary *)update {
	NSDictionary *body = TGAccountDict(update);
	self.frozen = [body[@"is_frozen"] boolValue];
	self.freezingDate = [TGAccountNumber(body[@"freezing_date"]) longLongValue];
	self.freezeDeletionDate = [TGAccountNumber(body[@"deletion_date"]) longLongValue];
	self.freezeAppealLink = TGAccountString(body[@"appeal_link"]);
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGFreezeStateDidChangeNotification
					  object:nil];
}

- (void)clearFreezeState {
	self.frozen = NO;
	self.freezingDate = 0;
	self.freezeDeletionDate = 0;
	self.freezeAppealLink = nil;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGFreezeStateDidChangeNotification
					  object:nil];
}

#pragma mark - age verification

- (void)handleUpdateAgeVerificationParameters:(NSDictionary *)update {
	NSDictionary *parameters = TGAccountDict(update[@"parameters"]);
	self.ageVerificationRequired = parameters != nil;
	self.ageVerificationMinAge = [TGAccountNumber(parameters[@"min_age"]) integerValue];
	self.ageVerificationBotUsername = TGAccountString(parameters[@"verification_bot_username"]);
	self.ageVerificationCountry = TGAccountString(parameters[@"country"]);
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGAgeVerificationParametersDidChangeNotification
					  object:nil];
}

- (void)clearAgeVerificationParameters {
	self.ageVerificationRequired = NO;
	self.ageVerificationMinAge = 0;
	self.ageVerificationBotUsername = nil;
	self.ageVerificationCountry = nil;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGAgeVerificationParametersDidChangeNotification
					  object:nil];
}

#pragma mark - terms of service update

- (void)handleUpdateTermsOfService:(NSDictionary *)update {
	NSDictionary *body = TGAccountDict(update);
	NSDictionary *terms = TGAccountDict(body[@"terms_of_service"]);
	NSDictionary *text = TGAccountDict(terms[@"text"]);
	self.pendingTermsOfServiceId = TGAccountString(body[@"terms_of_service_id"]);
	self.pendingTermsOfServiceText = TGAccountString(text[@"text"]);
	self.pendingTermsOfServiceEntities = TGMCFlattenEntities(text[@"entities"]);
	self.pendingTermsOfServiceMinAge = [TGAccountNumber(terms[@"min_user_age"]) integerValue];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGTermsOfServiceDidChangeNotification
					  object:nil];
}

- (void)clearPendingTermsOfService {
	self.pendingTermsOfServiceId = nil;
	self.pendingTermsOfServiceText = nil;
	self.pendingTermsOfServiceEntities = nil;
	self.pendingTermsOfServiceMinAge = 0;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGTermsOfServiceDidChangeNotification
					  object:nil];
}

#pragma mark - countries and phone numbers

- (void)countriesWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getCountries"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion([NSArray array]);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGAccountArray(result[@"countries"])) {
			NSDictionary *country = TGAccountDict(entry);
			if (!country || [TGAccountBool(country[@"is_hidden"]) boolValue])
				continue;
			NSMutableArray *codes = [NSMutableArray array];
			for (id code in TGAccountArray(country[@"calling_codes"])) {
				if ([code isKindOfClass:[NSString class]])
					[codes addObject:code];
			}
			[out addObject:@{
				@"code" : TGAccountString(country[@"country_code"]),
				@"name" : TGAccountString(country[@"name"]),
				@"englishName" : TGAccountString(country[@"english_name"]),
				@"flag" : TGAccountString(country[@"flag_emoji"]),
				@"callingCodes" : codes,
			}];
		}
		completion(out);
	}];
}

- (void)guessedCountryCodeWithCompletion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"getCountryCode"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSString *code = TGAccountString(result[@"text"]);
		completion(code.length ? code : nil);
	}];
}

- (void)phoneNumberInfo:(NSString *)phoneNumberPrefix
			 completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getPhoneNumberInfo",
		@"phone_number_prefix" : phoneNumberPrefix ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSDictionary *country = TGAccountDict(result[@"country"]);
		if (!country) {
			completion(nil);
			return;
		}
		completion(@{
			@"countryCode" : TGAccountString(country[@"country_code"]),
			@"countryName" : TGAccountString(country[@"name"]),
			@"callingCode" : TGAccountString(result[@"country_calling_code"]),
			@"formatted" : TGAccountString(result[@"formatted_phone_number"]),
		});
	}];
}

- (void)preferredLanguageForCountry:(NSString *)countryCode
						 completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"getPreferredCountryLanguage",
		@"country_code" : countryCode ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSString *language = TGAccountString(result[@"text"]);
		completion(language.length ? language : nil);
	}];
}

#pragma mark - login: phone number and code

- (void)startLoginWithPhoneNumber:(NSString *)phoneNumber
				  isCurrentNumber:(BOOL)isCurrentNumber
					   completion:(void (^)(BOOL, NSInteger))completion {
	[self request:@{
		@"@type" : @"setAuthenticationPhoneNumber",
		@"phone_number" : phoneNumber ?: @"",
		@"settings" : TGAccountPhoneSettings(isCurrentNumber),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result), TGResultFloodWaitSeconds(result));
	}];
}

- (void)authorizationStateOfType:(NSString *)type
					  completion:(void (^)(NSDictionary *state))completion {
	[self request:@{@"@type" : @"getAuthorizationState"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		if (type.length && ![TGAccountString(result[@"@type"]) isEqualToString:type]) {
			completion(nil);
			return;
		}
		completion(result);
	}];
}

- (void)sendCode:(NSString *)code completion:(void (^)(BOOL, NSInteger))completion {
	[self request:@{
		@"@type" : @"checkAuthenticationCode",
		@"code" : code ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result), TGResultFloodWaitSeconds(result));
	}];
}

- (void)sendPassword:(NSString *)password completion:(void (^)(BOOL, NSInteger))completion {
	[self request:@{
		@"@type" : @"checkAuthenticationPassword",
		@"password" : password ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result), TGResultFloodWaitSeconds(result));
	}];
}

- (void)authenticationCodeInfoWithCompletion:(void (^)(NSDictionary *))completion {
	[self authorizationStateOfType:@"authorizationStateWaitCode"
						completion:^(NSDictionary *state) {
							if (!completion)
								return;
							completion(TGAccountCodeInfoDict(state[@"code_info"]));
						}];
}

- (void)resendAuthenticationCodeWithFailureMessage:(NSString *)verificationFailedMessage
										completion:(void (^)(NSDictionary *, NSInteger))completion {
	NSDictionary *reason = verificationFailedMessage.length
		? [NSDictionary dictionaryWithObjectsAndKeys:
				  @"resendCodeReasonVerificationFailed", @"@type",
			  verificationFailedMessage, @"error_message", nil]
		: [NSDictionary dictionaryWithObject:@"resendCodeReasonUserRequest" forKey:@"@type"];

	__weak TGClient *weakSelf = self;
	[self request:@{@"@type" : @"resendAuthenticationCode", @"reason" : reason}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				if (completion)
					completion(nil, TGResultFloodWaitSeconds(result));
				return;
			}
			[weakSelf authenticationCodeInfoWithCompletion:^(NSDictionary *info) {
				if (completion)
					completion(info, -1);
			}];
		}];
}

- (void)reportAuthenticationCodeMissing:(NSString *)mobileNetworkCode
							 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"reportAuthenticationCodeMissing",
		@"mobile_network_code" : mobileNetworkCode ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - login: registration

- (void)registrationTermsWithCompletion:(void (^)(NSDictionary *))completion {
	[self authorizationStateOfType:@"authorizationStateWaitRegistration"
						completion:^(NSDictionary *state) {
							if (!completion)
								return;
							NSDictionary *terms = TGAccountDict(state[@"terms_of_service"]);
							if (!terms) {
								completion(nil);
								return;
							}
							NSDictionary *text = TGAccountDict(terms[@"text"]);
							completion(@{
								@"text" : TGAccountString(text[@"text"]),
								@"minUserAge" : TGAccountNumber(terms[@"min_user_age"]),
								@"showPopup" : TGAccountBool(terms[@"show_popup"]),
							});
						}];
}

- (void)registerWithFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
				   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"registerUser",
		@"first_name" : firstName ?: @"",
		@"last_name" : lastName ?: @"",
		@"disable_notification" : @NO,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)acceptTermsOfService:(NSString *)termsId completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"acceptTermsOfService",
		@"terms_of_service_id" : termsId ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - login: QR code

- (void)confirmQrCodeLogin:(NSString *)link
				completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"confirmQrCodeAuthentication",
		@"link" : link ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion(TGAccountSessionDict(result));
	}];
}

#pragma mark - login: email address as second factor

- (void)setAuthenticationEmailAddress:(NSString *)emailAddress
						   completion:(void (^)(NSString *, NSInteger))completion {
	__weak TGClient *weakSelf = self;
	[self request:@{
		@"@type" : @"setAuthenticationEmailAddress",
		@"email_address" : emailAddress ?: @"",
	} completion:^(NSDictionary *result) {
		if (TGResultIsError(result)) {
			if (completion)
				completion(nil, 0);
			return;
		}
		[weakSelf authenticationEmailStateWithCompletion:^(NSDictionary *info) {
			if (!completion)
				return;
			NSString *pattern = TGAccountString(info[@"pattern"]);
			completion(pattern.length ? pattern : nil,
				[TGAccountNumber(info[@"codeLength"]) integerValue]);
		}];
	}];
}

- (void)checkAuthenticationEmailCode:(NSString *)code
						  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"checkAuthenticationEmailCode",
		@"code" : @{@"@type" : @"emailAddressAuthenticationCode", @"code" : code ?: @""},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)authenticationEmailStateWithCompletion:(void (^)(NSDictionary *))completion {
	[self authorizationStateOfType:@"authorizationStateWaitEmailCode"
						completion:^(NSDictionary *state) {
							if (!completion)
								return;
							if (!state) {
								completion(nil);
								return;
							}
							NSDictionary *codeInfo = TGAccountEmailCodeInfo(state[@"code_info"]);
							NSDictionary *reset = TGAccountDict(state[@"email_address_reset_state"]);
							NSString *resetType = TGAccountString(reset[@"@type"]);
							NSString *resetState = @"";
							if ([resetType isEqualToString:@"emailAddressResetStateAvailable"])
								resetState = @"available";
							else if ([resetType isEqualToString:@"emailAddressResetStatePending"])
								resetState = @"pending";
							completion(@{
								@"pattern" : TGAccountString(codeInfo[@"pattern"]),
								@"codeLength" : TGAccountNumber(codeInfo[@"codeLength"]),
								@"resetState" : resetState,
								@"waitPeriod" : TGAccountNumber(reset[@"wait_period"]),
								@"resetIn" : TGAccountNumber(reset[@"reset_in"]),
							});
						}];
}

- (void)resetAuthenticationEmailAddressWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"resetAuthenticationEmailAddress"}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - login: forgotten two-step password

- (void)requestAuthenticationPasswordRecoveryWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"requestAuthenticationPasswordRecovery"}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)checkAuthenticationPasswordRecoveryCode:(NSString *)recoveryCode
									 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"checkAuthenticationPasswordRecoveryCode",
		@"recovery_code" : recoveryCode ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)recoverAuthenticationPasswordWithCode:(NSString *)recoveryCode
								  newPassword:(NSString *)newPassword
									  newHint:(NSString *)newHint
								   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"recoverAuthenticationPassword",
		@"recovery_code" : recoveryCode ?: @"",
		@"new_password" : newPassword ?: @"",
		@"new_hint" : newHint ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - changing our own phone number

- (void)sendChangePhoneNumberCode:(NSString *)phoneNumber
					   completion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{
		@"@type" : @"sendPhoneNumberCode",
		@"phone_number" : phoneNumber ?: @"",
		@"settings" : TGAccountPhoneSettings(NO),
		@"type" : @{@"@type" : @"phoneNumberCodeTypeChange"},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGResultErrorMessage(result));
			return;
		}
		completion(TGAccountCodeInfoDict(result), nil);
	}];
}

- (void)checkChangePhoneNumberCode:(NSString *)code
						completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"checkPhoneNumberCode",
		@"code" : code ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGResultErrorMessage(result));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)resendChangePhoneNumberCodeWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"resendPhoneNumberCode",
		@"reason" : @{@"@type" : @"resendCodeReasonUserRequest"},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion(TGAccountCodeInfoDict(result));
	}];
}

- (void)reportChangePhoneNumberCodeMissing:(NSString *)mobileNetworkCode
								completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"reportPhoneNumberCodeMissing",
		@"mobile_network_code" : mobileNetworkCode ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGResultErrorMessage(result));
			return;
		}
		completion(YES, nil);
	}];
}

#pragma mark - login email address, from Settings

- (void)setLoginEmailAddress:(NSString *)emailAddress
				  completion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{
		@"@type" : @"setLoginEmailAddress",
		@"new_login_email_address" : emailAddress ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		NSDictionary *info = TGAccountEmailCodeInfo(result);
		completion(TGAccountString(info[@"pattern"]),
			[TGAccountNumber(info[@"codeLength"]) integerValue]);
	}];
}

- (void)resendLoginEmailAddressCodeWithCompletion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{@"@type" : @"resendLoginEmailAddressCode"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, 0);
				return;
			}
			NSDictionary *info = TGAccountEmailCodeInfo(result);
			completion(TGAccountString(info[@"pattern"]),
				[TGAccountNumber(info[@"codeLength"]) integerValue]);
		}];
}

- (void)checkLoginEmailAddressCode:(NSString *)code completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"checkLoginEmailAddressCode",
		@"code" : @{@"@type" : @"emailAddressAuthenticationCode", @"code" : code ?: @""},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - generic email verification

- (void)sendEmailAddressVerificationCode:(NSString *)emailAddress
							  completion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{
		@"@type" : @"sendEmailAddressVerificationCode",
		@"email_address" : emailAddress ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		NSDictionary *info = TGAccountEmailCodeInfo(result);
		completion(TGAccountString(info[@"pattern"]),
			[TGAccountNumber(info[@"codeLength"]) integerValue]);
	}];
}

- (void)resendEmailAddressVerificationCodeWithCompletion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{@"@type" : @"resendEmailAddressVerificationCode"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, 0);
				return;
			}
			NSDictionary *info = TGAccountEmailCodeInfo(result);
			completion(TGAccountString(info[@"pattern"]),
				[TGAccountNumber(info[@"codeLength"]) integerValue]);
		}];
}

- (void)checkEmailAddressVerificationCode:(NSString *)code completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"checkEmailAddressVerificationCode",
		@"code" : code ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - our own profile

- (void)usernamesWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMe"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSDictionary *usernames = TGAccountDict(result[@"usernames"]);
		if (!usernames) {
			completion(@{
				@"editable" : @"",
				@"active" : [NSArray array],
				@"disabled" : [NSArray array],
			});
			return;
		}
		NSMutableArray *active = [NSMutableArray array];
		for (id name in TGAccountArray(usernames[@"active_usernames"])) {
			if ([name isKindOfClass:[NSString class]])
				[active addObject:name];
		}
		NSMutableArray *disabled = [NSMutableArray array];
		for (id name in TGAccountArray(usernames[@"disabled_usernames"])) {
			if ([name isKindOfClass:[NSString class]])
				[disabled addObject:name];
		}
		completion(@{
			@"editable" : TGAccountString(usernames[@"editable_username"]),
			@"active" : active,
			@"disabled" : disabled,
		});
	}];
}

- (void)setUsername:(NSString *)username
			 active:(BOOL)active
		 completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"toggleUsernameIsActive",
		@"username" : username ?: @"",
		@"is_active" : active ? @YES : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGResultErrorMessage(result));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)reorderActiveUsernames:(NSArray *)usernames completion:(void (^)(BOOL, NSString *))completion {
	NSMutableArray *names = [NSMutableArray array];
	for (id name in TGAccountArray(usernames)) {
		if ([name isKindOfClass:[NSString class]])
			[names addObject:name];
	}
	[self request:@{
		@"@type" : @"reorderActiveUsernames",
		@"usernames" : names,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGResultErrorMessage(result));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^)(BOOL))completion {
	[self setProfilePhotoAtPath:path public:NO completion:completion];
}

- (void)setProfilePhotoAtPath:(NSString *)path
					   public:(BOOL)isPublic
				   completion:(void (^)(BOOL))completion {
	if (!path.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"setProfilePhoto",
		@"photo" : @{
			@"@type" : @"inputChatPhotoStatic",
			@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
		},
		@"is_public" : @(isPublic),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)profilePhotosWithCompletion:(void (^)(NSArray *, BOOL))completion {
	__weak TGClient *weakSelf = self;
	[self request:@{@"@type" : @"getMe"} completion:^(NSDictionary *me) {
		if (TGResultIsError(me)) {
			if (completion)
				completion(@[], YES);
			return;
		}
		[weakSelf request:@{
			@"@type" : @"getUserProfilePhotos",
			@"user_id" : TGAccountNumber(me[@"id"]),
			@"offset" : @(0),
			@"limit" : @(100),
		} completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@[], YES);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGAccountArray(result[@"photos"])) {
				NSDictionary *photo = TGAccountDict(entry);
				if (!photo)
					continue;
				NSArray *sizes = TGAccountArray(photo[@"sizes"]);
				NSNumber *small = nil;
				NSNumber *big = nil;
				NSInteger bestWidth = -1;
				NSInteger smallestWidth = NSIntegerMax;
				for (id sizeEntry in sizes) {
					NSDictionary *size = TGAccountDict(sizeEntry);
					NSDictionary *file = TGAccountDict(size[@"photo"]);
					if (!file)
						continue;
					NSInteger width = [TGAccountNumber(size[@"width"]) integerValue];
					if (width > bestWidth) {
						bestWidth = width;
						big = TGAccountNumber(file[@"id"]);
					}
					if (width < smallestWidth) {
						smallestWidth = width;
						small = TGAccountNumber(file[@"id"]);
					}
				}
				[out addObject:@{
					@"id" : TGAccountNumber(photo[@"id"]),
					@"fileId" : big ?: @0,
					@"smallFileId" : small ?: @0,
					@"date" : TGAccountNumber(photo[@"added_date"]),
				}];
			}
			completion(out, NO);
		}];
	}];
}

- (void)deleteProfilePhoto:(long long)photoId completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"deleteProfilePhoto",
		@"profile_photo_id" : @(photoId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)publicLinkWithCompletion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{@"@type" : @"getUserLink"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		NSString *url = TGAccountString(result[@"url"]);
		NSInteger expiresIn = [TGAccountNumber(result[@"expires_in"]) integerValue];
		NSString *username = TGUsernameInInternalPublicChatLink(url);
		if (!username) {
			completion(url.length ? url : nil, expiresIn);
			return;
		}
		[self publicLinkForUsername:username completion:^(NSString *httpLink) {
			completion(httpLink.length ? httpLink : url, expiresIn);
		}];
	}];
}

- (void)setBirthdateDay:(NSInteger)day
				  month:(NSInteger)month
				   year:(NSInteger)year
			 completion:(void (^)(BOOL))completion {
	if (day < 1 || day > 31 || month < 1 || month > 12) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"setBirthdate",
		@"birthdate" : @{
			@"@type" : @"birthdate",
			@"day" : @(day),
			@"month" : @(month),
			@"year" : @(year),
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)clearBirthdateWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"setBirthdate"} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setPersonalChat:(int64_t)chatId completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setPersonalChat",
		@"chat_id" : @(chatId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

static NSDictionary *TGAccountFlattenUser(NSDictionary *user) {
	if (!user)
		return nil;
	NSString *first = TGAccountString(user[@"first_name"]);
	NSString *last = TGAccountString(user[@"last_name"]);
	NSString *name = last.length
		? [NSString stringWithFormat:@"%@ %@", first, last]
		: first;
	NSDictionary *usernames = TGAccountDict(user[@"usernames"]);
	NSDictionary *verification = TGAccountDict(user[@"verification_status"]);
	NSDictionary *photo = TGAccountDict(user[@"profile_photo"]);
	NSDictionary *small = TGAccountDict(photo[@"small"]);
	NSDictionary *big = TGAccountDict(photo[@"big"]);
	return @{
		@"id" : TGAccountNumber(user[@"id"]),
		@"firstName" : first,
		@"lastName" : last,
		@"name" : name,
		@"username" : TGAccountString(usernames[@"editable_username"]),
		@"phoneNumber" : TGAccountString(user[@"phone_number"]),
		@"isPremium" : TGAccountBool(user[@"is_premium"]),
		@"isVerified" : TGAccountBool(verification[@"is_verified"]),
		@"smallFileId" : TGAccountNumber(small[@"id"]),
		@"bigFileId" : TGAccountNumber(big[@"id"]),
	};
}

static NSString *TGAccountSessionDeviceType(id value) {
	NSString *name = TGAccountString(value);
	if ([name hasPrefix:@"sessionDeviceType"])
		return [name substringFromIndex:[@"sessionDeviceType" length]];
	return @"Unknown";
}

static NSDictionary *TGAccountFlattenSession(NSDictionary *session) {
	if (!session)
		return nil;
	return @{
		@"id" : TGAccountNumber(session[@"id"]),
		@"isCurrent" : TGAccountBool(session[@"is_current"]),
		@"isPasswordPending" : TGAccountBool(session[@"is_password_pending"]),
		@"isUnconfirmed" : TGAccountBool(session[@"is_unconfirmed"]),
		@"isOfficialApplication" : TGAccountBool(session[@"is_official_application"]),
		@"canAcceptCalls" : TGAccountBool(session[@"can_accept_calls"]),
		@"canAcceptSecretChats" : TGAccountBool(session[@"can_accept_secret_chats"]),
		@"appName" : TGAccountString(session[@"application_name"]),
		@"appVersion" : TGAccountString(session[@"application_version"]),
		@"deviceModel" : TGAccountString(session[@"device_model"]),
		@"deviceType" : TGAccountSessionDeviceType(TGAccountDict(session[@"device_type"])[@"@type"]),
		@"platform" : TGSessionPlatformString(TGAccountString(session[@"platform"]), TGAccountString(session[@"system_version"])),
		@"systemVersion" : TGAccountString(session[@"system_version"]),
		@"ipAddress" : TGAccountString(session[@"ip_address"]),
		@"location" : TGAccountString(session[@"location"]),
		@"loginDate" : TGAccountNumber(session[@"log_in_date"]),
		@"lastActiveDate" : TGAccountNumber(session[@"last_active_date"]),
		@"apiId" : TGAccountNumber(session[@"api_id"]),
	};
}

- (void)accountInfoWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMe"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion(TGAccountFlattenUser(result));
	}];
}

- (void)profileInfoWithCompletion:(void (^)(NSDictionary *))completion {
	__weak TGClient *weakSelf = self;
	[self request:@{@"@type" : @"getMe"} completion:^(NSDictionary *me) {
		if (TGResultIsError(me)) {
			if (completion)
				completion(nil);
			return;
		}
		NSDictionary *base = TGAccountFlattenUser(me);
		[weakSelf request:@{
			@"@type" : @"getUserFullInfo",
			@"user_id" : TGAccountNumber(me[@"id"]),
		} completion:^(NSDictionary *full) {
			if (!completion)
				return;
			NSMutableDictionary *out = [NSMutableDictionary dictionaryWithDictionary:base];
			NSDictionary *bio = TGAccountDict(full[@"bio"]);
			NSDictionary *birthdate = TGAccountDict(full[@"birthdate"]);
			[out setObject:TGAccountString(bio[@"text"]) forKey:@"bio"];
			[out setObject:TGAccountNumber(birthdate[@"day"]) forKey:@"birthdayDay"];
			[out setObject:TGAccountNumber(birthdate[@"month"]) forKey:@"birthdayMonth"];
			[out setObject:TGAccountNumber(birthdate[@"year"]) forKey:@"birthdayYear"];
			[out setObject:TGAccountNumber(full[@"personal_chat_id"]) forKey:@"personalChatId"];
			completion(out);
		}];
	}];
}

- (void)setFirstName:(NSString *)firstName
			lastName:(NSString *)lastName
		  completion:(void (^)(BOOL))completion {
	if (![firstName isKindOfClass:[NSString class]] || firstName.length == 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"setName",
		@"first_name" : firstName,
		@"last_name" : [lastName isKindOfClass:[NSString class]] ? lastName : @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setBio:(NSString *)bio completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setBio",
		@"bio" : [bio isKindOfClass:[NSString class]] ? bio : @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)bioLengthMaxWithCompletion:(void (^)(NSInteger))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getOption", @"name" : @"bio_length_max"}
		completion:^(NSDictionary *result) {
			NSNumber *value = TGResultIsError(result) ? nil : result[@"value"];
			completion([value isKindOfClass:NSNumber.class] ? [value integerValue] : 0);
		}];
}

#pragma mark - profile audio

- (void)profileAudiosForUser:(int64_t)userId
					  offset:(NSInteger)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *, BOOL))completion {
	[self request:@{
		@"@type" : @"getUserProfileAudios",
		@"user_id" : @(userId),
		@"offset" : @((int32_t)offset),
		@"limit" : @((int32_t)(limit > 0 ? limit : 20)),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], YES);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGAccountArray(result[@"audios"])) {
			NSDictionary *audio = TGAccountDict(entry);
			if (!audio)
				continue;
			NSDictionary *file = TGAccountDict(audio[@"audio"]);
			NSNumber *fileId = [file[@"id"] isKindOfClass:NSNumber.class] ? file[@"id"] : @0;
			[out addObject:@{
				@"fileId" : fileId,
				@"title" : TGAccountString(audio[@"title"]),
				@"performer" : TGAccountString(audio[@"performer"]),
				@"duration" : audio[@"duration"] ?: @0,
			}];
		}
		completion(out, NO);
	}];
}

- (void)addProfileAudioAtPath:(NSString *)path
						title:(NSString *)title
					performer:(NSString *)performer
					 duration:(NSInteger)duration
				   completion:(void (^)(BOOL))completion {
	if (!path.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"addProfileAudio",
		@"audio" : @{
			@"@type" : @"inputAudio",
			@"audio" : @{@"@type" : @"inputFileLocal", @"path" : path},
			@"duration" : @((int32_t)duration),
			@"title" : title ?: @"",
			@"performer" : performer ?: @"",
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)removeProfileAudioFileId:(long long)fileId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"removeProfileAudio", @"file_id" : @(fileId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)setProfileAudioFileId:(long long)fileId
				  afterFileId:(long long)afterFileId
				   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setProfileAudioPosition",
		@"file_id" : @(fileId),
		@"after_file_id" : @(afterFileId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setAccountTtlDays:(NSInteger)days completion:(void (^)(BOOL))completion {
	if (days <= 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"setAccountTtl",
		@"ttl" : @{
			@"@type" : @"accountTtl",
			@"days" : @(days),
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)sessionInfoForId:(long long)sessionId
			  completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getActiveSessions"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		for (id entry in TGAccountArray(result[@"sessions"])) {
			NSDictionary *session = TGAccountDict(entry);
			if (!session)
				continue;
			if ([session[@"id"] longLongValue] == sessionId) {
				completion(TGAccountFlattenSession(session));
				return;
			}
		}
		completion(nil);
	}];
}

- (void)logOutWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"logOut"} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setUsername:(NSString *)username completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"setUsername", @"username" : username ?: @""}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(![result[@"@type"] isEqualToString:@"error"]);
		}];
}

- (void)clearLocalDatabaseWithCompletion:(void (^)(long long))completion {
	[self.chatsById removeAllObjects];
	[self rebuildChats];
	[self clearAllCacheWithCompletion:completion];
}

- (void)giftsForUser:(int64_t)userId completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"getReceivedGifts",
		@"owner_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)},
		@"offset" : @"",
		@"limit" : @(100),
	} completion:^(NSDictionary *result) {
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *entry in result[@"gifts"]) {
			NSDictionary *sent = entry[@"gift"];
			BOOL isUnique = [sent[@"@type"] isEqualToString:@"sentGiftUpgraded"];
			NSDictionary *gift = sent[@"gift"] ?: sent;
			NSString *giftId = [entry[@"received_gift_id"] isKindOfClass:[NSString class]] ? entry[@"received_gift_id"] : @"";
			NSMutableDictionary *row = [NSMutableDictionary dictionaryWithDictionary:@{
				@"giftId" : giftId,
				@"title" : gift[@"title"] ?: TGL(@"GiftLink.Gift", @"Gift"),
				@"isUnique" : @(isUnique),
				@"isSaved" : @([entry[@"is_saved"] boolValue]),
				@"isPinned" : @([entry[@"is_pinned"] boolValue]),
			}];
			if (isUnique) {
				row[@"starCount"] = @0;
				row[@"valueCurrency"] = gift[@"value_currency"] ?: @"";
				row[@"valueAmount"] = gift[@"value_amount"] ?: @0;
			} else {
				row[@"starCount"] = gift[@"star_count"] ?: @0;
			}
			[out addObject:row];
		}
		NSMutableArray *pinnedRows = [NSMutableArray array];
		NSMutableArray *otherRows = [NSMutableArray array];
		for (NSDictionary *row in out) {
			if ([row[@"isPinned"] boolValue])
				[pinnedRows addObject:row];
			else
				[otherRows addObject:row];
		}
		NSMutableArray *ordered = [NSMutableArray arrayWithArray:pinnedRows];
		[ordered addObjectsFromArray:otherRows];
		if (completion)
			completion(ordered);
	}];
}

- (void)premiumStateWithCompletion:(void (^)(NSString *))completion {
	if (![self.me[@"is_premium"] boolValue]) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getOption", @"name" : @"premium_expiration_date"}
		completion:^(NSDictionary *option) {
			double until = [option[@"value"] doubleValue];
			if (until <= 0) {
				if (completion)
					completion(TGL(@"Stars.Subscription.Active", @"Active"));
				return;
			}
			if (completion)
				completion([NSString stringWithFormat:@"%@ %@",
					TGL(@"Stars.Transaction.Subscription.Status.Expires", @"Expires"),
					[TGDateUtils stringForFullDate:(int)until]]);
		}];
}

- (void)bioForUser:(int64_t)userId completion:(void (^)(NSString *bio))completion {
	[self request:@{@"@type" : @"getUserFullInfo",
		@"user_id" : @(userId)}
		completion:^(NSDictionary *full) {
			if (!completion)
				return;
			if (TGResultIsError(full)) {
				completion(@"");
				return;
			}
			completion(TGAccountString(TGAccountDict(full[@"bio"])[@"text"]));
		}];
}

- (void)sendCode:(NSString *)code {
	[self send:@{
		@"@type" : @"checkAuthenticationCode",
		@"code" : code ?: @"",
	}];
}

- (void)sendPassword:(NSString *)password {
	[self send:@{
		@"@type" : @"checkAuthenticationPassword",
		@"password" : password ?: @"",
	}];
}

- (void)deleteAccountWithReason:(NSString *)reason
					   password:(NSString *)password
					 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"deleteAccount",
		@"reason" : reason ?: @"",
		@"password" : password ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

@end
