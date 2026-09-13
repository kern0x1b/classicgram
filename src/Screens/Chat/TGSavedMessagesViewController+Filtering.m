#import "TGSavedMessagesViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGMediaViewController.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "UIView+SafeTint.h"
#import "UIButton+TGScopeButtonStyle.h"

@implementation TGSavedMessagesViewController (Filtering)

- (void)buildScopeBar {
	CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, kSavedScopeHeight);
	UIImage *plate = [UIImage imageNamed:@"SearchBarScopeBarBackground.png"];
	if (plate) {
		UIImageView *plateView = [[UIImageView alloc] initWithFrame:frame];
		plateView.image = plate;
		plateView.userInteractionEnabled = YES;
		self.scopeBar = plateView;
	} else {
		self.scopeBar = [[UIView alloc] initWithFrame:frame];
		self.scopeBar.backgroundColor = [[TGTheme shared] barColour];
		UIView *line = [[UIView alloc] initWithFrame:
				CGRectMake(0, kSavedScopeHeight - 1, frame.size.width, 1)];
		line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		line.backgroundColor = [[TGTheme shared] separatorColour];
		[self.scopeBar addSubview:line];
	}
	self.scopeBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.scopeBar.clipsToBounds = YES;

	self.scopeButtons = [NSMutableArray array];
	NSArray *titles = TGSavedScopeTitles();
	for (NSInteger i = 0; i < titles.count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = (NSInteger)i;
		button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		[button setTitle:titles[i] forState:UIControlStateNormal];
		[button tg_styleAsScopeButtonSelected:(i == (NSUInteger)self.scope)];
		[button addTarget:self action:@selector(scopeTapped:)
			forControlEvents:UIControlEventTouchDown];
		[self.scopeBar addSubview:button];
		[self.scopeButtons addObject:button];
	}

	[self.tableView addSubview:self.scopeBar];
	self.tableView.contentInset = UIEdgeInsetsMake(kSavedScopeHeight, 0, 0, 0);
	self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
	[self layoutScopeBar];
}

- (void)layoutScopeBar {
	CGFloat width = self.view.bounds.size.width;
	NSInteger count = self.scopeButtons.count;
	if (width < 1 || count == 0)
		return;

	self.scopeBar.frame = CGRectMake(0, self.tableView.contentOffset.y,
		width, kSavedScopeHeight);
	[self.tableView bringSubviewToFront:self.scopeBar];

	CGFloat available = width - 12;
	CGFloat each = (CGFloat)(int)(available / count);
	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = self.scopeButtons[i];
		CGFloat buttonWidth = (i == count - 1) ? (available - each * (count - 1)) : each;
		button.frame = CGRectMake(6 + each * i,
			(CGFloat)(int)((kSavedScopeHeight - kSavedScopeButtonHeight) / 2),
			buttonWidth, kSavedScopeButtonHeight);
	}
}

- (void)scopeTapped:(UIButton *)button {
	if (button.tag == self.scope || self.reordering)
		return;

	if (button.tag != kSavedScopeChats) {
		[self openSharedMediaForScope:button.tag];
		return;
	}

	self.scope = button.tag;
	for (UIButton *other in self.scopeButtons)
		[other tg_styleAsScopeButtonSelected:(other.tag == self.scope)];

	self.messageHits = @[];
	self.topicHits = @[];
	self.messagesLoadedOnce = NO;
	self.messagesCanLoadMore = NO;
	self.messagesNextId = 0;
	[self updateSeparatorStyle];
	[self updateTableHeader];
	[self.tableView reloadData];
	[self reloadForScope];
}

static NSInteger TGSavedMediaScopeForSavedScope(NSInteger savedScope) {
	switch (savedScope) {
		case 2:
			return TGMediaScopeFiles;
		case 3:
			return TGMediaScopeMusic;
		case 4:
			return TGMediaScopeLinks;
		default:
			return TGMediaScopeMedia;
	}
}

- (void)openSharedMediaForScope:(NSInteger)savedScope {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId || !self.navigationController)
		return;
	TGMediaViewController *media = [[TGMediaViewController alloc] initWithChatId:chatId];
	media.initialScope = TGSavedMediaScopeForSavedScope(savedScope);
	media.chatTitle = TGL(@"Settings.SavedMessages", @"Saved Messages");
	[self.navigationController pushViewController:media animated:YES];
}

- (void)reloadForScope {
	if (self.scope == kSavedScopeChats && !self.query.length) {
		[self.spinner stopAnimating];
		[self applyCachedTopics];
		[self updateEmptyContainer];
		return;
	}
	[self reloadMessages];
}

- (void)buildSearchBar {
	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width, kSavedSearchBarHeight)];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Chat.SearchTagsPlaceholder", @"Search messages or tags");
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self styleSearchBar];
}

- (void)styleSearchBar {
	TGTheme *theme = [TGTheme shared];
	self.searchBar.barStyle = UIBarStyleDefault;
	UIImage *plate = [UIImage imageNamed:@"SearchBarBackground.png"];
	if (plate && [self.searchBar respondsToSelector:@selector(setBackgroundImage:)])
		[self.searchBar setBackgroundImage:plate];
	[self.searchBar tg_setTintColor:[theme accentColour]];
}

