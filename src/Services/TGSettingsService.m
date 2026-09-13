#import "TGClient+ChatState.h"
#import "TGSettingsService.h"
#import "TGPreferenceFlags.h"
#import "TGClient+ChatList.h"
#import "TGClient+ChatManagement.h"
#import "TGFlattenChatList.h"
#import "TGClient+Account.h"
#import "TGClient+Translation.h"
#import "TGClient+Network.h"
#import "TGClient+Storage.h"
#import "TGClient+AppSettings.h"
#import "TGClient+Notifications.h"
#import "TGClient+Stories.h"
#import "TGClient+UserStatus.h"
#import "TGClient+Premium.h"
#import "TGAccountManager.h"

@implementation TGSettingsService

+ (NSDictionary *)me {
	return [TGClient shared].me;
}

+ (TGConnectionState)connectionState {
	return [TGClient shared].connectionState;
}

+ (void)statusForUser:(int64_t)userId completion:(void (^)(NSString *status))completion {
	[[TGClient shared] statusForUser:userId completion:completion];
}

+ (int64_t)savedMessagesChatId {
	return [[TGClient shared] savedMessagesChatId];
}

+ (NSNumber *)photoFileIdForUserId:(int64_t)userId {
	return [[TGClient shared] photoFileIdForUserId:userId];
}

+ (void)resolvePhotoFileIdForUserId:(int64_t)userId
						 completion:(void (^)(NSNumber *fileId))completion {
	[[TGClient shared] resolvePhotoFileIdForUserId:userId completion:completion];
}

+ (NSArray *)chats {
	return [TGClient shared].chats;
}

+ (NSArray *)archivedChats {
	return [TGClient shared].archivedChats;
}

+ (int)unreadBadgeCountInChats:(NSArray *)chats {
	return (int)TGUnreadBadgeCountInChatRows(chats,
		[TGPreferenceFlags badgeCountsUnreadChats],
		[TGPreferenceFlags badgeIncludesMuted]);
}

+ (int)totalUnreadBadgeCount {
	NSInteger total = [self unreadBadgeCountInChats:[self chats]];
	total += [self unreadBadgeCountInChats:[self archivedChats]];

	BOOL countChats = [TGPreferenceFlags badgeCountsUnreadChats];
	NSInteger currentSlot = [TGAccountManager shared].currentSlot;
	for (NSDictionary *account in [TGAccountManager shared].accounts) {
		if ([account[@"slot"] integerValue] == currentSlot)
			continue;
		NSInteger accountUnread = [account[@"unread"] integerValue];
		total += countChats ? (accountUnread > 0 ? 1 : 0) : accountUnread;
	}

	return total < 0 ? 0 : total;
}

+ (BOOL)isFrozen {
	return [TGClient shared].frozen;
}

+ (BOOL)ageVerificationRequired {
	return [TGClient shared].ageVerificationRequired;
}

+ (BOOL)hasPendingTermsOfServiceUpdate {
	return [TGClient shared].pendingTermsOfServiceId.length > 0;
}

+ (void)chatWithUsername:(NSString *)username
			  completion:(void (^)(int64_t chatId, NSString *title))completion {
	[[TGClient shared] chatWithUsername:username completion:completion];
}

+ (void)setLanguage:(NSString *)packId {
	[[TGClient shared] setLanguage:packId];
}

+ (void)setAccountTtlDays:(NSInteger)days completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setAccountTtlDays:days completion:completion];
}

+ (void)titleForChatId:(int64_t)chatId completion:(void (^)(NSString *title))completion {
	[[TGClient shared] titleForChatId:chatId completion:completion];
}

+ (void)archiveSettingsWithCompletion:(void (^)(NSDictionary *settings))completion {
	[[TGClient shared] archiveSettingsWithCompletion:completion];
}

+ (void)guessedCountryCodeWithCompletion:(void (^)(NSString *countryCode))completion {
	[[TGClient shared] guessedCountryCodeWithCompletion:completion];
}

+ (void)preferredLanguageForCountry:(NSString *)countryCode
						 completion:(void (^)(NSString *languageCode))completion {
	[[TGClient shared] preferredLanguageForCountry:countryCode completion:completion];
}

+ (void)logOutWithCompletion:(void (^)(BOOL ok))completion {
	[[TGClient shared] logOutWithCompletion:completion];
}

+ (void)clearLocalDatabaseWithCompletion:(void (^)(long long freed))completion {
	[[TGClient shared] clearLocalDatabaseWithCompletion:completion];
}

