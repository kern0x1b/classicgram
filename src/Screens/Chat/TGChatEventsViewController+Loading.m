#import "TGChatEventsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDateUtils.h"
#import "UIView+SafeTint.h"

static const NSInteger kEventsPageSize = 50;

@implementation TGChatEventsViewController (Loading)

- (void)reload {
	self.loading = NO;
	self.loaded = NO;
	self.failed = NO;
	self.exhausted = NO;
	self.oldestEventId = 0;
	self.loadGeneration++;
	[self.events removeAllObjects];
	[self.expandedGroupIds removeAllObjects];
	[self rebuildSections];
	[self updateSpamBanner];
	[self.tableView reloadData];
	[self showLoading];
	[self loadNextPage];
}

- (void)loadNextPage {
	if (self.loading || self.exhausted)
		return;
	if (self.chatId == 0) {
		self.loaded = YES;
		self.failed = YES;
		[self updateStates];
		return;
	}

	self.loading = YES;
	NSInteger generation = self.loadGeneration;
	long long from = self.oldestEventId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] eventLogForChat:self.chatId
								 query:self.searchQuery
						   fromEventId:from
								 limit:kEventsPageSize
							   filters:self.filters
							   userIds:self.userIds
							completion:^(NSArray *events) {
								__strong typeof(weakSelf) strongSelf = weakSelf;
								if (!strongSelf)
									return;
								if (generation != strongSelf.loadGeneration)
									return;
								[strongSelf handlePage:events fromEventId:from];
							}];
}

- (void)handlePage:(NSArray *)events fromEventId:(long long)from {
	self.loading = NO;
	self.loaded = YES;

	if (![events isKindOfClass:[NSArray class]]) {
		self.failed = self.events.count == 0;
		[self updateStates];
		return;
	}

	self.failed = NO;
	if (events.count == 0) {
		self.exhausted = YES;
	} else {
		for (NSDictionary *event in events) {
			if (![event isKindOfClass:[NSDictionary class]])
				continue;
			[self.events addObject:event];
			long long eventId = TGEventsLongLong(event, @"eventId");
			if (eventId != 0)
				self.oldestEventId = eventId;
		}
		if ((NSInteger)events.count < kEventsPageSize)
			self.exhausted = YES;
		if (self.oldestEventId == from)
			self.exhausted = YES;
	}

	[self rebuildSections];
	[self updateSpamBanner];
	[self.tableView reloadData];
	[self updateStates];
}

- (void)showLoading {
	self.messageView.hidden = YES;
	self.tableView.hidden = YES;
	[self.spinner startAnimating];
	[self layoutOverlays];
}

- (void)updateStates {
	[self.spinner stopAnimating];

	if (self.events.count) {
		self.messageView.hidden = YES;
		self.tableView.hidden = NO;
		return;
	}

	self.tableView.hidden = YES;
	self.messageView.hidden = NO;
	if (self.failed) {
		self.messageView.titleLabel.text = TGL(@"Channel.AdminLog.LoadErrorTitle", @"Couldn't Load");
		self.messageView.bodyLabel.text = TGL(@"Channel.AdminLog.LoadErrorText", @"Check your connection and try again.");
		[self.messageView.actionButton setTitle:TGL(@"Common.Retry", @"Retry") forState:UIControlStateNormal];
	} else if (self.searchQuery.length) {
		self.messageView.titleLabel.text = TGL(@"Channel.AdminLog.EmptyFilterTitle", @"No actions");
		self.messageView.bodyLabel.text = [NSString stringWithFormat:
				TGL(@"Channel.AdminLog.EmptyFilterQueryText", @"No recent actions that contain '%@' have been found."),
			self.searchQuery];
		[self.messageView.actionButton setTitle:nil forState:UIControlStateNormal];
	} else if (self.filters.count || self.userIds.count) {
		self.messageView.titleLabel.text = TGL(@"Channel.AdminLog.EmptyFilterTitle", @"No actions");
		self.messageView.bodyLabel.text = TGL(@"Channel.AdminLog.EmptyFilterText", @"No recent action matches the filter. Admin actions are kept for 48 hours.");
		[self.messageView.actionButton setTitle:nil forState:UIControlStateNormal];
	} else {
		self.messageView.titleLabel.text = TGL(@"Channel.AdminLog.EmptyTitle", @"No actions yet");
		self.messageView.bodyLabel.text = TGL(@"Channel.AdminLog.InfoPanelChannelAlertText", @"Actions taken by the admins of this chat over the last 48 hours are listed here.");
		[self.messageView.actionButton setTitle:nil forState:UIControlStateNormal];
	}
	[self layoutOverlays];
}

- (void)retryLoadingEvents {
	[self reload];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];

	NSString *query = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (query.length == 0) {
		self.searchQuery = nil;
		[self reload];
		return;
	}

	self.searchQuery = query;
	[self performSelector:@selector(runSearch) withObject:nil afterDelay:0.4];
}

- (void)runSearch {
	if (!self.searchQuery.length)
		return;
	[self reload];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
	[self runSearch];
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
	searchBar.text = @"";
	self.searchQuery = nil;
	[searchBar setShowsCancelButton:NO animated:YES];
	[searchBar resignFirstResponder];
	[self reload];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	if (searchBar.text.length == 0)
		[searchBar setShowsCancelButton:NO animated:YES];
}

@end
