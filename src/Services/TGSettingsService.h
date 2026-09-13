#import <Foundation/Foundation.h>
#import "TGClient.h"

@interface TGSettingsService : NSObject

+ (NSDictionary *)me;

+ (TGConnectionState)connectionState;

+ (void)statusForUser:(int64_t)userId completion:(void (^)(NSString *status))completion;

+ (int64_t)savedMessagesChatId;

+ (NSNumber *)photoFileIdForUserId:(int64_t)userId;
+ (void)resolvePhotoFileIdForUserId:(int64_t)userId
						 completion:(void (^)(NSNumber *fileId))completion;

+ (NSArray *)chats;

+ (NSArray *)archivedChats;

+ (int)unreadBadgeCountInChats:(NSArray *)chats;

+ (int)totalUnreadBadgeCount;

+ (BOOL)isFrozen;

+ (BOOL)ageVerificationRequired;

+ (BOOL)hasPendingTermsOfServiceUpdate;

+ (void)chatWithUsername:(NSString *)username
			  completion:(void (^)(int64_t chatId, NSString *title))completion;

+ (void)setLanguage:(NSString *)packId;

+ (void)setAccountTtlDays:(NSInteger)days completion:(void (^)(BOOL ok))completion;

+ (void)titleForChatId:(int64_t)chatId completion:(void (^)(NSString *title))completion;

+ (void)archiveSettingsWithCompletion:(void (^)(NSDictionary *settings))completion;

+ (void)guessedCountryCodeWithCompletion:(void (^)(NSString *countryCode))completion;

+ (void)preferredLanguageForCountry:(NSString *)countryCode
						 completion:(void (^)(NSString *languageCode))completion;

+ (void)logOutWithCompletion:(void (^)(BOOL ok))completion;

+ (void)clearLocalDatabaseWithCompletion:(void (^)(long long freed))completion;

+ (void)premiumStateWithCompletion:(void (^)(NSString *state))completion;

+ (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^)(BOOL ok))completion;

+ (void)languagePacksWithCompletion:(void (^)(NSArray *packs, NSString *current, BOOL failed))completion;

+ (void)synchronizeLanguagePack:(NSString *)packId;

+ (void)languagePackStrings:(NSString *)packId
					   keys:(NSArray *)keys
				 completion:(void (^)(NSDictionary *strings))completion;

+ (void)deleteLanguagePack:(NSString *)packId
				completion:(void (^)(BOOL deleted))completion;

+ (void)setOptionNamed:(NSString *)name value:(id)value isBoolean:(BOOL)isBoolean;

+ (void)optionNamed:(NSString *)name completion:(void (^)(id value))completion;

+ (NSString *)connectionStateTitleForState:(TGConnectionState)state;

+ (void)setDataSaverEnabled:(BOOL)enabled completion:(void (^)(BOOL ok))completion;

+ (void)activeProxyWithCompletion:(void (^)(NSDictionary *proxy))completion;

+ (void)activeProxyIdWithCompletion:(void (^)(NSInteger proxyId))completion;

+ (void)setProxy:(NSInteger)proxyId enabled:(BOOL)enabled completion:(void (^)(BOOL ok))completion;

+ (void)resetNetworkStatisticsWithCompletion:(void (^)(BOOL ok))completion;

+ (void)networkStatsOnlyCurrent:(BOOL)onlyCurrent
					 completion:(void (^)(NSArray *entries, NSInteger sinceDate))completion;

+ (void)networkTotalsOnlyCurrent:(BOOL)onlyCurrent
					  completion:(void (^)(long long sent, long long received,
									 NSDictionary *byNetwork))completion;

+ (void)autosaveSettingsWithCompletion:
	(void (^)(NSDictionary *privateChats, NSDictionary *groups,
		NSDictionary *channels))completion;

+ (void)autosaveExceptionsWithCompletion:(void (^)(NSArray *exceptions))completion;

