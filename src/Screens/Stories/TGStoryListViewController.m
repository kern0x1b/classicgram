#import "TGGroupedCaption.h"
#import "TGStoryListViewController.h"
#import "TGIcons.h"
#import "TGStoryPaging.h"
#import "TGStoriesViewController.h"
#import "TGLocalization.h"
#import "TGClient+Stories.h"
#import "TGClient+Contacts.h"
#import "TGClient+Notifications.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGTheme.h"
#import "RootViewController.h"
#import "TGStoryContactPicker.h"
#import "TGStoryHelpers.h"
#import "TGBusinessLocationPickerViewController.h"
#import "TGAccountManager.h"

#import <CoreLocation/CoreLocation.h>

@implementation TGStoryListViewController {
	UITableView *_tableView;
	NSMutableArray *_rows;
	NSMutableArray *_pinned;
	NSString *_nextOffset;
	NSInteger _fromStoryId;
	BOOL _loading;
	BOOL _loadFailed;
	BOOL _exhausted;
	NSUInteger _loadGeneration;
	NSInteger _archiveTotal;
	NSInteger _profileTotal;
	NSInteger _albumCount;
	NSInteger _closeFriendsCount;
	NSInteger _hiddenCount;
	NSInteger _exceptionCount;
}

+ (void)pushMode:(TGStoryListMode)mode
		  chatId:(int64_t)chatId
		   title:(NSString *)title
			from:(UIViewController *)host {
	TGStoryListViewController *list = [[TGStoryListViewController alloc] init];
	list.mode = mode;
	list.chatId = chatId;
	list.title = title;
	if ([RootViewController isSplitLayoutActive] && [RootViewController pushInDetail:list])
		return;
	if (host.navigationController == nil)
		return;
	[host.navigationController pushViewController:list animated:YES];
}

- (BOOL)isGrouped {
	return self.mode == TGStoryListMenu || self.mode == TGStoryListSettings;
}

- (BOOL)isStoryList {
	return self.mode == TGStoryListArchive || self.mode == TGStoryListProfile ||
		self.mode == TGStoryListAlbum || self.mode == TGStoryListTag ||
		self.mode == TGStoryListVenue || self.mode == TGStoryListLocation;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	_rows = [[NSMutableArray alloc] init];
	_pinned = [[NSMutableArray alloc] init];

	UITableViewStyle style = [self isGrouped]
		? UITableViewStyleGrouped
		: UITableViewStylePlain;
	_tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:style];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.rowHeight = 44.0f;
	_tableView.separatorColor = [[TGTheme shared] separatorColour];
	_tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[self.view addSubview:_tableView];

	if ([self isStoryList] || self.mode == TGStoryListAlbums) {
		UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self
					action:@selector(rowHeld:)];
		hold.minimumPressDuration = 0.5;
		[_tableView addGestureRecognizer:hold];
	}

	if (self.mode == TGStoryListAlbums) {
		self.navigationItem.rightBarButtonItem =
			[TGIcons headerBarButtonItemWithTitle:TGL(@"ChatList.ContextMenuBadgeNew", @"New")
											 bold:NO
										   target:self
										   action:@selector(createAlbumPressed)];
	}

	[self reload];
}

- (void)reload {
	_loadGeneration++;
	[_rows removeAllObjects];
	[_pinned removeAllObjects];
	_nextOffset = nil;
	_fromStoryId = 0;
	_loading = NO;
	_exhausted = NO;
	[_tableView reloadData];
	[self loadMore];
}

- (void)showMessage:(NSString *)message {
	[[[TGAlertView alloc] initWithTitle:nil
								message:message
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  okButtonTitle:nil
						completionBlock:nil] show];
}

#pragma mark - loading

- (void)loadMenuCounts {
	__weak TGStoryListViewController *weakSelf = self;
	_exhausted = YES;
	_loading = NO;
	int64_t chatId = self.chatId;
	[[TGClient shared] archivedStoriesInChat:chatId
								 fromStoryId:0
									   limit:1
								  completion:^(NSArray *stories, NSInteger total) {
									  (void)stories;
									  TGStoryListViewController *strongSelf = weakSelf;
									  if (strongSelf == nil)
										  return;
									  strongSelf->_archiveTotal = total;
									  [strongSelf->_tableView reloadData];
								  }];
	[[TGClient shared] profileStoriesInChat:chatId
								fromStoryId:0
									  limit:1
								 completion:^(NSArray *stories, NSArray *pinnedIds, NSInteger total) {
									 (void)stories;
									 (void)pinnedIds;
									 TGStoryListViewController *strongSelf = weakSelf;
									 if (strongSelf == nil)
										 return;
									 strongSelf->_profileTotal = total;
									 [strongSelf->_tableView reloadData];
								 }];
	[[TGClient shared] storyAlbumsInChat:chatId completion:^(NSArray *albums, BOOL failed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil || failed)
			return;
		strongSelf->_albumCount = (NSInteger)albums.count;
		[strongSelf->_tableView reloadData];
	}];
}

- (void)loadSettingsCounts {
	__weak TGStoryListViewController *weakSelf = self;
	_exhausted = YES;
	_loading = NO;
	[[TGClient shared] closeFriendsWithCompletion:^(NSArray *users, BOOL failed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil || failed)
			return;
		strongSelf->_closeFriendsCount = (NSInteger)users.count;
		[strongSelf->_tableView reloadData];
	}];
	[[TGClient shared] hiddenStoryPostersWithCompletion:^(NSArray *users) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf->_hiddenCount = (NSInteger)users.count;
		[strongSelf->_tableView reloadData];
	}];
	[[TGClient shared] storyNotificationExceptionsWithCompletion:^(NSArray *chats, BOOL failed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (failed)
			return;
		strongSelf->_exceptionCount = (NSInteger)chats.count;
		[strongSelf->_tableView reloadData];
	}];
}

