#import "TGClient.h"
#import "TGClientAuthenticating.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGFreezeStateDidChangeNotification;
extern NSString *const TGAgeVerificationParametersDidChangeNotification;
extern NSString *const TGTermsOfServiceDidChangeNotification;

@interface TGClient (Account) <TGClientAuthenticating>

#pragma mark - frozen account

- (void)handleUpdateFreezeState:(NSDictionary *)update;
- (void)clearFreezeState;

#pragma mark - age verification

- (void)handleUpdateAgeVerificationParameters:(NSDictionary *)update;
- (void)clearAgeVerificationParameters;

#pragma mark - terms of service update

- (void)handleUpdateTermsOfService:(NSDictionary *)update;

- (void)clearPendingTermsOfService;

#pragma mark - countries and phone numbers

- (void)countriesWithCompletion:(void (^ _Nullable)(NSArray *countries))completion;

- (void)bioForUser:(int64_t)userId completion:(void (^ _Nullable)(NSString *bio))completion;

- (void)guessedCountryCodeWithCompletion:(void (^ _Nullable)(NSString *countryCode))completion;

- (void)phoneNumberInfo:(NSString *)phoneNumberPrefix
			 completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)preferredLanguageForCountry:(NSString *)countryCode
						 completion:(void (^ _Nullable)(NSString *languageCode))completion;

#pragma mark - login: phone number and code

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

#pragma mark - login: registration

- (void)registrationTermsWithCompletion:(void (^ _Nullable)(NSDictionary *terms))completion;

- (void)registerWithFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)acceptTermsOfService:(NSString *)termsId completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - login: QR code

- (void)confirmQrCodeLogin:(NSString *)link
				completion:(void (^ _Nullable)(NSDictionary *session))completion;

#pragma mark - login: email address as second factor

- (void)setAuthenticationEmailAddress:(NSString *)emailAddress
						   completion:(void (^ _Nullable)(NSString *pattern, NSInteger codeLength))completion;

- (void)checkAuthenticationEmailCode:(NSString *)code
						  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)authenticationEmailStateWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)resetAuthenticationEmailAddressWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - login: forgotten two-step password

- (void)requestAuthenticationPasswordRecoveryWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)checkAuthenticationPasswordRecoveryCode:(NSString *)recoveryCode
									 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)recoverAuthenticationPasswordWithCode:(NSString *)recoveryCode
								  newPassword:(NSString *)newPassword
									  newHint:(NSString *)newHint
								   completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - changing our own phone number

- (void)sendChangePhoneNumberCode:(NSString *)phoneNumber
					   completion:(void (^ _Nullable)(NSDictionary *_Nullable info, NSString *_Nullable errorMessage))completion;

- (void)checkChangePhoneNumberCode:(NSString *)code
						completion:(void (^ _Nullable)(BOOL ok, NSString *_Nullable errorMessage))completion;

- (void)resendChangePhoneNumberCodeWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)reportChangePhoneNumberCodeMissing:(nullable NSString *)mobileNetworkCode
								completion:(void (^ _Nullable)(BOOL ok, NSString *_Nullable errorMessage))completion;

#pragma mark - login email address, from Settings

- (void)setLoginEmailAddress:(NSString *)emailAddress
				  completion:(void (^ _Nullable)(NSString *pattern, NSInteger codeLength))completion;

- (void)resendLoginEmailAddressCodeWithCompletion:(void (^ _Nullable)(NSString *pattern, NSInteger codeLength))completion;

- (void)checkLoginEmailAddressCode:(NSString *)code completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - generic email verification

- (void)sendEmailAddressVerificationCode:(NSString *)emailAddress
							  completion:(void (^ _Nullable)(NSString *pattern, NSInteger codeLength))completion;

- (void)resendEmailAddressVerificationCodeWithCompletion:(void (^ _Nullable)(NSString *pattern, NSInteger codeLength))completion;

- (void)checkEmailAddressVerificationCode:(NSString *)code completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - our own profile

- (void)usernamesWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)setUsername:(NSString *)username
			 active:(BOOL)active
		 completion:(void (^ _Nullable)(BOOL ok, NSString *errorMessage))completion;

- (void)reorderActiveUsernames:(NSArray *)usernames completion:(void (^ _Nullable)(BOOL ok, NSString *errorMessage))completion;

- (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setProfilePhotoAtPath:(NSString *)path
					   public:(BOOL)isPublic
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)profilePhotosWithCompletion:(void (^ _Nullable)(NSArray *photos, BOOL failed))completion;

- (void)deleteProfilePhoto:(long long)photoId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)publicLinkWithCompletion:(void (^ _Nullable)(NSString *url, NSInteger expiresIn))completion;

- (void)setBirthdateDay:(NSInteger)day
				  month:(NSInteger)month
				   year:(NSInteger)year
			 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)clearBirthdateWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setPersonalChat:(int64_t)chatId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)accountInfoWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)profileInfoWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)setFirstName:(NSString *)firstName
			lastName:(NSString *)lastName
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setBio:(NSString *)bio completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)bioLengthMaxWithCompletion:(void (^ _Nullable)(NSInteger lengthMax))completion;

#pragma mark - profile audio

- (void)profileAudiosForUser:(int64_t)userId
					  offset:(NSInteger)offset
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *audios, BOOL failed))completion;

- (void)addProfileAudioAtPath:(NSString *)path
						title:(NSString *)title
					performer:(NSString *)performer
					 duration:(NSInteger)duration
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)removeProfileAudioFileId:(long long)fileId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setProfileAudioFileId:(long long)fileId
				  afterFileId:(long long)afterFileId
				   completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - account lifetime and sessions

- (void)setAccountTtlDays:(NSInteger)days completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)sessionInfoForId:(long long)sessionId
			  completion:(void (^ _Nullable)(NSDictionary *session))completion;

- (void)logOutWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setUsername:(NSString *)username completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)clearLocalDatabaseWithCompletion:(void (^ _Nullable)(long long freed))completion;

- (void)giftsForUser:(int64_t)userId completion:(void (^ _Nullable)(NSArray *gifts))completion;
- (void)premiumStateWithCompletion:(void (^ _Nullable)(NSString *state))completion;

- (void)sendCode:(NSString *)code;
- (void)sendPassword:(NSString *)password;

- (void)deleteAccountWithReason:(NSString *)reason
					   password:(NSString * _Nullable)password
					 completion:(void (^ _Nullable)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END
