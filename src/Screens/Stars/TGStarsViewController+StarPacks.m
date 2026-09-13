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
#import "TGFlattenPayments.h"
@implementation TGStarsViewController (StarPacks)

+ (void)presentNotEnoughStarsAlertFromViewController:(UIViewController *)presenter {
	__weak UIViewController *weakPresenter = presenter;
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Stars.Intro.Title", @"Telegram Stars")
						 message:TGL(@"Stars.NotEnoughStars", @"You don't have enough Stars for this.")
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   okButtonTitle:TGL(@"Stars.Purchase.GetStars", @"Get Stars")
				 completionBlock:^(bool okButtonPressed) {
					 UIViewController *strongPresenter = weakPresenter;
					 UINavigationController *nav = strongPresenter.navigationController;
					 if (!okButtonPressed || !nav)
						 return;
					 TGStarsViewController *host = [[TGStarsViewController alloc] init];
					 host.opensStarPacks = YES;
					 [nav pushViewController:host animated:YES];
				 }];
	[alert show];
}

- (NSString *)priceTextForOption:(NSDictionary *)option {
	NSString *currency = option[@"currency"];
	if (![currency isKindOfClass:[NSString class]] || !currency.length)
		return @"";
	return [NSString stringWithFormat:@"%@ %@", currency,
		TGPayDecimalAmount([option[@"amount"] longLongValue], currency)];
}

- (void)fillList:(TGStarsListViewController *)list withOptions:(NSArray *)options {
	if (![options isKindOfClass:[NSArray class]])
		return;
	for (NSDictionary *option in options) {
		if (![option isKindOfClass:[NSDictionary class]])
			continue;
		NSString *title = [self starsText:[option[@"stars"] longLongValue] signed:NO];
		if ([option[@"isAdditional"] boolValue])
			title = [NSString stringWithFormat:@"%@ %@", title, TGL(@"Stars.StarPacks.ExtraSuffix", @"(extra)")];
		[list appendRow:TGStarsRow(title, nil, [self priceTextForOption:option], nil)];
	}
}

- (void)pushStarPacksForUser:(int64_t)userId name:(NSString *)name {
	TGStarsListViewController *list = [[TGStarsListViewController alloc]
		initWithTitle:name.length ? name : TGL(@"Stars.Purchase.GiftStars", @"Gift Stars To")];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.StarPacks.NoPacksAvailable", @"No Packs Available");
	list.comment = TGL(@"Stars.StarPacks.ThesePacksMayBeBoughtAsGift", @"These are the packs that may be bought as a gift for this contact.");
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[self.navigationController pushViewController:list animated:YES];
	TGClient *client = [TGClient shared];
	[client starGiftPaymentOptionsForUser:userId
							   completion:^(NSArray *options) {
								   typeof(self) strongSelf = weakSelf;
								   TGStarsListViewController *strongList = weakList;
								   if (!strongSelf || !strongList)
									   return;
								   [strongSelf fillList:strongList withOptions:options];
								   [strongList finishLoadingWithMore:NO];
							   }];
}

- (void)pushStarPacks {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:TGL(@"Stars.Purchase.GetStars", @"Get Stars")];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.StarPacks.NoPacksAvailable", @"No Packs Available");
	list.comment = TGL(@"Stars.StarPacks.PricesShownInSmallestUnit", @"Prices are shown in the smallest unit of each currency. Stars are bought outside this client.");
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[self.navigationController pushViewController:list animated:YES];
	[[TGClient shared] starPaymentOptionsWithCompletion:^(NSArray *options) {
		typeof(self) strongSelf = weakSelf;
		TGStarsListViewController *strongList = weakList;
		if (!strongSelf || !strongList)
			return;
		[strongSelf fillList:strongList withOptions:options];
		[strongList appendRow:TGStarsRow(TGL(@"Stars.StarPacks.PacksForAContact", @"Packs for a Contact"), nil, nil, ^{
			typeof(self) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			[innerSelf pickUserWithTitle:TGL(@"Stars.Purchase.GiftStars", @"Gift Stars To")
								 handler:^(int64_t userId, NSString *name) {
									 typeof(self) pickSelf = weakSelf;
									 if (pickSelf)
										 [pickSelf pushStarPacksForUser:userId name:name];
								 }];
		})];
		[strongList finishLoadingWithMore:NO];
	}];
}

@end
