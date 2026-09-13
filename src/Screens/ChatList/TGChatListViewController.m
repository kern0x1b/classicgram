#import "TGSearchBarPin.h"
#import "TGFriendlyError.h"
#import "TGClient+ChatState.h"
#import "TGChatListViewController.h"
#import "TGLocalization.h"
#import "RootViewController.h"
#import "TGClient+Account.h"
#import "TGClient+ChatList.h"
#import "TGClient+Stories.h"
#import "TGClient+Privacy.h"
#import "TGClient+Contacts.h"
#import "TGClient+Network.h"
#import "TGClient+SecretChats.h"
#import "TGAccountManager.h"
#import "TGChatViewController.h"
#import "TGFoldersViewController.h"
#import "TGPreferenceFlags.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGSwipeGestureRecognizer.h"
#import "TGEmoji.h"
#import "TGActionsMenu.h"
#import "UIView+SafeTint.h"
#import "TGDiskCache.h"
#import "TGImageDecode.h"
#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAlertView.h"
#import "TGChatListHelpers.h"
#import "TGChatListArchiveVisibility.h"
#import "TGFlattenContacts.h"

#pragma mark - chat id picker

#import "TGChatIdPickerViewController.h"

#pragma mark - cell

#import "TGChatCell.h"

#pragma mark - controller

#import "TGChatListViewControllerInternal.h"

@implementation TGChatListViewController

- (void)buildRowCaches {
	self.chats = @[];
	self.avatars = [NSMutableDictionary dictionary];
	self.avatarMinis = [NSMutableDictionary dictionary];
	self.avatarsRequested = [NSMutableSet set];
	self.avatarsInFlight = [NSMutableSet set];
	self.avatarsFailedOnce = [NSMutableSet set];
	self.listUnread = [NSMutableDictionary dictionary];
	self.listUnreadIsNative = [NSMutableSet set];
	self.storyPostersById = [NSMutableDictionary dictionary];
	self.secretStatuses = [NSMutableDictionary dictionary];
	self.secretStatusesRequested = [NSMutableSet set];
	self.muteRemaining = [NSMutableDictionary dictionary];
	self.rowDetails = [NSMutableDictionary dictionary];
	self.rowDetailsRequested = [NSMutableSet set];
	self.foldersPumped = [NSMutableSet set];
	self.chatsPendingDeletion = [NSMutableSet set];
	self.folderLimit = 60;
}

- (void)buildSearchBar {
	CGFloat searchWidth = self.view.bounds.size.width;
	if (searchWidth < 1)
		searchWidth = self.tableView.bounds.size.width;
	if (searchWidth < 1)
		searchWidth = [UIScreen mainScreen].applicationFrame.size.width;
	self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, searchWidth, 44)];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"DialogList.SearchLabelCompact", @"Search");
	[self styleSearchBar];
	[self rebuildTableHeader];
}

- (void)styleListTable {
	self.tableView.rowHeight = kRowHeight;
	[self applySeparatorStyle];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.tableView.backgroundView = nil;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.view.layer.backgroundColor = [[TGTheme shared] listBackgroundColour].CGColor;
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[[TGTheme shared] styleTabBar:self.tabBarController.tabBar];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = [self defaultTitle];
	[self buildRowCaches];
	if (!self.showsArchive)
		[[TGClient shared] loadActiveStoriesArchived:NO];

	[self installComposeButton];
	[self updateEditingChrome];

	[self buildSearchBar];

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(rowHeld:)];
	[self.tableView addGestureRecognizer:hold];

	[self styleListTable];

	[self installThemeObserver];
	[self installStoryObserver];
	[self installFolderObserver];
	[self installBirthdayObserver];
	[self installUnreadMessageCountObserver];
	[self installUnreadChatCountObserver];
	[self installUnconfirmedSessionObserver];
	[self installSecretChatStateObserver];

	if ([self.tabBarController isKindOfClass:[RootViewController class]])
		[(RootViewController *)self.tabBarController updateUnreadBadge];

	[self buildEmptyContainer];

	[self applyTitleView];
	[self installClientHandlers];
	[self reload];
}

- (void)installComposeButton {
	UIButton *compose = [UIButton buttonWithType:UIButtonTypeCustom];
	[TGIcons styleHeaderButton:compose];
	[compose setImage:[UIImage imageNamed:@"ComposeMessageIcon"] forState:UIControlStateNormal];
	compose.accessibilityLabel = TGL(@"VoiceOver.Navigation.Compose", @"Compose");
	compose.frame = CGRectMake(0, 0, 30, 30);
	[compose addTarget:self action:@selector(composeTapped) forControlEvents:UIControlEventTouchUpInside];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:compose];
}

- (void)installThemeObserver {
	__weak typeof(self) weakSelf = self;
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	self.themeObserver = [centre addObserverForName:TGThemeChangedNotification
											 object:nil
											  queue:[NSOperationQueue mainQueue]
										 usingBlock:^(NSNotification *note) {
											 [TGIcons flush];
											 TGTheme *theme = [TGTheme shared];
											 [theme styleNavigationBar:weakSelf.navigationController.navigationBar];
											 weakSelf.tableView.backgroundColor = [theme listBackgroundColour];
											 weakSelf.view.layer.backgroundColor = [theme listBackgroundColour].CGColor;
											 weakSelf.tableView.separatorColor = [theme separatorColour];
											 [weakSelf applySeparatorStyle];
											 [theme styleTabBar:weakSelf.tabBarController.tabBar];
											 [weakSelf styleSearchBar];
											 [weakSelf applyTitleView];
											 [weakSelf updateEditingChrome];
											 [weakSelf rebuildTableHeader];
											 [weakSelf.tableView reloadData];
										 }];
}

- (void)installFolderObserver {
	if (self.showsArchive)
		return;
	__weak typeof(self) weakSelf = self;
	self.folderObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatFoldersDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf foldersChanged];
				}];
	[[TGClient shared] beginObservingFolderChanges];

	self.folderLayoutObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGPreferenceChatListLayoutChangedNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf folderLayoutChanged];
				}];
}

- (void)installUnreadMessageCountObserver {
	__weak typeof(self) weakSelf = self;
	self.unreadMessageCountObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUnreadMessageCountDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf handleUnreadMessageCountUpdate:note.userInfo];
				}];
}

- (void)installUnreadChatCountObserver {
	__weak typeof(self) weakSelf = self;
	self.unreadChatCountObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUnreadChatCountDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf handleUnreadChatCountUpdate:note.userInfo];
				}];
}

- (void)installUnconfirmedSessionObserver {
	__weak typeof(self) weakSelf = self;
	self.unconfirmedSessionObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUnconfirmedSessionDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf fetchUnconfirmedSession];
				}];
}

- (void)installSecretChatStateObserver {
	__weak typeof(self) weakSelf = self;
	self.secretChatStateObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGSecretChatStateDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf secretChatStateNotificationReceived:note];
				}];
}

- (void)folderLayoutChanged {
	[self applyTitleView];
	[self rebuildTableHeader];
}

- (void)foldersChanged {
	[self.foldersPumped removeAllObjects];
	if (self.folderId != 0 && ![self folderExists:self.folderId])
		self.folderId = 0;
	[self applyTitleView];
	[self rebuildTableHeader];
	[self reload];
}

