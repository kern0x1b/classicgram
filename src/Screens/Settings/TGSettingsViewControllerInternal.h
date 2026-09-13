#import <UIKit/UIKit.h>
#import "TGSettingsViewController.h"
#import "TGInAppNotificationPreferences.h"

extern const CGFloat kHeaderHeight;
extern const CGFloat kHeaderAvatar;

enum {
	TGSettingsPageAutoDownload = 100,
	TGSettingsPageAutosave = 101,
	TGSettingsPageWallpaper = 102,
	TGSettingsPageChatListLayout = 103,
	TGSettingsPageDataUsage = 104,
	TGSettingsPageAutoDownloadKind = 105,
	TGSettingsPageTextSize = 106,
	TGSettingsPageNotificationExceptions = 110,
	TGSettingsPageNotificationSounds = 111,
	TGSettingsPageNotificationTone = 112
};

enum {
	TGSettingsUsageSectionTotal = 0,
	TGSettingsUsageSectionMedia,
	TGSettingsUsageSectionCalls,
	TGSettingsUsageSectionReset,
	TGSettingsUsageSectionCount
};

enum {
	TGSettingsNotifSectionPrivate = 0,
	TGSettingsNotifSectionGroups,
	TGSettingsNotifSectionChannels,
	TGSettingsNotifSectionReactions,
	TGSettingsNotifSectionStories,
	TGSettingsNotifSectionContacts,
	TGSettingsNotifSectionSounds,
	TGSettingsNotifSectionBadge,
	TGSettingsNotifSectionInApp,
	TGSettingsNotifSectionReset,
	TGSettingsNotifSectionCount
};

enum {
	TGSettingsRootKindSuggestions = 0,
	TGSettingsRootKindPhoto,
	TGSettingsRootKindAccounts,
	TGSettingsRootKindProfile,
	TGSettingsRootKindProxy,
	TGSettingsRootKindShortcuts,
	TGSettingsRootKindAdvanced,
	TGSettingsRootKindPayment,
	TGSettingsRootKindExtra,
	TGSettingsRootKindHelp,
	TGSettingsRootKindLogout
};

extern NSString *const TGSettingsPresetDefaultsKey;
extern NSString *const TGSettingsSavedPresetsKey;
extern NSString *const TGSettingsSavedCustomSettingsKey;
extern NSString *const TGSettingsLessCallDataKey;
extern NSString *const TGSettingsArchiveSuggestionKey;
extern NSString *TGSettingsReactionSourceKey(void);
extern NSString *TGSettingsReactionPreviewKey(void);
extern NSString *TGSettingsPollVoteSourceKey(void);
extern NSString *const TGSettingsLastProxyKey;
extern NSString *const TGSettingsContactRegisteredOption;
extern NSString *const TGSettingsStoriesExceptionsScope;
extern NSString *const TGSettingsWallpaperBlurKey;
extern NSString *const TGSettingsTopChatsOption;

enum {
	TGSettingsLanguageSectionTranslation = 0,
	TGSettingsLanguageSectionList = 1
};

BOOL TGSettingsTabletLayout(void);

BOOL TGSettingsShowInDetailPane(UIViewController *sender,
	UIViewController *target);

CGFloat TGSettingsScreenWidth(void);

CGFloat TGSettingsGroupedInset(CGFloat width);

NSString *TGSettingsBytes(long long bytes);

NSString *TGSettingsDuration(double seconds);

@interface TGSettingsViewController () <UIActionSheetDelegate, UIAlertViewDelegate,
	UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) NSInteger slotPendingSignOut;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) NSMutableDictionary *muted;
