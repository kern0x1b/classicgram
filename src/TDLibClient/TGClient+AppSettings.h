#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (AppSettings)

#pragma mark - wallpapers

- (void)installedBackgroundsForDarkTheme:(BOOL)forDarkTheme
							  completion:(void (^ _Nullable)(NSArray *backgrounds, BOOL failed))completion;

- (void)setDefaultBackgroundId:(NSString *)backgroundId
					   blurred:(BOOL)blurred
						moving:(BOOL)moving
				  forDarkTheme:(BOOL)forDarkTheme
					completion:(void (^ _Nullable)(NSDictionary *background))completion;

- (void)setDefaultBackgroundRow:(NSDictionary *)row
						blurred:(BOOL)blurred
				   forDarkTheme:(BOOL)forDarkTheme
					 completion:(void (^ _Nullable)(NSDictionary *background))completion;

- (void)setDefaultBackgroundColor:(NSInteger)color
					 forDarkTheme:(BOOL)forDarkTheme
					   completion:(void (^ _Nullable)(NSDictionary *background))completion;

- (void)setDefaultBackgroundGradientTop:(NSInteger)topColor
								 bottom:(NSInteger)bottomColor
							   rotation:(NSInteger)rotation
						   forDarkTheme:(BOOL)forDarkTheme
							 completion:(void (^ _Nullable)(NSDictionary *background))completion;

- (void)setDefaultBackgroundAtPath:(NSString *)path
						   blurred:(BOOL)blurred
					  forDarkTheme:(BOOL)forDarkTheme
						completion:(void (^ _Nullable)(NSDictionary *background))completion;

- (void)resetDefaultBackgroundForDarkTheme:(BOOL)forDarkTheme completion:(void (^ _Nullable)(BOOL success))completion;

- (void)shareUrlForBackgroundNamed:(NSString *)name
							  kind:(NSString *)kind
						completion:(void (^ _Nullable)(NSString *url))completion;

- (void)removeInstalledBackgroundId:(NSString *)backgroundId completion:(void (^ _Nullable)(BOOL success))completion;
- (void)resetInstalledBackgroundsWithCompletion:(void (^ _Nullable)(BOOL success))completion;

#pragma mark - per-chat wallpaper

- (void)chatBackgroundRowForChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(NSDictionary *row, NSInteger darkThemeDimming))completion;

- (void)setChatBackgroundRow:(NSDictionary *)row
					 blurred:(BOOL)blurred
					 forChat:(int64_t)chatId
				 onlyForSelf:(BOOL)onlyForSelf
				  completion:(void (^ _Nullable)(BOOL success, BOOL premiumRequired))completion;

- (void)setChatBackgroundAtPath:(NSString *)path
						blurred:(BOOL)blurred
						forChat:(int64_t)chatId
					onlyForSelf:(BOOL)onlyForSelf
					 completion:(void (^ _Nullable)(BOOL success, BOOL premiumRequired))completion;

- (void)resetChatBackgroundForChat:(int64_t)chatId
						completion:(void (^ _Nullable)(BOOL success))completion;

- (void)deleteChatBackgroundForChat:(int64_t)chatId
					restorePrevious:(BOOL)restorePrevious
						 completion:(void (^ _Nullable)(BOOL success))completion;

#pragma mark - per-chat theme

- (void)setChatThemeName:(NSString *)themeName
				 forChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(BOOL success))completion;

- (NSArray *)emojiChatThemeRows;

- (void)chatThemeEmojiForChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSString *emoji))completion;

- (void)chatThemeColoursForChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(NSDictionary *colours))completion;

- (void)handleUpdateEmojiChatThemes:(NSDictionary *)update;

#pragma mark - web browser settings

- (void)handleUpdateWebBrowserSettings:(NSDictionary *)update;

- (NSDictionary *)cachedWebBrowserSettings;

- (BOOL)shouldOpenExternallyForUrl:(NSString *)url;

- (void)changeWebBrowserSettingsOpenExternal:(BOOL)openExternal
						  displayCloseButton:(BOOL)displayCloseButton
								  completion:(void (^ _Nullable)(BOOL success))completion;

- (void)addWebBrowserSettingsExceptionForUrl:(NSString *)url
							  openExternally:(BOOL)openExternal
								  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)removeWebBrowserSettingsExceptionForUrl:(NSString *)url
									 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)removeAllWebBrowserSettingsExceptionsWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - account switch

- (void)resetAppSettingsCachesForAccountSwitch;

#pragma mark - save to camera roll

#pragma mark - suggested actions

- (void)hideSuggestedActionNamed:(NSString *)name;

- (void)acceptArchiveAndMuteSuggestion;

@end

NS_ASSUME_NONNULL_END
