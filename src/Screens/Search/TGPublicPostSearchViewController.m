#import "TGPublicPostSearchViewController.h"
#import "TGIcons.h"

#import "TGClient+Search.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGChatViewController.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"

static NSString *const kTGPublicPostCellId = @"post";

@interface TGPublicPostSearchViewController () <UISearchBarDelegate, UITableViewDataSource,
	UITableViewDelegate> {
	UISearchBar *_bar;
	UILabel *_statusLabel;
	UIButton *_paidSearchButton;
	UITableView *_tableView;
	UIActivityIndicatorView *_spinner;

	NSMutableArray *_rows;
	NSString *_query;
	NSString *_nextOffset;
	BOOL _loading;
	BOOL _limitsExceeded;
	NSDictionary *_lastLimits;
	BOOL _searchedOnce;
	NSInteger _pendingPaidStarCount;
	BOOL _confirmingPaidSearch;
	NSUInteger _searchGeneration;
}
@end

@implementation TGPublicPostSearchViewController

- (instancetype)init {
	self = [super init];
	if (self) {
		self.title = TGL(@"DialogList.SearchSectionPublicPosts", @"Public Posts");
		_rows = [[NSMutableArray alloc] init];
		_query = @"";
		_nextOffset = @"";
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	_bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44.0f)];
	_bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_bar.placeholder = TGL(@"HashtagSearch.SearchPlaceholder", @"Hashtag search");
	_bar.delegate = self;
	[self.view addSubview:_bar];

	_statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_statusLabel.backgroundColor = [UIColor clearColor];
	_statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_statusLabel.font = [UIFont systemFontOfSize:13];
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.numberOfLines = 2;
	[self.view addSubview:_statusLabel];

	_paidSearchButton = [TGIcons actionButtonWithTitle:@""
												  kind:TGActionButtonKindNeutral
												target:self
												action:@selector(paidSearchButtonPressed)];
	_paidSearchButton.hidden = YES;
	[self.view addSubview:_paidSearchButton];

	_tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	_tableView.separatorColor = [[TGTheme shared] separatorColour];
	_tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	[self.view addSubview:_tableView];

	_spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.hidesWhenStopped = YES;
	[self.view addSubview:_spinner];

	[self setStatusText:TGL(@"HashtagSearch.SearchPrompt", @"Type a hashtag to find public posts that carry it.")];
	[self layoutChrome];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	[self layoutChrome];
}

- (void)layoutChrome {
	CGFloat width = self.view.bounds.size.width;
	CGFloat top = 0.0f;
	_bar.frame = CGRectMake(0, top, width, 44.0f);
	top += 44.0f;

	BOOL showsStatus = _statusLabel.text.length > 0;
	CGFloat statusHeight = showsStatus ? 32.0f : 0.0f;
	_statusLabel.frame = CGRectMake(8, top, width - 16, statusHeight);
	top += statusHeight;

	BOOL showsPaidButton = !_paidSearchButton.hidden;
	CGFloat paidButtonHeight = showsPaidButton ? 44.0f : 0.0f;
	_paidSearchButton.frame = CGRectMake(8, top, width - 16, paidButtonHeight);
	top += paidButtonHeight;

	_tableView.frame = CGRectMake(0, top, width, self.view.bounds.size.height - top);
	_spinner.center = CGPointMake(width / 2.0f, top + 60.0f);
}

- (void)setStatusText:(NSString *)text {
	_statusLabel.text = text ?: @"";
	[self layoutChrome];
}

- (void)setPaidSearchButtonStarCount:(NSInteger)stars {
	_pendingPaidStarCount = stars;
	NSString *template = TGL(@"ChatList.GlobalSearch.SearchButtonPaidTitle", @"Search for  *  %@");
	NSString *title = [[NSString stringWithFormat:template, @(stars)]
			stringByReplacingOccurrencesOfString:@"*" withString:@"★"];
	[_paidSearchButton setTitle:title forState:UIControlStateNormal];
	_paidSearchButton.hidden = NO;
	[self layoutChrome];
}