- (void (^)(NSArray *stories, BOOL more))appendStoriesHandler {
	NSUInteger generation = _loadGeneration;
	__weak TGStoryListViewController *weakSelf = self;
	return ^(NSArray *stories, BOOL more) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf->_loadGeneration != generation)
			return;
		strongSelf->_loading = NO;
		if ([stories isKindOfClass:[NSArray class]] && stories.count > 0) {
			[strongSelf->_rows addObjectsFromArray:stories];
			NSDictionary *last = [stories objectAtIndex:stories.count - 1];
			strongSelf->_fromStoryId = TGStoryNumber(last, @"id");
		} else {
			more = NO;
		}
		strongSelf->_exhausted = !more;
		[strongSelf->_tableView reloadData];
	};
}

- (void)loadMore {
	if (_loading || _exhausted)
		return;
	_loading = YES;

	if (self.mode == TGStoryListMenu) {
		[self loadMenuCounts];
		return;
	}

	if (self.mode == TGStoryListSettings) {
		[self loadSettingsCounts];
		return;
	}

	void (^appendStories)(NSArray *, BOOL) = [self appendStoriesHandler];

	if (self.mode == TGStoryListArchive) {
		[self loadArchivePageAppending:appendStories];
		return;
	}

	if (self.mode == TGStoryListProfile) {
		[self loadProfilePageAppending:appendStories];
		return;
	}

	if (self.mode == TGStoryListAlbum) {
		[self loadAlbumPageAppending:appendStories];
		return;
	}

	if (self.mode == TGStoryListTag) {
		[self loadTagPageAppending:appendStories];
		return;
	}

	if (self.mode == TGStoryListVenue) {
		[self loadVenuePageAppending:appendStories];
		return;
	}

	if (self.mode == TGStoryListLocation) {
		[self loadLocationPageAppending:appendStories];
		return;
	}

	if (self.mode == TGStoryListForwards) {
		[self loadForwardsPage];
		return;
	}

	if (self.mode == TGStoryListAlbums) {
		[self loadAlbumList];
		return;
	}

	if (self.mode == TGStoryListHidden) {
		[self loadHiddenPosters];
		return;
	}

	if (self.mode == TGStoryListExceptions) {
		[self loadNotificationExceptions];
		return;
	}

	_loading = NO;
	_exhausted = YES;
}

- (void)loadArchivePageAppending:(void (^)(NSArray *stories, BOOL more))appendStories {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] archivedStoriesInChat:self.chatId
								 fromStoryId:_fromStoryId
									   limit:30
								  completion:^(NSArray *stories, NSInteger total) {
									  TGStoryListViewController *strongSelf = weakSelf;
									  BOOL more = strongSelf != nil &&
										  TGStoryPageHasMore(strongSelf->_rows.count, stories.count, total);
									  appendStories(stories, more);
								  }];
}

- (void)loadProfilePageAppending:(void (^)(NSArray *stories, BOOL more))appendStories {
	NSUInteger generation = _loadGeneration;
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] profileStoriesInChat:self.chatId
								fromStoryId:_fromStoryId
									  limit:30
								 completion:^(NSArray *stories, NSArray *pinnedIds, NSInteger total) {
									 TGStoryListViewController *strongSelf = weakSelf;
									 if (strongSelf != nil && strongSelf->_loadGeneration != generation)
										 return;
									 if (strongSelf != nil && [pinnedIds isKindOfClass:[NSArray class]]) {
										 [strongSelf->_pinned removeAllObjects];
										 [strongSelf->_pinned addObjectsFromArray:pinnedIds];
									 }
									 BOOL more = strongSelf != nil &&
										 TGStoryPageHasMore(strongSelf->_rows.count, stories.count, total);
									 appendStories(stories, more);
								 }];
}

- (void)loadAlbumPageAppending:(void (^)(NSArray *stories, BOOL more))appendStories {
	__weak TGStoryListViewController *weakSelf = self;
	NSInteger offset = (NSInteger)_rows.count;
	[[TGClient shared] storiesInAlbum:self.albumId
							   inChat:self.chatId
							   offset:offset
								limit:30
						   completion:^(NSArray *stories, NSInteger total) {
							   TGStoryListViewController *strongSelf = weakSelf;
							   BOOL more = strongSelf != nil &&
								   TGStoryPageHasMore(strongSelf->_rows.count, stories.count, total);
							   appendStories(stories, more);
						   }];
}

- (void)loadTagPageAppending:(void (^)(NSArray *stories, BOOL more))appendStories {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] searchStoriesWithTag:(self.tag ?: @"")
							   posterChatId:0
									 offset:_nextOffset
									  limit:20
								 completion:^(NSArray *stories, NSString *nextOffset, NSInteger total) {
									 (void)total;
									 TGStoryListViewController *strongSelf = weakSelf;
									 if (strongSelf == nil)
										 return;
									 strongSelf->_nextOffset = nextOffset;
									 appendStories(stories, nextOffset.length > 0);
								 }];
}

- (void)loadVenuePageAppending:(void (^)(NSArray *stories, BOOL more))appendStories {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] searchStoriesAtVenueProvider:(self.venueProvider ?: @"")
											venueId:(self.venueId ?: @"")
		offset:_nextOffset
											  limit:20
										 completion:^(NSArray *stories, NSString *nextOffset, NSInteger total) {
											 (void)total;
											 TGStoryListViewController *strongSelf = weakSelf;
											 if (strongSelf == nil)
												 return;
											 strongSelf->_nextOffset = nextOffset;
											 appendStories(stories, nextOffset.length > 0);
										 }];
}

- (void)loadLocationPageAppending:(void (^)(NSArray *stories, BOOL more))appendStories {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] searchStoriesAtCountryCode:(self.locationCountryCode ?: @"")
											state:(self.locationState ?: @"")
		city:(self.locationCity ?: @"")
		street:(self.locationStreet ?: @"")
		offset:_nextOffset
											limit:20
									   completion:^(NSArray *stories, NSString *nextOffset, NSInteger total) {
										   (void)total;
										   TGStoryListViewController *strongSelf = weakSelf;
										   if (strongSelf == nil)
											   return;
										   strongSelf->_nextOffset = nextOffset;
										   appendStories(stories, nextOffset.length > 0);
									   }];
}

