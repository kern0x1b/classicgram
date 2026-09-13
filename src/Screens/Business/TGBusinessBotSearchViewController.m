#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGBusinessBotSearchViewController.h"
#import "TGLocalization.h"
#import "TGContactsService.h"
#import "TGUserDisplayNameStore.h"
#import "TGTheme.h"

typedef NS_ENUM(NSInteger, TGBBSState) {
	TGBBSStateIdle = 0,
	TGBBSStateSearching,
	TGBBSStateNotFound,
	TGBBSStateLookupFailed,
	TGBBSStateNotBot,
	TGBBSStateNotEligible,
	TGBBSStateFound,
};

@interface TGBusinessBotSearchViewController ()

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) TGBBSState state;
@property (nonatomic, copy) NSString *resultUsername;
@property (nonatomic, assign) int64_t resultUserId;
@property (nonatomic, copy) NSString *resultName;

@end

@implementation TGBusinessBotSearchViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Business.Bot", @"Bot");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
	self.searchBar.delegate = self;
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.placeholder = TGL(@"ChatbotSetup.BotSearchPlaceholder", @"Bot Username");
	self.searchBar.text = self.initialUsername;
	self.tableView.tableHeaderView = self.searchBar;

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (!self.initialUsername.length)
		[self.searchBar becomeFirstResponder];
}

- (void)viewDidLayoutSubviews {
	if ([[UIViewController class] instancesRespondToSelector:@selector(viewDidLayoutSubviews)])
		[super viewDidLayoutSubviews];
	self.spinner.center = CGPointMake(floorf(self.view.bounds.size.width / 2), 90);
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runBotSearch)
											   object:nil];
}

- (NSString *)trimmedQuery {
	return [self.searchBar.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runBotSearch)
											   object:nil];
	if ([self trimmedQuery].length == 0) {
		self.state = TGBBSStateIdle;
		[self.spinner stopAnimating];
		[self.tableView reloadData];
		return;
	}
	[self performSelector:@selector(runBotSearch) withObject:nil afterDelay:0.4];
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
											 selector:@selector(runBotSearch)
											   object:nil];
	self.state = TGBBSStateIdle;
	[self.spinner stopAnimating];
	[self.tableView reloadData];
}

- (void)runBotSearch {
	NSString *query = [self trimmedQuery];
	if (query.length == 0)
		return;
	self.state = TGBBSStateSearching;
	[self.spinner startAnimating];
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[TGContactsService userIdForUsername:query completion:^(int64_t userId, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![[strongSelf trimmedQuery] isEqualToString:query])
			return;
		if (failed || !userId) {
			[strongSelf.spinner stopAnimating];
			strongSelf.state = failed ? TGBBSStateLookupFailed : TGBBSStateNotFound;
			[strongSelf.tableView reloadData];
			return;
		}
		[TGContactsService businessBotEligibilityForUserId:userId
												  completion:^(BOOL isBot, BOOL canConnectToBusiness) {
			__strong typeof(weakSelf) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (![[innerSelf trimmedQuery] isEqualToString:query])
				return;
			[innerSelf.spinner stopAnimating];
			if (!isBot) {
				innerSelf.state = TGBBSStateNotBot;
				[innerSelf.tableView reloadData];
				return;
			}
			if (!canConnectToBusiness) {
				innerSelf.state = TGBBSStateNotEligible;
				[innerSelf.tableView reloadData];
				return;
			}
			innerSelf.state = TGBBSStateFound;
			innerSelf.resultUsername = query;
			innerSelf.resultUserId = userId;
			innerSelf.resultName = [TGUserDisplayNameStore nameForUserId:userId];
			[innerSelf.tableView reloadData];
		}];
	}];
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.state == TGBBSStateFound ? 1 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	switch (self.state) {
		case TGBBSStateNotFound:
			return TGL(@"ChatbotSetup.BotNotFoundStatus", @"No bot was found with that username.");
		case TGBBSStateLookupFailed:
			return TGL(@"ChatbotSetup.BotLookupFailed", @"That username could not be checked. Try again in a moment.");
		case TGBBSStateNotBot:
			return TGL(@"ChatbotSetup.UsernameIsNotBot", @"The specified username belongs to a user, not a bot.");
		case TGBBSStateNotEligible:
			return TGL(@"ChatbotSetup.BotCannotConnect", @"This bot cannot be connected to a business account.");
		default:
			return nil;
	}
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"result"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"result"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = [UIFont systemFontOfSize:17];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.textLabel.text = self.resultName.length ? self.resultName : self.resultUsername;
	cell.detailTextLabel.text = [NSString stringWithFormat:@"@%@", self.resultUsername];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (self.state != TGBBSStateFound)
		return;
	void (^pick)(int64_t, NSString *) = self.onPick;
	int64_t userId = self.resultUserId;
	NSString *name = self.resultName;
	[self.navigationController popViewControllerAnimated:YES];
	if (pick)
		pick(userId, name);
}

@end