- (BOOL)folderExists:(NSInteger)folderId {
	for (id entry in [self folderList])
		if ([TGReplyDictionary(entry)[@"id"] integerValue] == folderId)
			return YES;
	return NO;
}

- (void)installStoryObserver {
	__weak typeof(self) weakSelf = self;
	self.storyObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGStoryUpdateNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf handleStoryUpdate:note.object];
				}];
}

- (void)handleStoryUpdate:(id)update {
	if (self.showsArchive)
		return;

	NSDictionary *object = TGReplyDictionary(update);
	NSString *type = TGTDLibTypeOf(object);
	int64_t chatId = 0;
	if ([type isEqualToString:@"updateChatActiveStories"])
		chatId = [TGReplyDictionary(object[@"active_stories"])[@"chat_id"] longLongValue];
	else if ([type isEqualToString:@"updateStoryPostSucceeded"] ||
		[type isEqualToString:@"updateStory"])
		chatId = [TGReplyDictionary(object[@"story"])[@"poster_chat_id"] longLongValue];
	else if ([type isEqualToString:@"updateStoryDeleted"])
		chatId = [object[@"story_poster_chat_id"] longLongValue];
	if (chatId == 0)
		return;

	[self mergeStoryPosterForChat:chatId attempt:0];
}

- (NSString *)storyTitleForChat:(int64_t)chatId {
	for (NSDictionary *chat in self.chats) {
		if ([chat[@"id"] longLongValue] == chatId)
			return TGReplyString(chat[@"title"]) ?: @"";
	}
	NSString *name = chatId > 0 ? [[TGClient shared] nameForUserId:chatId] : nil;
	return name.length ? name : @"Story";
}

- (NSNumber *)storyPhotoFileIdForChat:(int64_t)chatId {
	for (NSDictionary *chat in self.chats) {
		if ([chat[@"id"] longLongValue] != chatId)
			continue;
		id fileId = chat[@"photoFileId"];
		return [fileId isKindOfClass:[NSNumber class]] ? fileId : nil;
	}
	return nil;
}

- (void)mergeStoryPosterForChat:(int64_t)chatId attempt:(NSInteger)attempt {
	if (self.storyProbesPending > 0) {
		if (attempt >= 5)
			return;
		__weak typeof(self) weakSelf = self;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kChatListDeferredActionDelay * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
				[weakSelf mergeStoryPosterForChat:chatId attempt:(attempt + 1)];
			});
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] activeStoriesForChat:chatId completion:^(NSDictionary *reply) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.showsArchive || strongSelf.storyProbesPending > 0)
			return;
		if (!strongSelf.storyPostersById)
			strongSelf.storyPostersById = [NSMutableDictionary dictionary];

		NSDictionary *active = TGReplyDictionary(reply);
		NSArray *stories = TGReplyArray(active[@"stories"]);
		NSNumber *key = @(chatId);

		if (!stories.count || [active[@"archived"] boolValue]) {
			if (!strongSelf.storyPostersById[key])
				return;
			[strongSelf.storyPostersById removeObjectForKey:key];
			[strongSelf commitStoryPosters];
			return;
		}

		NSMutableDictionary *poster = [NSMutableDictionary dictionary];
		poster[@"chatId"] = key;
		poster[@"title"] = [strongSelf storyTitleForChat:chatId];
		poster[@"stories"] = stories;
		poster[@"order"] = active[@"order"] ?: @0;
		poster[@"unread"] = active[@"unread"] ?: @NO;
		NSNumber *fileId = [strongSelf storyPhotoFileIdForChat:chatId];
		if (fileId)
			poster[@"photoFileId"] = fileId;

		if ([strongSelf.storyPostersById[key] isEqual:poster])
			return;
		strongSelf.storyPostersById[key] = poster;
		[strongSelf commitStoryPosters];
	}];
}

- (void)updateEditingChrome {
	if (self.multiSelecting)
		return;
	BOOL editing = self.tableView.editing;
	UIButton *button = [TGIcons headerButtonWithTitle:(editing ? TGL(@"Common.Done", @"Done") : TGL(@"Common.Edit", @"Edit"))
												 bold:editing
											   target:self
											   action:@selector(editTapped)];
	[button addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
									 initWithTarget:self
											 action:@selector(editHeld:)]];
	UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:button];

	if ([self isPushedList]) {
		self.navigationItem.hidesBackButton = YES;
		self.navigationItem.leftBarButtonItem = [TGIcons
			backBarButtonItemWithTitle:[self backTitle]
								target:self
								action:@selector(backTapped)];
		self.navigationItem.rightBarButtonItem = item;
		return;
	}

	self.navigationItem.leftBarButtonItem = item;
	self.navigationItem.rightBarButtonItem.customView.alpha = editing ? 0.0f : 1.0f;
}

- (BOOL)isPushedList {
	UINavigationController *nav = self.navigationController;
	return nav != nil && [nav.viewControllers firstObject] != self;
}

- (NSString *)backTitle {
	return TGL(@"DialogList.Title", @"Chats");
}

- (void)backTapped {
	[self closeOpenSwipeCellAnimated:NO];
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)editTapped {
	[self closeOpenSwipeCellAnimated:NO];
	BOOL turningEditingOff = self.tableView.editing;
	[self.tableView setEditing:!self.tableView.editing animated:YES];
	[self updateEditingChrome];
	if (turningEditingOff)
		[self endInteractiveMoveIfNeeded];
}

- (void)editHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	[self actionsTapped];
}

- (void)endInteractiveMoveIfNeeded {
	if (!self.interactiveMoveInProgress)
		return;
	self.interactiveMoveInProgress = NO;
	BOOL reloadWasPending = self.reloadPendingAfterInteractiveMove;
	self.reloadPendingAfterInteractiveMove = NO;
	if (reloadWasPending)
		[self reload];
}

- (void)installClientHandlers {
	if (self.chatsChangedObserver)
		return;
	__weak typeof(self) weakSelf = self;
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	self.chatsChangedObserver = [centre addObserverForName:TGChatsDidChangeNotification
													 object:nil
													  queue:[NSOperationQueue mainQueue]
												 usingBlock:^(NSNotification *note) {
		[weakSelf reload];
		TGChatListViewController *strongSelf = weakSelf;
		if ([strongSelf.tabBarController isKindOfClass:[RootViewController class]])
			[(RootViewController *)strongSelf.tabBarController updateUnreadBadge];
	}];
	self.unreadBadgesObserver = [centre addObserverForName:TGChatUnreadMentionsDidChangeNotification
													  object:nil
													   queue:[NSOperationQueue mainQueue]
												  usingBlock:^(NSNotification *note) {
		[weakSelf reload];
	}];
	self.unreadReactionsObserver = [centre addObserverForName:TGChatUnreadReactionsDidChangeNotification
														 object:nil
														  queue:[NSOperationQueue mainQueue]
													 usingBlock:^(NSNotification *note) {
		[weakSelf reload];
	}];
	self.archiveChangedObserver = [centre addObserverForName:TGArchivedChatsDidChangeNotification
													   object:nil
														queue:[NSOperationQueue mainQueue]
												   usingBlock:^(NSNotification *note) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (strongSelf.showsArchive)
			[strongSelf reload];
		else
			[strongSelf rebuildTableHeader];
		[strongSelf.tableView reloadData];
	}];
	self.connectionStateObserver = [centre addObserverForName:TGConnectionStateDidChangeNotification
														object:nil
														 queue:[NSOperationQueue mainQueue]
													usingBlock:^(NSNotification *note) {
		TGChatListViewController *strongSelf = weakSelf;
		id rawText = note.userInfo[TGConnectionStateTitleKey];
		NSString *line = [rawText isKindOfClass:NSString.class] ? rawText : nil;
		strongSelf.connectionText = line.length ? line : nil;
		[strongSelf applyTitleView];
		[strongSelf updateEmptyState];
	}];
	self.accountSwitchObserver = [centre addObserverForName:TGAccountDidSwitchNotification
													  object:nil
													   queue:[NSOperationQueue mainQueue]
												  usingBlock:^(NSNotification *note) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf buildRowCaches];
		[strongSelf rebuildTableHeader];
		[strongSelf reload];
	}];
}

