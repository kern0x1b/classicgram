#import "TGChatEventsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDateUtils.h"
#import "UIView+SafeTint.h"
#import "TGHexColour.h"

const CGFloat kEventsAvatarSide = 40.0f;
const CGFloat kEventsMinRowHeight = 51.0f;

CGFloat TGEventsRetinaPixel(void) {
	return [UIScreen mainScreen].scale > 1.0f ? 0.5f : 0.0f;
}

NSNumber *TGEventsNumber(NSDictionary *source, NSString *key) {
	id value = [source isKindOfClass:[NSDictionary class]] ? source[key] : nil;
	return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

long long TGEventsLongLong(NSDictionary *source, NSString *key) {
	return [TGEventsNumber(source, key) longLongValue];
}

int TGEventsInt(NSDictionary *source, NSString *key) {
	return [TGEventsNumber(source, key) intValue];
}

NSString *TGEventsText(NSDictionary *source, NSString *key) {
	id value = [source isKindOfClass:[NSDictionary class]] ? source[key] : nil;
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

@implementation TGChatEventsViewController

- (instancetype)initWithChatId:(int64_t)chatId {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_chatId = chatId;
		_events = [NSMutableArray array];
		_sections = [NSMutableArray array];
		_expandedGroupIds = [NSMutableSet set];
	}
	return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle {
	self = [super initWithNibName:nibName bundle:bundle];
	if (self) {
		_events = [NSMutableArray array];
		_sections = [NSMutableArray array];
		_expandedGroupIds = [NSMutableSet set];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.themeChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.themeChangedObserverToken];
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
}

- (void)buildTable {
	self.tableView = [[UITableView alloc]
		initWithFrame:self.view.bounds
				style:UITableViewStylePlain];
	self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.backgroundColor = self.view.backgroundColor;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	[self.view addSubview:self.tableView];
}

- (void)buildSearchBar {
	self.searchBar = [[UISearchBar alloc]
		initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Common.Search", @"Search");
	self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.barStyle = UIBarStyleDefault;
	if ([self.searchBar respondsToSelector:@selector(setBackgroundImage:)]) {
		UIImage *background = [UIImage imageNamed:@"SearchBarBackground.png"];
		[self.searchBar setBackgroundImage:background];
	}
	if ([self.searchBar respondsToSelector:@selector(setBarTintColor:)]) {
		self.searchBar.barTintColor = [[TGTheme shared] listBackgroundColour];
		[self.searchBar tg_setTintColor:[[TGTheme shared] accentColour]];
	} else {
		[self.searchBar tg_setTintColor:[UIColor colorWithWhite:0.68f alpha:1.0f]];
	}
}

- (void)buildSpamBanner {
	self.spamBanner = [UIButton buttonWithType:UIButtonTypeCustom];
	self.spamBanner.frame = CGRectMake(0, 44, self.view.bounds.size.width, 40);
	self.spamBanner.hidden = YES;
	self.spamBanner.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.spamBanner.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	self.spamBanner.contentHorizontalAlignment =
		UIControlContentHorizontalAlignmentLeft;
	self.spamBanner.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
	[self.spamBanner addTarget:self action:@selector(spamBannerPressed)
			  forControlEvents:UIControlEventTouchUpInside];
}

- (void)buildHeaderContainer {
	self.headerContainer = [[UIView alloc]
		initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
	self.headerContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.headerContainer addSubview:self.searchBar];
	[self.headerContainer addSubview:self.spamBanner];
	self.tableView.tableHeaderView = self.headerContainer;
	[self layoutHeaderContainer];
}

- (void)layoutHeaderContainer {
	CGFloat width = self.tableView.bounds.size.width;
	if (width <= 0)
		width = self.view.bounds.size.width;

	CGFloat searchHeight = CGRectGetHeight(self.searchBar.frame);
	self.searchBar.frame = CGRectMake(0, 0, width, searchHeight);

	CGFloat spamHeight = self.spamBanner.hidden ? 0 : CGRectGetHeight(self.spamBanner.frame);
	self.spamBanner.frame = CGRectMake(0, searchHeight, width,
		CGRectGetHeight(self.spamBanner.frame));

	self.headerContainer.frame = CGRectMake(0, 0, width, searchHeight + spamHeight);
	self.tableView.tableHeaderView = self.headerContainer;
}

- (void)buildInfoButton {
	self.infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.infoButton.frame = CGRectMake(0, 0, 36, 36);
	self.infoButton.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
	self.infoButton.backgroundColor = [UIColor whiteColor];
	self.infoButton.layer.cornerRadius = 18.0f;
	self.infoButton.layer.masksToBounds = YES;
	self.infoButton.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
	self.infoButton.layer.borderColor = TGColourFromHex(0xd9dde2).CGColor;

	UIImage *icon = [UIImage imageNamed:@"EventsInfo.png"];
	if (icon) {
		[self.infoButton setImage:icon forState:UIControlStateNormal];
	} else {
		[self.infoButton setTitle:@"i" forState:UIControlStateNormal];
		self.infoButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
		[self.infoButton setTitleColor:TGColourFromHex(0x337acc) forState:UIControlStateNormal];
	}
	[self.infoButton addTarget:self action:@selector(infoButtonPressed)
			  forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.infoButton];
}

- (void)buildMessageView {
	self.messageView = [[TGPlaceholderView alloc] initWithFrame:CGRectMake(0, 0, 250, 60)];
	self.messageView.hidden = YES;

	self.messageView.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	self.messageView.titleLabel.textColor = TGColourFromHex(0x8b97a5);

	self.messageView.bodyLabel.font = [UIFont systemFontOfSize:14];
	self.messageView.bodyLabel.textColor = TGColourFromHex(0x8b97a5);

	self.messageView.actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	[self.messageView.actionButton setTitleColor:TGColourFromHex(0x337acc) forState:UIControlStateNormal];
	[self.messageView.actionButton addTarget:self action:@selector(retryLoadingEvents)
							 forControlEvents:UIControlEventTouchUpInside];

	[self.view insertSubview:self.messageView belowSubview:self.tableView];
}

- (void)buildSpinner {
	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
			UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	[self buildTable];
	[self buildSearchBar];
	[self buildSpamBanner];
	[self buildHeaderContainer];
	[self buildMessageView];
	[self buildInfoButton];
	[self buildSpinner];

	self.title = TGL(@"Group.Info.AdminLog", @"Recent Actions");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	NSString *filterTitle = TGL(@"Channel.AdminLogFilter.Title", @"Filter");
	UIButton *filter = [TGIcons headerButtonWithTitle:filterTitle
												 bold:NO
											   target:self
											   action:@selector(filterPressed)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:filter];

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	__weak typeof(self) weakSelf = self;
	self.themeChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGThemeChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf themeChanged];
				}];

	[self loadAdministrators];
	[self loadChatKind];
	[self reload];
}