@property (nonatomic, strong) NSArray *languages;
@property (nonatomic, strong) NSString *currentLanguage;
@property (nonatomic, assign) BOOL languagesLoaded;
@property (nonatomic, assign) BOOL languagesFailed;
@property (nonatomic, strong) UILabel *headerNameLabel;
@property (nonatomic, strong) UILabel *headerStatusLabel;
@property (nonatomic, strong) NSMutableDictionary *archive;
@property (nonatomic, assign) BOOL dataSaver;
@property (nonatomic, strong) NSMutableDictionary *autosave;
@property (nonatomic, strong) NSArray *backgrounds;
@property (nonatomic, assign) BOOL backgroundsLoaded;
@property (nonatomic, assign) BOOL backgroundsFailed;
@property (nonatomic, assign) BOOL lessCallData;
@property (nonatomic, strong) NSArray *suggestions;
@property (nonatomic, strong) NSMutableDictionary *scopeSettings;
@property (nonatomic, assign) NSUInteger reactionSettingsWriteGeneration;
@property (nonatomic, strong) NSMutableDictionary *exceptionCounts;
@property (nonatomic, strong) NSArray *exceptions;
@property (nonatomic, assign) BOOL exceptionsLoaded;
@property (nonatomic, assign) BOOL exceptionsFailed;
@property (nonatomic, strong) NSString *exceptionsScope;
@property (nonatomic, assign) BOOL contactRegisteredMuted;
@property (nonatomic, strong) NSArray *usageMedia;
@property (nonatomic, strong) NSDictionary *usageCalls;
@property (nonatomic, strong) NSArray *usageNetworks;
@property (nonatomic, assign) long long usageSent;
@property (nonatomic, assign) long long usageReceived;
@property (nonatomic, assign) NSInteger usageSince;
@property (nonatomic, assign) BOOL usageLoaded;
@property (nonatomic, strong) NSArray *autosaveExceptions;
@property (nonatomic, assign) BOOL autosaveExceptionsLoaded;
@property (nonatomic, strong) NSMutableDictionary *chatTitles;
@property (nonatomic, assign) BOOL wallpaperBlurred;
@property (nonatomic, strong) UIImage *wallpaperOriginal;
@property (nonatomic, strong) NSString *wallpaperBackgroundId;
@property (nonatomic, assign) BOOL wallpaperBackgroundIsMoving;
@property (nonatomic, strong) NSString *proxyDetail;
@property (nonatomic, strong) NSString *suggestedLanguage;
@property (nonatomic, strong) NSDictionary *pressedBackground;
@property (nonatomic, strong) NSString *premiumSummary;
@property (nonatomic, strong) NSArray *savedSounds;
@property (nonatomic, assign) BOOL savedSoundsLoaded;
@property (nonatomic, strong) NSDictionary *pressedSound;
@property (nonatomic, assign) NSInteger activeProxyId;
@property (nonatomic, strong) id connectionStateObserverToken;
@property (nonatomic, strong) id notificationUpdateObserverToken;
@property (nonatomic, strong) id defaultBackgroundObserverToken;
@property (nonatomic, strong) id accountSignOutFailedObserverToken;
@property (nonatomic, strong) id accountsChangedObserverToken;
@property (nonatomic, assign) BOOL pickingProfilePhoto;
@property (nonatomic, strong) UIPopoverController *pickerPopover;
@property (nonatomic, strong) NSArray *photoSheetActions;
@property (nonatomic, assign) BOOL detailPaneShown;
@property (nonatomic, assign) BOOL topChatsDisabled;
@property (nonatomic, assign) BOOL topChatsLoaded;
@property (nonatomic, copy) NSString *autoDownloadKind;
@property (nonatomic, strong) NSMutableDictionary *autoDownloadValues;
- (void)openViewController:(UIViewController *)next;
- (void)updateEditButton;
- (UIView *)disclosureAccessory;
- (UIView *)checkAccessory;
- (void)markDisclosure:(UITableViewCell *)cell;
- (void)markChecked:(BOOL)checked on:(UITableViewCell *)cell;
- (id)init;
- (void)viewDidLoad;
- (NSString *)titleForCurrentPage;
- (void)editTapped;
- (BOOL)canEditNotificationExceptionRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)commitDeleteNotificationExceptionAtIndexPath:(NSIndexPath *)indexPath;
- (void)applyTheme;
- (void)viewWillAppear:(BOOL)animated;
- (void)openPage:(TGSettingsPage)page;
@end

