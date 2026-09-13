#import "TGGroupedCaption.h"
#import "TGClient+Contacts.h"
#import "TGIcons.h"
#import "TGStoryViewersViewController.h"
#import "TGLocalization.h"
#import "TGClient+Stories.h"
#import "TGTheme.h"
#import "TGStoryViewersFooter.h"
#import "TGStoryHelpers.h"
#import "TGStoryViewersPresenter.h"
#import "TGStoryViewersRowBridge.h"
#import "TGActionSheet.h"
#import "TGProfileViewController.h"

@implementation TGStoryViewersViewController {
	UITableView *_tableView;
	NSMutableArray *_rows;
	NSString *_nextOffset;
	BOOL _loading;
	BOOL _loaded;
	BOOL _loadFailed;
	BOOL _exhausted;
	NSInteger _loadGeneration;
	TGStoryViewersPresenter *_presenter;
	TGStoryViewersRowBridge *_rowBridge;
	TGStoryViewerSortMode _sortMode;
}

- (BOOL)isChannelInteractions {
	return _chatId != 0 && [[TGClient shared] me] != nil &&
		_chatId != TGStoryChatId([[TGClient shared] me], @"id");
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Story.ViewList.TitleViewers", @"Viewers");
	_sortMode = [self isChannelInteractions] ? TGStoryViewerSortRecent : TGStoryViewerSortReactions;
	_rows = [[NSMutableArray alloc] init];
	_presenter = [[TGStoryViewersPresenter alloc] init];
	_rowBridge = [[TGStoryViewersRowBridge alloc] initWithPresenter:_presenter];
	_tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
	_tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.rowHeight = 44.0f;
	_tableView.separatorColor = [[TGTheme shared] separatorColour];
	_tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[self.view addSubview:_tableView];
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Contacts.Sort", @"Sort") bold:NO
									   target:self
									   action:@selector(sortPressed)];
	[self loadMore];
}

- (void)sortPressed {
	BOOL channel = [self isChannelInteractions];
	NSString *primaryTitle = channel
		? TGL(@"Story.ViewList.ContextSortReposts", @"Reposts First")
		: TGL(@"Story.ViewList.ContextSortReactions", @"Reactions First");
	TGStoryViewerSortMode primaryMode = channel ? TGStoryViewerSortReposts : TGStoryViewerSortReactions;
	NSString *recentTitle = TGL(@"Story.ViewList.ContextSortRecent", @"Recent First");
	NSString *infoTitle = channel
		? TGL(@"Story.ViewList.ContextSortChannelInfo", @"Choose the order for the list of reactions.")
		: TGL(@"Story.ViewList.ContextSortInfo", @"Choose the order for the list of viewers.");

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	[actions addObject:[[TGActionSheetAction alloc]
			initWithTitle:_sortMode == primaryMode ? [@"✓ " stringByAppendingString:primaryTitle] : primaryTitle
				   action:@"primary"]];
	[actions addObject:[[TGActionSheetAction alloc]
			initWithTitle:_sortMode == TGStoryViewerSortRecent ? [@"✓ " stringByAppendingString:recentTitle] : recentTitle
				   action:@"recent"]];

	__weak TGStoryViewersViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:infoTitle
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 TGStoryViewersViewController *strongSelf = weakSelf;
						 if (strongSelf == nil)
							 return;
						 TGStoryViewerSortMode newMode = [action isEqualToString:@"primary"]
							 ? primaryMode
							 : TGStoryViewerSortRecent;
						 [strongSelf applySortMode:newMode];
					 }
						  target:self];
	[sheet tg_showFromBarButtonItem:self.navigationItem.rightBarButtonItem inView:self.view];
}

- (void)applySortMode:(TGStoryViewerSortMode)sortMode {
	if (_sortMode == sortMode)
		return;
	_sortMode = sortMode;
	_loadGeneration++;
	_loading = NO;
	_loaded = NO;
	_loadFailed = NO;
	[_rows removeAllObjects];
	_nextOffset = nil;
	_exhausted = NO;
	[_presenter updateWithRows:_rows];
	[_tableView reloadData];
	[self loadMore];
}

- (void)loadMore {
	if (_loading || _exhausted)
		return;
	_loading = YES;
	NSInteger generation = _loadGeneration;
	__weak TGStoryViewersViewController *weakSelf = self;
	void (^handler)(NSArray *, NSString *, NSInteger, BOOL) =
			^(NSArray *viewers, NSString *nextOffset, NSInteger total, BOOL failed) {
		(void)total;
		TGStoryViewersViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (strongSelf->_loadGeneration != generation)
			return;
		strongSelf->_loading = NO;
		strongSelf->_loaded = YES;
		strongSelf->_loadFailed = failed;
		if (failed)
			strongSelf->_exhausted = YES;
		if ([viewers isKindOfClass:[NSArray class]])
			[strongSelf->_rows addObjectsFromArray:viewers];
		strongSelf->_nextOffset = nextOffset;
		strongSelf->_exhausted = (nextOffset.length == 0);
		[strongSelf->_presenter updateWithRows:strongSelf->_rows];
		[strongSelf->_tableView reloadData];
	};

	if ([self isChannelInteractions]) {
		[[TGClient shared] viewersOfStory:_storyId
								   inChat:_chatId
								 sortMode:_sortMode
								   offset:_nextOffset
									limit:50
							   completion:handler];
	} else {
		[[TGClient shared] viewersOfStory:_storyId
								 sortMode:_sortMode
								   offset:_nextOffset
									limit:50
							   completion:handler];
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	(void)tableView;
	(void)section;
	return TGStoryViewersFooterText(_loaded, _loadFailed, _rows.count);
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption
															   width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption
												  width:tableView.bounds.size.width];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	(void)tableView;
	(void)section;
	return (NSInteger)_rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([_rowBridge ownsRowAtIndex:indexPath.row]) {
		if (indexPath.row + 5 >= (NSInteger)_rows.count)
			[self loadMore];
		return [_rowBridge cellForRow:indexPath.row inTable:tableView];
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"viewer"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"viewer"];
	NSDictionary *row = [_rows objectAtIndex:(NSUInteger)indexPath.row];
	NSString *name = TGStoryString(row, @"name");
	NSString *emoji = TGStoryString(row, @"emoji");
	cell.textLabel.text = emoji.length > 0
		? [NSString stringWithFormat:@"%@  %@", name, emoji]
		: name;
	cell.detailTextLabel.text = TGStoryAgeText((int)TGStoryNumber(row, @"date"));
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	[[TGTheme shared] styleCell:cell];

	if (indexPath.row + 5 >= (NSInteger)_rows.count)
		[self loadMore];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row >= (NSInteger)_rows.count)
		return;
	NSDictionary *row = [_rows objectAtIndex:(NSUInteger)indexPath.row];
	int64_t actorId = TGStoryChatId(row, @"id");
	if (actorId == 0)
		return;
	NSString *name = TGStoryString(row, @"name");
	if (actorId < 0) {
		[TGProfileViewController showProfileForChatId:actorId
											   userId:0
												title:name
										 inNavigation:self.navigationController];
		return;
	}

	__weak TGStoryViewersViewController *weakSelf = self;
	[[TGClient shared] privateChatWithUser:actorId completion:^(int64_t chatId) {
		TGStoryViewersViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[TGProfileViewController showProfileForChatId:chatId
											   userId:actorId
												title:name
										 inNavigation:strongSelf.navigationController];
	}];
}

@end