- (void)loadForwardsPage {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] publicForwardsOfStory:self.storyId
									  inChat:self.chatId
									  offset:_nextOffset
									   limit:20
								  completion:^(NSArray *forwards, NSString *nextOffset) {
									  TGStoryListViewController *strongSelf = weakSelf;
									  if (strongSelf == nil)
										  return;
									  strongSelf->_loading = NO;
									  strongSelf->_nextOffset = nextOffset;
									  if ([forwards isKindOfClass:[NSArray class]])
										  [strongSelf->_rows addObjectsFromArray:forwards];
									  strongSelf->_exhausted = (nextOffset.length == 0 || forwards.count == 0);
									  [strongSelf->_tableView reloadData];
								  }];
}

- (void)loadAlbumList {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] storyAlbumsInChat:self.chatId completion:^(NSArray *albums, BOOL failed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf->_loading = NO;
		strongSelf->_exhausted = YES;
		strongSelf->_loadFailed = failed;
		if ([albums isKindOfClass:[NSArray class]])
			[strongSelf->_rows addObjectsFromArray:albums];
		[strongSelf->_tableView reloadData];
	}];
}

- (void)loadHiddenPosters {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] hiddenStoryPostersWithCompletion:^(NSArray *users) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf->_loading = NO;
		strongSelf->_exhausted = YES;
		if ([users isKindOfClass:[NSArray class]])
			[strongSelf->_rows addObjectsFromArray:users];
		[strongSelf->_tableView reloadData];
	}];
}

- (void)loadNotificationExceptions {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] storyNotificationExceptionsWithCompletion:^(NSArray *chats, BOOL failed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf->_loading = NO;
		strongSelf->_exhausted = YES;
		strongSelf->_loadFailed = failed;
		if (!failed && [chats isKindOfClass:[NSArray class]])
			[strongSelf->_rows addObjectsFromArray:chats];
		[strongSelf->_tableView reloadData];
	}];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	(void)tableView;
	if (self.mode == TGStoryListMenu)
		return 2;
	if (self.mode == TGStoryListSettings)
		return 3;
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	(void)tableView;
	if (self.mode == TGStoryListMenu)
		return section == 0 ? 4 : 1;
	if (self.mode == TGStoryListSettings)
		return 2;
	return (NSInteger)_rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	(void)tableView;
	if (self.mode != TGStoryListSettings)
		return nil;
	if (section == 0)
		return TGL(@"Notification.Exceptions.StoriesHeader", @"STORY NOTIFICATIONS");
	if (section == 1)
		return TGL(@"Stories.PreloadStories", @"Preload Stories");
	return TGL(@"PrivacySettings.PrivacyTitle", @"PRIVACY");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	(void)tableView;
	if (self.mode == TGStoryListSettings && section == 1)
		return TGL(@"Stories.PreloadStoriesFooter",
				   @"Fetching stories ahead of time uses more memory and data.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (NSString *)reactionSource {
	NSString *value = [[NSUserDefaults standardUserDefaults]
		stringForKey:[TGAccountManager defaultsKey:@"TGStoryReactionSource"]];
	return value.length > 0 ? value : @"all";
}

- (NSString *)reactionSourceTitle {
	NSString *source = [self reactionSource];
	if ([source isEqualToString:@"contacts"])
		return TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts");
	if ([source isEqualToString:@"none"])
		return TGL(@"PrivacySettings.LastSeenNobody", @"Nobody");
	return TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody");
}

- (BOOL)preloadOnNetwork:(NSString *)type {
	NSString *key = [TGAccountManager defaultsKey:[@"TGStoryPreload_" stringByAppendingString:type]];
	return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (NSString *)forwardTitleForRow:(NSDictionary *)row {
	NSString *title = TGStoryString(row, @"title");
	if (title.length > 0)
		return title;
	NSString *resolved = [[TGClient shared] titleForChatId:TGStoryChatId(row, @"chatId")];
	return resolved.length > 0 ? resolved : TGL(@"Contacts.UnknownName", @"Unknown");
}

- (NSString *)storySummary:(NSDictionary *)story {
	NSString *caption = TGStoryString(story, @"caption");
	if (caption.length > 0)
		return caption;
	NSString *kind = TGStoryString(story, @"kind");
	if ([kind isEqualToString:@"video"])
		return TGL(@"Message.Video", @"Video");
	if ([kind isEqualToString:@"live"])
		return TGL(@"Story.Camera.Live", @"Live");
	return TGL(@"Message.Photo", @"Photo");
}

- (UITableViewCell *)menuCellIn:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"menu"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"menu"];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.accessoryView = nil;
	cell.detailTextLabel.text = @"";

	if (indexPath.section == 1) {
		cell.textLabel.text = TGL(@"Stories.StorySettings", @"Story Settings");
		[[TGTheme shared] styleCell:cell];
		return cell;
	}

	if (indexPath.row == 0) {
		cell.textLabel.text = TGL(@"ChatList.Context.Archive", @"Archive");
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)_archiveTotal];
	} else if (indexPath.row == 1) {
		cell.textLabel.text = TGL(@"StoryList.TitleSaved", @"My Stories");
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)_profileTotal];
	} else if (indexPath.row == 2) {
		cell.textLabel.text = TGL(@"SearchImages.Title", @"Albums");
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)_albumCount];
	} else {
		cell.textLabel.text = TGL(@"Stories.SearchByLocation", @"Search Stories by Location");
	}
	[[TGTheme shared] styleCell:cell];
	return cell;
}

