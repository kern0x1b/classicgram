#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGUnconfirmedSessionDidChangeNotification;

@interface TGClient (Privacy)

#pragma mark - privacy rules

+ (NSArray *)privacySettingNames;

+ (NSString *)titleForPrivacySetting:(NSString *)setting;

- (void)privacyRuleDetailed:(NSString *)setting
				 completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)setPrivacyRule:(NSString *)setting
					to:(NSString *)value
		  allowedUsers:(NSArray *)allowedUserIds
	   restrictedUsers:(NSArray *)restrictedUserIds
			completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setPrivacyRule:(NSString *)setting
					to:(NSString *)value
		  allowedUsers:(NSArray *)allowedUserIds
	   restrictedUsers:(NSArray *)restrictedUserIds
		  allowedChats:(NSArray * _Nullable)allowedChatIds
	   restrictedChats:(NSArray * _Nullable)restrictedChatIds
			completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setPrivacyRule:(NSString *)setting
					to:(NSString *)value
		  allowedUsers:(NSArray *)allowedUserIds
	   restrictedUsers:(NSArray *)restrictedUserIds
		  allowedChats:(NSArray * _Nullable)allowedChatIds
	   restrictedChats:(NSArray * _Nullable)restrictedChatIds
			 allowBots:(BOOL)allowBots
		  restrictBots:(BOOL)restrictBots
	 allowPremiumUsers:(BOOL)allowPremiumUsers
			completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - read-date privacy

- (void)readDatePrivacyShowWithCompletion:(void (^ _Nullable)(BOOL show, BOOL failed))completion;

- (void)setReadDatePrivacyShow:(BOOL)show completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - who may start a chat

- (void)newChatPrivacySettingsWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)setNewChatPrivacyAllowsUnknownUsers:(BOOL)allow
								 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setNewChatPrivacyStarCount:(long long)starCount
						 completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - block list

- (void)setUser:(int64_t)userId
		blocked:(BOOL)blocked
	 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setSender:(int64_t)senderId
		   isChat:(BOOL)isChat
		  blocked:(BOOL)blocked
	   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)blockedSendersFromOffset:(NSInteger)offset
						   limit:(NSInteger)limit
					  completion:(void (^ _Nullable)(NSArray *senders, NSInteger total))completion;

#pragma mark - sessions

- (void)handleUpdateUnconfirmedSession:(NSDictionary *)update;

- (void)activeSessionsWithCompletion:(void (^ _Nullable)(NSArray *sessions, NSInteger inactiveTtlDays))completion;

- (void)unconfirmedSessionsWithCompletion:(void (^ _Nullable)(NSArray *sessions))completion;

- (void)terminateSession:(long long)sessionId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)terminateAllOtherSessionsWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)confirmSession:(long long)sessionId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setSession:(long long)sessionId
	  canAcceptCalls:(BOOL)canAcceptCalls
	canAcceptSecrets:(BOOL)canAcceptSecretChats
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setInactiveSessionTtlDays:(NSInteger)days completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - connected websites

- (void)connectedWebsitesWithCompletion:(void (^ _Nullable)(NSArray *websites, BOOL failed))completion;

- (void)disconnectWebsite:(long long)websiteId completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)disconnectAllWebsitesWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - two-step verification

- (void)passwordStateWithCompletion:(void (^ _Nullable)(NSDictionary *state))completion;

- (void)setPasswordWithOldPassword:(NSString *)oldPassword
					   newPassword:(NSString *)newPassword
							  hint:(NSString *)hint
					 recoveryEmail:(nullable NSString *)recoveryEmail
						completion:(void (^ _Nullable)(NSDictionary *state))completion;

- (void)disablePasswordWithOldPassword:(NSString *)oldPassword
							completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)recoveryEmailWithPassword:(NSString *)password
					   completion:(void (^ _Nullable)(NSString *email, NSString *errorMessage))completion;

- (void)setRecoveryEmail:(NSString *)email
				password:(NSString *)password
			  completion:(void (^ _Nullable)(NSDictionary *state))completion;

- (void)checkRecoveryEmailCode:(NSString *)code
					completion:(void (^ _Nullable)(NSDictionary *state))completion;

- (void)resendRecoveryEmailCodeWithCompletion:(void (^ _Nullable)(NSDictionary *state))completion;

#pragma mark - forgotten password, at the login screen

- (void)requestPasswordRecoveryWithCompletion:(void (^ _Nullable)(NSString *emailPattern, NSInteger codeLength))completion;

- (void)checkRecoveryCode:(NSString *)code
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)recoverPasswordWithCode:(NSString *)code
					newPassword:(NSString *)newPassword
						   hint:(NSString *)hint
					 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)resetPasswordWithCompletion:(void (^ _Nullable)(NSString *result, NSInteger date))completion;

- (void)cancelPasswordResetWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - account

- (void)defaultAutoDeleteSecondsWithCompletion:(void (^ _Nullable)(NSInteger seconds, BOOL failed))completion;
- (void)setDefaultAutoDeleteSeconds:(NSInteger)seconds completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - reporting

- (void)reportChat:(int64_t)chatId
		messageIds:(NSArray *)messageIds
		  optionId:(NSString *)optionId
			  text:(NSString *)text
		completion:(void (^ _Nullable)(NSDictionary *result))completion;

- (void)reportChatPhoto:(int64_t)chatId
				 fileId:(long long)fileId
				 reason:(NSString *)reason
				   text:(NSString *)text
			 completion:(void (^ _Nullable)(BOOL ok))completion;
#pragma mark - chat action bar

- (void)actionBarForChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(NSDictionary *actionBar))completion;

- (void)removeActionBarForChat:(int64_t)chatId
					completion:(void (^ _Nullable)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END
