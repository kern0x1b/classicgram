#import <Foundation/Foundation.h>
#import "TGAuthState.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TGClientAuthenticating <NSObject>

@property (nonatomic, readonly) TGAuthState authState;

- (void)guessedCountryCodeWithCompletion:(void (^ _Nullable)(NSString *countryCode))completion;

- (void)phoneNumberInfo:(NSString *)phoneNumberPrefix
			 completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)startLoginWithPhoneNumber:(NSString *)phoneNumber
				  isCurrentNumber:(BOOL)isCurrentNumber
					   completion:(void (^ _Nullable)(BOOL ok, NSInteger retryAfterSeconds))completion;

- (void)sendCode:(NSString *)code completion:(void (^ _Nullable)(BOOL ok, NSInteger retryAfterSeconds))completion;

- (void)sendPassword:(NSString *)password completion:(void (^ _Nullable)(BOOL ok, NSInteger retryAfterSeconds))completion;

- (void)authenticationCodeInfoWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)resendAuthenticationCodeWithFailureMessage:(NSString *)verificationFailedMessage
										completion:(void (^ _Nullable)(NSDictionary *info, NSInteger retryAfterSeconds))completion;

- (void)reportAuthenticationCodeMissing:(NSString *)mobileNetworkCode
							 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)registrationTermsWithCompletion:(void (^ _Nullable)(NSDictionary *terms))completion;

- (void)registerWithFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setAuthenticationEmailAddress:(NSString *)emailAddress
						   completion:(void (^ _Nullable)(NSString *pattern, NSInteger codeLength))completion;

- (void)checkAuthenticationEmailCode:(NSString *)code
						  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)authenticationEmailStateWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)resetAuthenticationEmailAddressWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)requestAuthenticationPasswordRecoveryWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)checkAuthenticationPasswordRecoveryCode:(NSString *)recoveryCode
									 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)recoverAuthenticationPasswordWithCode:(NSString *)recoveryCode
								  newPassword:(NSString *)newPassword
									  newHint:(NSString *)newHint
								   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)deleteAccountWithReason:(NSString *)reason
					   password:(NSString *)password
					 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)logOutWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END