- (UITableViewCell *)settingsCellIn:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"setting"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"setting"];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.detailTextLabel.text = @"";
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;

	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = TGL(@"PeerInfo.AllowedReactions.Title", @"Reactions");
			cell.detailTextLabel.text = [self reactionSourceTitle];
		} else {
			cell.textLabel.text = TGL(@"Notifications.MessageNotificationsExceptions", @"Exceptions");
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)_exceptionCount];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	} else if (indexPath.section == 1) {
		NSString *type = indexPath.row == 0 ? @"mobile" : @"wifi";
		cell.textLabel.text = indexPath.row == 0 ? TGL(@"NetworkUsageSettings.Cellular", @"Cellular") : TGL(@"NetworkUsageSettings.Wifi", @"Wi-Fi");
		UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
		toggle.tag = indexPath.row == 0 ? 1 : 2;
		toggle.on = [self preloadOnNetwork:type];
		[toggle addTarget:self
					  action:@selector(preloadToggled:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	} else {
		if (indexPath.row == 0) {
			cell.textLabel.text = TGL(@"PrivacySettings.LastSeenCloseFriends", @"Close Friends");
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)_closeFriendsCount];
		} else {
			cell.textLabel.text = TGL(@"Story.Privacy.ExcludedPeople", @"Excluded People");
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)_hiddenCount];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	}

	[[TGTheme shared] styleCell:cell];
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.mode == TGStoryListMenu)
		return [self menuCellIn:tableView indexPath:indexPath];
	if (self.mode == TGStoryListSettings)
		return [self settingsCellIn:tableView indexPath:indexPath];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"row"];
	cell.accessoryType = UITableViewCellAccessoryNone;

	if (indexPath.row >= (NSInteger)_rows.count)
		return cell;
	NSDictionary *row = [_rows objectAtIndex:(NSUInteger)indexPath.row];

	if (self.mode == TGStoryListAlbums) {
		cell.textLabel.text = TGStoryString(row, @"name");
		cell.detailTextLabel.text = @"";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if (self.mode == TGStoryListHidden || self.mode == TGStoryListExceptions) {
		NSString *name = TGStoryString(row, @"name");
		if (name.length == 0)
			name = TGStoryString(row, @"title");
		cell.textLabel.text = name;
		cell.detailTextLabel.text = @"";
	} else if (self.mode == TGStoryListForwards) {
		cell.textLabel.text = [self forwardTitleForRow:row];
		cell.detailTextLabel.text = TGStoryAgeText((int)TGStoryNumber(row, @"date"));
		if (TGStoryFlag(row, @"isStory"))
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else {
		cell.textLabel.text = [self storySummary:row];
		NSString *age = TGStoryAgeText((int)TGStoryNumber(row, @"date"));
		BOOL isPinned = [_pinned containsObject:[NSNumber numberWithInteger:TGStoryNumber(row, @"id")]];
		cell.detailTextLabel.text = isPinned
			? [NSString stringWithFormat:TGL(@"Message.PinnedTextMessage", @"Pinned · %@"), age]
			: age;
	}

	[[TGTheme shared] styleCell:cell];

	if (indexPath.row + 5 >= (NSInteger)_rows.count)
		[self loadMore];
	return cell;
}

#pragma mark - selection

- (void)selectMenuRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1) {
		[TGStoryListViewController pushMode:TGStoryListSettings
									 chatId:self.chatId
									  title:TGL(@"Stories.StorySettings", @"Story Settings")
									   from:self];
		return;
	}
	if (indexPath.row == 0)
		[TGStoryListViewController pushMode:TGStoryListArchive
									 chatId:self.chatId
									  title:TGL(@"ChatList.Context.Archive", @"Archive")
									   from:self];
	else if (indexPath.row == 1)
		[TGStoryListViewController pushMode:TGStoryListProfile
									 chatId:self.chatId
									  title:TGL(@"StoryList.TitleSaved", @"My Stories")
									   from:self];
	else if (indexPath.row == 2)
		[TGStoryListViewController pushMode:TGStoryListAlbums
									 chatId:self.chatId
									  title:TGL(@"SearchImages.Title", @"Albums")
									   from:self];
	else
		[self promptSearchByLocation];
}

- (void)promptSearchByLocation {
	TGBusinessLocationPickerViewController *picker =
		[[TGBusinessLocationPickerViewController alloc] initWithHasPoint:NO latitude:0 longitude:0];
	__weak TGStoryListViewController *weakSelf = self;
	picker.onPicked = ^(double latitude, double longitude) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf resolveLocationSearchAtLatitude:latitude longitude:longitude];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)resolveLocationSearchAtLatitude:(double)latitude longitude:(double)longitude {
	CLGeocoder *geocoder = [[CLGeocoder alloc] init];
	CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
	__weak TGStoryListViewController *weakSelf = self;
	[geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.navigationController == nil)
			return;
		CLPlacemark *placemark = placemarks.count ? [placemarks objectAtIndex:0] : nil;
		if (error != nil || placemark == nil || !placemark.locality.length) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Chat.LocationIsNotAvailable", @"Location is not available.")
							seconds:3
						   onCommit:nil];
			return;
		}
		TGStoryListViewController *list = [[TGStoryListViewController alloc] init];
		list.mode = TGStoryListLocation;
		list.locationCountryCode = placemark.ISOcountryCode;
		list.locationState = placemark.administrativeArea;
		list.locationCity = placemark.locality;
		list.locationStreet = placemark.thoroughfare;
		list.title = placemark.locality;
		[strongSelf.navigationController pushViewController:list animated:YES];
	}];
}

