#import "RootViewController.h"
#import "TGDevice.h"
#import "TGLocalization.h"
#import "TGCallsViewController.h"
#import "TGChatListViewController.h"
#import "TGContactsViewController.h"
#import "TGSettingsViewController.h"
#import "TGPreferenceFlags.h"
#import "TGTabBar.h"
#import "TGHacks.h"
#import "TGTabsContainerViewDelegate.h"
#import "TGAccountManager.h"
#import "UIView+SafeTint.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGSettingsService.h"
#import "TGClient+Account.h"
#import "TGClient+Notifications.h"
#import "TGServiceNotificationAlert.h"
#import "TGFrozenAccountViewController.h"
#import "TGAgeVerificationViewController.h"
#import "TGTermsOfServiceUpdateViewController.h"
#import "TGCapabilities.h"
#import "AppDelegate.h"

static const CGFloat kTabBarHeight = 49.0f;
static const NSInteger kRootServiceNotificationAlertTag = 941;

@interface TGDetailPlaceholderViewController : UIViewController
@property (nonatomic, strong) UIImageView *wallpaperView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) id themeObserver;
@end

@implementation TGDetailPlaceholderViewController

- (void)loadView {
	[super loadView];

	UIImageView *wallpaperView = [[UIImageView alloc] initWithFrame:self.view.bounds];
	wallpaperView.contentMode = UIViewContentModeScaleAspectFill;
	wallpaperView.clipsToBounds = YES;
	wallpaperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:wallpaperView];
	self.wallpaperView = wallpaperView;

	UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentCenter;
	label.numberOfLines = 0;
	label.font = [UIFont systemFontOfSize:22];
	label.text = TGL(@"ChatList.StartMessaging", @"No Conversation Selected");
	[self.view addSubview:label];
	self.emptyLabel = label;

	[self applyTheme];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	__weak typeof(self) weakSelf = self;
	self.themeObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGThemeChangedNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf applyTheme];
				}];
}

- (void)dealloc {
	if (self.themeObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.themeObserver];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self applyTheme];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	[theme restyleNavigationBar:self.navigationController.navigationBar];

	self.view.backgroundColor = [theme chatBackgroundColour];
	self.wallpaperView.image = [TGCapabilities canShowWallpaper] ? [theme wallpaper] : nil;
	self.emptyLabel.textColor = [UIColor colorWithWhite:0.55f alpha:1.0f];
	self.emptyLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.7f];
	self.emptyLabel.shadowOffset = CGSizeMake(0, 1);
}

@end

@interface RootViewController () <TGTabBarDelegate, UINavigationControllerDelegate,
	UISplitViewControllerDelegate, UIPopoverControllerDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) TGTabBar *customTabBar;
@property (nonatomic, strong) id layoutDelegate;
@property (nonatomic, strong) NSMutableIndexSet *insetTabs;
@property (nonatomic, strong) NSMutableIndexSet *builtTabs;
@property (nonatomic, assign) BOOL isSplitMaster;
@property (nonatomic, strong) UISplitViewController *splitController;
@property (nonatomic, strong) RootViewController *splitMaster;
@property (nonatomic, strong) UINavigationController *detailNav;
@property (nonatomic, strong) UIPopoverController *masterPopover;
@property (nonatomic, strong) UIBarButtonItem *masterBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *detailCloseBarButtonItem;
@property (nonatomic, assign) NSInteger pendingIconBadge;
@property (nonatomic, assign) NSInteger pushedIconBadge;
@property (nonatomic, assign) BOOL iconBadgeScheduled;
@property (nonatomic, assign) BOOL iconBadgePushed;
@property (nonatomic, strong) id callsTabVisibilityObserverToken;
@property (nonatomic, strong) id localizationChangedObserverToken;
@property (nonatomic, strong) id freezeStateObserverToken;
@property (nonatomic, strong) id ageVerificationParametersObserverToken;
@property (nonatomic, strong) id termsOfServiceObserverToken;
@property (nonatomic, strong) id serviceNotificationObserverToken;
@property (nonatomic, strong) id themeChangedForDetailObserverToken;
@end

