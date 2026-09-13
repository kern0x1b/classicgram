#import "TGImageDecode.h"
#import "TGSavedMessagesViewController.h"
#import "TGSavedMessagesViewControllerInternal.h"
#import "RootViewController.h"
#import "TGEmoji.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+SavedMessages.h"
#import "TGClient+Messages.h"
#import "TGClient+Search.h"
#import "TGClient+Notifications.h"
#import "TGFileDownloadService.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGPopupMenu.h"
#import "UIView+SafeTint.h"
#import "TGPreferenceFlags.h"
#import "TGStringTruncation.h"
#import <QuartzCore/QuartzCore.h>
#import "TGDateUtils.h"
#import "TGSavedMessagesText.h"

const CGFloat kSavedRowHeight = 73.0f;
const CGFloat kSavedAvatar = 56.0f;
const CGFloat kSavedAvatarLeft = 8.0f;
const CGFloat kSavedTextLeft = 73.0f;
const CGFloat kSavedMessageRowHeight = 51.0f;
const NSInteger kSavedTopicPage = 40;
const NSInteger kSavedMessagePage = 60;

const NSInteger kSavedDeleteAlertTag = 71;
const NSInteger kSavedRangeAlertTag = 72;
const NSInteger kSavedReminderSheetTag = 75;
const NSInteger kSavedModeSheetTag = 76;
const NSInteger kSavedReminderMenuSheetTag = 77;
const CGFloat kSavedBannerHeight = 42.0f;

const CGFloat kSavedScopeHeight = 44.0f;
const CGFloat kSavedScopeButtonHeight = 30.0f;
const CGFloat kSavedSearchBarHeight = 44.0f;

const NSInteger kSavedScopeChats = 0;

NSArray *TGSavedScopeTitles(void) {
	return @[
		TGL(@"DialogList.TabTitle", @"Chats"),
		TGL(@"SharedMedia.CategoryMedia", @"Media"),
		TGL(@"SharedMedia.CategoryDocs", @"Docs"),
		TGL(@"SharedMedia.CategoryOther", @"Audio"),
		TGL(@"SharedMedia.CategoryLinks", @"Links"),
	];
}

NSString *TGSavedDate(NSTimeInterval unix) {
	if (unix <= 0)
		return @"";
	return [TGDateUtils stringForMessageListDate:(int)unix];
}

NSString *TGSavedTopicTitle(NSDictionary *topic) {
	NSString *title = topic[@"title"];
	if ([title isKindOfClass:NSString.class] && title.length)
		return title;

	NSString *kind = TGSavedTopicKind(topic);
	if ([kind isEqualToString:@"myNotes"])
		return TGL(@"DialogList.MyNotes", @"My Notes");
	if ([kind isEqualToString:@"authorHidden"])
		return TGL(@"ChatList.AuthorHidden", @"Author Hidden");

	int64_t chatId = [topic[@"chatId"] longLongValue];
	NSString *name = chatId ? [[TGClient shared] titleForChatId:chatId] : nil;
	return name.length ? name : TGL(@"Settings.SavedMessages", @"Saved Messages");
}

@implementation TGSavedMessagesViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	TGTheme *theme = [TGTheme shared];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"Settings.SavedMessages", @"Saved Messages");
	self.topics = @[];
	self.topicHits = @[];
	self.messageHits = @[];
	self.query = @"";
	self.scope = kSavedScopeChats;
	self.avatars = [NSMutableDictionary dictionary];
	self.avatarsRequested = [NSMutableSet set];
	self.avatarChatIdsRequested = [NSMutableSet set];
	self.chatFileIds = [NSMutableDictionary dictionary];

	[self buildTableBackground];
	[self buildSearchBar];
	[self buildScopeBar];

	[self showListButtons];

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(topicHeld:)];
	[self.tableView addGestureRecognizer:hold];

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

	[self buildReminderBanner];
	[self updateTableHeader];

	[self reloadTopics];
}

- (void)updateSeparatorStyle {
	BOOL platedTopics = self.scope == kSavedScopeChats && !self.query.length;
	self.tableView.separatorStyle = platedTopics
		? UITableViewCellSeparatorStyleNone
		: UITableViewCellSeparatorStyleSingleLine;
}

- (void)buildTableBackground {
	TGTheme *theme = [TGTheme shared];

	self.tableView.rowHeight = kSavedRowHeight;
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];

	[self updateSeparatorStyle];

	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.tableView.backgroundView = nil;
	self.view.layer.backgroundColor = [theme listBackgroundColour].CGColor;

	UIView *background = self.tableView;
	[self buildEmptyContainerInside:background];

	self.spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.center = CGPointMake(background.bounds.size.width / 2.0f, 120);
	self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	self.spinner.hidesWhenStopped = YES;
	[background addSubview:self.spinner];

	[self.tableView bringSubviewToFront:self.emptyContainer];
	[self.tableView bringSubviewToFront:self.spinner];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.themeChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.themeChangedObserverToken];
	[[TGClient shared] setSavedMessagesTopicsChangedHandler:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setSavedMessagesTopicsChangedHandler:^{
		[weakSelf applyCachedTopics];
	}];

	if (self.loadedOnce)
		[self applyCachedTopics];

	[self reloadReminders];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[TGClient shared] setSavedMessagesTopicsChangedHandler:nil];
	[TGPopupMenu dismiss];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];

	UINavigationController *nav = self.navigationController;
	if (nav && [nav.viewControllers containsObject:self])
		return;

	[self.avatars removeAllObjects];
	[self.avatarsRequested removeAllObjects];
	[self.avatarChatIdsRequested removeAllObjects];
	[self.chatFileIds removeAllObjects];
	[[TGClient shared] resetSavedMessagesTopicsCache];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutScopeBar];
	[self hideSearchBarOnFirstLayout];
}

- (void)themeChanged {
	TGTheme *theme = [TGTheme shared];
	[self styleSearchBar];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];
	self.view.layer.backgroundColor = [theme listBackgroundColour].CGColor;
	[self updateReminderBanner];

	[self updateSeparatorStyle];

	for (UIView *view in self.emptyContainer.subviews) {
		if ([view isKindOfClass:UILabel.class])
			[(UILabel *)view setTextColor:[theme secondaryTextColour]];
	}
	[self.tableView reloadData];
}

@end