- (void)selectSettingsRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0 && indexPath.row == 0) {
		[self askReactionSource];
		return;
	}
	if (indexPath.section == 0 && indexPath.row == 1) {
		[TGStoryListViewController pushMode:TGStoryListExceptions
									 chatId:self.chatId
									  title:TGL(@"Notifications.MessageNotificationsExceptions", @"Exceptions")
									   from:self];
		return;
	}
	if (indexPath.section == 2 && indexPath.row == 0) {
		[self editCloseFriends];
		return;
	}
	if (indexPath.section == 2 && indexPath.row == 1) {
		[TGStoryListViewController pushMode:TGStoryListHidden
									 chatId:self.chatId
									  title:TGL(@"Story.Privacy.ExcludedPeople", @"Excluded People")
									   from:self];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (self.mode == TGStoryListMenu) {
		[self selectMenuRowAtIndexPath:indexPath];
		return;
	}

	if (self.mode == TGStoryListSettings) {
		[self selectSettingsRowAtIndexPath:indexPath];
		return;
	}

	if (indexPath.row >= (NSInteger)_rows.count)
		return;
	NSDictionary *row = [_rows objectAtIndex:(NSUInteger)indexPath.row];

	if (self.mode == TGStoryListAlbums) {
		TGStoryListViewController *list = [[TGStoryListViewController alloc] init];
		list.mode = TGStoryListAlbum;
		list.chatId = self.chatId;
		list.albumId = TGStoryNumber(row, @"id");
		list.title = TGStoryString(row, @"name");
		[self.navigationController pushViewController:list animated:YES];
		return;
	}

	if (self.mode == TGStoryListHidden) {
		[self unhidePoster:row];
		return;
	}

	if (self.mode == TGStoryListExceptions) {
		[self askMutingForChat:row];
		return;
	}

	if (self.mode == TGStoryListForwards) {
		if (!TGStoryFlag(row, @"isStory"))
			return;
		[self openStory:TGStoryNumber(row, @"storyId")
				 inChat:TGStoryChatId(row, @"chatId")
				   name:[self forwardTitleForRow:row]];
		return;
	}

	[self openStory:TGStoryNumber(row, @"id")
			 inChat:(TGStoryChatId(row, @"chatId") != 0 ? TGStoryChatId(row, @"chatId") : self.chatId)
			   name:self.title];
}

- (void)openStory:(NSInteger)storyId inChat:(int64_t)chatId name:(NSString *)name {
	if (storyId == 0 || chatId == 0)
		return;
	NSArray *ids = [NSArray arrayWithObject:[NSNumber numberWithInteger:storyId]];
	TGStoriesViewController *viewer =
		[[TGStoriesViewController alloc] initWithChatId:chatId storyIds:ids startIndex:0];
	viewer.posterName = name;
	[self.navigationController pushViewController:viewer animated:YES];
}

#pragma mark - settings actions

- (void)preloadToggled:(UISwitch *)toggle {
	NSString *type = (toggle.tag == 1) ? @"mobile" : @"wifi";
	NSString *key = [TGAccountManager defaultsKey:[@"TGStoryPreload_" stringByAppendingString:type]];
	BOOL desired = toggle.on;
	[[NSUserDefaults standardUserDefaults] setBool:desired forKey:key];
	[[NSUserDefaults standardUserDefaults] synchronize];

	__weak TGStoryListViewController *weakSelf = self;
	__weak UISwitch *weakToggle = toggle;
	[[TGClient shared] setStoryPreloading:desired
								 onNetwork:type
								completion:^(BOOL ok) {
		if (ok)
			return;
		TGStoryListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[[NSUserDefaults standardUserDefaults] setBool:!desired forKey:key];
		[[NSUserDefaults standardUserDefaults] synchronize];
		weakToggle.on = !desired;
		[strongSelf showMessage:TGL(@"Toast.CouldNotChangeStoryPreload", @"Could not change story preload settings")];
	}];
}

- (void)askReactionSource {
	NSArray *titles = [NSArray arrayWithObjects:
			TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody"),
			TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts"),
			TGL(@"PrivacySettings.LastSeenNobody", @"Nobody"), nil];
	NSArray *values = [NSArray arrayWithObjects:@"all", @"contacts", @"none", nil];

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	for (NSString *title in titles)
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:title]];

	__weak TGStoryListViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Notifications.Reactions.SheetTitleStories", @"Reaction notifications from")
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 TGStoryListViewController *strongSelf = weakSelf;
						 if (strongSelf == nil)
							 return;
						 NSInteger index = [titles indexOfObject:action];
						 if (index == NSNotFound)
							 return;
						 NSString *source = [values objectAtIndex:index];
						 NSString *defaultsKey = [TGAccountManager defaultsKey:@"TGStoryReactionSource"];
						 NSString *previousSource = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey];
						 [[NSUserDefaults standardUserDefaults] setObject:source forKey:defaultsKey];
						 [[NSUserDefaults standardUserDefaults] synchronize];
						 [strongSelf->_tableView reloadData];
						 [[TGClient shared] setStoryReactionNotificationSource:source
																	 completion:^(BOOL ok) {
							 if (ok)
								 return;
							 TGStoryListViewController *innerSelf = weakSelf;
							 if (!innerSelf)
								 return;
							 [[NSUserDefaults standardUserDefaults] setObject:previousSource forKey:defaultsKey];
							 [[NSUserDefaults standardUserDefaults] synchronize];
							 [innerSelf->_tableView reloadData];
							 [innerSelf showMessage:TGL(@"Toast.CouldNotChangeReactionNotifications", @"Could not change reaction notification settings")];
						 }];
					 }
						  target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)editCloseFriends {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] closeFriendsWithCompletion:^(NSArray *users, BOOL failed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (failed) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotLoadCloseFriends", @"Could not read your Close Friends list")
						   seconds:2
						  onCommit:nil];
			return;
		}

		NSMutableArray *current = [[NSMutableArray alloc] init];
		for (NSDictionary *user in users) {
			if ([user isKindOfClass:[NSDictionary class]])
				[current addObject:[NSNumber numberWithLongLong:TGStoryChatId(user, @"id")]];
		}

		[TGStoryContactPicker presentFrom:strongSelf
									title:TGL(@"PrivacySettings.LastSeenCloseFriends", @"Close Friends")
							  preselected:current
								   picked:^(NSArray *userIds) {
									   TGStoryListViewController *innerSelf = weakSelf;
									   if (innerSelf == nil || userIds == nil)
										   return;
									   [[TGClient shared] setCloseFriends:userIds completion:^(BOOL ok) {
										   TGStoryListViewController *doneSelf = weakSelf;
										   if (doneSelf == nil)
											   return;
										   if (!ok) {
											   [TGSnackbar showInView:doneSelf.navigationController.view
																  text:TGL(@"Toast.CouldNotSaveCloseFriends", @"Could not save your Close Friends list")
															   seconds:2
															  onCommit:nil];
											   return;
										   }
										   doneSelf->_closeFriendsCount = (NSInteger)userIds.count;
										   [doneSelf->_tableView reloadData];
									   }];
								   }];
	}];
}

