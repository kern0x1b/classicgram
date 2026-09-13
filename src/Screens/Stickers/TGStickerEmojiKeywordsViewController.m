#import "TGGroupedCaption.h"
#import "TGStickerEmojiKeywordsViewController.h"
#import "TGClient+Stickers.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGSnackbar.h"
#import "TGStickersViewControllerInternal.h"

@interface TGStickerEmojiKeywordsViewController ()

@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray *categories;
@property (nonatomic, strong) NSArray *suggestions;
@property (nonatomic, strong) NSArray *exactEmojis;
@property (nonatomic, assign) BOOL searching;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL failed;

@end

@implementation TGStickerEmojiKeywordsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.category ? (self.category[@"name"] ?: TGL(@"EmojiInput.PanelTitleEmoji", @"Emoji"))
							   : TGL(@"Stickers.EmojiKeywords", @"Emoji Keywords");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.table = [[UITableView alloc] initWithFrame:self.view.bounds
											  style:UITableViewStyleGrouped];
	self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleHeight;
	self.table.dataSource = self;
	self.table.delegate = self;
	self.table.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.table.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[self.view addSubview:self.table];

	if (!self.category) {
		self.searchBar = [[UISearchBar alloc] initWithFrame:
				CGRectMake(0, 0, self.view.bounds.size.width, kStickersSearchBarHeight)];
		self.searchBar.delegate = self;
		self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.searchBar.placeholder = TGL(@"EmojiSearch.SearchEmojiPlaceholder", @"Search Emoji");
		self.table.tableHeaderView = self.searchBar;
	}

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
			UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	if (self.category) {
		self.loaded = YES;
		return;
	}
	[self loadCategories];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	self.spinner.center = CGPointMake(floorf(self.view.bounds.size.width / 2),
		floorf(self.view.bounds.size.height / 2));
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runEmojiSearch)
											   object:nil];
}

- (void)loadCategories {
	[self.spinner startAnimating];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] emojiCategoriesForStickers:NO completion:^(NSArray *categories) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.spinner stopAnimating];
		strongSelf.loaded = YES;
		strongSelf.failed = (categories.count == 0);
		strongSelf.categories = categories ?: @[];
		[strongSelf.table reloadData];
	}];
}

- (NSString *)trimmedQuery {
	return [self.searchBar.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
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
	[searchBar resignFirstResponder];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runEmojiSearch)
											   object:nil];
	self.searching = NO;
	self.suggestions = nil;
	self.exactEmojis = nil;
	[self.table reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runEmojiSearch)
											   object:nil];
	if ([self trimmedQuery].length == 0) {
		self.searching = NO;
		self.suggestions = nil;
		self.exactEmojis = nil;
		[self.table reloadData];
		return;
	}
	[self performSelector:@selector(runEmojiSearch) withObject:nil afterDelay:0.3];
}

- (void)runEmojiSearch {
	NSString *query = [self trimmedQuery];
	if (query.length == 0)
		return;
	self.searching = YES;
	[self.spinner startAnimating];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] emojiSuggestionsForText:query completion:^(NSArray *suggestions) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.searching)
			return;
		if (![[strongSelf trimmedQuery] isEqualToString:query])
			return;
		[strongSelf.spinner stopAnimating];
		strongSelf.suggestions = suggestions ?: @[];
		[strongSelf.table reloadData];
	}];

	[[TGClient shared] keywordEmojisForText:query completion:^(NSArray *emojis) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.searching)
			return;
		if (![[strongSelf trimmedQuery] isEqualToString:query])
			return;
		strongSelf.exactEmojis = emojis ?: @[];
		[strongSelf.table reloadData];
	}];
}