static __weak RootViewController *gSplitRoot = nil;
static BOOL gIconBadgePushed = NO;
static BOOL gFrozenScreenPresented = NO;
static BOOL gAgeVerificationScreenPresented = NO;
static BOOL gTermsOfServiceScreenPresented = NO;

@implementation RootViewController

- (void)loadView {
	[super loadView];
	self.layoutDelegate = [[TGTabsContainerViewDelegate alloc] init];
	[TGHacks setLayoutDelegateForContainerView:self.view layoutDelegate:self.layoutDelegate];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if (gSplitRoot != nil && gSplitRoot != self)
		self.isSplitMaster = YES;

	if ([TGDevice isPadIdiom] && !self.isSplitMaster) {
		UISplitViewController *split = [self splitLayoutController];
		self.tabBar.hidden = true;
		dispatch_async(dispatch_get_main_queue(), ^{
			UIWindow *window = [UIApplication sharedApplication].keyWindow;
			if (window.rootViewController == self)
				window.rootViewController = split;
		});
		return;
	}

	[self buildTabs];
}

- (UINavigationController *)placeholderTab {
	UIViewController *blank = [[UIViewController alloc] init];
	blank.view.backgroundColor = [UIColor colorWithRed:0.84f green:0.85f blue:0.87f alpha:1.0f];
	UINavigationController *nav =
		[[UINavigationController alloc] initWithRootViewController:blank];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	return nav;
}

- (UIViewController *)rootControllerForTab:(NSUInteger)index {
	if (index == (NSUInteger)kTabIndexContacts)
		return [[TGContactsViewController alloc] init];
	if (index == (NSUInteger)kTabIndexCalls)
		return [[TGCallsViewController alloc] init];
	return [[TGSettingsViewController alloc] init];
}

- (void)materialiseTab:(NSUInteger)index {
	if (index == (NSUInteger)kTabIndexChats || [self.builtTabs containsIndex:index])
		return;
	NSMutableArray *tabs = [[super viewControllers] mutableCopy];
	if (index >= tabs.count)
		return;
	UIViewController *root = [self rootControllerForTab:index];
	UINavigationController *nc =
		[[UINavigationController alloc] initWithRootViewController:root];
	nc.delegate = self;
	tabs[index] = nc;
	[self.builtTabs addIndex:index];
	NSInteger selected = [super selectedIndex];
	[super setViewControllers:tabs animated:NO];
	[super setSelectedIndex:selected];
	[self.insetTabs removeIndex:index];
	[self applyTabBarInsetForIndex:index];
}