- (void)unhidePoster:(NSDictionary *)user {
	int64_t userId = TGStoryChatId(user, @"id");
	if (userId == 0)
		return;
	BOOL isChat = [user[@"isChat"] boolValue];
	NSString *name = TGStoryString(user, @"name");
	__weak TGStoryListViewController *weakSelf = self;
	[TGSnackbar showInView:self.navigationController.view
					  text:[NSString stringWithFormat:TGL(@"StoryFeed.TooltipUnarchive", @"Stories from %@ will now be shown in Chats."), name]
				   seconds:5
				  onCommit:^{
					  [[TGClient shared] setStorySender:userId
												 isChat:isChat
										  storiesHidden:NO
										   completion:^(BOOL ok) {
						  TGStoryListViewController *strongSelf = weakSelf;
						  if (!strongSelf)
							  return;
						  if (!ok) {
							  [strongSelf showMessage:TGL(@"Toast.CouldNotUnhideStories", @"Could not unhide this account's stories")];
							  return;
						  }
						  [strongSelf reload];
					  }];
				  }];
}

- (void)askMutingForChat:(NSDictionary *)chat {
	int64_t chatId = TGStoryChatId(chat, @"id");
	if (chatId == 0)
		return;

	NSArray *actions = [NSArray arrayWithObjects:
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"StoryFeed.ContextNotifyOff", @"Mute Stories") action:@"mute"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"StoryFeed.ContextNotifyOn", @"Unmute Stories") action:@"unmute"], nil];

	__weak TGStoryListViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGStoryString(chat, @"title")
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 [[TGClient shared] setChat:chatId storiesMuted:[action isEqualToString:@"mute"]];
						 [weakSelf reload];
					 }
						  target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

#pragma mark - albums

- (void)createAlbumPressed {
	__weak TGStoryListViewController *weakSelf = self;
	TGAlertView *alert = nil;
	__block __weak TGAlertView *weakAlert = nil;
	void (^created)(NSDictionary *) = ^(NSDictionary *album) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (![album isKindOfClass:[NSDictionary class]]) {
			[strongSelf showMessage:TGL(@"Stories.CouldNotCreateTheAlbum", @"Could not create the album")];
			return;
		}
		[strongSelf reload];
	};
	void (^entered)(bool) = ^(bool okButtonPressed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil || !okButtonPressed)
			return;
		NSString *name = nil;
		if ([weakAlert respondsToSelector:@selector(textFieldAtIndex:)])
			name = [weakAlert textFieldAtIndex:0].text;
		if (name.length == 0)
			return;
		NSArray *empty = [NSArray array];
		[[TGClient shared] createStoryAlbumInChat:strongSelf.chatId name:name storyIds:empty completion:created];
	};
	alert = [[TGAlertView alloc] initWithTitle:nil
									   message:TGL(@"Stories.CreateAlbum.Placeholder", @"Album name")
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
								 okButtonTitle:TGL(@"Common.Create", @"Create")
							   completionBlock:entered];
	weakAlert = alert;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert show];
}

- (void)renameAlbum:(NSDictionary *)album {
	NSInteger albumId = TGStoryNumber(album, @"id");
	__weak TGStoryListViewController *weakSelf = self;
	TGAlertView *alert = nil;
	__block __weak TGAlertView *weakAlert = nil;
	void (^renamed)(NSDictionary *) = ^(NSDictionary *updated) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (![updated isKindOfClass:[NSDictionary class]]) {
			[strongSelf showMessage:TGL(@"Stories.CouldNotRenameTheAlbum", @"Could not rename the album")];
			return;
		}
		[strongSelf reload];
	};
	void (^entered)(bool) = ^(bool okButtonPressed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil || !okButtonPressed)
			return;
		NSString *name = nil;
		if ([weakAlert respondsToSelector:@selector(textFieldAtIndex:)])
			name = [weakAlert textFieldAtIndex:0].text;
		if (name.length == 0)
			return;
		[[TGClient shared] renameStoryAlbum:albumId inChat:strongSelf.chatId name:name completion:renamed];
	};
	alert = [[TGAlertView alloc] initWithTitle:nil
									   message:TGL(@"Stories.CreateAlbum.Placeholder", @"Album name")
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
								 okButtonTitle:TGL(@"Conversation.LinkDialogSave", @"Save")
							   completionBlock:entered];
	weakAlert = alert;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].text = TGStoryString(album, @"name");
	}
	[alert show];
}

- (void)deleteAlbum:(NSDictionary *)album {
	NSInteger albumId = TGStoryNumber(album, @"id");
	int64_t chatId = self.chatId;
	__weak TGStoryListViewController *weakSelf = self;
	[[[TGAlertView alloc] initWithTitle:nil
								message:[NSString stringWithFormat:
										TGL(@"Stories.DeleteAlbum.Confirmation", @"Delete %@?"),
										TGStoryString(album, @"name") ?: @""]
					  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
						  okButtonTitle:TGL(@"Common.Delete", @"Delete")
						completionBlock:^(bool okButtonPressed) {
							if (!okButtonPressed)
								return;
							[[TGClient shared] deleteStoryAlbum:albumId
														  inChat:chatId
													  completion:^(BOOL ok) {
								TGStoryListViewController *strongSelf = weakSelf;
								if (!strongSelf)
									return;
								if (!ok)
									[strongSelf showMessage:TGL(@"Stories.CouldNotDeleteTheAlbum", @"Could not delete the album")];
								[strongSelf reload];
							}];
						}] show];
}