+ (void)premiumStateWithCompletion:(void (^)(NSString *state))completion {
	[[TGClient shared] premiumStateWithCompletion:completion];
}

+ (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setProfilePhotoAtPath:path completion:completion];
}

+ (void)languagePacksWithCompletion:(void (^)(NSArray *packs, NSString *current, BOOL failed))completion {
	[[TGClient shared] languagePacksWithCompletion:completion];
}

+ (void)synchronizeLanguagePack:(NSString *)packId {
	[[TGClient shared] synchronizeLanguagePack:packId];
}

+ (void)languagePackStrings:(NSString *)packId
					   keys:(NSArray *)keys
				 completion:(void (^)(NSDictionary *strings))completion {
	[[TGClient shared] languagePackStrings:packId keys:keys completion:completion];
}

+ (void)deleteLanguagePack:(NSString *)packId
				completion:(void (^)(BOOL deleted))completion {
	[[TGClient shared] deleteLanguagePack:packId completion:completion];
}

+ (void)setOptionNamed:(NSString *)name value:(id)value isBoolean:(BOOL)isBoolean {
	[[TGClient shared] setOptionNamed:name value:value isBoolean:isBoolean];
}

+ (void)optionNamed:(NSString *)name completion:(void (^)(id value))completion {
	[[TGClient shared] optionNamed:name completion:completion];
}

+ (NSString *)connectionStateTitleForState:(TGConnectionState)state {
	return [[TGClient shared] connectionStateTitleForState:state];
}

+ (void)setDataSaverEnabled:(BOOL)enabled completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setDataSaverEnabled:enabled completion:completion];
}

+ (void)activeProxyWithCompletion:(void (^)(NSDictionary *proxy))completion {
	[[TGClient shared] activeProxyWithCompletion:completion];
}

+ (void)activeProxyIdWithCompletion:(void (^)(NSInteger proxyId))completion {
	[[TGClient shared] activeProxyIdWithCompletion:completion];
}

+ (void)setProxy:(NSInteger)proxyId enabled:(BOOL)enabled completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setProxy:proxyId enabled:enabled completion:completion];
}

+ (void)resetNetworkStatisticsWithCompletion:(void (^)(BOOL ok))completion {
	[[TGClient shared] resetNetworkStatisticsWithCompletion:completion];
}

+ (void)networkStatsOnlyCurrent:(BOOL)onlyCurrent
					 completion:(void (^)(NSArray *entries, NSInteger sinceDate))completion {
	[[TGClient shared] networkStatsOnlyCurrent:onlyCurrent completion:completion];
}

+ (void)networkTotalsOnlyCurrent:(BOOL)onlyCurrent
					  completion:(void (^)(long long sent, long long received,
									 NSDictionary *byNetwork))completion {
	[[TGClient shared] networkTotalsOnlyCurrent:onlyCurrent completion:completion];
}

+ (void)autosaveSettingsWithCompletion:
	(void (^)(NSDictionary *privateChats, NSDictionary *groups,
		NSDictionary *channels))completion {
	[[TGClient shared] autosaveSettingsWithCompletion:completion];
}

+ (void)autosaveExceptionsWithCompletion:(void (^)(NSArray *exceptions))completion {
	[[TGClient shared] autosaveExceptionsWithCompletion:completion];
}

+ (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				 forScope:(NSString *)scope {
	[[TGClient shared] setAutosavePhotos:photos videos:videos maxVideoBytes:maxVideoBytes
								forScope:scope];
}

+ (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				 forScope:(NSString *)scope
			   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setAutosavePhotos:photos
								   videos:videos
							maxVideoBytes:maxVideoBytes
								 forScope:scope
							   completion:completion];
}

+ (void)clearAutosaveExceptionsWithCompletion:(void (^)(BOOL ok))completion {
	[[TGClient shared] clearAutosaveExceptionsWithCompletion:completion];
}

+ (void)setAutoDownloadSettings:(NSDictionary *)settings
				 forNetworkType:(NSString *)type
					 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setAutoDownloadSettings:settings forNetworkType:type completion:completion];
}

+ (NSDictionary *)autoDownloadSettingsForNetworkType:(NSString *)type {
	return [[TGClient shared] autoDownloadSettingsForNetworkType:type];
}

+ (void)forgetAutoDownloadSettingsMirror {
	[[TGClient shared] forgetAutoDownloadSettingsMirror];
}

+ (void)autoDownloadPresetNamed:(NSString *)name
					 completion:(void (^)(NSDictionary *settings))completion {
	[[TGClient shared] autoDownloadPresetNamed:name completion:completion];
}