- (void)buildTabs {
	if (self.callsTabVisibilityObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.callsTabVisibilityObserverToken];
		self.callsTabVisibilityObserverToken = nil;
	}
	if (self.localizationChangedObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.localizationChangedObserverToken];
		self.localizationChangedObserverToken = nil;
	}
	if (self.freezeStateObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.freezeStateObserverToken];
		self.freezeStateObserverToken = nil;
	}
	if (self.ageVerificationParametersObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.ageVerificationParametersObserverToken];
		self.ageVerificationParametersObserverToken = nil;
	}
	if (self.termsOfServiceObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.termsOfServiceObserverToken];
		self.termsOfServiceObserverToken = nil;
	}
	if (self.serviceNotificationObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.serviceNotificationObserverToken];
		self.serviceNotificationObserverToken = nil;
	}
	self.builtTabs = [NSMutableIndexSet indexSet];

	TGChatListViewController *chats = [[TGChatListViewController alloc] init];
	UINavigationController *chatsNC =
		[[UINavigationController alloc] initWithRootViewController:chats];

	UINavigationController *contactsNC = [self placeholderTab];
	UINavigationController *callsNC = [self placeholderTab];
	UINavigationController *settingsNC = [self placeholderTab];

	[self setViewControllers:@[ contactsNC, callsNC, chatsNC, settingsNC ] animated:NO];
	[self setSelectedIndex:kTabIndexChats];
	if ([TGDevice isPadIdiom]) {
		__weak RootViewController *weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			RootViewController *strongSelf = weakSelf;
			[strongSelf setSelectedIndex:kTabIndexChats];
			strongSelf.customTabBar.selectedIndex = kTabIndexChats;
		});
	}

	self.customTabBar = [[TGTabBar alloc] initWithFrame:
			CGRectMake(0, self.view.bounds.size.height - kTabBarHeight,
				self.view.bounds.size.width, kTabBarHeight)];
	self.customTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	self.customTabBar.tabDelegate = self;
	self.customTabBar.selectedIndex = kTabIndexChats;
	self.customTabBar.visibleTabs = [TGTabBar defaultVisibleTabs];
	[self.view insertSubview:self.customTabBar aboveSubview:self.tabBar];

	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	__weak typeof(self) weakSelf = self;
	self.callsTabVisibilityObserverToken = [centre
		addObserverForName:TGCallsTabVisibilityChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf callsTabVisibilityChanged];
				}];
	self.localizationChangedObserverToken = [centre
		addObserverForName:TGLocalizationDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf localizationChanged];
				}];

	self.freezeStateObserverToken = [centre
		addObserverForName:TGFreezeStateDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf freezeStateChanged];
				}];
	self.ageVerificationParametersObserverToken = [centre
		addObserverForName:TGAgeVerificationParametersDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf ageVerificationParametersChanged];
				}];
	self.termsOfServiceObserverToken = [centre
		addObserverForName:TGTermsOfServiceDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf termsOfServiceUpdateChanged];
				}];
	self.serviceNotificationObserverToken = [centre
		addObserverForName:TGServiceNotificationDidArriveNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf showServiceNotification:note.userInfo];
				}];
	dispatch_async(dispatch_get_main_queue(), ^{
		[self freezeStateChanged];
		[self ageVerificationParametersChanged];
		[self termsOfServiceUpdateChanged];
	});

	self.tabBar.hidden = true;

	for (UINavigationController *nc in @[ contactsNC, callsNC, chatsNC, settingsNC ])
		nc.delegate = self;

	[self applyTabBarInsetForIndex:self.selectedIndex];
}

#pragma mark - split layout (iPad only)

- (UISplitViewController *)splitLayoutController {
	if (![TGDevice isPadIdiom] || self.isSplitMaster)
		return nil;
	if (!self.splitController)
		[self buildSplitLayout];
	return self.splitController;
}

- (void)buildSplitLayout {
	if (self.splitController)
		return;
	gSplitRoot = self;

	RootViewController *master = [[RootViewController alloc] init];
	master.isSplitMaster = YES;
	self.splitMaster = master;

	self.detailNav = [[UINavigationController alloc]
		initWithRootViewController:[[TGDetailPlaceholderViewController alloc] init]];
	self.detailNav.delegate = self;
	[[TGTheme shared] styleNavigationBar:self.detailNav.navigationBar];

	self.splitController = [[UISplitViewController alloc] init];
	self.splitController.delegate = self;
	self.splitController.viewControllers = @[ master, self.detailNav ];

	__weak RootViewController *weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf restyleDetailNavigationBar];
	});
	self.themeChangedForDetailObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGThemeChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf themeChangedForDetail];
				}];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.callsTabVisibilityObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.callsTabVisibilityObserverToken];
	if (self.localizationChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.localizationChangedObserverToken];
	if (self.freezeStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.freezeStateObserverToken];
	if (self.ageVerificationParametersObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.ageVerificationParametersObserverToken];
	if (self.termsOfServiceObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.termsOfServiceObserverToken];
	if (self.serviceNotificationObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.serviceNotificationObserverToken];
	if (self.themeChangedForDetailObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.themeChangedForDetailObserverToken];
}

- (void)themeChangedForDetail {
	[self restyleDetailNavigationBar];
}

