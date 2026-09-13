#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGSecretChatStateDidChangeNotification;

@interface TGClient (SecretChats)

#pragma mark - lifecycle

- (void)createSecretChatWithUser:(int64_t)userId
					  completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)openSecretChatId:(int)secretChatId
			  completion:(void (^ _Nullable)(int64_t chatId))completion;

- (void)closeSecretChatId:(int)secretChatId completion:(nullable void (^)(BOOL ok))completion;

- (void)closeSecretChatForChat:(int64_t)chatId
				  deleteHistory:(BOOL)deleteHistory
					 completion:(nullable void (^)(BOOL ok))completion;

#pragma mark - state

- (BOOL)isSecretChat:(int64_t)chatId;

- (int)secretChatIdForChat:(int64_t)chatId;

- (int64_t)secretChatUserIdForChat:(int64_t)chatId;

- (void)secretChatInfoForChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)secretChatStatusForChat:(int64_t)chatId
					 completion:(void (^ _Nullable)(NSString *status))completion;

- (void)canSendInSecretChat:(int64_t)chatId
				 completion:(void (^ _Nullable)(BOOL canSend, NSString *state))completion;

#pragma mark - encryption key

- (void)encryptionKeyGridForChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(NSArray *cells))completion;

- (void)encryptionKeyHashForChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(NSString *base64))completion;

#pragma mark - capability gating

- (void)secretChat:(int64_t)chatId
	supportsFeature:(NSString *)feature
		 completion:(void (^ _Nullable)(BOOL supported))completion;

- (BOOL)secretChat:(int64_t)chatId allowsInputMessage:(NSString *)kind;

- (BOOL)chatAllowsMessageEditing:(int64_t)chatId;

#pragma mark - self-destruct timer

- (void)autoDeleteTimeForChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSInteger seconds))completion;

+ (NSArray *)autoDeleteLadder;

+ (NSString *)autoDeleteTitleForSeconds:(NSInteger)seconds;

- (void)defaultAutoDeleteTimeWithCompletion:(void (^ _Nullable)(NSInteger seconds, BOOL failed))completion;

- (void)setDefaultAutoDeleteTime:(NSInteger)seconds completion:(nullable void (^)(BOOL ok))completion;

#pragma mark - sessions

- (void)setSession:(int64_t)sessionId canAcceptSecretChats:(BOOL)canAccept;

#pragma mark - service messages

- (NSString *)secretServiceTextForMessage:(NSDictionary *)message;

- (NSString *)textForSecretChatNotification:(NSDictionary *)notification;

#pragma mark - account switch

- (void)resetSecretChatCachesForAccountSwitch;

- (void)tgSecretRemember:(NSDictionary *)chat;

@end

NS_ASSUME_NONNULL_END
