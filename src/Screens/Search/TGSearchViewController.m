#import "TGClient+Contacts.h"
#import "TGClient+ChatState.h"
#import "AppDelegate.h"
#import "TGImageDecode.h"
#import "TGSearchViewController.h"
#import "TGSearchViewControllerInternal.h"
#import "TGSearchCalendarViewController.h"
#import "TGSearchResultCell.h"
#import "TGSearchMessageCell.h"
#import "TGClient+Search.h"
#import "TGClient+ChatList.h"
#import "TGClient+WebLinks.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+SafeTint.h"

NSString *const kSearchRecentsKey = @"TGSearchRecentPeers";
const NSUInteger kSearchRecentsLimit = 12;

const NSInteger kSheetRowActions = 0;
const NSInteger kSheetSender = 4;

@implementation TGSearchViewController

@dynamic contacts;

- (NSArray *)contacts {
	return _contacts;
}

+ (NSArray *)chatTypeTitles {
	return @[ TGL(@"HashtagSearch.AllChats", @"All Chats"),
		TGL(@"ChatSettings.PrivateChats", @"Private Chats"),
		TGL(@"ChatSettings.Groups", @"Groups"),
		TGL(@"AutoDownloadSettings.Channels", @"Channels") ];
}

+ (NSString *)chatTypeForIndex:(NSInteger)index {
	switch (index) {
		case 1:
			return @"private";
		case 2:
			return @"group";
		case 3:
			return @"channel";
		default:
			return nil;
	}
}

+ (NSArray *)scopeTitles {
	return @[ TGL(@"ChatList.Tabs.All", @"All"),
		TGL(@"PeerInfo.PaneMedia", @"Media"),
		TGL(@"PeerInfo.PaneLinks", @"Links"),
		TGL(@"PeerInfo.PaneFiles", @"Files"),
		TGL(@"Cache.Music", @"Music"),
		TGL(@"PeerInfo.PaneVoiceAndVideo", @"Voice") ];
}

+ (NSString *)filterForScope:(NSInteger)scope {
	switch (scope) {
		case 1:
			return @"searchMessagesFilterPhotoAndVideo";
		case 2:
			return @"searchMessagesFilterUrl";
		case 3:
			return @"searchMessagesFilterDocument";
		case 4:
			return @"searchMessagesFilterAudio";
		case 5:
			return @"searchMessagesFilterVoiceAndVideoNote";
		default:
			return nil;
	}
}

+ (BOOL)isTagQuery:(NSString *)query {
	return query.length > 1 &&
		([query hasPrefix:@"#"] || [query hasPrefix:@"$"]);
}

+ (UIImage *)transparentBarBackground {
	static UIImage *image = nil;
	if (!image) {
		UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0);
		image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	}
	return image;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.chatHits = @[];
	self.contactHits = @[];
	self.globalHits = @[];
	self.messageHits = @[];
	self.contacts = @[];
	self.sections = @[];
	_resultsPresenter = [[TGSearchResultsPresenter alloc] init];
	_resultsRowBridge = [[TGSearchResultsRowBridge alloc] initWithPresenter:_resultsPresenter];
	_resultsRowBridge.delegate = self;
	self.hashtagHits = @[];
	self.recentTags = @[];
	self.remoteRecents = @[];
	self.topPeers = @[];
	self.tmeLinks = @[];
	self.senderCandidates = @[];
	self.liveLocations = @[];
	self.recentMatches = @[];
	_query = @"";
	_scope = 0;
	_messagesOffset = @"";
	_messagesFromId = 0;
	[self loadRecents];
	self.avatars = [NSMutableDictionary dictionary];
	self.avatarsRequested = [NSMutableSet set];
	self.tableView.rowHeight = kSearchRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	if (self.tableView.tableFooterView == nil)
		self.tableView.tableFooterView = [[UIView alloc] init];

	if ([self.tableView respondsToSelector:@selector(setKeyboardDismissMode:)])
		self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

	CGFloat barWidth = self.view.bounds.size.width;
	if (barWidth < 1)
		barWidth = [UIScreen mainScreen].applicationFrame.size.width;
	self.bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, barWidth, 44)];
	self.bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.bar.delegate = self;
	self.bar.placeholder = TGL(@"Common.Search", @"Search");
	self.bar.barStyle = UIBarStyleDefault;
	[self.bar tg_setTintColor:[[TGTheme shared] accentColour]];
	if ([self.bar respondsToSelector:@selector(setBackgroundImage:)])
		[self.bar setBackgroundImage:[[self class] transparentBarBackground]];
	self.navigationItem.titleView = self.bar;
	self.navigationItem.hidesBackButton = YES;
	UIButton *cancel = [TGIcons headerButtonWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
											   target:self
											   action:@selector(cancel)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancel];

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	_statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
	_statusLabel.backgroundColor = [UIColor clearColor];
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.font = [UIFont systemFontOfSize:15];
	_statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_statusLabel.hidden = YES;
	[self.view addSubview:_statusLabel];

	[self buildScopeBar];

	UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handleLongPress:)];
	press.minimumPressDuration = 0.5;
	[self.tableView addGestureRecognizer:press];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] contactsWithCompletion:^(NSArray *users) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.contacts = users ?: @[];
		[strongSelf runLocalSearch];
	}];

	[[TGClient shared] recentlyFoundChatsWithQuery:@"" limit:12 completion:^(NSArray *chats) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.remoteRecents = chats ?: @[];
		if (![strongSelf hasActiveQuery])
			[strongSelf rebuildSections];
	}];

	[[TGClient shared] topChatsWithCompletion:^(NSArray *chats) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.topPeers = [strongSelf peerRowsFromChats:chats];
		if (![strongSelf hasActiveQuery])
			[strongSelf rebuildSections];
	}];

	[[TGClient shared] recentlyVisitedTMeUrlsWithReferrer:nil completion:^(NSArray *urls) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.tmeLinks = [strongSelf linkRowsFromUrls:urls];
		if (![strongSelf hasActiveQuery])
			[strongSelf rebuildSections];
	}];

	[self reloadRecentTags];

	[self rebuildSections];
	if (self.presetQuery.length) {
		self.bar.text = self.presetQuery;
		[self searchBar:self.bar textDidChange:self.presetQuery];
	} else {
		[self.bar becomeFirstResponder];
	}
}