- (BOOL)isSplitLayoutActive {
	if (self.isSplitMaster)
		return [[RootViewController splitRootController] splitController] != nil;
	return self.splitController != nil;
}

+ (RootViewController *)splitRootController {
	return gSplitRoot;
}

+ (void)forgetSplitLayout {
	gSplitRoot = nil;
}

+ (BOOL)isSplitLayoutActive {
	RootViewController *root = gSplitRoot;
	return root != nil && root.splitController != nil;
}

- (UINavigationController *)detailNavigationController {
	if (self.isSplitMaster)
		return [[RootViewController splitRootController] detailNavigationController];
	return self.detailNav;
}

+ (UINavigationController *)detailNavigationController {
	return [gSplitRoot detailNavigationController];
}

- (void)restyleDetailNavigationBar {
	if (self.isSplitMaster) {
		[[RootViewController splitRootController] restyleDetailNavigationBar];
		return;
	}
	if (self.detailNav)
		[[TGTheme shared] restyleNavigationBar:self.detailNav.navigationBar];
}

- (void)dismissMasterPopover {
	if (self.masterPopover.popoverVisible)
		[self.masterPopover dismissPopoverAnimated:YES];
}

- (void)applyMasterBarButtonTo:(UIViewController *)controller {
	[self applyDetailChromeTo:controller];
}

- (BOOL)detailRootNeedsCloseButton:(UIViewController *)controller {
	if (!controller || [controller isKindOfClass:[TGDetailPlaceholderViewController class]])
		return NO;
	return [self.detailNav.viewControllers firstObject] == controller;
}

- (void)applyDetailChromeTo:(UIViewController *)controller {
	if (!controller)
		return;

	BOOL isDetailRoot = [self.detailNav.viewControllers firstObject] == controller;
	if (!isDetailRoot) {
		if (controller.navigationItem.leftBarButtonItem == self.masterBarButtonItem)
			controller.navigationItem.leftBarButtonItem = nil;
		return;
	}

	NSMutableArray *items = [NSMutableArray array];
	if (self.masterBarButtonItem)
		[items addObject:self.masterBarButtonItem];
	if ([self detailRootNeedsCloseButton:controller]) {
		if (!self.detailCloseBarButtonItem) {
			NSString *closeTitle = TGL(@"Common.Close", @"Close");
			UIBarButtonItem *closeItem =
				[TGIcons headerBarButtonItemWithTitle:closeTitle
												 bold:NO
											   target:self
											   action:@selector(detailCloseTapped)];
			self.detailCloseBarButtonItem = closeItem;
		}
		[items addObject:self.detailCloseBarButtonItem];
	}

	if (items.count > 1)
		controller.navigationItem.leftBarButtonItems = items;
	else
		controller.navigationItem.leftBarButtonItem = [items firstObject];
}

- (void)detailCloseTapped {
	[self showDetailEmptyState];
}

- (BOOL)presentInDetail:(UIViewController *)controller {
	if (self.isSplitMaster)
		return [[RootViewController splitRootController] presentInDetail:controller];
	if (!self.splitController || !controller)
		return NO;
	[self dismissMasterPopover];
	[self.detailNav setViewControllers:@[ controller ] animated:NO];
	[self applyDetailChromeTo:controller];
	[self restyleDetailNavigationBar];
	return YES;
}

+ (BOOL)presentInDetail:(UIViewController *)controller {
	return [gSplitRoot presentInDetail:controller];
}

- (BOOL)pushInDetail:(UIViewController *)controller {
	if (self.isSplitMaster)
		return [[RootViewController splitRootController] pushInDetail:controller];
	if (!self.splitController || !controller)
		return NO;
	[self dismissMasterPopover];
	UIViewController *root = [self.detailNav.viewControllers firstObject];
	if ([root isKindOfClass:[TGDetailPlaceholderViewController class]])
		return [self presentInDetail:controller];
	[self.detailNav pushViewController:controller animated:YES];
	[self restyleDetailNavigationBar];
	return YES;
}

+ (BOOL)pushInDetail:(UIViewController *)controller {
	return [gSplitRoot pushInDetail:controller];
}