- (NSArray *)categoryEmojis {
	NSArray *emojis = self.category[@"emojis"];
	return [emojis isKindOfClass:[NSArray class]] ? emojis : @[];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.category)
		return 1;
	return self.searching ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.category)
		return (NSInteger)[self categoryEmojis].count;
	if (!self.searching)
		return (NSInteger)self.categories.count;
	return section == 0 ? (NSInteger)self.exactEmojis.count
						: (NSInteger)self.suggestions.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (self.category || !self.searching)
		return nil;
	if (section == 0)
		return self.exactEmojis.count ? TGL(@"Stickers.ExactKeyword", @"Exact Keyword") : nil;
	return self.suggestions.count ? TGL(@"Stickers.Suggestions", @"Suggestions") : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (self.category)
		return [self categoryEmojis].count ? TGL(@"Stickers.TapEmojiToCopy", @"Tap an emoji to copy it.")
										   : TGL(@"Stickers.CategoryEmpty", @"This category is empty.");
	if (self.searching) {
		if (section != 1)
			return nil;
		if (self.exactEmojis.count == 0 && self.suggestions.count == 0)
			return TGL(@"EmojiSearch.SearchEmojiEmptyResult", @"No emoji found");
		return TGL(@"Stickers.TapEmojiToCopy", @"Tap an emoji to copy it.");
	}
	if (!self.loaded)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	if (self.failed || self.categories.count == 0)
		return TGL(@"Stickers.EmojiListLoadFailed", @"The emoji list could not be loaded. Check the connection and try again.");
	return TGL(@"Stickers.TypeWordForEmoji", @"Type a word to look up the emoji it stands for.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedHeaderViewWithTitle:
			[self tableView:tableView titleForHeaderInSection:section]
									   width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	CGFloat measured = [theme groupedCommentHeightForText:caption
													width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:
			[self tableView:tableView titleForFooterInSection:section]
									   width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"emoji"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"emoji"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];

	if (self.category) {
		NSArray *emojis = [self categoryEmojis];
		if (indexPath.row >= (NSInteger)emojis.count)
			return cell;
		cell.textLabel.font = [UIFont systemFontOfSize:24];
		cell.textLabel.text = emojis[indexPath.row];
		cell.detailTextLabel.text = @"";
		return cell;
	}

	if (!self.searching) {
		if (indexPath.row >= (NSInteger)self.categories.count)
			return cell;
		NSDictionary *category = self.categories[indexPath.row];
		NSInteger count = (NSInteger)[category[@"emojis"] count];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.text = category[@"name"];
		cell.detailTextLabel.text = count ? [NSString stringWithFormat:@"%d", (int)count] : @"";
		TGStickersApplyDisclosure(cell);
		return cell;
	}

	cell.textLabel.font = [UIFont systemFontOfSize:24];
	if (indexPath.section == 0) {
		if (indexPath.row >= (NSInteger)self.exactEmojis.count)
			return cell;
		cell.textLabel.text = self.exactEmojis[indexPath.row];
		cell.detailTextLabel.text = @"";
		return cell;
	}
	if (indexPath.row >= (NSInteger)self.suggestions.count)
		return cell;
	NSDictionary *suggestion = self.suggestions[indexPath.row];
	cell.textLabel.text = suggestion[@"emoji"];
	cell.detailTextLabel.text = suggestion[@"keyword"];
	return cell;
}

- (void)copyEmoji:(NSString *)emoji {
	if (emoji.length == 0)
		return;
	[UIPasteboard generalPasteboard].string = emoji;
	[TGSnackbar showInView:self.view text:TGL(@"Conversation.EmojiCopied", @"Emoji copied to clipboard") seconds:2 onCommit:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (self.category) {
		NSArray *emojis = [self categoryEmojis];
		if (indexPath.row < (NSInteger)emojis.count)
			[self copyEmoji:emojis[indexPath.row]];
		return;
	}

	if (!self.searching) {
		if (indexPath.row >= (NSInteger)self.categories.count)
			return;
		TGStickerEmojiKeywordsViewController *next =
			[[TGStickerEmojiKeywordsViewController alloc] init];
		next.category = self.categories[indexPath.row];
		[self.navigationController pushViewController:next animated:YES];
		return;
	}

	if (indexPath.section == 0) {
		if (indexPath.row < (NSInteger)self.exactEmojis.count)
			[self copyEmoji:self.exactEmojis[indexPath.row]];
		return;
	}
	if (indexPath.row < (NSInteger)self.suggestions.count)
		[self copyEmoji:self.suggestions[indexPath.row][@"emoji"]];
}

@end