- (NSString *)defaultTitle {
	if (self.showsArchive)
		return TGL(@"ChatListFolder.CategoryArchived", @"Archived");
	if (self.folderId != 0) {
		for (id entry in [self folderList]) {
			NSDictionary *f = TGReplyDictionary(entry);
			if ([f[@"id"] integerValue] == self.folderId)
				return TGReplyString(f[@"title"]) ?: TGL(@"DialogList.SearchSectionMessages", @"Messages");
		}
	}
	return TGL(@"DialogList.SearchSectionMessages", @"Messages");
}

- (NSArray *)folderList {
	return TGReplyArray([TGClient shared].folders) ?: @[];
}

- (BOOL)hasFolders {
	return [self folderList].count > 0;
}

- (BOOL)usesFolderStrip {
	return !self.showsArchive && [self hasFolders] &&
		![TGPreferenceFlags chatListShowsFolderChooser];
}

- (BOOL)usesFolderChooser {
	return !self.showsArchive && [self hasFolders] &&
		[TGPreferenceFlags chatListShowsFolderChooser];
}

- (UIView *)titleStatusView {
	if (!self.titleStatusContainer) {
		self.titleStatusContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
		self.titleStatusContainer.clipsToBounds = NO;

		self.titleStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		self.titleStatusLabel.backgroundColor = [UIColor clearColor];
		self.titleStatusLabel.font = [UIFont boldSystemFontOfSize:15];
		self.titleStatusLabel.textColor = [UIColor whiteColor];
		self.titleStatusLabel.shadowColor = [UIColor
			colorWithRed:0x41 / 255.0f
				   green:0x5a / 255.0f
					blue:0x7e / 255.0f
				   alpha:1.0f];
		self.titleStatusLabel.shadowOffset = CGSizeMake(0, -1);
		[self.titleStatusContainer addSubview:self.titleStatusLabel];

		self.titleStatusIndicator = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		[self.titleStatusContainer addSubview:self.titleStatusIndicator];
	}

	self.titleStatusLabel.text = self.connectionText ?: @"";
	[self.titleStatusLabel sizeToFit];
	CGRect holder = self.titleStatusContainer.bounds;
	CGRect label = self.titleStatusLabel.frame;
	CGRect spinner = self.titleStatusIndicator.frame;
	label.origin = CGPointMake((int)((holder.size.width - label.size.width + spinner.size.width + 5) / 2),
		(int)((holder.size.height - label.size.height) / 2) - 1);
	self.titleStatusLabel.frame = label;
	self.titleStatusIndicator.frame = CGRectMake(label.origin.x - spinner.size.width - 5,
		label.origin.y + 3, spinner.size.width, spinner.size.height);
	[self.titleStatusIndicator startAnimating];
	return self.titleStatusContainer;
}

- (void)applyTitleView {
	self.title = [self defaultTitle];
	if (self.connectionText.length) {
		self.navigationItem.titleView = [self titleStatusView];
		return;
	}
	if (self.titleStatusIndicator)
		[self.titleStatusIndicator stopAnimating];
	if (![self usesFolderChooser]) {
		self.navigationItem.titleView = nil;
		self.titleLabelView = nil;
		return;
	}

	NSString *text = [self defaultTitle];
	UIFont *font = [UIFont boldSystemFontOfSize:20];
	CGFloat textWidth = MIN(180, (int)[text sizeWithFont:font].width);
	UIImage *caret = TGTitleCaretImage();
	CGFloat width = textWidth + 6 + caret.size.width;

	UIControl *holder = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, width, 40)];
	self.titleLabelView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, textWidth, 40)];
	self.titleLabelView.backgroundColor = [UIColor clearColor];
	self.titleLabelView.font = font;
	self.titleLabelView.textColor = [UIColor whiteColor];
	self.titleLabelView.shadowColor = [UIColor colorWithWhite:0 alpha:0.4f];
	self.titleLabelView.shadowOffset = CGSizeMake(0, -1);
	self.titleLabelView.textAlignment = NSTextAlignmentCenter;
	self.titleLabelView.text = text;
	[holder addSubview:self.titleLabelView];

	UIImageView *arrow = [[UIImageView alloc] initWithImage:caret];
	arrow.frame = CGRectMake(textWidth + 6, (int)((40 - caret.size.height) / 2) + 1,
		caret.size.width, caret.size.height);
	[holder addSubview:arrow];

	self.titleLabelView.userInteractionEnabled = NO;
	arrow.userInteractionEnabled = NO;
	[holder addTarget:self action:@selector(foldersTapped)
		forControlEvents:UIControlEventTouchUpInside];
	self.navigationItem.titleView = holder;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self installClientHandlers];
	[self applyTitleView];
	[self applyBottomBarInset];
	[self rebuildTableHeader];
	[self resetSearchBarRevealOnAppear];
	NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
	if (selected && ![self splitLayoutActive])
		[self.tableView deselectRowAtIndexPath:selected animated:animated];
	if ([self.tabBarController isKindOfClass:[RootViewController class]])
		[(RootViewController *)self.tabBarController updateUnreadBadge];
	[self reload];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[self closeOpenSwipeCellAnimated:YES];
	self.scrollAnchor = scrollView.contentOffset.y + scrollView.contentInset.top;
}

- (BOOL)searchBarActive {
	return self.searchResults != nil || self.searchBar.text.length > 0 ||
		[self.searchBar isFirstResponder];
}

- (void)revealSearchBarIfPulled:(UIScrollView *)scrollView {
	if (self.searchBarRevealed || !scrollView.dragging)
		return;
	if (self.scrollAnchor < kSearchBarHeight - 0.5f)
		return;
	if (scrollView.contentOffset.y + scrollView.contentInset.top > kSearchBarHeight / 2)
		return;
	self.searchBarRevealed = YES;
}

- (void)hideSearchBarIfScrolledPast:(UIScrollView *)scrollView {
	if (!self.searchBarRevealed || [self searchBarActive])
		return;
	if (scrollView.contentOffset.y + scrollView.contentInset.top < kSearchBarHeight + 0.5f)
		return;
	self.searchBarRevealed = NO;
}

- (CGFloat)restingSearchBarOffset {
	return ([self searchBarActive] || self.searchBarRevealed) ? 0 : kSearchBarHeight;
}