- (void)hidePaidSearchButton {
	if (_paidSearchButton.hidden)
		return;
	_paidSearchButton.hidden = YES;
	_pendingPaidStarCount = 0;
	[self layoutChrome];
}

#pragma mark - search bar

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
	NSString *query = [searchBar.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!query.length)
		return;
	_searchGeneration++;
	_loading = NO;
	_query = query;
	_nextOffset = @"";
	[_rows removeAllObjects];
	[_tableView reloadData];
	[self hidePaidSearchButton];
	_searchedOnce = YES;
	[self checkLimitsThenSearch];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	(void)searchBar;
	[_bar resignFirstResponder];
}

#pragma mark - the free/paid pre-flight

- (void)checkLimitsThenSearch {
	if (_loading)
		return;
	_loading = YES;
	[_spinner startAnimating];
	[self setStatusText:@""];

	NSUInteger generation = _searchGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] publicPostSearchLimitsForQuery:_query completion:^(NSDictionary *limits) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf->_searchGeneration != generation)
			return;
		if (limits == nil) {
			strongSelf->_loading = NO;
			[strongSelf->_spinner stopAnimating];
			[strongSelf setStatusText:TGL(@"Story.PublicPosts.LimitsFailed", @"Could not check today's search limits. Try again.")];
			return;
		}
		strongSelf->_lastLimits = limits;
		if ([limits[@"isCurrentQueryFree"] boolValue]) {
			[strongSelf performSearchAtOffset:@"" starCount:0];
			return;
		}

		strongSelf->_loading = NO;
		[strongSelf->_spinner stopAnimating];
		[strongSelf presentPaidSearchButtonWithLimits:limits];
	}];
}

- (void)presentPaidSearchButtonWithLimits:(NSDictionary *)limits {
	NSInteger stars = [limits[@"starCount"] integerValue];
	if (stars <= 0) {
		NSInteger dailyFreeQueryCount = [limits[@"dailyFreeQueryCount"] integerValue];
		[self setStatusText:TGLPlural(@"ChatList.GlobalSearch.LimitPlaceholder.Text", dailyFreeQueryCount,
					@"You can make up to\n%@ search query per day.", @"You can make up to\n%@ search queries per day.")];
		return;
	}
	[self setPaidSearchButtonStarCount:stars];
}

- (void)paidSearchButtonPressed {
	if (_pendingPaidStarCount <= 0 || _confirmingPaidSearch)
		return;
	_confirmingPaidSearch = YES;
	NSInteger stars = _pendingPaidStarCount;
	NSString *offset = _nextOffset;
	NSUInteger generation = _searchGeneration;
	__weak typeof(self) weakSelf = self;
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Stars.Transfer.Title", @"Confirm Your Purchase")
						 message:[NSString stringWithFormat:
								   TGL(@"Story.PublicPosts.ConfirmPaidSearchMessage",
									   @"%@ will be taken from your balance to run this search."),
								 [NSString stringWithFormat:@"%ld ★", (long)stars]]
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   okButtonTitle:TGL(@"Stars.Transfer.Pay", @"Confirm and Pay")
				 completionBlock:^(bool okButtonPressed) {
					 typeof(self) strongSelf = weakSelf;
					 if (!strongSelf)
						 return;
					 strongSelf->_confirmingPaidSearch = NO;
					 if (!okButtonPressed || strongSelf->_searchGeneration != generation)
						 return;
					 [strongSelf hidePaidSearchButton];
					 [strongSelf performSearchAtOffset:offset starCount:stars];
				 }];
	[alert show];
}