- (void)showDetailEmptyState {
	if (self.isSplitMaster) {
		[[RootViewController splitRootController] showDetailEmptyState];
		return;
	}
	if (!self.splitController)
		return;
	[self presentInDetail:[[TGDetailPlaceholderViewController alloc] init]];
}

+ (void)showDetailEmptyState {
	[gSplitRoot showDetailEmptyState];
}

#pragma mark - UISplitViewControllerDelegate

- (BOOL)splitViewController:(UISplitViewController *)svc
	shouldHideViewController:(UIViewController *)vc
			   inOrientation:(UIInterfaceOrientation)orientation {
	return NO;
}

- (void)splitViewController:(UISplitViewController *)svc
	 willHideViewController:(UIViewController *)aViewController
		  withBarButtonItem:(UIBarButtonItem *)barButtonItem
	   forPopoverController:(UIPopoverController *)pc {
	barButtonItem.title = TGL(@"DialogList.Title", @"Chats");
	self.masterBarButtonItem = barButtonItem;
	self.masterPopover = pc;
	pc.delegate = self;
	[self applyMasterBarButtonTo:self.detailNav.topViewController];
	[self restyleDetailNavigationBar];
}

- (void)splitViewController:(UISplitViewController *)svc
	   willShowViewController:(UIViewController *)aViewController
	invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
	UIViewController *top = self.detailNav.topViewController;
	if (top.navigationItem.leftBarButtonItem == barButtonItem)
		top.navigationItem.leftBarButtonItem = nil;
	top.navigationItem.leftBarButtonItems = nil;
	self.masterBarButtonItem = nil;
	self.masterPopover = nil;
	[self applyDetailChromeTo:[self.detailNav.viewControllers firstObject]];
	[self restyleDetailNavigationBar];
}

- (void)splitViewController:(UISplitViewController *)svc
			popoverController:(UIPopoverController *)pc
	willPresentViewController:(UIViewController *)aViewController {
	self.masterPopover = pc;
}

#pragma mark - rotation

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
										 duration:(NSTimeInterval)duration {
	[super willAnimateRotationToInterfaceOrientation:orientation duration:duration];
	[self restyleDetailNavigationBar];
}

- (BOOL)shouldAutorotate {
	if ([TGDevice isPadIdiom])
		return YES;
	return [super shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	if ([TGDevice isPadIdiom])
		return UIInterfaceOrientationMaskAll;
	return [super supportedInterfaceOrientations];
}

#pragma mark - tabs

- (CGFloat)tabBarInsetForController:(UIViewController *)controller {
	if (!self.customTabBar || !controller)
		return 0;
	UINavigationController *nav = controller.navigationController;
	if (!nav || [nav.viewControllers firstObject] != controller)
		return 0;
	if (![[super viewControllers] containsObject:nav])
		return 0;
	return kTabBarHeight;
}

- (void)applyTabBarInsetForIndex:(NSUInteger)index {
	if (self.splitMaster) {
		[self.splitMaster applyTabBarInsetForIndex:index];
		return;
	}
	if (index >= self.viewControllers.count)
		return;
	id controller = self.viewControllers[index];
	if (![controller isKindOfClass:[UINavigationController class]])
		return;
	UIViewController *top = [[(UINavigationController *)controller viewControllers] firstObject];
	if (![top isKindOfClass:[UITableViewController class]])
		return;
	if (!top.isViewLoaded && index != [super selectedIndex])
		return;
	UITableView *tableView = ((UITableViewController *)top).tableView;
	CGFloat bottom = [self tabBarInsetForController:top];
	UIEdgeInsets insets = tableView.contentInset;
	if (insets.bottom == bottom && tableView.scrollIndicatorInsets.bottom == bottom)
		return;
	insets.bottom = bottom;
	tableView.contentInset = insets;
	tableView.scrollIndicatorInsets = insets;
}

- (void)applyTabBarInsetsToAllTabs {
	for (NSInteger i = 0; i < self.viewControllers.count; i++)
		[self applyTabBarInsetForIndex:i];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self applyTabBarInsetsToAllTabs];
	[self updateUnreadBadge];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self applyTabBarInsetsToAllTabs];
}