+ (void)applyAutoDownloadPresetNamed:(NSString *)name
					  toNetworkTypes:(NSArray *)types
						  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] applyAutoDownloadPresetNamed:name toNetworkTypes:types completion:completion];
}

+ (void)installedBackgroundsForDarkTheme:(BOOL)forDarkTheme
							  completion:(void (^)(NSArray *backgrounds, BOOL failed))completion {
	[[TGClient shared] installedBackgroundsForDarkTheme:forDarkTheme completion:completion];
}

+ (void)setDefaultBackgroundId:(NSString *)backgroundId
					blurred:(BOOL)blurred
					 moving:(BOOL)moving
			   forDarkTheme:(BOOL)forDarkTheme
				 completion:(void (^)(NSDictionary *background))completion {
	[[TGClient shared] setDefaultBackgroundId:backgroundId blurred:blurred moving:moving
								   forDarkTheme:forDarkTheme completion:completion];
}

+ (void)setDefaultBackgroundRow:(NSDictionary *)row
						blurred:(BOOL)blurred
				   forDarkTheme:(BOOL)forDarkTheme
					 completion:(void (^)(NSDictionary *background))completion {
	[[TGClient shared] setDefaultBackgroundRow:row blurred:blurred forDarkTheme:forDarkTheme
									completion:completion];
}

+ (void)setDefaultBackgroundColor:(NSInteger)color
					 forDarkTheme:(BOOL)forDarkTheme
					   completion:(void (^)(NSDictionary *background))completion {
	[[TGClient shared] setDefaultBackgroundColor:color forDarkTheme:forDarkTheme
									  completion:completion];
}

+ (void)setDefaultBackgroundGradientTop:(NSInteger)topColor
								 bottom:(NSInteger)bottomColor
							   rotation:(NSInteger)rotation
						   forDarkTheme:(BOOL)forDarkTheme
							 completion:(void (^)(NSDictionary *background))completion {
	[[TGClient shared] setDefaultBackgroundGradientTop:topColor bottom:bottomColor
											  rotation:rotation
										  forDarkTheme:forDarkTheme
											completion:completion];
}

+ (void)setDefaultBackgroundAtPath:(NSString *)path
						   blurred:(BOOL)blurred
					  forDarkTheme:(BOOL)forDarkTheme
						completion:(void (^)(NSDictionary *background))completion {
	[[TGClient shared] setDefaultBackgroundAtPath:path blurred:blurred forDarkTheme:forDarkTheme
									   completion:completion];
}

+ (void)resetDefaultBackgroundForDarkTheme:(BOOL)forDarkTheme completion:(void (^)(BOOL))completion {
	[[TGClient shared] resetDefaultBackgroundForDarkTheme:forDarkTheme completion:completion];
}

+ (void)shareUrlForBackgroundNamed:(NSString *)name
							  kind:(NSString *)kind
						completion:(void (^)(NSString *url))completion {
	[[TGClient shared] shareUrlForBackgroundNamed:name kind:kind completion:completion];
}

+ (void)removeInstalledBackgroundId:(NSString *)backgroundId completion:(void (^)(BOOL))completion {
	[[TGClient shared] removeInstalledBackgroundId:backgroundId completion:completion];
}

+ (void)resetInstalledBackgroundsWithCompletion:(void (^)(BOOL success))completion {
	[[TGClient shared] resetInstalledBackgroundsWithCompletion:completion];
}

+ (void)hideSuggestedActionNamed:(NSString *)name {
	[[TGClient shared] hideSuggestedActionNamed:name];
}

+ (void)acceptArchiveAndMuteSuggestion {
	[[TGClient shared] acceptArchiveAndMuteSuggestion];
}

+ (void)notificationSettingsForScope:(NSString *)scope
						  completion:(void (^)(NSDictionary *settings))completion {
	[[TGClient shared] notificationSettingsForScope:scope completion:completion];
}

+ (void)notificationExceptionsForScope:(NSString *)scope
						  compareSound:(BOOL)compareSound
							completion:(void (^)(NSArray *chats, BOOL failed))completion {
	[[TGClient shared] notificationExceptionsForScope:scope compareSound:compareSound
										   completion:completion];
}

+ (void)clearNotificationExceptionsForScope:(NSString *)scope
								 completion:(void (^)(NSInteger resetCount))completion {
	[[TGClient shared] clearNotificationExceptionsForScope:scope completion:completion];
}

+ (void)resetAllNotificationSettingsWithCompletion:(void (^)(BOOL ok))completion {
	[[TGClient shared] resetAllNotificationSettingsWithCompletion:completion];
}