- (void)snapSearchBar:(UIScrollView *)scrollView {
	CGFloat top = scrollView.contentInset.top;
	CGFloat shown = scrollView.contentOffset.y + top;
	if (shown > kSearchBarHeight - 0.5f)
		return;

	CGFloat target = [self restingSearchBarOffset];
	if (fabs(shown - target) < 0.5f)
		return;

	[scrollView setContentOffset:CGPointMake(0, target - top) animated:YES];
}

- (void)resetSearchBarRevealOnAppear {
	if ([self searchBarActive])
		return;
	self.searchBarRevealed = NO;
	UITableView *table = self.tableView;
	if (table.dragging || table.tracking || table.decelerating)
		return;
	CGFloat top = table.contentInset.top;
	CGFloat shown = table.contentOffset.y + top;
	if (shown < -0.5f || shown >= kSearchBarHeight - 0.5f)
		return;
	CGFloat reachable = table.contentSize.height - table.bounds.size.height + top + table.contentInset.bottom;
	if (reachable < kSearchBarHeight)
		return;
	table.contentOffset = CGPointMake(0, kSearchBarHeight - top);
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self closeOpenSwipeCellAnimated:NO];
	[TGPopupMenu dismiss];
	[TGActionsMenu dismiss];
	[self endInteractiveMoveIfNeeded];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (self.emptyContainer && !self.emptyContainer.hidden)
		[self updateEmptyState];
	[self revealSearchBarIfPulled:scrollView];
	[self hideSearchBarIfScrolledPast:scrollView];
	[self revealArchiveIfPulled:scrollView];
	[self loadMoreIfNeeded];
	[self fetchMissingAvatarsThrottled];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (!decelerate) {
		[self collapseArchiveIfScrolledPast];
		[self snapSearchBar:scrollView];
		[self fetchMissingAvatars];
		self.scrollAnchor = scrollView.contentOffset.y + scrollView.contentInset.top;
	}
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	[self collapseArchiveIfScrolledPast];
	[self snapSearchBar:scrollView];
	[self fetchMissingAvatars];
	self.scrollAnchor = scrollView.contentOffset.y + scrollView.contentInset.top;
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
	[self collapseArchiveIfScrolledPast];
	[self fetchMissingAvatars];
	self.scrollAnchor = scrollView.contentOffset.y + scrollView.contentInset.top;
}

- (BOOL)archiveBannerAllowed {
	return !self.showsArchive && self.folderId == 0 && self.searchResults == nil &&
		!self.tableView.editing;
}

- (void)revealArchiveIfPulled:(UIScrollView *)scrollView {
	if (self.archiveRevealed || !self.archiveAvailable || !TGArchiveHiddenByDefault())
		return;
	if (![self archiveBannerAllowed] || !scrollView.dragging)
		return;
	if (self.scrollAnchor > kSearchBarHeight + 0.5f)
		return;
	if (scrollView.contentOffset.y + scrollView.contentInset.top > -kArchivePullThreshold)
		return;

	CGPoint offset = scrollView.contentOffset;
	self.archiveRevealed = YES;
	[self rebuildTableHeader];
	if (!CGPointEqualToPoint(scrollView.contentOffset, offset))
		scrollView.contentOffset = offset;

	UIView *row = self.archiveRowView;
	if (row) {
		row.alpha = 0;
		[UIView animateWithDuration:0.25 animations:^{
			row.alpha = 1;
		}];
	}
}

- (void)collapseArchiveIfScrolledPast {
	if (!self.archiveRevealed || !TGArchiveHiddenByDefault() || ![self archiveBannerAllowed])
		return;
	UITableView *table = self.tableView;
	if (table.contentOffset.y + table.contentInset.top < self.archiveRowTop + kRowHeight)
		return;

	CGPoint offset = table.contentOffset;
	self.archiveRevealed = NO;
	[self rebuildTableHeader];
	offset.y -= kRowHeight;
	table.contentOffset = offset;
}

- (void)toggleArchiveHiddenByDefaultFromCell:(TGChatCell *)cell {
	if (cell) {
		[cell setSwipeActionsVisible:NO animated:YES];
		if (self.openSwipeCell == cell)
			self.openSwipeCell = nil;
	}

	BOOL hidden = !TGArchiveHiddenByDefault();
	TGSetArchiveHiddenByDefault(hidden);
	self.archiveRevealed = NO;
	[self rebuildTableHeader];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self applyBottomBarInset];
	UIView *header = self.tableView.tableHeaderView;
	CGFloat width = self.tableView.bounds.size.width;
	if (header && width >= 1 && header.frame.size.width != width)
		[self rebuildTableHeader];
	[self updateEmptyState];
}

- (void)applyBottomBarInset {
	CGFloat bottom = 0;
	id tabs = self.tabBarController;
	if ([tabs isKindOfClass:[RootViewController class]])
		bottom = [(RootViewController *)tabs tabBarInsetForController:self];

	UIEdgeInsets insets = self.tableView.contentInset;
	if (insets.bottom == bottom &&
		self.tableView.scrollIndicatorInsets.bottom == bottom)
		return;
	insets.bottom = bottom;
	self.tableView.contentInset = insets;
	self.tableView.scrollIndicatorInsets = insets;
}

- (void)buildOverscrollFiller {
	if (self.overscrollFiller)
		return;
	UIView *filler = [UIView alloc];
	filler = [filler initWithFrame:
			CGRectMake(0, -500, self.tableView.bounds.size.width, 500)];
	filler.backgroundColor = [UIColor colorWithRed:0xe4 / 255.0f green:0xe9 / 255.0f
											  blue:0xf0 / 255.0f
											 alpha:1.0f];
	filler.opaque = YES;
	filler.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.overscrollFiller = filler;
	[self.tableView addSubview:filler];
}

- (void)buildEmptyContainer {
	[self buildOverscrollFiller];
	UIColor *ink = [UIColor colorWithRed:0x8b / 255.0f green:0x97 / 255.0f
									blue:0xa5 / 255.0f
								   alpha:1.0f];

	self.emptyContainer = [[TGPlaceholderView alloc] initWithFrame:CGRectMake(0, 0, 250, 0)];
	self.emptyContainer.userInteractionEnabled = YES;
	self.emptyContainer.hidden = YES;

	self.emptyContainer.iconView.image = [UIImage imageNamed:@"NoMessages.png"];

	self.emptyContainer.titleLabel.textColor = ink;
	self.emptyContainer.titleLabel.font = [UIFont boldSystemFontOfSize:15];

	self.emptyContainer.bodyLabel.textColor = ink;
	self.emptyContainer.bodyLabel.font = [UIFont systemFontOfSize:14];

	self.emptyContainer.actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	self.emptyContainer.actionButton.backgroundColor = [[TGTheme shared] accentColour];
	self.emptyContainer.actionButton.layer.cornerRadius = 6;
	self.emptyContainer.actionButton.clipsToBounds = YES;
	[self.emptyContainer.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.emptyContainer.actionButton addTarget:self action:@selector(emptyActionButtonTapped)
								forControlEvents:UIControlEventTouchUpInside];

	[self.tableView addSubview:self.emptyContainer];
}

- (void)updateEmptyState {
	if (!self.emptyContainer)
		return;

	NSInteger rows = [self visibleChats].count + [self headerRows].count;
	if (rows > 0) {
		self.emptyContainer.hidden = YES;
		return;
	}

	NSDictionary *wording = [self emptyStateWording];
	self.emptyContainer.titleLabel.text = wording[@"title"];
	self.emptyContainer.bodyLabel.text = wording[@"text"];
	[self.emptyContainer.actionButton setTitle:wording[@"button"] forState:UIControlStateNormal];

	[self layoutEmptyContent];
}

