#import "TGListBackground.h"
#import "TGImageDecode.h"
#import "TGAccountUsernamesViewController.h"
#import "TGAccountSettingsViewController.h"
#import "TGLocalization.h"
#import "TGNotificationManager.h"
#import "TGSettingsViewController.h"
#import "TGEmoji.h"
#import "RootViewController.h"
#import "TGTheme.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGDevice.h"
#import "TGFoldersViewController.h"
#import "TGProxyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGTabBar.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"
#import "TGClient+Network.h"
#import "TGClient+Notifications.h"

const CGFloat kHeaderHeight = 86.0f;
const CGFloat kHeaderAvatar = 70.0f;
NSString *const TGSettingsPresetDefaultsKey = @"TGAutoDownloadPresetNames";
NSString *const TGSettingsSavedPresetsKey = @"TGAutoDownloadPresetsBeforeSaver";
NSString *const TGSettingsSavedCustomSettingsKey = @"TGAutoDownloadCustomSettingsBeforeSaver";
NSString *const TGSettingsLessCallDataKey = @"TGUseLessDataForCalls";
NSString *const TGSettingsArchiveSuggestionKey = @"TGArchiveSuggestionDismissed";
NSString *TGSettingsReactionSourceKey(void) {
	return [TGAccountManager defaultsKey:@"TGReactionNotificationSource"];
}
NSString *TGSettingsReactionPreviewKey(void) {
	return [TGAccountManager defaultsKey:@"TGReactionNotificationPreview"];
}
NSString *TGSettingsPollVoteSourceKey(void) {
	return [TGAccountManager defaultsKey:@"TGPollVoteNotificationSource"];
}
NSString *const TGSettingsLastProxyKey = @"TGLastEnabledProxyId";
NSString *const TGSettingsContactRegisteredOption =
	@"disable_contact_registered_notifications";
NSString *const TGSettingsStoriesExceptionsScope = @"stories";
NSString *const TGSettingsWallpaperBlurKey = @"TGWallpaperBlurred";
NSString *const TGSettingsTopChatsOption = @"disable_top_chats";
BOOL TGSettingsTabletLayout(void) {
	return [RootViewController isSplitLayoutActive];
}
BOOL TGSettingsShowInDetailPane(UIViewController *sender,
	UIViewController *target) {
	(void)sender;
	if (!target || !TGSettingsTabletLayout())
		return NO;
	return [RootViewController pushInDetail:target];
}
CGFloat TGSettingsScreenWidth(void) {
	return [UIScreen mainScreen].bounds.size.width;
}
CGFloat TGSettingsGroupedInset(CGFloat width) {
	if (width < 400.0f)
		return 0.0f;
	CGFloat content = MIN(width, 678.0f);
	return (CGFloat)(int)((width - content) / 2.0f);
}
NSString *TGSettingsBytes(long long bytes) {
	if (bytes <= 0)
		return [NSString stringWithFormat:TGL(@"FileSize.KB", @"%@ KB"), @"0"];
	if (bytes < 1024)
		return [NSString stringWithFormat:TGL(@"FileSize.KB", @"%@ KB"), @"1"];
	if (bytes < 1024 * 1024)
		return [NSString stringWithFormat:TGL(@"FileSize.KB", @"%@ KB"),
			[NSString stringWithFormat:@"%lld", bytes / 1024]];
	if (bytes < 1024LL * 1024LL * 1024LL)
		return [NSString stringWithFormat:TGL(@"FileSize.MB", @"%@ MB"),
			[NSString stringWithFormat:@"%.1f", bytes / (1024.0 * 1024.0)]];
	return [NSString stringWithFormat:TGL(@"FileSize.GB", @"%@ GB"),
		[NSString stringWithFormat:@"%.2f", bytes / (1024.0 * 1024.0 * 1024.0)]];
}
NSString *TGSettingsDuration(double seconds) {
	long long total = (long long)seconds;
	if (total <= 0)
		return TGL(@"Settings.DurationNone", @"none");
	if (total < 60)
		return [NSString stringWithFormat:TGL(@"GroupInfo.SlowmodeSeconds", @"%lds"), (long)total];
	if (total < 3600)
		return [NSString stringWithFormat:@"%@ %@",
			[NSString stringWithFormat:TGL(@"GroupInfo.SlowmodeMinutes", @"%ldm"), (long)(total / 60)],
			[NSString stringWithFormat:TGL(@"GroupInfo.SlowmodeSeconds", @"%lds"), (long)(total % 60)]];
	return [NSString stringWithFormat:@"%@ %@",
		[NSString stringWithFormat:TGL(@"GroupInfo.SlowmodeHours", @"%ldh"), (long)(total / 3600)],
		[NSString stringWithFormat:TGL(@"GroupInfo.SlowmodeMinutes", @"%ldm"), (long)((total % 3600) / 60)]];
}

@implementation TGSettingsViewController