+ (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				 forScope:(NSString *)scope;

+ (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				 forScope:(NSString *)scope
			   completion:(void (^)(BOOL ok))completion;

+ (void)clearAutosaveExceptionsWithCompletion:(void (^)(BOOL ok))completion;

+ (void)setAutoDownloadSettings:(NSDictionary *)settings
				 forNetworkType:(NSString *)type
					 completion:(void (^)(BOOL ok))completion;

+ (NSDictionary *)autoDownloadSettingsForNetworkType:(NSString *)type;

+ (void)forgetAutoDownloadSettingsMirror;

+ (void)autoDownloadPresetNamed:(NSString *)name
					 completion:(void (^)(NSDictionary *settings))completion;

+ (void)applyAutoDownloadPresetNamed:(NSString *)name
					  toNetworkTypes:(NSArray *)types
						  completion:(void (^)(BOOL ok))completion;

+ (void)installedBackgroundsForDarkTheme:(BOOL)forDarkTheme
							  completion:(void (^)(NSArray *backgrounds, BOOL failed))completion;

+ (void)setDefaultBackgroundId:(NSString *)backgroundId
					   blurred:(BOOL)blurred
						moving:(BOOL)moving
				  forDarkTheme:(BOOL)forDarkTheme
					completion:(void (^)(NSDictionary *background))completion;

+ (void)setDefaultBackgroundRow:(NSDictionary *)row
						blurred:(BOOL)blurred
				   forDarkTheme:(BOOL)forDarkTheme
					 completion:(void (^)(NSDictionary *background))completion;

+ (void)setDefaultBackgroundColor:(NSInteger)color
					 forDarkTheme:(BOOL)forDarkTheme
					   completion:(void (^)(NSDictionary *background))completion;

+ (void)setDefaultBackgroundGradientTop:(NSInteger)topColor
								 bottom:(NSInteger)bottomColor
							   rotation:(NSInteger)rotation
						   forDarkTheme:(BOOL)forDarkTheme
							 completion:(void (^)(NSDictionary *background))completion;

+ (void)setDefaultBackgroundAtPath:(NSString *)path
						   blurred:(BOOL)blurred
					  forDarkTheme:(BOOL)forDarkTheme
						completion:(void (^)(NSDictionary *background))completion;

+ (void)resetDefaultBackgroundForDarkTheme:(BOOL)forDarkTheme completion:(void (^)(BOOL success))completion;

+ (void)shareUrlForBackgroundNamed:(NSString *)name
							  kind:(NSString *)kind
						completion:(void (^)(NSString *url))completion;

+ (void)removeInstalledBackgroundId:(NSString *)backgroundId completion:(void (^)(BOOL success))completion;

+ (void)resetInstalledBackgroundsWithCompletion:(void (^)(BOOL success))completion;

+ (void)hideSuggestedActionNamed:(NSString *)name;

+ (void)acceptArchiveAndMuteSuggestion;

+ (void)notificationSettingsForScope:(NSString *)scope
						  completion:(void (^)(NSDictionary *settings))completion;

+ (void)notificationExceptionsForScope:(NSString *)scope
						  compareSound:(BOOL)compareSound
							completion:(void (^)(NSArray *chats, BOOL failed))completion;

+ (void)clearNotificationExceptionsForScope:(NSString *)scope
								 completion:(void (^)(NSInteger resetCount))completion;

+ (void)resetAllNotificationSettingsWithCompletion:(void (^)(BOOL ok))completion;

+ (void)setReactionNotificationsSource:(NSString *)source
						pollVoteSource:(NSString *)pollVoteSource
						   showPreview:(BOOL)showPreview;

+ (void)setReactionNotificationsSource:(NSString *)source
						pollVoteSource:(NSString *)pollVoteSource
						   showPreview:(BOOL)showPreview
							completion:(void (^)(BOOL ok))completion;

+ (void)savedNotificationSoundsWithCompletion:(void (^)(NSArray *sounds))completion;

+ (void)removeSavedNotificationSound:(long long)soundId;

+ (void)archiveChatListSettingsWithCompletion:(void (^)(NSDictionary *settings))completion;

+ (void)updateArchiveChatListSettings:(NSDictionary *)changes
						   completion:(void (^)(BOOL ok))completion;

+ (void)resetNotificationSettingsForChat:(int64_t)chatId;

+ (void)resetNotificationSettingsForChat:(int64_t)chatId
							   completion:(void (^)(BOOL ok))completion;

+ (void)updateScope:(NSString *)scope
			 values:(NSDictionary *)changes
		 completion:(void (^)(BOOL ok))completion;

+ (void)storyNotificationExceptionsWithCompletion:(void (^)(NSArray *chats, BOOL failed))completion;

+ (void)setChat:(int64_t)chatId storiesMuted:(BOOL)muted;

+ (NSInteger)notificationMuteForever;

+ (void)accentColorsForChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *colors))completion;

+ (void)myAccentColorsWithCompletion:(void (^)(NSDictionary *colors))completion;

+ (NSNumber *)rgbForAccentColorId:(NSInteger)colorId;

+ (NSArray *)profileGradientForColorId:(NSInteger)colorId;

+ (NSArray *)pickableAccentColorIds;

+ (NSArray *)pickableProfileAccentColorIds;

+ (void)setMyAccentColorId:(NSInteger)colorId
	backgroundCustomEmojiId:(int64_t)customEmojiId
				 completion:(void (^)(BOOL ok))completion;

+ (void)setMyProfileAccentColorId:(NSInteger)colorId
		  backgroundCustomEmojiId:(int64_t)customEmojiId
					   completion:(void (^)(BOOL ok))completion;

+ (void)setChatAccentColorId:(NSInteger)colorId
	 backgroundCustomEmojiId:(int64_t)customEmojiId
					 forChat:(int64_t)chatId
				  completion:(void (^)(BOOL ok))completion;

+ (void)setChatProfileAccentColorId:(NSInteger)colorId
			backgroundCustomEmojiId:(int64_t)customEmojiId
							forChat:(int64_t)chatId
						 completion:(void (^)(BOOL ok))completion;

+ (NSString *)accentColorCatalogDidChangeNotificationName;

+ (BOOL)isPremiumAccount;

@end