- (NSDictionary *)emptyStateWording {
	if (self.searchResults) {
		return @{
			@"title" : TGL(@"ChatList.Search.NoResults", @"No Results"),
			@"text" : TGL(@"ChatList.Search.NoResultsDescription",
				@"There were no results.\nTry a new search."),
		};
	}
	if (self.showsArchive) {
		return @{
			@"title" : TGL(@"ArchiveInfo.Title", @"This is Your Archive"),
			@"text" : TGL(@"ArchiveInfo.ChatsText",
				@"Move any chat into your Archive and back by swiping on it."),
		};
	}
	if (self.folderId != 0) {
		return @{
			@"title" : TGL(@"ChatList.EmptyChatListFilterTitle", @"Folder is empty."),
			@"text" : TGL(@"ChatList.EmptyChatListFilterText",
				@"No chats currently match this folder."),
			@"button" : TGL(@"ChatList.EmptyChatListEditFilter", @"Edit Folder"),
		};
	}
	if ([TGClient shared].connectionState != TGConnectionStateReady) {
		return @{
			@"title" : TGL(@"Channel.NotificationLoading", @"Loading…"),
			@"text" : @"",
		};
	}
	return @{
		@"title" : TGL(@"DialogList.NoMessagesTitle", @"You have no conversations yet"),
		@"text" : TGL(@"DialogList.NoMessagesText",
			@"Start messaging by pressing the pencil button in the top right corner or go to the Contacts section."
			 "top right corner or go to the Contacts section."),
		@"button" : TGL(@"ChatList.EmptyChatListNewMessage", @"New Message"),
	};
}

- (void)emptyActionButtonTapped {
	if (self.folderId != 0) {
		[self openFolder:self.folderId];
		return;
	}
	if (!self.showsArchive && self.searchResults == nil)
		[self composeTapped];
}

- (void)openFolder:(NSInteger)identifier {
	TGFoldersViewController *editor = [[TGFoldersViewController alloc] init];
	editor.page = TGFoldersPageEditor;
	editor.folderId = identifier;
	[self.navigationController pushViewController:editor animated:YES];
}

- (void)layoutEmptyContent {
	CGFloat width = 250;
	CGFloat height = [self.emptyContainer layoutContentWidth:width];

	CGRect bounds = self.tableView.bounds;
	self.emptyContainer.frame = CGRectMake((int)((bounds.size.width - width) / 2),
		bounds.origin.y + (int)((bounds.size.height - height) / 2), width, height);
	self.emptyContainer.hidden = NO;
	[self.tableView bringSubviewToFront:self.emptyContainer];
}

- (void)dealloc {
	if (self.themeObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.themeObserver];
	if (self.storyObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.storyObserver];
	if (self.folderObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.folderObserver];
	if (self.folderLayoutObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.folderLayoutObserver];
	if (self.unreadMessageCountObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.unreadMessageCountObserver];
	if (self.unreadChatCountObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.unreadChatCountObserver];
	if (self.unconfirmedSessionObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.unconfirmedSessionObserver];
	if (self.secretChatStateObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.secretChatStateObserver];
	if (self.birthdayObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.birthdayObserver];
	if (self.chatsChangedObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatsChangedObserver];
	if (self.unreadBadgesObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.unreadBadgesObserver];
	if (self.unreadReactionsObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.unreadReactionsObserver];
	if (self.archiveChangedObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.archiveChangedObserver];
	if (self.connectionStateObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.connectionStateObserver];
	if (self.accountSwitchObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.accountSwitchObserver];
}