- (void)reloadRecentTags {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchedForTagsWithPrefix:@"" limit:12 completion:^(NSArray *tags) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.recentTags = tags ?: @[];
		if (![strongSelf hasActiveQuery])
			[strongSelf rebuildSections];
	}];
}

- (BOOL)hasActiveQuery {
	return _query.length != 0 || _tagEmoji.length != 0 || _tagCustomEmojiId != 0 ||
		_senderUserId != 0 || _dateAnchored || [self scopeRunsWithoutQuery];
}

- (BOOL)scopeRunsWithoutQuery {
	if (_scopedChatId)
		return NO;
	return _scope != 0;
}

- (NSArray *)peerRowsFromChats:(NSArray *)chats {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *chat in chats) {
		if (![chat isKindOfClass:NSDictionary.class])
			continue;
		int64_t chatId = [chat[@"id"] longLongValue];
		NSString *title = [chat[@"title"] isKindOfClass:NSString.class] ? chat[@"title"] : @"";
		if (!chatId || !title.length)
			continue;
		[rows addObject:@{@"title" : title,
			@"chatId" : @(chatId),
			@"isGroup" : @([chat[@"isGroup"] boolValue]),
			@"isTopPeer" : @YES,
			@"fileId" : ([chat[@"photoFileId"] isKindOfClass:NSNumber.class]
					? chat[@"photoFileId"]
					: ([[TGClient shared] photoFileIdForChat:chatId]
							  ?: [NSNull null]))}];
		if (rows.count >= 10)
			break;
	}
	return rows;
}

- (NSString *)usernameFromTMeUrl:(NSString *)url {
	if (!url.length)
		return nil;
	NSRange marker = [url rangeOfString:@"t.me/" options:NSBackwardsSearch];
	if (marker.location == NSNotFound)
		return nil;
	NSString *tail = [url substringFromIndex:marker.location + marker.length];
	NSRange slash = [tail rangeOfString:@"/"];
	if (slash.location != NSNotFound)
		tail = [tail substringToIndex:slash.location];
	NSRange question = [tail rangeOfString:@"?"];
	if (question.location != NSNotFound)
		tail = [tail substringToIndex:question.location];
	if ([tail hasPrefix:@"+"] || [tail hasPrefix:@"joinchat"])
		return nil;
	return tail.length ? tail : nil;
}

- (NSArray *)linkRowsFromUrls:(NSArray *)urls {
	NSMutableArray *rows = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for (NSDictionary *entry in urls) {
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSString *url = [entry[@"url"] isKindOfClass:NSString.class] ? entry[@"url"] : @"";
		if (!url.length || [seen containsObject:url])
			continue;
		NSString *kind = [entry[@"kind"] isKindOfClass:NSString.class] ? entry[@"kind"] : @"";
		if ([kind isEqualToString:@"stickerSet"])
			continue;
		NSString *username = [self usernameFromTMeUrl:url];
		NSString *title = [entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"";
		if (!title.length)
			title = username.length ? [@"@" stringByAppendingString:username] : url;

		NSString *subtitle = @"";
		NSInteger members = [entry[@"memberCount"] integerValue];
		if (members > 0)
			subtitle = TGLPlural(@"Conversation.StatusMembers", members, @"1 member", @"%@ members");
		else if (username.length && ![title isEqualToString:[@"@" stringByAppendingString:username]])
			subtitle = [@"@" stringByAppendingString:username];

		[seen addObject:url];
		[rows addObject:@{@"title" : title,
			@"subtitle" : subtitle,
			@"tmeUrl" : url,
			@"username" : (username ?: @""),
			@"userId" : (entry[@"userId"] ?: @0),
			@"chatId" : (entry[@"chatId"] ?: @0),
			@"isGroup" : @([kind isEqualToString:@"supergroup"] ||
				[kind isEqualToString:@"chatInvite"]),
			@"fileId" : ([entry[@"photoFileId"] isKindOfClass:NSNumber.class]
					? entry[@"photoFileId"]
					: [NSNull null])}];
		if (rows.count >= 6)
			break;
	}
	return rows;
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutScopeBar];
}

@end