@interface TGSettingsViewController (Header)

- (void)applyBottomBarInset;
- (void)buildHeader;
- (NSString *)displayName;
- (NSString *)initialsForName:(NSString *)name;
- (void)refreshHeader;
- (void)buildVersionFooter;
- (void)buildHeaderAvatarIn:(UIView *)header
					forName:(NSString *)name
					account:(NSDictionary *)me;
- (void)buildHeaderNameLabelIn:(UIView *)header
						 width:(CGFloat)width
						  name:(NSString *)name;
- (void)buildHeaderStatusLabelIn:(UIView *)header
						   width:(CGFloat)width;
- (void)viewDidLayoutSubviews;
- (void)layoutHeaderForWidth:(CGFloat)width;
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;
- (CGFloat)commentHeightForCaption:(NSString *)caption;
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;

@end

@interface TGSettingsViewController (Loading)

- (void)loadForPage;
- (void)loadUsage;
- (void)loadProxyStatus;
- (void)loadTitlesForAutosaveExceptions;
+ (NSString *)usageNetworkTitle:(NSString *)name;
- (void)loadAutosaveSettings;
- (void)loadAutosavePage;
- (void)loadWallpaperPage;
- (void)loadRootPage;
- (void)loadPremiumSummary;
- (void)loadNotificationsPage;
- (void)loadExceptionsPage;
- (void)loadLanguagePage;
- (void)loadDataPage;
- (void)loadUsageByKind;
- (void)loadUsageTotals;
- (void)loadSuggestions;
- (BOOL)showsSuggestions;
- (NSInteger)rootKindForSection:(NSInteger)section;
- (void)acceptSuggestionAtRow:(NSInteger)row;
- (void)dismissSuggestionAtRow:(NSInteger)row;
- (void)suggestionDismissTapped:(UIButton *)button;

@end

@interface TGSettingsViewController (AutoDownload)

+ (NSString *)titleForNetworkKind:(NSString *)kind;
- (UIImage *)blankSwatchOfSize:(CGSize)size;
+ (NSString *)kindOfBackground:(NSDictionary *)background;
+ (NSString *)titleForBackground:(NSDictionary *)background at:(NSInteger)index;
- (NSInteger)ordinalOfBackgroundAtRow:(NSInteger)row;
+ (NSString *)detailForBackground:(NSDictionary *)background;
- (void)applyDataSaver:(BOOL)on;
+ (NSArray *)autoDownloadKindKeys;
+ (NSArray *)autoDownloadKindTitles;
+ (NSArray *)autoDownloadPhotoLimits;
+ (NSArray *)autoDownloadFileLimits;
+ (NSArray *)autoDownloadLimitsForKey:(NSString *)key;
+ (NSString *)autoDownloadLimitTitle:(long long)bytes;
- (void)loadAutoDownloadKindPage;
- (BOOL)autoDownloadFlagForKey:(NSString *)key;
- (long long)autoDownloadLimitForKey:(NSString *)key;
- (void)commitAutoDownloadValuesFrom:(NSDictionary *)previousValues;
- (NSInteger)autoDownloadKindRowsInSection:(NSInteger)section;
- (NSString *)autoDownloadKindHeaderForSection:(NSInteger)section;
- (NSString *)autoDownloadKindFooterForSection:(NSInteger)section;
- (UITableViewCell *)fillAutoDownloadKindCell:(UITableViewCell *)cell
										   at:(NSIndexPath *)path;
- (void)autoDownloadEnabledToggled:(UISwitch *)toggle;
- (void)autoDownloadPreloadToggled:(UISwitch *)toggle;
- (void)tapAutoDownloadKind:(NSIndexPath *)path;
- (void)applyAutoDownloadLimitFromSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index;
- (void)applyAutoDownloadPresetFromSheetAtIndex:(NSInteger)index;
- (UITableViewCell *)fillUsageCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillUsageTotalCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillUsageMediaCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillUsageCallsCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillAutosaveCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillAutosaveExceptionCell:(UITableViewCell *)cell
											at:(NSIndexPath *)path;