+ (void)setReactionNotificationsSource:(NSString *)source
						pollVoteSource:(NSString *)pollVoteSource
						   showPreview:(BOOL)showPreview {
	[self setReactionNotificationsSource:source
						 pollVoteSource:pollVoteSource
							showPreview:showPreview
							 completion:nil];
}

+ (void)setReactionNotificationsSource:(NSString *)source
						pollVoteSource:(NSString *)pollVoteSource
						   showPreview:(BOOL)showPreview
							completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] changeReactionNotificationSettings:@{
		@"messageSource" : source ?: @"none",
		@"pollVoteSource" : pollVoteSource ?: @"none",
		@"showPreview" : @(showPreview),
	}
											  completion:completion];
}

+ (void)savedNotificationSoundsWithCompletion:(void (^)(NSArray *sounds))completion {
	[[TGClient shared] savedNotificationSoundsWithCompletion:completion];
}

+ (void)removeSavedNotificationSound:(long long)soundId {
	[[TGClient shared] removeSavedNotificationSound:soundId];
}

+ (void)archiveChatListSettingsWithCompletion:(void (^)(NSDictionary *settings))completion {
	[[TGClient shared] archiveChatListSettingsWithCompletion:completion];
}

+ (void)updateArchiveChatListSettings:(NSDictionary *)changes
						   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] updateArchiveChatListSettings:changes completion:completion];
}

+ (void)resetNotificationSettingsForChat:(int64_t)chatId {
	[[TGClient shared] resetNotificationSettingsForChat:chatId];
}

+ (void)resetNotificationSettingsForChat:(int64_t)chatId
							   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] resetNotificationSettingsForChat:chatId completion:completion];
}

+ (void)updateScope:(NSString *)scope
			 values:(NSDictionary *)changes
		 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] updateScope:scope values:changes completion:completion];
}

+ (void)storyNotificationExceptionsWithCompletion:(void (^)(NSArray *chats, BOOL failed))completion {
	[[TGClient shared] storyNotificationExceptionsWithCompletion:completion];
}

+ (void)setChat:(int64_t)chatId storiesMuted:(BOOL)muted {
	[[TGClient shared] setChat:chatId storiesMuted:muted];
}

+ (NSInteger)notificationMuteForever {
	return kNotificationMuteForever;
}

+ (void)accentColorsForChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *colors))completion {
	[[TGClient shared] accentColorsForChat:chatId completion:completion];
}

+ (void)myAccentColorsWithCompletion:(void (^)(NSDictionary *colors))completion {
	[[TGClient shared] myAccentColorsWithCompletion:completion];
}

+ (NSNumber *)rgbForAccentColorId:(NSInteger)colorId {
	return [TGClient rgbForAccentColorId:colorId];
}

+ (NSArray *)profileGradientForColorId:(NSInteger)colorId {
	return [TGClient profileGradientForColorId:colorId];
}

+ (NSArray *)pickableAccentColorIds {
	return [TGClient pickableAccentColorIds];
}

+ (NSArray *)pickableProfileAccentColorIds {
	return [TGClient pickableProfileAccentColorIds];
}

+ (void)setMyAccentColorId:(NSInteger)colorId
	backgroundCustomEmojiId:(int64_t)customEmojiId
				 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setMyAccentColorId:colorId backgroundCustomEmojiId:customEmojiId completion:completion];
}

+ (void)setMyProfileAccentColorId:(NSInteger)colorId
		  backgroundCustomEmojiId:(int64_t)customEmojiId
					   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setMyProfileAccentColorId:colorId backgroundCustomEmojiId:customEmojiId completion:completion];
}

+ (void)setChatAccentColorId:(NSInteger)colorId
	 backgroundCustomEmojiId:(int64_t)customEmojiId
					 forChat:(int64_t)chatId
				  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChatAccentColorId:colorId backgroundCustomEmojiId:customEmojiId
									forChat:chatId
								 completion:completion];
}

+ (void)setChatProfileAccentColorId:(NSInteger)colorId
			backgroundCustomEmojiId:(int64_t)customEmojiId
							forChat:(int64_t)chatId
						 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setChatProfileAccentColorId:colorId backgroundCustomEmojiId:customEmojiId
										   forChat:chatId
										completion:completion];
}

+ (NSString *)accentColorCatalogDidChangeNotificationName {
	return TGAccentColorCatalogDidChangeNotification;
}

+ (BOOL)isPremiumAccount {
	return [[TGClient shared] isPremiumAccount];
}

@end
