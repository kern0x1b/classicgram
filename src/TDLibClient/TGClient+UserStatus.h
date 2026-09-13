#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGAccentColorCatalogDidChangeNotification;

@interface TGClient (UserStatus)

#pragma mark - chat lifecycle

- (void)openChat:(int64_t)chatId;

- (void)closeChat:(int64_t)chatId;

#pragma mark - last seen

+ (NSDictionary *)statusInfoForUserStatus:(nullable NSDictionary *)status;

- (void)statusInfoForUser:(int64_t)userId
			   completion:(void (^ _Nullable)(NSDictionary *info))completion;

+ (nullable NSString *)hiddenStatusHintForStatusInfo:(NSDictionary *)info;

- (void)setSelfOnline:(BOOL)online;

- (void)groupOnlineSummaryForChat:(int64_t)chatId
					   completion:(void (^ _Nullable)(NSString *text, NSInteger members, NSInteger online))completion;

#pragma mark - emoji status

- (void)emojiStatusForUser:(int64_t)userId
				completion:(void (^ _Nullable)(NSDictionary *status))completion;

- (void)emojiStatusForChat:(int64_t)chatId
				completion:(void (^ _Nullable)(NSDictionary *status))completion;

- (void)customEmojiIconsForIds:(NSArray *)ids
					completion:(void (^ _Nullable)(NSDictionary *iconsById))completion;

#pragma mark - bot verification badge

- (void)botVerificationForUser:(int64_t)userId
					completion:(void (^ _Nullable)(NSDictionary *badge))completion;

- (void)botVerificationForChat:(int64_t)chatId
					completion:(void (^ _Nullable)(NSDictionary *badge))completion;

- (void)pickableEmojiStatusIconsWithCompletion:(void (^ _Nullable)(NSArray *icons))completion;

- (void)pickableChatEmojiStatusIconsForChat:(int64_t)chatId
								  completion:(void (^ _Nullable)(NSArray *icons))completion;

- (void)setMyEmojiStatusCustomEmojiId:(int64_t)customEmojiId
					   expirationDate:(int32_t)expirationDate
						   completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)setChatEmojiStatusCustomEmojiId:(int64_t)customEmojiId
						 expirationDate:(int32_t)expirationDate
								forChat:(int64_t)chatId
							 completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

#pragma mark - badges

- (void)badgesForUser:(int64_t)userId
		   completion:(void (^ _Nullable)(NSDictionary *badges))completion;

- (void)badgesForChat:(int64_t)chatId
		   completion:(void (^ _Nullable)(NSDictionary *badges))completion;

#pragma mark - accent colours

- (void)accentColorsForChat:(int64_t)chatId
				 completion:(void (^ _Nullable)(NSDictionary *colors))completion;

- (void)myAccentColorsWithCompletion:(void (^ _Nullable)(NSDictionary *colors))completion;

+ (NSNumber *)rgbForAccentColorId:(NSInteger)colorId;

+ (nullable NSArray *)profileGradientForColorId:(NSInteger)colorId;

+ (NSArray *)pickableAccentColorIds;

+ (NSArray *)pickableProfileAccentColorIds;

- (void)handleUpdateAccentColors:(NSDictionary *)update;

- (void)handleUpdateProfileAccentColors:(NSDictionary *)update;

- (void)setMyAccentColorId:(NSInteger)colorId
	backgroundCustomEmojiId:(int64_t)customEmojiId
				 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setMyProfileAccentColorId:(NSInteger)colorId
		  backgroundCustomEmojiId:(int64_t)customEmojiId
					   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setChatAccentColorId:(NSInteger)colorId
	 backgroundCustomEmojiId:(int64_t)customEmojiId
					 forChat:(int64_t)chatId
				  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setChatProfileAccentColorId:(NSInteger)colorId
			backgroundCustomEmojiId:(int64_t)customEmojiId
							forChat:(int64_t)chatId
						 completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - account switch

- (void)resetUserStatusCachesForAccountSwitch;

@end

NS_ASSUME_NONNULL_END
