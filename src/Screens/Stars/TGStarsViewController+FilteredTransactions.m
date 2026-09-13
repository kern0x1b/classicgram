#import "TGStarsViewController.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Payments.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGForwardPicker.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
@implementation TGStarsViewController (FilteredTransactions)

- (void)loadTransactionsInto:(TGStarsListViewController *)list
				   direction:(NSString *)direction
					  offset:(NSString *)offset {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	TGClient *client = [TGClient shared];
	[client starTransactionsWithDirection:direction offset:offset limit:kStarsPageSize completion:^(NSArray *transactions, NSString *nextOffset) {
		typeof(self) strongSelf = weakSelf;
		TGStarsListViewController *strongList = weakList;
		if (!strongSelf || !strongList)
			return;
		if (![transactions isKindOfClass:[NSArray class]]) {
			strongList.emptyText = TGL(@"Stars.HistoryUnavailable", @"History Unavailable");
			[strongList finishLoadingWithMore:NO];
			return;
		}
		for (NSDictionary *transaction in transactions) {
			if (![transaction isKindOfClass:[NSDictionary class]])
				continue;
			NSString *date = [strongSelf subtitleForTransaction:transaction];
			long long stars = [transaction[@"stars"] longLongValue];
			long long starsNanos = [transaction[@"starsNanos"] longLongValue];
			NSString *amount = [strongSelf starsText:stars nanos:starsNanos signed:YES];
			NSString *subtitle = date.length
				? [NSString stringWithFormat:@"%@ · %@", amount, date]
				: amount;
			NSString *who = [strongSelf counterpartyForTransaction:transaction];
			[strongList appendRow:TGStarsRow(who, subtitle, nil, ^{
				typeof(self) innerSelf = weakSelf;
				if (innerSelf)
					[innerSelf pushTransactionDetails:transaction];
			})];
		}
		NSString *next = [nextOffset isKindOfClass:[NSString class]] ? nextOffset : @"";
		BOOL more = next.length > 0 && transactions.count > 0;
		if (more) {
			strongList.loadMoreBlock = ^{
				typeof(self) innerSelf = weakSelf;
				TGStarsListViewController *innerList = weakList;
				if (innerSelf && innerList)
					[innerSelf loadTransactionsInto:innerList direction:direction offset:next];
			};
		} else {
			strongList.loadMoreBlock = nil;
		}
		[strongList finishLoadingWithMore:more];
	}];
}

- (void)pushTransactionsWithDirection:(NSString *)direction title:(NSString *)title {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:title];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.FilteredTransactions.NoPayments", @"No Payments");
	[self.navigationController pushViewController:list animated:YES];
	[self loadTransactionsInto:list direction:direction offset:@""];
}

@end