- (id)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)dealloc {
	if (_connectionStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_connectionStateObserverToken];
	if (_notificationUpdateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_notificationUpdateObserverToken];
	if (_defaultBackgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_defaultBackgroundObserverToken];
	if (_accountSignOutFailedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_accountSignOutFailedObserverToken];
	if (_accountsChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_accountsChangedObserverToken];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[self applyTheme];
	TGApplyRTLTableMirroring(self.tableView);

	self.muted = [NSMutableDictionary dictionary];
	self.archive = [NSMutableDictionary dictionary];
	self.autosave = [NSMutableDictionary dictionary];
	self.scopeSettings = [NSMutableDictionary dictionary];
	self.exceptionCounts = [NSMutableDictionary dictionary];
	self.chatTitles = [NSMutableDictionary dictionary];
	self.suggestions = @[];
	self.dataSaver = [[NSUserDefaults standardUserDefaults] boolForKey:@"TGDataSaver"];
	self.lessCallData = [[NSUserDefaults standardUserDefaults]
		boolForKey:TGSettingsLessCallDataKey];
	self.wallpaperBlurred = [[NSUserDefaults standardUserDefaults]
		boolForKey:TGSettingsWallpaperBlurKey];
	self.activeProxyId = -1;
	self.savedSounds = @[];

	self.title = [self titleForCurrentPage];

	if (self.page == TGSettingsPageRoot) {
		[self updateEditButton];
		self.tableView.sectionHeaderHeight = 0;
		self.tableView.sectionFooterHeight = 0;
		[self applyBottomBarInset];
		[self buildHeader];
		[self buildVersionFooter];

		__weak typeof(self) weakSelf = self;
		self.connectionStateObserverToken = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGConnectionStateDidChangeNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
						TGSettingsViewController *strongSelf = weakSelf;
						if (!strongSelf)
							return;
						if (!strongSelf.isViewLoaded || !strongSelf.view.window)
							return;
						[strongSelf loadProxyStatus];
					}];

		self.accountSignOutFailedObserverToken = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGAccountSignOutFailedNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
						TGSettingsViewController *strongSelf = weakSelf;
						if (!strongSelf)
							return;
						if (!strongSelf.isViewLoaded || !strongSelf.view.window)
							return;
						[strongSelf.tableView reloadData];
						[[[UIAlertView alloc]
								initWithTitle:nil
									  message:TGL(@"Settings.SignOutFailedMessage", @"Could not sign out of that account. Please check your connection and try again.")
									 delegate:nil
							cancelButtonTitle:TGL(@"Common.OK", @"OK")
							otherButtonTitles:nil] show];
					}];

		self.accountsChangedObserverToken = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGAccountsDidChangeNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
						TGSettingsViewController *strongSelf = weakSelf;
						if (!strongSelf)
							return;
						if (!strongSelf.isViewLoaded || !strongSelf.view.window)
							return;
						[strongSelf.tableView reloadData];
					}];
	}
	if (self.page == TGSettingsPageNotifications ||
		(NSInteger)self.page == TGSettingsPageNotificationExceptions) {
		__weak typeof(self) weakSelf = self;
		self.notificationUpdateObserverToken = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGNotificationUpdateNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						TGSettingsViewController *strongSelf = weakSelf;
						if (!strongSelf)
							return;
						if (!strongSelf.isViewLoaded || !strongSelf.view.window)
							return;
						if (strongSelf.page == TGSettingsPageNotifications)
							[strongSelf loadNotificationsPage];
						else if ((NSInteger)strongSelf.page == TGSettingsPageNotificationExceptions)
							[strongSelf loadExceptionsPage];
					}];
	}
	if ((NSInteger)self.page == TGSettingsPageWallpaper) {
		__weak typeof(self) weakSelf = self;
		self.defaultBackgroundObserverToken = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGChatBackgroundDidChangeNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
						TGSettingsViewController *strongSelf = weakSelf;
						if (!strongSelf)
							return;
						if (note.object)
							return;
						if (!strongSelf.isViewLoaded || !strongSelf.view.window)
							return;
						[strongSelf loadWallpaperPage];
					}];
	}
	if (self.page == TGSettingsPageLanguage || self.page == TGSettingsPageRoot || (NSInteger)self.page == TGSettingsPageNotificationSounds || (NSInteger)self.page == TGSettingsPageWallpaper) {
		UILongPressGestureRecognizer *recognizer = [UILongPressGestureRecognizer alloc];
		UILongPressGestureRecognizer *press = [recognizer initWithTarget:self action:@selector(longPressed:)];
		press.minimumPressDuration = 0.5;
		[self.tableView addGestureRecognizer:press];
	}
	[self loadForPage];
}