- (void)navigationController:(UINavigationController *)navigationController
	  willShowViewController:(UIViewController *)viewController
					animated:(BOOL)animated {
	[[TGTheme shared] styleNavigationBar:navigationController.navigationBar];
	if (navigationController == self.detailNav)
		return;
	self.customTabBar.hidden = viewController != navigationController.viewControllers.firstObject;
	if (!self.customTabBar.hidden)
		[self applyTabBarInsetForIndex:[[self viewControllers] indexOfObject:navigationController]];
}

- (void)navigationController:(UINavigationController *)navigationController
	   didShowViewController:(UIViewController *)viewController
					animated:(BOOL)animated {
	if (navigationController == self.detailNav)
		return;
	NSUInteger index = [[self viewControllers] indexOfObject:navigationController];
	if (index != NSNotFound)
		[self applyTabBarInsetForIndex:index];
}

- (void)callsTabVisibilityChanged {
	NSArray *tabs = [TGTabBar defaultVisibleTabs];
	self.customTabBar.visibleTabs = tabs;
	if (![tabs containsObject:@(kTabIndexCalls)] && (int)self.selectedIndex == kTabIndexCalls)
		[self setSelectedIndex:kTabIndexChats];
	else
		[self.customTabBar setSelectedIndex:(int)self.selectedIndex];
}

- (void)localizationChanged {
	if ([super viewControllers].count == 0)
		return;

	NSInteger selected = [super selectedIndex];
	NSMutableIndexSet *wasBuilt = [self.builtTabs mutableCopy];
	[self buildTabs];
	for (NSInteger index = [wasBuilt firstIndex]; index != NSNotFound;
		 index = [wasBuilt indexGreaterThanIndex:index])
		[self materialiseTab:index];
	[self setSelectedIndex:selected];
	self.customTabBar.selectedIndex = (int)selected;
	[self applyTabBarInsetsToAllTabs];

	if ([TGDevice isPadIdiom] && [RootViewController detailNavigationController])
		[RootViewController presentInDetail:[[TGDetailPlaceholderViewController alloc] init]];
}

- (void)freezeStateChanged {
	if (![TGSettingsService isFrozen]) {
		gFrozenScreenPresented = NO;
		return;
	}
	if (gFrozenScreenPresented || self.presentedViewController)
		return;
	gFrozenScreenPresented = YES;
	TGFrozenAccountViewController *screen = [[TGFrozenAccountViewController alloc] init];
	UINavigationController *nav = [[UINavigationController alloc]
		initWithRootViewController:screen];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)ageVerificationParametersChanged {
	if (![TGSettingsService ageVerificationRequired]) {
		gAgeVerificationScreenPresented = NO;
		return;
	}
	if (gAgeVerificationScreenPresented || self.presentedViewController)
		return;
	gAgeVerificationScreenPresented = YES;
	TGAgeVerificationViewController *screen = [[TGAgeVerificationViewController alloc] init];
	UINavigationController *nav = [[UINavigationController alloc]
		initWithRootViewController:screen];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)termsOfServiceUpdateChanged {
	if (![TGSettingsService hasPendingTermsOfServiceUpdate]) {
		gTermsOfServiceScreenPresented = NO;
		return;
	}
	if (gTermsOfServiceScreenPresented || self.presentedViewController)
		return;
	gTermsOfServiceScreenPresented = YES;
	TGTermsOfServiceUpdateViewController *screen = [[TGTermsOfServiceUpdateViewController alloc] init];
	UINavigationController *nav = [[UINavigationController alloc]
		initWithRootViewController:screen];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)showServiceNotification:(NSDictionary *)alert {
	NSString *text = alert[TGServiceNotificationTextKey];
	if (![text isKindOfClass:NSString.class] || !text.length)
		return;
	BOOL needsLogOut = [alert[TGServiceNotificationNeedsLogOutKey] boolValue];
	UIAlertView *notice = [UIAlertView alloc];
	notice = [notice initWithTitle:TGL(@"Notification.ServiceNoticeTitle", @"Telegram")
						   message:text
						  delegate:needsLogOut ? self : nil
				 cancelButtonTitle:needsLogOut ? TGL(@"Common.Cancel", @"Cancel")
											   : TGL(@"Common.OK", @"OK")
				 otherButtonTitles:needsLogOut ? TGL(@"Settings.Logout", @"Log Out") : nil, nil];
	notice.tag = kRootServiceNotificationAlertTag;
	[notice show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag != kRootServiceNotificationAlertTag)
		return;
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	[TGSettingsService logOutWithCompletion:nil];
}

