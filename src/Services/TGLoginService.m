#import "TGLoginService.h"
#import "TGClient.h"
#import "TGClient+Account.h"

static id<TGClientAuthenticating> gLoginServiceClient = nil;

@implementation TGLoginService

+ (id<TGClientAuthenticating>)client {
	return gLoginServiceClient ?: [TGClient shared];
}

+ (TGAuthState)authState {
	return [self client].authState;
}

+ (void)guessedCountryCodeWithCompletion:(void (^)(NSString *countryCode))completion {
	[[self client] guessedCountryCodeWithCompletion:completion];
}

+ (void)phoneNumberInfo:(NSString *)phoneNumberPrefix
			 completion:(void (^)(NSDictionary *info))completion {
	[[self client] phoneNumberInfo:phoneNumberPrefix completion:completion];
}

+ (void)startLoginWithPhoneNumber:(NSString *)phoneNumber
				  isCurrentNumber:(BOOL)isCurrentNumber
					   completion:(void (^)(BOOL ok, NSInteger retryAfterSeconds))completion {
	[[self client] startLoginWithPhoneNumber:phoneNumber isCurrentNumber:isCurrentNumber
								  completion:completion];
}

+ (void)sendCode:(NSString *)code completion:(void (^)(BOOL ok, NSInteger retryAfterSeconds))completion {
	[[self client] sendCode:code completion:completion];
}

+ (void)sendPassword:(NSString *)password completion:(void (^)(BOOL ok, NSInteger retryAfterSeconds))completion {
	[[self client] sendPassword:password completion:completion];
}

+ (void)authenticationCodeInfoWithCompletion:(void (^)(NSDictionary *info))completion {
	[[self client] authenticationCodeInfoWithCompletion:completion];
}

+ (void)resendAuthenticationCodeWithFailureMessage:(NSString *)verificationFailedMessage
										completion:(void (^)(NSDictionary *info, NSInteger retryAfterSeconds))completion {
	id<TGClientAuthenticating> client = [self client];
	[client resendAuthenticationCodeWithFailureMessage:verificationFailedMessage completion:completion];
}

+ (void)reportAuthenticationCodeMissing:(NSString *)mobileNetworkCode
							 completion:(void (^)(BOOL ok))completion {
	[[self client] reportAuthenticationCodeMissing:mobileNetworkCode completion:completion];
}

+ (void)registrationTermsWithCompletion:(void (^)(NSDictionary *terms))completion {
	[[self client] registrationTermsWithCompletion:completion];
}

+ (void)registerWithFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
				   completion:(void (^)(BOOL ok))completion {
	[[self client] registerWithFirstName:firstName lastName:lastName completion:completion];
}

+ (void)setAuthenticationEmailAddress:(NSString *)emailAddress
						   completion:(void (^)(NSString *pattern, NSInteger codeLength))completion {
	[[self client] setAuthenticationEmailAddress:emailAddress completion:completion];
}

+ (void)checkAuthenticationEmailCode:(NSString *)code
						  completion:(void (^)(BOOL ok))completion {
	[[self client] checkAuthenticationEmailCode:code completion:completion];
}

+ (void)authenticationEmailStateWithCompletion:(void (^)(NSDictionary *info))completion {
	[[self client] authenticationEmailStateWithCompletion:completion];
}

+ (void)resetAuthenticationEmailAddressWithCompletion:(void (^)(BOOL ok))completion {
	[[self client] resetAuthenticationEmailAddressWithCompletion:completion];
}

+ (void)requestAuthenticationPasswordRecoveryWithCompletion:(void (^)(BOOL ok))completion {
	[[self client] requestAuthenticationPasswordRecoveryWithCompletion:completion];
}

+ (void)checkAuthenticationPasswordRecoveryCode:(NSString *)recoveryCode
									 completion:(void (^)(BOOL ok))completion {
	[[self client] checkAuthenticationPasswordRecoveryCode:recoveryCode completion:completion];
}

+ (void)recoverAuthenticationPasswordWithCode:(NSString *)recoveryCode
								  newPassword:(NSString *)newPassword
									  newHint:(NSString *)newHint
								   completion:(void (^)(BOOL ok))completion {
	id<TGClientAuthenticating> client = [self client];
	[client recoverAuthenticationPasswordWithCode:recoveryCode
									  newPassword:newPassword
										  newHint:newHint
									   completion:completion];
}

+ (void)deleteAccountWithReason:(NSString *)reason
					   password:(NSString *)password
					 completion:(void (^)(BOOL ok))completion {
	[[self client] deleteAccountWithReason:reason password:password completion:completion];
}

+ (void)logOutWithCompletion:(void (^)(BOOL ok))completion {
	[[self client] logOutWithCompletion:completion];
}

@end