- (void)loadChatKind {
	if (self.chatId == 0)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] canSendInChat:self.chatId
						  completion:^(BOOL canSend, BOOL isChannel, NSDictionary *permissions) {
							  __strong typeof(weakSelf) strongSelf = weakSelf;
							  if (!strongSelf)
								  return;
							  strongSelf.broadcastChannel = isChannel;
						  }];
}

- (void)infoButtonPressed {
	NSString *text = self.broadcastChannel
		? TGL(@"Channel.AdminLog.InfoPanelChannelAlertText",
			  @"Actions taken by the admins of this chat over the last 48 hours are listed here.")
		: TGL(@"Channel.AdminLog.InfoPanelAlertText",
			  @"This is a list of all service actions taken by the group's members and admins in the last 48 hours.");
	[[[TGAlertView alloc]
		initWithTitle:TGL(@"Channel.AdminLog.InfoPanelAlertTitle", @"What is the event log?")
			  message:text
	  cancelButtonTitle:TGL(@"Common.OK", @"OK")
		 okButtonTitle:nil
	   completionBlock:nil] show];
}

- (void)themeChanged {
	TGTheme *theme = [TGTheme shared];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.backgroundColor = self.view.backgroundColor;
	[self updateSpamBanner];
	[self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	TGActionSheet *sheet = self.currentActionSheet;
	if (sheet) {
		[sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
		self.currentActionSheet = nil;
	}
}

- (void)loadAdministrators {
	if (self.chatId == 0)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] administratorsForChat:self.chatId
								  completion:^(NSArray *administrators) {
									  __strong typeof(weakSelf) strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  strongSelf.administrators = [administrators isKindOfClass:[NSArray class]]
										  ? administrators
										  : nil;
								  }];
}

- (void)viewDidLayoutSubviews {
	if ([[UIViewController class] instancesRespondToSelector:@selector(viewDidLayoutSubviews)])
		[super viewDidLayoutSubviews];
	[self layoutOverlays];
}

- (void)viewWillLayoutSubviews {
	if ([[UIViewController class] instancesRespondToSelector:@selector(viewWillLayoutSubviews)])
		[super viewWillLayoutSubviews];
	[self layoutOverlays];
}

- (void)layoutOverlays {
	CGRect bounds = self.view.bounds;
	self.spinner.center = CGPointMake(floorf(bounds.size.width / 2),
		floorf(bounds.size.height / 2));

	CGFloat infoSide = CGRectGetWidth(self.infoButton.frame);
	self.infoButton.frame = CGRectMake(bounds.size.width - infoSide - 14,
		bounds.size.height - infoSide - 14, infoSide, infoSide);

	if (self.messageView.hidden)
		return;

	CGFloat width = 250;
	CGFloat height = [self.messageView layoutContentWidth:width];
	self.messageView.frame = CGRectMake(floorf((bounds.size.width - width) / 2),
		floorf((bounds.size.height - height) / 2), width, height);
}

@end