+ (NSString *)colourWord:(NSDictionary *)background;
- (UIImage *)swatchForBackground:(NSDictionary *)background size:(CGSize)size;
- (UIImage *)compositePatternImage:(UIImage *)pattern
					overBackground:(NSDictionary *)background
							  size:(CGSize)size;
+ (NSArray *)builtinWallpaperNames;
+ (NSString *)builtinWallpaperFileAtIndex:(NSInteger)index;
- (UITableViewCell *)fillWallpaperCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillBuiltinWallpaperCell:(UITableViewCell *)cell
										   at:(NSIndexPath *)path;
- (UIImage *)swatchFromImage:(UIImage *)image size:(CGSize)size;
- (UITableViewCell *)fillWallpaperChooserCell:(UITableViewCell *)cell
										   at:(NSIndexPath *)path;
+ (NSArray *)archiveKeys;
+ (NSArray *)archiveTitles;
- (UITableViewCell *)fillDataCell:(UITableViewCell *)cell at:(NSIndexPath *)indexPath;
- (UITableViewCell *)fillDataMainCell:(UITableViewCell *)cell
								   at:(NSIndexPath *)indexPath;
- (UITableViewCell *)fillDataPrivacyCell:(UITableViewCell *)cell
									  at:(NSIndexPath *)indexPath;
- (void)syncContactsToggled:(UISwitch *)toggle;
- (void)secretLinkPreviewsToggled:(UISwitch *)toggle;
- (void)frequentContactsToggled:(UISwitch *)toggle;
- (UITableViewCell *)fillArchiveCell:(UITableViewCell *)cell
								  at:(NSIndexPath *)indexPath;
- (void)dataSaverToggled:(UISwitch *)toggle;
- (void)archiveToggled:(UISwitch *)toggle;
- (void)lessCallDataToggled:(UISwitch *)toggle;
- (void)writeLessCallData:(BOOL)useLess completion:(void (^)(BOOL ok))completion;
- (void)autosaveToggled:(UISwitch *)toggle;

@end

@interface TGSettingsViewController (Wallpaper)

- (void)showPicker:(UIImagePickerController *)picker;
- (void)showSheet:(UIActionSheet *)sheet;
- (CGRect)anchorRect;
- (BOOL)dismissPickerPopover;
- (UIImage *)wallpaperSizedImage:(UIImage *)image;
- (void)uploadWallpaperFromOriginal;
- (void)adoptBackgroundLocally:(NSDictionary *)background;
+ (NSArray *)wallpaperColourNames;
+ (NSArray *)wallpaperColourValues;
+ (NSArray *)wallpaperGradientNames;
+ (NSArray *)wallpaperGradientValues;
- (void)confirmResetUsage;
- (void)installWallpaperFromOriginal;
- (UIImage *)blurredWallpaper:(UIImage *)image;
- (void)tapWallpaper:(NSIndexPath *)indexPath;
- (void)confirmClearBackgroundList;
- (void)applyBuiltinWallpaperAtRow:(NSInteger)row;
- (void)syncBuiltinWallpaperNamed:(NSString *)name;
- (void)tapWallpaperChooserRow:(NSInteger)row;
- (void)showWallpaperColourSheet;
- (void)pushWallpaperGradientScreen;
- (void)applyBackground:(NSDictionary *)background;
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index;
- (void)handleUntaggedWallpaperSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index;
- (void)handleWallpaperSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index;
- (void)applyReactionSourceFromSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index;
- (void)toggleProxyFromSheet;
- (void)deletePressedSound;
- (void)applyWallpaperFillFromSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index;
- (void)handlePressedBackgroundSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index;
- (void)presentWallpaperPicker;
- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info;
- (void)wallpaperBlurToggled:(UISwitch *)toggle;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)confirmedLogOut;
- (void)confirmedClearLocalDatabase;
- (void)confirmedClearAutosaveExceptions;
- (void)confirmedResetInstalledBackgrounds;
- (void)confirmedResetUsage;
- (void)confirmedClearNotificationExceptions;
- (void)confirmedResetAllNotificationSettings;