- (void)performSearchAtOffset:(NSString *)offset starCount:(NSInteger)starCount {
	_loading = YES;
	[_spinner startAnimating];

	NSUInteger generation = _searchGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchPublicPostsWithQuery:_query
										   offset:offset
										starCount:starCount
											limit:20
									   completion:^(NSArray *messages, NSString *nextOffset,
										   NSDictionary *limits, BOOL limitsExceeded,
										   NSString *error) {
										   typeof(self) strongSelf = weakSelf;
										   if (strongSelf == nil
											   || strongSelf->_searchGeneration != generation)
											   return;
										   strongSelf->_loading = NO;
										   [strongSelf->_spinner stopAnimating];

										   if (error.length) {
											   [strongSelf setStatusText:error];
											   return;
										   }

										   if (limits != nil)
											   strongSelf->_lastLimits = limits;
										   strongSelf->_limitsExceeded = limitsExceeded;
										   strongSelf->_nextOffset = limitsExceeded ? offset : (nextOffset ?: @"");
										   [strongSelf->_rows addObjectsFromArray:messages];
										   [strongSelf->_tableView reloadData];
										   [strongSelf updateStatusAfterSearch];
									   }];
}

- (void)updateStatusAfterSearch {
	if (_limitsExceeded) {
		[self presentPaidSearchButtonWithLimits:_lastLimits];
		return;
	}
	[self hidePaidSearchButton];
	if (_rows.count == 0) {
		[self setStatusText:TGL(@"HashtagSearch.NoResults", @"No public posts matched that search.")];
		return;
	}
	NSInteger remaining = [_lastLimits[@"remainingFreeQueryCount"] integerValue];
	if (_nextOffset.length == 0) {
		[self setStatusText:TGL(@"Story.PublicPosts.EndOfResults", @"End of results.")];
	} else {
		[self setStatusText:TGLPlural(@"ChatList.GlobalSearch.StartPlaceholder.RemainingSubtitle", remaining,
									@"%@ free search remaining today.", @"%@ free searches remaining today.")];
	}
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	(void)tableView;
	(void)section;
	return (NSInteger)_rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kTGPublicPostCellId];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:kTGPublicPostCellId];
	}
	NSDictionary *row = [_rows objectAtIndex:(NSUInteger)indexPath.row];
	NSString *chatTitle = [row[@"chatTitle"] isKindOfClass:NSString.class] ? row[@"chatTitle"] : @"";
	NSString *text = [row[@"text"] isKindOfClass:NSString.class] ? row[@"text"] : @"";
	NSInteger date = [row[@"date"] integerValue];

	cell.textLabel.text = chatTitle.length ? chatTitle : TGL(@"ChatList.UnnamedChat", @"Chat");
	NSString *snippet = text.length ? text : TGL(@"Business.Links.ItemNoText", @"(no text)");
	cell.detailTextLabel.text = date > 0
		? [NSString stringWithFormat:@"%@ · %@", [TGDateUtils stringForMessageListDate:(int)date], snippet]
		: snippet;
	cell.detailTextLabel.numberOfLines = 2;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	[[TGTheme shared] styleCell:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *row = [_rows objectAtIndex:(NSUInteger)indexPath.row];
	int64_t chatId = [row[@"chatId"] longLongValue];
	NSString *fallbackTitle = [row[@"chatTitle"] isKindOfClass:NSString.class] ? row[@"chatTitle"] : @"";
	int64_t messageId = [row[@"id"] longLongValue];
	if (!chatId)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatSummaryForChatId:chatId completion:^(NSDictionary *chat) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		BOOL isGroup = [chat[@"isGroup"] boolValue] || [chat[@"isChannel"] boolValue];
		NSString *title = [chat[@"title"] isKindOfClass:NSString.class] && [chat[@"title"] length]
			? chat[@"title"]
			: fallbackTitle;
		TGChatViewController *controller = [[TGChatViewController alloc] init];
		controller.chatId = chatId;
		controller.chatTitle = title;
		controller.group = isGroup;
		controller.focusMessageId = messageId;
		[strongSelf.navigationController pushViewController:controller animated:YES];
	}];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (_loading || _limitsExceeded || _nextOffset.length == 0 || _rows.count == 0)
		return;
	CGFloat bottom = scrollView.contentOffset.y + scrollView.bounds.size.height;
	if (bottom > scrollView.contentSize.height - 200.0f)
		[self performSearchAtOffset:_nextOffset starCount:0];
}

@end