- (void)moveAlbumUp:(NSUInteger)index {
	if (index == 0 || index >= _rows.count)
		return;
	NSMutableArray *ordered = [_rows mutableCopy];
	id album = [ordered objectAtIndex:index];
	[ordered removeObjectAtIndex:index];
	[ordered insertObject:album atIndex:index - 1];

	NSMutableArray *ids = [[NSMutableArray alloc] init];
	for (NSDictionary *entry in ordered)
		[ids addObject:[NSNumber numberWithInteger:TGStoryNumber(entry, @"id")]];

	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] reorderStoryAlbums:ids
									inChat:self.chatId
								completion:^(BOOL ok) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showMessage:TGL(@"Stories.CouldNotReorderTheAlbum", @"Could not reorder the album")];
			[strongSelf reload];
			return;
		}
		[strongSelf->_rows removeAllObjects];
		[strongSelf->_rows addObjectsFromArray:ordered];
		[strongSelf->_tableView reloadData];
	}];
}

- (void)moveStoryUp:(NSUInteger)index {
	if (index == 0 || index >= _rows.count)
		return;
	NSMutableArray *ordered = [_rows mutableCopy];
	id story = [ordered objectAtIndex:index];
	[ordered removeObjectAtIndex:index];
	[ordered insertObject:story atIndex:index - 1];

	NSMutableArray *ids = [[NSMutableArray alloc] init];
	for (NSDictionary *entry in ordered)
		[ids addObject:[NSNumber numberWithInteger:TGStoryNumber(entry, @"id")]];

	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] reorderStories:ids
							  inAlbum:self.albumId
							   inChat:self.chatId
						   completion:^(NSDictionary *album) {
							   TGStoryListViewController *strongSelf = weakSelf;
							   if (strongSelf == nil)
								   return;
							   if (![album isKindOfClass:[NSDictionary class]]) {
								   [strongSelf showMessage:TGL(@"Stories.CouldNotReorderTheAlbum",
															   @"Could not reorder the album")];
								   [strongSelf reload];
								   return;
							   }
							   [strongSelf->_rows removeAllObjects];
							   [strongSelf->_rows addObjectsFromArray:ordered];
							   [strongSelf->_tableView reloadData];
						   }];
}

- (void)addStoryToAlbum:(NSInteger)storyId {
	int64_t chatId = self.chatId;
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] storyAlbumsInChat:chatId completion:^(NSArray *albums, BOOL failed) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (failed) {
			[strongSelf showMessage:TGL(@"Stories.AlbumsLoadFailed", @"The albums could not be read")];
			return;
		}
		if (![albums isKindOfClass:[NSArray class]] || albums.count == 0) {
			[strongSelf showMessage:TGL(@"Stories.NoAlbumsYet", @"No albums yet")];
			return;
		}

		[strongSelf presentAlbumChooser:albums forStoryId:storyId inChat:chatId];
	}];
}

- (void)presentAlbumChooser:(NSArray *)albums
				 forStoryId:(NSInteger)storyId
					 inChat:(int64_t)chatId {
	NSMutableArray *actions = [[NSMutableArray alloc] init];
	NSMutableDictionary *byTitle = [[NSMutableDictionary alloc] init];
	for (NSDictionary *album in albums) {
		if (![album isKindOfClass:[NSDictionary class]])
			continue;
		NSString *name = TGStoryString(album, @"name");
		if (name.length == 0)
			continue;
		[byTitle setObject:[NSNumber numberWithInteger:TGStoryNumber(album, @"id")] forKey:name];
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:name action:name]];
	}
	if (actions.count == 0) {
		[self showMessage:TGL(@"Stories.NoAlbumsYet", @"No albums yet")];
		return;
	}

	__weak TGStoryListViewController *weakSelf = self;
	void (^added)(NSDictionary *) = ^(NSDictionary *album) {
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		BOOL ok = [album isKindOfClass:[NSDictionary class]];
		[strongSelf showMessage:ok ? TGLPlural(@"Stories.ToastAddedToFolder", 1,
											@"Story added to folder.", @"%@ stories added to folder.")
							 : TGL(@"Stories.CouldNotAddToTheAlbum", @"Could not add to the album")];
	};
	void (^chosen)(id, NSString *) = ^(id target, NSString *action) {
		(void)target;
		TGStoryListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		NSNumber *albumId = [byTitle objectForKey:action];
		if (albumId == nil)
			return;
		NSArray *ids = [NSArray arrayWithObject:[NSNumber numberWithInteger:storyId]];
		[[TGClient shared] addStories:ids toAlbum:[albumId integerValue] inChat:chatId completion:added];
	};
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Stories.MenuAddToAlbum", @"Add to album")
						 actions:actions
					 actionBlock:chosen
						  target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)removeStoryFromAlbum:(NSInteger)storyId {
	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] removeStories:[NSArray arrayWithObject:[NSNumber numberWithInteger:storyId]]
						   fromAlbum:self.albumId
							  inChat:self.chatId
						  completion:^(NSDictionary *album) {
							  TGStoryListViewController *strongSelf = weakSelf;
							  if (strongSelf == nil)
								  return;
							  if (![album isKindOfClass:[NSDictionary class]]) {
								  [strongSelf showMessage:TGL(@"Stories.CouldNotRemoveTheStory",
															  @"Could not remove the story")];
								  return;
							  }
							  [strongSelf reload];
						  }];
}

