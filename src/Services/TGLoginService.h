#import <Foundation/Foundation.h>
#import "TGAuthState.h"
#import "TGClientAuthenticating.h"

@interface TGLoginService : NSObject

+ (id<TGClientAuthenticating>)client;

+ (TGAuthState)authState;

+ (void)guessedCountryCodeWithCompletion:(void (^)(NSString *countryCode))completion;

+ (void)phoneNumberInfo:(NSString *)phoneNumberPrefix
			 completion:(void (^)(NSDictionary *info))completion;

+ (void)startLoginWithPhoneNumber:(NSString *)phoneNumber
				  isCurrentNumber:(BOOL)isCurrentNumber
					   completion:(void (^)(BOOL ok, NSInteger retryAfterSeconds))completion;

+ (void)sendCode:(NSString *)code completion:(void (^)(BOOL ok, NSInteger retryAfterSeconds))completion;

+ (void)sendPassword:(NSString *)password completion:(void (^)(BOOL ok, NSInteger retryAfterSeconds))completion;

+ (void)authenticationCodeInfoWithCompletion:(void (^)(NSDictionary *info))completion;

+ (void)resendAuthenticationCodeWithFailureMessage:(NSString *)verificationFailedMessage
										completion:(void (^)(NSDictionary *info, NSInteger retryAfterSeconds))completion;

+ (void)reportAuthenticationCodeMissing:(NSString *)mobileNetworkCode
							 completion:(void (^)(BOOL ok))completion;

+ (void)registrationTermsWithCompletion:(void (^)(NSDictionary *terms))completion;

+ (void)registerWithFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
				   completion:(void (^)(BOOL ok))completion;

+ (void)setAuthenticationEmailAddress:(NSString *)emailAddress
						   completion:(void (^)(NSString *pattern, NSInteger codeLength))completion;

+ (void)checkAuthenticationEmailCode:(NSString *)code
						  completion:(void (^)(BOOL ok))completion;

+ (void)authenticationEmailStateWithCompletion:(void (^)(NSDictionary *info))completion;

+ (void)resetAuthenticationEmailAddressWithCompletion:(void (^)(BOOL ok))completion;

+ (void)requestAuthenticationPasswordRecoveryWithCompletion:(void (^)(BOOL ok))completion;

+ (void)checkAuthenticationPasswordRecoveryCode:(NSString *)recoveryCode
									 completion:(void (^)(BOOL ok))completion;

+ (void)recoverAuthenticationPasswordWithCode:(NSString *)recoveryCode
								  newPassword:(NSString *)newPassword
									  newHint:(NSString *)newHint
								   completion:(void (^)(BOOL ok))completion;

+ (void)deleteAccountWithReason:(NSString *)reason
					   password:(NSString *)password
					 completion:(void (^)(BOOL ok))completion;

+ (void)logOutWithCompletion:(void (^)(BOOL ok))completion;

@end
