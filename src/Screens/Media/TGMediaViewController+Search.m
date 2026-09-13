#import "TGMediaViewControllerInternal.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGViewRecycler.h"
#import "UIButton+TGScopeButtonStyle.h"

@implementation TGMediaViewController (Search)

- (void)buildScopeBar {
	CGRect scopeFrame = CGRectMake(0, 0, self.view.bounds.size.width, kMediaScopeHeight);
	UIImage *scopeBackground = [UIImage imageNamed:@"SearchBarScopeBarBackground.png"];
	if (scopeBackground) {
		UIImageView *barView = [[UIImageView alloc] initWithFrame:scopeFrame];
		barView.image = scopeBackground;
		barView.userInteractionEnabled = YES;
		self.scopeBar = barView;
	} else {
		self.scopeBar = [[UIView alloc] initWithFrame:scopeFrame];
		UIColor *scopeColour = [UIColor colorWithRed:0xc3 / 255.0f green:0xcb / 255.0f blue:0xd4 / 255.0f alpha:1.0f];
		self.scopeBar.backgroundColor = scopeColour;
		UIView *scopeLine = [[UIView alloc] initWithFrame:
				CGRectMake(0, kMediaScopeHeight - 1, scopeFrame.size.width, 1)];
		scopeLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		scopeLine.backgroundColor = [[TGTheme shared] separatorColour];
		[self.scopeBar addSubview:scopeLine];
	}
	self.scopeBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.scopeBar.clipsToBounds = YES;
	[self.view addSubview:self.scopeBar];

	self.scopeButtons = [NSMutableArray array];
	NSArray *scopeTitles = TGMediaScopeTitles();
	for (NSInteger i = 0; i < scopeTitles.count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = (NSInteger)i;
		button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		[button setTitle:scopeTitles[i] forState:UIControlStateNormal];
		[button tg_styleAsScopeButtonSelected:(i == self.scope)];
		[button addTarget:self action:@selector(scopeTapped:)
			forControlEvents:UIControlEventTouchDown];
		[self.scopeBar addSubview:button];
		[self.scopeButtons addObject:button];
	}
}

- (void)buildSearchBar {
	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width, kMediaSearchBarHeight)];
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Common.Search", @"Search");
	UIImage *searchBackground = [UIImage imageNamed:@"SearchBarBackground.png"];
	if (searchBackground && [self.searchBar respondsToSelector:@selector(setBackgroundImage:)])
		[self.searchBar setBackgroundImage:searchBackground];
}

- (void)layoutScopeButtons {
	CGFloat width = self.view.bounds.size.width;
	NSInteger count = self.scopeButtons.count;
	if (width < 1 || count == 0)
		return;

	CGFloat available = width - 12;
	CGFloat each = (CGFloat)(int)(available / count);
	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = self.scopeButtons[i];
		CGFloat buttonWidth = (i == count - 1) ? (available - each * (count - 1)) : each;
		button.frame = CGRectMake(6 + each * i,
			(CGFloat)(int)((kMediaScopeHeight - kMediaScopeButtonHeight) / 2),
			buttonWidth, kMediaScopeButtonHeight);
	}
}

- (void)scopeTapped:(UIButton *)button {
	if (button.tag == self.scope)
		return;

	self.scope = button.tag;
	[self updateTitleForScope];
	self.loadToken++;
	for (UIButton *other in self.scopeButtons)
		[other tg_styleAsScopeButtonSelected:(other.tag == self.scope)];

	self.query = @"";
	self.searchBar.text = @"";
	[self.searchBar resignFirstResponder];
	[self updateSearchBarVisibility];

	[self.items removeAllObjects];
	self.lastMessageId = 0;
	self.canLoadMore = YES;
	self.loadedOnce = NO;
	self.loading = NO;
	[self setEmptyVisible:NO animated:NO];
	self.emptyLabel.text = TGMediaEmptyTextForScope(self.scope);
	[self.emptyLabel sizeToFit];
	self.emptyImageView.hidden = !TGMediaScopeIsGrid(self.scope);
	[self layoutEmptyView];
	self.view.backgroundColor = [self backgroundColourForScope:self.scope];
	self.tableView.backgroundColor = [self backgroundColourForScope:self.scope];
	self.dateIndicator.alpha = 0.0f;
	[self.recycler removeAllViews];
	self.tableView.rowHeight = TGMediaScopeIsGrid(self.scope)
		? kMediaRowHeight
		: kMediaListRowHeight;
	self.tableView.separatorStyle = TGMediaScopeIsGrid(self.scope)
		? UITableViewCellSeparatorStyleNone
		: UITableViewCellSeparatorStyleSingleLine;
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	[self.tableView reloadData];
	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self loadNextPage];
}

- (void)updateSearchBarVisibility {
	self.tableView.tableHeaderView = TGMediaScopeIsGrid(self.scope) ? nil : self.searchBar;
}

- (void)reloadFromStart {
	self.loadToken++;
	[self.items removeAllObjects];
	self.lastMessageId = 0;
	self.canLoadMore = YES;
	self.loadedOnce = NO;
	self.loading = NO;
	[self setEmptyVisible:NO animated:NO];
	[self.recycler removeAllViews];
	[self.tableView reloadData];
	[self loadNextPage];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
	NSString *text = searchBar.text ?: @"";
	if ([text isEqualToString:self.query ?: @""])
		return;
	self.query = text;
	[self reloadFromStart];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	if ((self.query ?: @"").length == 0)
		return;
	self.query = @"";
	[self reloadFromStart];
}

@end