- (void)tabBarSelectedItem:(int)index {
	if (index >= 0)
		[self materialiseTab:(NSUInteger)index];
	if ((int)self.selectedIndex != index)
		[self setSelectedIndex:index];
}

- (NSArray *)viewControllers {
	if (self.splitMaster)
		return self.splitMaster.viewControllers;
	return [super viewControllers];
}

- (NSUInteger)selectedIndex {
	if (self.splitMaster)
		return self.splitMaster.selectedIndex;
	return [super selectedIndex];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
	if (self.splitMaster) {
		[self.splitMaster setSelectedIndex:selectedIndex];
		return;
	}
	if (selectedIndex >= [super viewControllers].count)
		return;
	[self materialiseTab:selectedIndex];
	[super setSelectedIndex:selectedIndex];
	[self applyTabBarInsetForIndex:selectedIndex];
	[self.customTabBar setSelectedIndex:(int)selectedIndex];
}

- (UIViewController *)selectedViewController {
	if (self.splitMaster)
		return self.splitMaster.selectedViewController;
	return [super selectedViewController];
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
	if (self.splitMaster) {
		[self.splitMaster setSelectedViewController:selectedViewController];
		return;
	}
	NSInteger index = [[super viewControllers] indexOfObject:selectedViewController];
	if (index != NSNotFound) {
		[self materialiseTab:index];
		[self applyTabBarInsetForIndex:index];
		selectedViewController = [super viewControllers][index];
	}
	[super setSelectedViewController:selectedViewController];
	if (index != NSNotFound)
		[self.customTabBar setSelectedIndex:(int)index];
}

- (int)unreadInChats:(NSArray *)chats {
	return [TGSettingsService unreadBadgeCountInChats:chats];
}

- (void)pushIconBadge {
	if (![UIApplication instancesRespondToSelector:@selector(setApplicationIconBadgeNumber:)])
		return;
	if (self.iconBadgePushed && self.pendingIconBadge == self.pushedIconBadge)
		return;
	self.iconBadgePushed = YES;
	self.pushedIconBadge = self.pendingIconBadge;
	gIconBadgePushed = YES;
	[UIApplication sharedApplication].applicationIconBadgeNumber = self.pendingIconBadge;
}

+ (BOOL)iconBadgeWasPushed {
	return gIconBadgePushed;
}

- (void)updateUnreadBadge {
	if (self.splitMaster) {
		[self.splitMaster updateUnreadBadge];
		return;
	}
	if (!self.customTabBar)
		return;
	NSInteger total = [self unreadInChats:[TGSettingsService chats]];
	total += [self unreadInChats:[TGSettingsService archivedChats]];
	if (total < 0)
		total = 0;
	[self.customTabBar setUnreadCount:total];
	[[TGAccountManager shared] noteUnreadCount:total];

	NSInteger badgeTotal = [TGSettingsService totalUnreadBadgeCount];
	if (self.iconBadgeScheduled && badgeTotal == self.pendingIconBadge)
		return;
	self.iconBadgeScheduled = YES;
	self.pendingIconBadge = badgeTotal;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(pushIconBadge)
											   object:nil];
	[self performSelector:@selector(pushIconBadge) withObject:nil afterDelay:1.5];
}

@end