- (void)applySeparatorStyle {
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)rebuildTableHeader {
	CGFloat width = self.tableView.bounds.size.width;
	if (width < 1)
		width = self.view.bounds.size.width;
	if (width < 1)
		width = [UIScreen mainScreen].applicationFrame.size.width;
	NSInteger archivedCount = TGReplyArray([TGClient shared].archivedChats).count;
	BOOL hasArchive = !self.showsArchive && self.folderId == 0 && archivedCount > 0;
	if (!hasArchive)
		self.archiveRevealed = NO;
	BOOL archiveHidden = TGArchiveHiddenByDefault();
	BOOL showArchive = hasArchive && (!archiveHidden || self.archiveRevealed);
	BOOL showTray = !self.showsArchive && TGReplyArray(self.storyPosters).count > 0;
	BOOL showStrip = [self usesFolderStrip];
	BOOL showLogin = !self.showsArchive && self.unconfirmedSession != nil;
	BOOL showFolderBanner = !self.showsArchive && self.folderId != 0 &&
		self.folderNewChatsFolderId == self.folderId && self.folderNewChats.count > 0;
	BOOL showBirthday = !self.showsArchive && self.folderId == 0 &&
		[self todaysBirthdayUsers].count > 0;
	CGFloat loginHeight = showLogin ? kLoginBannerHeight : 0;
	CGFloat folderBannerHeight = showFolderBanner ? kFolderBannerHeight : 0;
	CGFloat birthdayHeight = showBirthday ? kBirthdayBannerHeight : 0;
	CGFloat trayHeight = showTray ? kStoryTrayHeight : 0;
	CGFloat stripHeight = showStrip ? kFolderStripHeight : 0;
	CGFloat rowsTop = kSearchBarHeight + loginHeight + folderBannerHeight + birthdayHeight + trayHeight + stripHeight;
	CGFloat height = rowsTop + (showArchive ? kRowHeight : 0);
	NSDictionary *topArchivedChat = TGReplyDictionary(TGReplyArray([TGClient shared].archivedChats).firstObject);

	NSMutableString *signature = [NSMutableString stringWithFormat:
			@"%.1f|%lu|%d%d%d%d%d%d%d|%ld",
		width, (unsigned long)archivedCount,
		hasArchive, showArchive, showTray, showStrip, showLogin, showFolderBanner, showBirthday,
		(long)[self.listUnread[@(TGChatListArchive)] integerValue]];
	if (showTray)
		[signature appendFormat:@"|tray:%@", TGReplyArray(self.storyPosters)];
	if (showStrip)
		[signature appendFormat:@"|strip:%@|current:%ld|counts:%@",
			[self folderStripEntries], (long)self.folderId,
			[self folderStripCaptions]];
	if (showLogin)
		[signature appendFormat:@"|login:%@", self.unconfirmedSession];
	if (showFolderBanner)
		[signature appendFormat:@"|banner:%@", self.folderNewChats];
	if (showBirthday)
		[signature appendFormat:@"|birthday:%@", [self todaysBirthdayUsers]];
	if (showArchive)
		[signature appendFormat:@"|top:%lld:%@:%@:%@:%ld",
			[topArchivedChat[@"id"] longLongValue],
			TGReplyString(topArchivedChat[@"text"]) ?: @"",
			TGReplyString(topArchivedChat[@"action"]) ?: @"",
			TGReplyString(topArchivedChat[@"draft"]) ?: @"",
			(long)[topArchivedChat[@"date"] integerValue]];

	if (self.tableView.tableHeaderView != nil &&
		[signature isEqualToString:self.headerSignature])
		return;
	self.headerSignature = signature;

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
	header.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.searchBar.frame = CGRectMake(0, 0, width, kSearchBarHeight);
	[header addSubview:self.searchBar];

	if (showLogin)
		[header addSubview:[self loginBannerWithWidth:width top:kSearchBarHeight]];
	if (showFolderBanner) {
		CGFloat top = kSearchBarHeight + loginHeight;
		[header addSubview:[self folderInviteBannerWithWidth:width top:top]];
	}
	if (showBirthday) {
		CGFloat top = kSearchBarHeight + loginHeight + folderBannerHeight;
		[header addSubview:[self birthdayBannerWithWidth:width top:top]];
	}
	if (showTray) {
		CGFloat top = kSearchBarHeight + loginHeight + folderBannerHeight + birthdayHeight;
		[header addSubview:[self storyTrayWithWidth:width top:top]];
	}
	if (showStrip) {
		CGFloat top = kSearchBarHeight + loginHeight + folderBannerHeight + birthdayHeight + trayHeight;
		[header addSubview:[self folderStripWithWidth:width top:top]];
	}

	if (showArchive) {
		TGChatCell *row = [self archiveHeaderRowWithWidth:width top:rowsTop count:archivedCount];
		[header addSubview:row];
		self.archiveRowView = row;

		UIView *hair = [UIView alloc];
		hair = [hair initWithFrame:
				CGRectMake(0, height - 0.5f, width, 0.5f)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		[header addSubview:hair];
	} else {
		self.archiveRowView = nil;
	}

	BOOL hadHeader = self.tableView.tableHeaderView != nil;
	CGPoint priorOffset = self.tableView.contentOffset;
	self.tableView.tableHeaderView = header;
	if (hadHeader)
		self.tableView.contentOffset = priorOffset;
	self.headerHeight = height;
	self.archiveAvailable = hasArchive;
	self.archiveRowTop = rowsTop;
	[self pinHeaderIfSearchBarClipped];
	[self applyInitialScrollOffset];
}

- (void)pinHeaderIfSearchBarClipped {
	UITableView *table = self.tableView;
	if (table.dragging || table.decelerating || table.tracking)
		return;
	CGFloat top = table.contentInset.top;
	CGFloat target = [self restingSearchBarOffset];
	CGFloat shown = table.contentOffset.y + top;
	CGFloat reachable = table.contentSize.height - table.bounds.size.height + top + table.contentInset.bottom;
	if (!TGChatListShouldPinSearchBar(shown, target, kSearchBarHeight, reachable))
		return;
	table.contentOffset = CGPointMake(0, target - top);
}

- (void)applyInitialScrollOffset {
	if (self.initialScrollApplied || self.searchResults)
		return;
	UITableView *table = self.tableView;
	if (table.dragging || table.tracking || table.decelerating)
		return;
	if (table.bounds.size.height < 1)
		return;
	if (table.contentOffset.y + table.contentInset.top != 0)
		return;
	CGFloat reachable = table.contentSize.height - table.bounds.size.height + table.contentInset.top + table.contentInset.bottom;
	if (reachable < kSearchBarHeight)
		return;
	self.initialScrollApplied = YES;
	table.contentOffset = CGPointMake(0, kSearchBarHeight - table.contentInset.top);
}

- (TGChatCell *)archiveHeaderRowWithWidth:(CGFloat)width top:(CGFloat)top count:(NSUInteger)__unused archivedCount {
	TGChatCell *row = [TGChatCell alloc];
	row = [row initWithStyle:UITableViewCellStyleDefault
			 reuseIdentifier:nil];
	row.frame = CGRectMake(0, top, width, kRowHeight);
	row.titleLabel.text = TGL(@"ChatList.ArchivedChatsTitle", @"Archived Chats");
	row.titleLabel.textColor = [[TGTheme shared] primaryTextColour];
	row.previewLabel.textColor = [[TGTheme shared] secondaryTextColour];
	NSDictionary *topArchivedChat = TGReplyArray([TGClient shared].archivedChats).firstObject;
	if (topArchivedChat)
		[self configurePreviewInCell:row chat:topArchivedChat plain:NO];
	NSInteger archiveUnread = [self.listUnread[@(TGChatListArchive)] integerValue];
	if (archiveUnread > 0) {
		row.badge.text = archiveUnread < 1000
			? [NSString stringWithFormat:@"%ld", (long)archiveUnread]
			: [NSString stringWithFormat:@"%ldK", (long)(archiveUnread / 1000)];
		row.badge.hidden = NO;
		row.badgeBackground.hidden = NO;
	}
	row.avatar.image = [TGIcons archiveAvatarOfSide:kAvatar];
	row.avatar.backgroundColor = [UIColor clearColor];
	row.backgroundColor = [[TGTheme shared] listBackgroundColour];
	row.userInteractionEnabled = YES;

	row.swipeActions = @[ @{@"kind" : @"archiveVisibility",
		@"title" : (TGArchiveHiddenByDefault() ? @"Unhide" : @"Hide")} ];
	__weak typeof(self) weakSelf = self;
	__weak TGChatCell *weakRow = row;
	row.onSwipeOpen = ^{
		[weakSelf closeOpenSwipeCellAnimated:YES];
		weakSelf.openSwipeCell = weakRow;
	};
	row.onSwipeAction = ^(NSString *__unused kind) {
		[weakSelf toggleArchiveHiddenByDefaultFromCell:weakRow];
	};

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(archiveRowTapped)];
	tap.cancelsTouchesInView = NO;
	[row addGestureRecognizer:tap];
	[row setNeedsLayout];
	[row layoutIfNeeded];
	return row;
}

- (void)archiveRowTapped {
	if (self.openSwipeCell) {
		[self closeOpenSwipeCellAnimated:YES];
		return;
	}
	[self openArchive];
}

- (UIView *)loginBannerWithWidth:(CGFloat)width top:(CGFloat)top {
	NSDictionary *session = self.unconfirmedSession;
	UIView *banner = [UIView alloc];
	banner = [banner initWithFrame:
			CGRectMake(0, top, width, kLoginBannerHeight)];
	banner.backgroundColor = [UIColor colorWithRed:0xFF / 255.0f green:0xF9 / 255.0f
											  blue:0xD8 / 255.0f
											 alpha:1.0f];

	NSString *device = TGReplyString(session[@"deviceModel"]) ?: TGReplyString(session[@"appName"]) ?: @"";
	NSString *location = TGReplyString(session[@"location"]) ?: TGReplyString(session[@"ip"]) ?: @"";

	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 7, width - 20, 18)];
	title.backgroundColor = [UIColor clearColor];
	title.font = [UIFont boldSystemFontOfSize:15];
	title.textColor = [UIColor colorWithRed:0x33 / 255.0f green:0x2C / 255.0f
									   blue:0x0A / 255.0f
									  alpha:1.0f];
	title.lineBreakMode = NSLineBreakByTruncatingTail;
	title.text = TGL(@"ChatList.SessionReview.PanelTitle", @"Someone just got access to your messages!");
	[banner addSubview:title];

	UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 25, width - 20, 15)];
	subtitle.backgroundColor = [UIColor clearColor];
	subtitle.font = [UIFont systemFontOfSize:12];
	subtitle.textColor = [UIColor colorWithRed:0x6B / 255.0f green:0x62 / 255.0f
										  blue:0x35 / 255.0f
										 alpha:1.0f];
	subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
	subtitle.text = [NSString stringWithFormat:TGL(@"ChatList.SessionReview.PanelText", @"We detected a new login to your account from %1$@, %2$@. Is it you?"),
		device, location];
	[banner addSubview:subtitle];

	CGFloat buttonWidth = (int)((width - 30) / 2);
	UIButton *mine = [self bannerButtonWithTitle:TGL(@"ChatList.SessionReview.PanelConfirm", @"It's Me")
										   frame:CGRectMake(10, 44, buttonWidth, 26)
										  action:@selector(confirmNewLogin)
									 destructive:NO];
	[banner addSubview:mine];
	CGRect notFrame = CGRectMake(width - 10 - buttonWidth, 44, buttonWidth, 26);
	UIButton *not= [self bannerButtonWithTitle:TGL(@"ChatList.SessionReview.PanelReject", @"Not Me")
										 frame:notFrame
										action:@selector(terminateNewLogin)
								   destructive:YES];
	[banner addSubview:not];

	UIView *hair = [UIView alloc];
	hair = [hair initWithFrame:
			CGRectMake(0, kLoginBannerHeight - 0.5f, width, 0.5f)];
	hair.backgroundColor = [[TGTheme shared] separatorColour];
	[banner addSubview:hair];
	return banner;
}