- (void)updateTableHeader {
	CGFloat width = self.tableView.bounds.size.width;
	BOOL showsReminders = (self.reminders.count > 0) &&
		(self.scope == kSavedScopeChats) && !self.query.length;
	CGFloat height = kSavedSearchBarHeight + (showsReminders ? kSavedBannerHeight : 0);

	UIView *current = self.tableView.tableHeaderView;
	if (current && fabs(current.frame.size.height - height) < 0.5f &&
		fabs(current.frame.size.width - width) < 0.5f)
		return;

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
	header.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.searchBar.frame = CGRectMake(0, 0, width, kSavedSearchBarHeight);
	[header addSubview:self.searchBar];

	if (showsReminders) {
		self.reminderBanner.frame = CGRectMake(0, kSavedSearchBarHeight,
			width, kSavedBannerHeight);
		[header addSubview:self.reminderBanner];
	}

	self.tableView.tableHeaderView = header;
}

- (BOOL)searchBarActive {
	return self.query.length > 0 || self.searchBar.text.length > 0 ||
		[self.searchBar isFirstResponder];
}

- (void)revealSearchBarIfPulled:(UIScrollView *)scrollView {
	if (self.searchBarRevealed || !scrollView.dragging)
		return;
	if (self.scrollAnchor < kSavedSearchBarHeight - 0.5f)
		return;
	if (scrollView.contentOffset.y + scrollView.contentInset.top > kSavedSearchBarHeight / 2)
		return;
	self.searchBarRevealed = YES;
}

- (void)hideSearchBarIfScrolledPast:(UIScrollView *)scrollView {
	if (!self.searchBarRevealed || [self searchBarActive])
		return;
	if (scrollView.contentOffset.y + scrollView.contentInset.top < kSavedSearchBarHeight + 0.5f)
		return;
	self.searchBarRevealed = NO;
}

- (CGFloat)restingSearchBarOffset {
	return ([self searchBarActive] || self.searchBarRevealed) ? 0 : kSavedSearchBarHeight;
}

- (void)snapSearchBar:(UIScrollView *)scrollView {
	CGFloat top = scrollView.contentInset.top;
	CGFloat shown = scrollView.contentOffset.y + top;
	if (shown > kSavedSearchBarHeight - 0.5f)
		return;

	CGFloat target = [self restingSearchBarOffset];
	if (fabs(shown - target) < 0.5f)
		return;

	[scrollView setContentOffset:CGPointMake(0, target - top) animated:YES];
}

- (void)hideSearchBarOnFirstLayout {
	UITableView *table = self.tableView;
	if ([self searchBarActive] || self.searchBarRevealed)
		return;
	if (table.dragging || table.tracking || table.decelerating)
		return;
	CGFloat top = table.contentInset.top;
	CGFloat shown = table.contentOffset.y + top;
	if (shown < -0.5f || shown >= kSavedSearchBarHeight - 0.5f)
		return;
	CGFloat reachable = table.contentSize.height - table.bounds.size.height + top + table.contentInset.bottom;
	if (reachable < kSavedSearchBarHeight)
		return;
	table.contentOffset = CGPointMake(0, kSavedSearchBarHeight - top);
	[self layoutScopeBar];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	self.scrollAnchor = scrollView.contentOffset.y + scrollView.contentInset.top;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self revealSearchBarIfPulled:scrollView];
	[self hideSearchBarIfScrolledPast:scrollView];
	[self layoutScopeBar];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (decelerate)
		return;
	[self snapSearchBar:scrollView];
	self.scrollAnchor = scrollView.contentOffset.y + scrollView.contentInset.top;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	[self snapSearchBar:scrollView];
	self.scrollAnchor = scrollView.contentOffset.y + scrollView.contentInset.top;
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
	self.searchBarRevealed = YES;
	[searchBar setShowsCancelButton:YES animated:YES];
	return YES;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	self.query = @"";
	self.topicHits = @[];
	self.messageHits = @[];
	self.searchToken++;
	self.messagesCanLoadMore = NO;
	self.messagesNextId = 0;
	[searchBar resignFirstResponder];
	self.searchBarRevealed = NO;
	[self updateSeparatorStyle];
	[self updateTableHeader];
	[self.tableView reloadData];
	[self reloadForScope];
	[self snapSearchBar:self.tableView];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	self.query = text ?: @"";
	self.searchToken++;
	[self updateTableHeader];

	if (!self.query.length) {
		self.topicHits = @[];
		self.messageHits = @[];
		self.messagesCanLoadMore = NO;
		self.messagesNextId = 0;
		[self.tableView reloadData];
		[self reloadForScope];
		return;
	}

	self.topicHits = [self topicsMatchingQuery:self.query];
	[self updateSeparatorStyle];
	[self.tableView reloadData];
	[self reloadMessages];
}

- (NSArray *)topicsMatchingQuery:(NSString *)query {
	if (self.scope != kSavedScopeChats)
		return @[];

	NSMutableArray *hits = [NSMutableArray array];
	for (NSDictionary *topic in self.topics) {
		NSString *title = TGSavedTopicTitle(topic);
		if ([title rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound)
			[hits addObject:topic];
	}
	return hits;
}

@end