@end

@interface TGSettingsViewController (Notifications)

+ (NSString *)pollVoteSource;
- (void)writeReactionSource:(NSString *)source
			 pollVoteSource:(NSString *)pollVoteSource
					preview:(BOOL)preview;
+ (NSArray *)notificationScopes;
+ (NSArray *)notificationScopeTitles;
+ (NSArray *)notificationRowsForSection:(NSInteger)section;
+ (NSArray *)reactionSources;
+ (NSArray *)reactionSourceTitles;
+ (NSString *)reactionSource;
+ (BOOL)reactionPreview;
- (NSDictionary *)settingsForScopeAtSection:(NSInteger)section;

@end

@interface TGSettingsViewController (Taps)

- (void)openNotificationSounds;
- (UIViewController *)savedMessagesController;
- (void)savedTopicsToggled:(UISwitch *)toggle;
- (void)callsTabToggled:(UISwitch *)toggle;
- (void)loadSavedSounds;
- (UITableViewCell *)fillToneCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (void)tapTone:(NSIndexPath *)path;
- (void)openNotificationTone;
- (void)tapSound:(NSIndexPath *)path;
- (BOOL)canClearExceptions;
- (void)confirmClearExceptions;
- (void)openExceptionsForScope:(NSString *)scope;
- (void)confirmClearDatabase;
- (void)removeChatWallpaperPressed;
- (void)confirmDeleteSyncedContacts;
- (void)confirmedDeleteSyncedContacts;
- (void)longPressed:(UILongPressGestureRecognizer *)gesture;
- (void)notificationToggled:(UISwitch *)toggle;
- (NSDictionary *)scopeChangesForKind:(NSString *)kind on:(BOOL)on;
- (void)applyScopeToggle:(UISwitch *)toggle
				 section:(NSInteger)section
					 row:(NSInteger)row;
- (void)tapNotifications:(NSIndexPath *)path;
- (void)showPollVoteSourceSheet;
- (void)showReactionSourceSheet;
- (void)confirmResetAllNotifications;
- (void)tapException:(NSIndexPath *)path;
- (void)showNotificationOptionsForExceptionChat:(int64_t)chatId atIndexPath:(NSIndexPath *)path;
- (void)showMuteDurationsForExceptionChat:(int64_t)chatId muted:(BOOL)muted;
- (void)togglePreviewForExceptionChat:(int64_t)chatId currentlyOn:(BOOL)preview;
- (void)reportExceptionSettingCouldNotBeChanged;
- (void)removeExceptionForChatId:(int64_t)chatId;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)handleSelectionAtIndexPath:(NSIndexPath *)indexPath
						   inTable:(UITableView *)tableView;
- (void)tapRootRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tapShortcutRow:(NSInteger)row;
- (void)tapAdvancedRow:(NSInteger)row;
- (void)tapPaymentRow:(NSInteger)row;
- (void)tapData:(NSIndexPath *)indexPath;
- (void)confirmLogout;
- (void)openHelp:(NSInteger)row;
- (void)openSupportChat:(int64_t)chatId title:(NSString *)title;
- (void)tapLanguage:(NSIndexPath *)indexPath;
- (void)pressBackgroundAtRow:(NSInteger)row;
- (void)tapAppearance:(NSIndexPath *)indexPath;

@end

@interface TGSettingsViewController (Rows)