- (UIButton *)bannerButtonWithTitle:(NSString *)title
							  frame:(CGRect)frame
							 action:(SEL)action
						destructive:(BOOL)destructive {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = frame;
	button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	[button setTitle:title forState:UIControlStateNormal];
	UIImage *plate = TGSwipePlateImage(destructive, NO);
	UIImage *pressed = TGSwipePlateImage(destructive, YES);
	if (plate) {
		[button setBackgroundImage:plate forState:UIControlStateNormal];
		[button setBackgroundImage:(pressed ?: plate) forState:UIControlStateHighlighted];
	} else {
		button.backgroundColor = destructive
			? [UIColor colorWithRed:0xC4 / 255.0f green:0x2B / 255.0f
							   blue:0x1E / 255.0f
							  alpha:1.0f]
			: [UIColor colorWithRed:0x8E / 255.0f green:0x9C / 255.0f
							   blue:0xAE / 255.0f
							  alpha:1.0f];
		button.layer.cornerRadius = 4;
	}
	UIColor *plain = [UIColor colorWithRed:0x4a / 255.0f
									 green:0x65 / 255.0f
									  blue:0x87 / 255.0f
									 alpha:1.0f];
	[button setTitleColor:(destructive ? [UIColor whiteColor] : plain)
				 forState:UIControlStateNormal];
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (void)refreshUnconfirmedSession {
	if (self.showsArchive)
		return;
	static NSTimeInterval lastSweep = 0;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - lastSweep < 30.0)
		return;
	lastSweep = now;
	[self fetchUnconfirmedSession];
}

- (void)fetchUnconfirmedSession {
	if (self.showsArchive)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] unconfirmedSessionsWithCompletion:^(NSArray *sessions) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSDictionary *first = nil;
		for (id entry in (TGReplyArray(sessions) ?: @[])) {
			NSDictionary *session = TGReplyDictionary(entry);
			if ([session[@"id"] longLongValue]) {
				first = session;
				break;
			}
		}
		NSNumber *wasId = strongSelf.unconfirmedSession[@"id"];
		NSNumber *nowId = first[@"id"];
		BOOL changed = (wasId == nil) != (nowId == nil) ||
			(nowId != nil && ![nowId isEqualToNumber:wasId]);
		strongSelf.unconfirmedSession = first;
		if (changed)
			[strongSelf rebuildTableHeader];
	}];
}

- (void)confirmNewLogin {
	long long sessionId = [self.unconfirmedSession[@"id"] longLongValue];
	NSDictionary *previousSession = self.unconfirmedSession;
	self.unconfirmedSession = nil;
	[self rebuildTableHeader];
	if (!sessionId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] confirmSession:sessionId completion:^(BOOL ok) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		strongSelf.unconfirmedSession = previousSession;
		[strongSelf rebuildTableHeader];
		[TGSnackbar showInView:strongSelf.navigationController.view
						  text:TGL(@"Toast.CouldNotConfirmSession", @"Could not confirm this session")
					   seconds:2
					  onCommit:nil];
	}];
}

- (void)terminateNewLogin {
	long long sessionId = [self.unconfirmedSession[@"id"] longLongValue];
	NSDictionary *previousSession = self.unconfirmedSession;
	self.unconfirmedSession = nil;
	[self rebuildTableHeader];
	if (!sessionId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] terminateSession:sessionId completion:^(BOOL ok) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		strongSelf.unconfirmedSession = previousSession;
		[strongSelf rebuildTableHeader];
		[TGSnackbar showInView:strongSelf.navigationController.view
						  text:TGL(@"AuthSessions.TerminateSessionFailed", @"That session could not be terminated.")
					   seconds:2
					  onCommit:nil];
	}];
}

- (void)refreshFolderNewChats {
	if (self.showsArchive || self.folderId == 0) {
		if (self.folderNewChats.count) {
			self.folderNewChats = nil;
			self.folderNewChatsFolderId = 0;
			[self rebuildTableHeader];
		}
		return;
	}

	NSInteger folderId = self.folderId;
	static NSTimeInterval lastSweep = 0;
	static NSInteger lastFolder = 0;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (folderId == lastFolder && now - lastSweep < 30.0)
		return;
	lastSweep = now;
	lastFolder = folderId;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] newChatsInFolder:folderId completion:^(NSArray *reply) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.folderId != folderId)
			return;
		NSArray *rows = TGChatRows(reply);
		BOOL had = strongSelf.folderNewChats.count > 0 && strongSelf.folderNewChatsFolderId == folderId;
		strongSelf.folderNewChats = rows;
		strongSelf.folderNewChatsFolderId = folderId;
		if (had || rows.count)
			[strongSelf rebuildTableHeader];
	}];
}

- (UIView *)folderInviteBannerWithWidth:(CGFloat)width top:(CGFloat)top {
	NSInteger count = self.folderNewChats.count;
	UIView *banner = [UIView alloc];
	banner = [banner initWithFrame:
			CGRectMake(0, top, width, kFolderBannerHeight)];
	banner.backgroundColor = [UIColor colorWithRed:0xE8 / 255.0f green:0xF2 / 255.0f
											  blue:0xFD / 255.0f
											 alpha:1.0f];

	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, width - 20, 18)];
	title.backgroundColor = [UIColor clearColor];
	title.font = [UIFont boldSystemFontOfSize:15];
	title.textColor = [UIColor colorWithRed:0x14 / 255.0f green:0x2C / 255.0f
									   blue:0x4B / 255.0f
									  alpha:1.0f];
	title.lineBreakMode = NSLineBreakByTruncatingTail;
	title.text = TGLPlural(@"ChatList.PanelNewChatsAvailable", (NSInteger)count,
		@"1 New Chat Available", @"%lu New Chats Available");
	[banner addSubview:title];

	CGFloat buttonWidth = (int)((width - 30) / 2);
	UIButton *add = [self bannerButtonWithTitle:TGL(@"ChatList.AddChatsToFolder", @"Add Chats")
										  frame:CGRectMake(10, 28, buttonWidth, 26)
										 action:@selector(addNewFolderChats)
									destructive:NO];
	[banner addSubview:add];
	CGRect skipFrame = CGRectMake(width - 10 - buttonWidth, 28, buttonWidth, 26);
	UIButton *skip = [self bannerButtonWithTitle:TGL(@"MemberRequests.Dismiss", @"Dismiss")
										   frame:skipFrame
										  action:@selector(dismissNewFolderChats)
									 destructive:NO];
	[banner addSubview:skip];

	UIView *hair = [UIView alloc];
	hair = [hair initWithFrame:
			CGRectMake(0, kFolderBannerHeight - 0.5f, width, 0.5f)];
	hair.backgroundColor = [[TGTheme shared] separatorColour];
	[banner addSubview:hair];
	return banner;
}

