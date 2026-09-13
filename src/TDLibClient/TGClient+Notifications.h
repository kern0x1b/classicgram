#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger kNotificationMuteForever;

extern NSString *const TGScopeNotificationSettingsDidChangeNotification;

extern NSString *const TGNotificationUpdateNotification;
extern NSString *const TGServiceNotificationDidArriveNotification;

@interface TGClient (Notifications)

#pragma mark - scope settings

- (void)notificationSettingsForScope:(NSString *)scope
						  completion:(void (^ _Nullable)(NSDictionary *settings))completion;

- (void)updateScope:(NSString *)scope
			 values:(NSDictionary *)changes
		 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setScope:(NSString *)scope muteForSeconds:(NSInteger)seconds;

#pragma mark - per-chat settings

- (void)notificationSettingsForChat:(int64_t)chatId
						 completion:(void (^ _Nullable)(NSDictionary *settings))completion;

- (void)setChat:(int64_t)chatId muteForSeconds:(NSInteger)seconds;

- (void)setChat:(int64_t)chatId
	muteForSeconds:(NSInteger)seconds
		completion:(nullable void (^)(BOOL ok))completion;

- (void)updateChat:(int64_t)chatId
			values:(NSDictionary *)changes
		completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)resetNotificationSettingsForChat:(int64_t)chatId;

- (void)resetNotificationSettingsForChat:(int64_t)chatId
							   completion:(nullable void (^)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId defaultDisableNotification:(BOOL)silent;

#pragma mark - exceptions

- (void)notificationExceptionsForScope:(NSString *)scope
						  compareSound:(BOOL)compareSound
							completion:(void (^ _Nullable)(NSArray *chats, BOOL failed))completion;

- (void)clearNotificationExceptionsForScope:(NSString *)scope
								 completion:(void (^ _Nullable)(NSInteger resetCount))completion;

- (void)resetAllNotificationSettingsWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - reactions

extern NSString *const TGReactionNotificationMessageSourceKey;
extern NSString *const TGReactionNotificationStorySourceKey;
extern NSString *const TGReactionNotificationPollVoteSourceKey;
extern NSString *const TGReactionNotificationPreviewKey;
extern NSString *const TGReactionNotificationSoundIdKey;

- (NSDictionary *)reactionNotificationSettings;

- (void)changeReactionNotificationSettings:(NSDictionary *)changes
								completion:(nullable void (^)(BOOL ok))completion;

- (void)applyReactionNotificationSettingsUpdate:(NSDictionary *)update;

#pragma mark - sounds

- (void)savedNotificationSoundsWithCompletion:(void (^ _Nullable)(NSArray *sounds))completion;

- (void)addSavedNotificationSoundAtPath:(NSString *)path
							 completion:(void (^ _Nullable)(NSDictionary *sound))completion;

- (void)removeSavedNotificationSound:(long long)soundId;

#pragma mark - archive settings

- (void)archiveChatListSettingsWithCompletion:(void (^ _Nullable)(NSDictionary *settings))completion;

- (void)updateArchiveChatListSettings:(NSDictionary *)changes
						   completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - local alerts

- (void)removeNotification:(NSInteger)notificationId inGroup:(NSInteger)groupId;

- (void)removeNotificationGroup:(NSInteger)groupId
			 upToNotificationId:(NSInteger)maxNotificationId;

- (NSString *)previewTextForPushContent:(NSDictionary *)content actorName:(NSString *)actorName;

- (NSString *)previewTextForMessageContent:(NSDictionary *)content actorName:(NSString *)actorName;

- (NSString *)titleForChatId:(int64_t)chatId;

- (NSDictionary *)alertForNotification:(NSDictionary *)notification
							  chatName:(NSString *)chatName;

@end

NS_ASSUME_NONNULL_END