- (void)showTranslateToggled:(UISwitch *)toggle;
- (UITableViewCell *)fillTranslationCell:(UITableViewCell *)cell;
- (UITableViewCell *)fillSoundCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
+ (NSArray *)accountsRows;
+ (NSArray *)profileRows;
+ (NSArray *)proxyRows;
+ (NSArray *)shortcutRows;
+ (NSArray *)advancedRows;
+ (NSArray *)paymentRows;
+ (NSArray *)extraRows;
+ (NSArray *)helpRows;
- (BOOL)canDeleteLanguagePackAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)fillRootCell:(UITableViewCell *)cell at:(NSIndexPath *)indexPath;
- (NSArray *)rootRowTableForKind:(NSInteger)kind;
- (void)decorateRootCell:(UITableViewCell *)cell
					kind:(NSInteger)kind
				   title:(NSString *)title;
- (UITableViewCell *)profilePhotoCellInTable:(UITableView *)tableView;
- (void)changePhotoButtonPressed;
- (void)presentProfilePhotoPickerFromSource:(UIImagePickerControllerSourceType)source;
- (void)takeProfilePhoto:(UIImage *)image;
- (UITableViewCell *)logoutCellInTable:(UITableView *)tableView;
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (UISwitch *)notificationSwitchOn:(BOOL)on tag:(NSInteger)tag;
- (UITableViewCell *)fillNotificationCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillReactionCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillNotificationScopeCell:(UITableViewCell *)cell
											at:(NSIndexPath *)path;
- (UITableViewCell *)fillExceptionCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillStoriesCell:(UITableViewCell *)cell;
- (UITableViewCell *)fillChatListLayoutCell:(UITableViewCell *)cell
										 at:(NSIndexPath *)path;
- (UITableViewCell *)fillLanguageCell:(UITableViewCell *)cell at:(NSIndexPath *)path;
- (UITableViewCell *)fillTextSizeCell:(UITableViewCell *)cell
								   at:(NSIndexPath *)path;
- (UITableViewCell *)fillAppearanceCell:(UITableViewCell *)cell at:(NSIndexPath *)indexPath;
- (UITableViewCell *)fillCallsTabCell:(UITableViewCell *)cell;
- (UITableViewCell *)fillSavedAsListCell:(UITableViewCell *)cell;
- (UITableViewCell *)suggestionCellInTable:(UITableView *)tableView
										at:(NSIndexPath *)indexPath;
- (UITableViewCell *)fillAutoDownloadCell:(UITableViewCell *)cell at:(NSIndexPath *)path;

@end

@interface TGSettingsViewController (AutoDownloadActions)

- (void)tapAutoDownload:(NSIndexPath *)indexPath;
- (void)confirmClearAutosaveExceptions;

@end

@interface TGSettingsViewController (DeviceSwitches)

- (void)storiesToggled:(UISwitch *)toggle;

@end

@interface TGSettingsViewController (RTLMirroring)

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface TGSettingsViewController (Shape)

+ (NSArray *)networkKinds;
+ (NSArray *)networkTitles;
+ (NSArray *)presetNames;
+ (NSArray *)autosaveScopes;
+ (NSArray *)autosaveTitles;
- (NSString *)presetNameForNetwork:(NSString *)kind;
- (void)rememberPreset:(NSString *)name forNetwork:(NSString *)kind;
- (NSString *)detailForNetwork:(NSString *)kind;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (NSInteger)autosaveRowsInSection:(NSInteger)section;
- (NSInteger)usageRowsInSection:(NSInteger)section;
- (NSInteger)wallpaperRowsInSection:(NSInteger)section;
- (NSInteger)rootRowsInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section;
- (NSString *)autoDownloadFooterForSection:(NSInteger)section;
- (NSString *)autosaveFooterForSection:(NSInteger)section;
- (NSString *)usageFooterForSection:(NSInteger)section;
- (NSString *)wallpaperFooterForSection:(NSInteger)section;
- (NSString *)rootFooterForSection:(NSInteger)section;
- (NSString *)appearanceFooterForSection:(NSInteger)section;
- (NSString *)notificationsFooterForSection:(NSInteger)section;
- (NSString *)exceptionsFooterForSection:(NSInteger)section;

@end