- (void)addNewFolderChats {
	NSInteger folderId = self.folderNewChatsFolderId;
	NSArray *rows = self.folderNewChats;
	if (!folderId || !rows.count)
		return;

	NSMutableArray *ids = [NSMutableArray array];
	NSMutableDictionary *titles = [NSMutableDictionary dictionary];
	for (NSDictionary *chat in rows) {
		NSNumber *key = chat[@"id"];
		if (![key isKindOfClass:[NSNumber class]])
			continue;
		[ids addObject:key];
		NSString *name = TGReplyString(chat[@"title"]);
		if (name.length)
			titles[key] = name;
	}
	if (!ids.count)
		return;

	TGChatIdPickerViewController *picker = [[TGChatIdPickerViewController alloc] init];
	picker.title = TGL(@"BusinessMessageSetup.Recipients.CategoryNewChats", @"New Chats");
	picker.prompt = TGL(@"ChatListFolder.NewChatsPrompt", @"Chats the folder's owner has added");
	picker.confirmTitle = TGL(@"Channel.JoinChannel", @"Join");
	picker.chatIds = ids;
	picker.titles = titles;
	__weak typeof(self) weakSelf = self;
	picker.onConfirm = ^(NSArray *picked) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[[TGClient shared] addNewChats:(picked.count ? picked : nil) toFolder:folderId
							 completion:^(BOOL success, NSString *errorMessage) {
			TGChatListViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (!success) {
				[TGSnackbar showInView:innerSelf.navigationController.view
								  text:TGFriendlyErrorText(errorMessage,
										   TGL(@"Login.UnknownError",
											   @"An error occurred, please try again later."))
							   seconds:2
							  onCommit:nil];
				return;
			}
			innerSelf.folderNewChats = nil;
			[innerSelf rebuildTableHeader];
			[innerSelf reload];
		}];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)dismissNewFolderChats {
	NSInteger folderId = self.folderNewChatsFolderId;
	NSArray *dismissed = self.folderNewChats;
	self.folderNewChats = nil;
	[self rebuildTableHeader];
	if (!folderId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] addNewChats:nil
						  toFolder:folderId
						completion:^(BOOL ok, NSString *__unused errorMessage) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		strongSelf.folderNewChats = dismissed;
		[strongSelf rebuildTableHeader];
	}];
}

- (void)installBirthdayObserver {
	__weak typeof(self) weakSelf = self;
	self.birthdayObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGCloseBirthdaysDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					(void)note;
					[weakSelf handleCloseBirthdaysUpdate];
				}];
}

- (void)handleCloseBirthdaysUpdate {
	[self rebuildTableHeader];
}

- (NSArray *)todaysBirthdayUsers {
	NSMutableArray *today = [NSMutableArray array];
	for (NSDictionary *user in [TGClient shared].closeBirthdayUsers) {
		if (TGBirthdateIsToday(user[@"birthdate"]))
			[today addObject:user];
	}
	return today;
}

- (UIView *)birthdayBannerWithWidth:(CGFloat)width top:(CGFloat)top {
	NSArray *users = [self todaysBirthdayUsers];
	NSInteger count = users.count;
	UIView *banner = [UIView alloc];
	banner = [banner initWithFrame:
			CGRectMake(0, top, width, kBirthdayBannerHeight)];
	banner.backgroundColor = [UIColor colorWithRed:0xFF / 255.0f green:0xF3 / 255.0f
											 blue:0xE0 / 255.0f
											alpha:1.0f];

	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, width - 20, 24)];
	title.backgroundColor = [UIColor clearColor];
	title.font = [UIFont boldSystemFontOfSize:15];
	title.textColor = [UIColor colorWithRed:0x4D / 255.0f green:0x33 / 255.0f
									   blue:0x0A / 255.0f
									  alpha:1.0f];
	title.numberOfLines = 2;
	title.lineBreakMode = NSLineBreakByTruncatingTail;
	BOOL single = (count == 1);
	if (single) {
		int64_t userId = [[users.firstObject objectForKey:@"userId"] longLongValue];
		NSString *name = [[TGClient shared] nameForUserId:userId] ?: @"";
		title.text = [NSString stringWithFormat:
			TGL(@"ChatList.BirthdaySingleTitle", @"It's %@'s birthday today! 🎂"), name];
	} else {
		title.text = TGLPlural(@"ChatList.BirthdayMultipleTitle", (NSInteger)count,
			@"%d contact has a birthday today! 🎂", @"%d contacts have birthdays today! 🎂");
	}
	[banner addSubview:title];

	CGFloat buttonWidth = (int)((width - 30) / 2);
	if (single) {
		UIButton *open = [self bannerButtonWithTitle:TGL(@"Conversation.LinkDialogOpen", @"Open")
											   frame:CGRectMake(10, 32, buttonWidth, 26)
											  action:@selector(openBirthdayChat)
										 destructive:NO];
		[banner addSubview:open];
	}
	CGRect dismissFrame = single
		? CGRectMake(width - 10 - buttonWidth, 32, buttonWidth, 26)
		: CGRectMake(10, 32, width - 20, 26);
	UIButton *dismiss = [self bannerButtonWithTitle:TGL(@"MemberRequests.Dismiss", @"Dismiss")
											  frame:dismissFrame
											 action:@selector(dismissBirthdayBanner)
										destructive:NO];
	[banner addSubview:dismiss];

	UIView *hair = [UIView alloc];
	hair = [hair initWithFrame:
			CGRectMake(0, kBirthdayBannerHeight - 0.5f, width, 0.5f)];
	hair.backgroundColor = [[TGTheme shared] separatorColour];
	[banner addSubview:hair];
	return banner;
}

- (void)dismissBirthdayBanner {
	[[TGClient shared] hideContactCloseBirthdays];
	[self rebuildTableHeader];
}

- (void)openBirthdayChat {
	NSArray *users = [self todaysBirthdayUsers];
	if (users.count != 1)
		return;
	int64_t userId = [[users.firstObject objectForKey:@"userId"] longLongValue];
	if (!userId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf || !chatId)
			return;
		TGChatViewController *vc = [[TGChatViewController alloc] init];
		vc.chatId = chatId;
		vc.chatTitle = [[TGClient shared] nameForUserId:userId]
			?: TGL(@"ChatList.UnnamedChat", @"Chat");
		vc.group = NO;
		[strongSelf presentChatController:vc];
	}];
}

@end