- (void)togglePinnedForStory:(NSInteger)storyId {
	NSNumber *key = [NSNumber numberWithInteger:storyId];
	NSMutableArray *ids = [_pinned mutableCopy];
	if ([ids containsObject:key])
		[ids removeObject:key];
	else
		[ids insertObject:key atIndex:0];

	NSArray *previousPinned = [_pinned copy];
	[_pinned removeAllObjects];
	[_pinned addObjectsFromArray:ids];
	[_tableView reloadData];

	__weak TGStoryListViewController *weakSelf = self;
	[[TGClient shared] setPinnedStories:ids
								  inChat:self.chatId
							  completion:^(BOOL ok) {
		if (ok)
			return;
		TGStoryListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf->_pinned removeAllObjects];
		[strongSelf->_pinned addObjectsFromArray:previousPinned];
		[strongSelf->_tableView reloadData];
		[strongSelf showMessage:TGL(@"Stories.CouldNotPinTheStory", @"Could not pin the story")];
	}];
}

#pragma mark - long press

- (NSMutableArray *)heldRowActionsForStory:(NSDictionary *)row {
	NSMutableArray *actions = [[NSMutableArray alloc] init];
	NSInteger storyId = TGStoryNumber(row, @"id");
	BOOL canAddToAlbum = TGStoryFlag(row, @"canAddToAlbum");

	if (self.mode == TGStoryListProfile) {
		BOOL isPinned = [_pinned containsObject:[NSNumber numberWithInteger:storyId]];
		NSString *pinTitle = isPinned ? TGL(@"ChatList.Context.Unpin", @"Unpin") : TGL(@"StoryList.ItemAction.Pin", @"Pin");
		TGActionSheetAction *sheetAction = [[TGActionSheetAction alloc] initWithTitle:pinTitle action:@"pin"];
		[actions addObject:sheetAction];
		if (canAddToAlbum) {
			sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Stories.MenuAddToAlbum", @"Add to album") action:@"album"];
			[actions addObject:sheetAction];
		}
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Story.Context.RemoveFromProfile", @"Remove from Profile") action:@"unprofile" type:TGActionSheetActionTypeDestructive];
		[actions addObject:sheetAction];
	} else if (self.mode == TGStoryListArchive) {
		TGActionSheetAction *sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"StoryList.SaveToProfile", @"Save to Profile") action:@"profile"];
		[actions addObject:sheetAction];
		if (canAddToAlbum) {
			sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Stories.MenuAddToAlbum", @"Add to album") action:@"album"];
			[actions addObject:sheetAction];
		}
	} else if (self.mode == TGStoryListAlbum) {
		TGActionSheetAction *sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Conversation.MessageOptionsLinkMoveUp", @"Move Up") action:@"up"];
		[actions addObject:sheetAction];
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Stories.MenuRemoveFromAlbum", @"Remove from Album") action:@"remove" type:TGActionSheetActionTypeDestructive];
		[actions addObject:sheetAction];
	} else if (self.mode == TGStoryListAlbums) {
		TGActionSheetAction *sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"PeerInfo.Gifts.RenameCollection", @"Rename") action:@"rename"];
		[actions addObject:sheetAction];
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Conversation.MessageOptionsLinkMoveUp", @"Move Up") action:@"albumup"];
		[actions addObject:sheetAction];
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Stories.MenuDeleteAlbum", @"Delete Album") action:@"deletealbum" type:TGActionSheetActionTypeDestructive];
		[actions addObject:sheetAction];
	}

	return actions;
}

- (void)rowHeld:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateBegan)
		return;

	CGPoint point = [recognizer locationInView:_tableView];
	NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:point];
	if (indexPath == nil || indexPath.row >= (NSInteger)_rows.count)
		return;

	NSInteger index = (NSUInteger)indexPath.row;
	NSDictionary *row = [_rows objectAtIndex:index];
	NSInteger storyId = TGStoryNumber(row, @"id");

	NSArray *actions = [self heldRowActionsForStory:row];

	if (actions.count == 0)
		return;

	__weak TGStoryListViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:nil
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 TGStoryListViewController *strongSelf = weakSelf;
						 if (strongSelf == nil)
							 return;

						 if ([action isEqualToString:@"pin"])
							 [strongSelf togglePinnedForStory:storyId];
						 else if ([action isEqualToString:@"album"])
							 [strongSelf addStoryToAlbum:storyId];
						 else if ([action isEqualToString:@"unprofile"]) {
							 [[TGClient shared] setStory:storyId
												   inChat:strongSelf.chatId
												onProfile:NO
											   completion:^(BOOL ok) {
								 TGStoryListViewController *innerSelf = weakSelf;
								 if (!innerSelf)
									 return;
								 if (!ok) {
									 [innerSelf showMessage:TGL(@"Toast.CouldNotRemoveStoryFromProfile",
																@"Could not remove the story from your profile")];
									 return;
								 }
								 [innerSelf reload];
							 }];
						 } else if ([action isEqualToString:@"profile"]) {
							 [[TGClient shared] setStory:storyId
												   inChat:strongSelf.chatId
												onProfile:YES
											   completion:^(BOOL ok) {
								 TGStoryListViewController *innerSelf = weakSelf;
								 if (!innerSelf)
									 return;
								 if (!ok) {
									 [innerSelf showMessage:TGL(@"Toast.CouldNotSaveStoryToProfile",
																@"Could not save the story to your profile")];
									 return;
								 }
								 [innerSelf showMessage:TGL(@"Story.ToastSavedToProfileTitle",
														 @"Story saved to your profile")];
							 }];
						 } else if ([action isEqualToString:@"up"])
							 [strongSelf moveStoryUp:index];
						 else if ([action isEqualToString:@"remove"])
							 [strongSelf removeStoryFromAlbum:storyId];
						 else if ([action isEqualToString:@"rename"])
							 [strongSelf renameAlbum:row];
						 else if ([action isEqualToString:@"albumup"])
							 [strongSelf moveAlbumUp:index];
						 else if ([action isEqualToString:@"deletealbum"])
							 [strongSelf deleteAlbum:row];
					 }
						  target:self];
	[sheet tg_showFromRect:[_tableView cellForRowAtIndexPath:indexPath].frame inView:_tableView];
}

@end