- (NSString *)titleForCurrentPage {
	if ((NSInteger)self.page == TGSettingsPageAutoDownload)
		return TGL(@"ChatSettings.AutoDownloadEnabled", @"Auto-Download Media");
	if ((NSInteger)self.page == TGSettingsPageAutoDownloadKind)
		return [TGSettingsViewController titleForNetworkKind:self.autoDownloadKind];
	if ((NSInteger)self.page == TGSettingsPageAutosave)
		return TGL(@"Preview.SaveToCameraRoll", @"Save to Camera Roll");
	if ((NSInteger)self.page == TGSettingsPageWallpaper)
		return TGL(@"Wallpaper.Title", @"Chat Wallpaper");
	if ((NSInteger)self.page == TGSettingsPageChatListLayout)
		return TGL(@"Settings.ChatList", @"Chat List");
	if ((NSInteger)self.page == TGSettingsPageTextSize)
		return TGL(@"ChatSettings.TextSize", @"Text Size");
	if ((NSInteger)self.page == TGSettingsPageDataUsage)
		return TGL(@"DataUsage.Header", @"Data Usage");
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions)
		return [self.exceptionsScope isEqualToString:TGSettingsStoriesExceptionsScope]
			? TGL(@"Settings.StoryExceptionsTitle", @"Story Exceptions")
			: TGL(@"Notifications.MessageNotificationsExceptions", @"Exceptions");
	if ((NSInteger)self.page == TGSettingsPageNotificationSounds)
		return TGL(@"Notifications.AlertTones", @"Notification Sounds");
	if ((NSInteger)self.page == TGSettingsPageNotificationTone)
		return TGL(@"Notifications.TextTone", @"Notification Tone");
	switch (self.page) {
		case TGSettingsPageAppearance:
			return TGL(@"Settings.Appearance", @"Appearance");
		case TGSettingsPageData:
			return TGL(@"Settings.ChatSettings", @"Data and Storage");
		case TGSettingsPageNotifications:
			return TGL(@"Notifications.Title", @"Notifications");
		case TGSettingsPageLanguage:
			return TGL(@"Settings.AppLanguage", @"Language");
		default:
			return TGL(@"Settings.Title", @"Settings");
	}
}

- (void)updateEditButton {
	BOOL editing = self.tableView.isEditing;
	UIButton *edit = [TGIcons headerButtonWithTitle:(editing ? TGL(@"Common.Done", @"Done") : TGL(@"Common.Edit", @"Edit"))
											   bold:editing
											 target:self
											 action:@selector(editTapped)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:edit];
}

- (void)editTapped {
	[self.tableView setEditing:!self.tableView.isEditing animated:YES];
	[self updateEditButton];
	[self.tableView reloadData];
}

- (BOOL)canEditNotificationExceptionRowAtIndexPath:(NSIndexPath *)indexPath {
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions)
		return indexPath.section == 0 && (NSUInteger)indexPath.row < self.exceptions.count;
	return NO;
}

- (void)commitDeleteNotificationExceptionAtIndexPath:(NSIndexPath *)indexPath {
	if ((NSInteger)self.page != TGSettingsPageNotificationExceptions)
		return;
	if ((NSUInteger)indexPath.row >= self.exceptions.count)
		return;
	NSDictionary *chat = self.exceptions[indexPath.row];
	if (![chat isKindOfClass:[NSDictionary class]])
		return;
	[self removeExceptionForChatId:[chat[@"id"] longLongValue]];
}

- (void)applyTheme {
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.backgroundView = nil;
	self.tableView.opaque = NO;
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (UIView *)disclosureAccessory {
	UIImage *art = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator.png"]);
	if (!art)
		return nil;
	UIImage *highlighted = [UIImage imageNamed:@"MenuDisclosureIndicator_Highlighted.png"];
	UIImageView *view = [[UIImageView alloc] initWithImage:art highlightedImage:highlighted];
	view.frame = CGRectMake(0, 0, art.size.width, art.size.height);
	return view;
}

- (UIView *)checkAccessory {
	UIImage *art = [UIImage imageNamed:@"ListCheck.png"];
	if (!art)
		return nil;
	UIImage *highlighted = [UIImage imageNamed:@"ListCheck_Highlighted.png"];
	UIImageView *view = [[UIImageView alloc] initWithImage:art highlightedImage:highlighted];
	view.frame = CGRectMake(0, 0, art.size.width, art.size.height);
	return view;
}

- (void)markDisclosure:(UITableViewCell *)cell {
	UIView *chevron = [self disclosureAccessory];
	if (chevron) {
		cell.accessoryView = chevron;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
}

- (void)markChecked:(BOOL)checked on:(UITableViewCell *)cell {
	cell.textLabel.textColor = checked ? [[TGTheme shared] groupedInfoColour]
									   : [[TGTheme shared] groupedTitleColour];
	if (!checked) {
		cell.accessoryView = nil;
		cell.accessoryType = UITableViewCellAccessoryNone;
		return;
	}
	UIView *check = [self checkAccessory];
	if (check) {
		cell.accessoryView = check;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.page == TGSettingsPageRoot) {
		[self refreshHeader];
		[self loadProxyStatus];
		[self loadPremiumSummary];
	}
	[self.tableView reloadData];
}

- (void)openPage:(TGSettingsPage)page {
	TGSettingsViewController *next = [[TGSettingsViewController alloc] init];
	next.page = page;
	[self openViewController:next];
}

- (void)openViewController:(UIViewController *)next {
	if (!next)
		return;
	if (self.page == TGSettingsPageRoot && TGSettingsShowInDetailPane(self, next)) {
		self.detailPaneShown = YES;
		return;
	}
	[self.navigationController pushViewController:next animated:YES];
}

@end
