#import "TGClient+ChatState.h"
#import "TGDateUtils.h"
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
#import "TGPaymentWebViewController.h"
#import "TGFlattenPayments.h"
@implementation TGStarsViewController (Invoices)

- (NSArray *)pairsForPaymentForm:(NSDictionary *)form {
	BOOL isStars = [form[@"isStars"] boolValue];

	NSMutableArray *pairs = [NSMutableArray array];
	NSString *currency = form[@"currency"];
	if (isStars) {
		[pairs addObject:@[ TGL(@"Chat.PostSuggestion.TablePrice", @"Price"), [self starsText:[form[@"starCount"] longLongValue] signed:NO] ]];
	} else {
		if ([currency isKindOfClass:[NSString class]] && currency.length) {
			[pairs addObject:@[ TGL(@"Chat.PostSuggestion.TablePrice", @"Price"), [NSString stringWithFormat:@"%@ %@", currency, TGPayDecimalAmount([form[@"totalAmount"] longLongValue], currency)] ]];
		}
	}
	NSArray *parts = form[@"priceParts"];
	if ([parts isKindOfClass:[NSArray class]]) {
		for (NSDictionary *part in parts) {
			if (![part isKindOfClass:[NSDictionary class]])
				continue;
			NSString *label = part[@"label"];
			if (![label isKindOfClass:[NSString class]] || !label.length)
				continue;
			[pairs addObject:@[ label, TGPayDecimalAmount([part[@"amount"] longLongValue], currency) ]];
		}
	}
	int64_t sellerId = [form[@"sellerBotUserId"] longLongValue];
	if (sellerId) {
		NSString *seller = [[TGClient shared] nameForUserId:sellerId];
		if (seller.length)
			[pairs addObject:@[ TGL(@"Stars.Invoice.Seller", @"Seller"), seller ]];
	}

	return pairs;
}

- (NSDictionary *)payWithStarsActionForForm:(NSDictionary *)form
									  price:(long long)price
								 controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(TGL(@"Stars.Transfer.PayWithStars", @"Pay With Stars"),
		[self starsText:price signed:NO], NO, ^{
			typeof(self) strongSelf = weakSelf;
			TGStarsDetailViewController *strongController = weakController;
			if (!strongSelf || !strongController)
				return;
			NSString *itemTitle = [form[@"title"] isKindOfClass:[NSString class]] ? form[@"title"] : @"";
			NSString *sellerName = [[TGClient shared] nameForUserId:[form[@"sellerBotUserId"] longLongValue]];
			NSString *message = (itemTitle.length && sellerName.length)
				? [NSString stringWithFormat:
						TGL(@"Stars.Transfer.Info", @"Do you want to buy %1$@ in %2$@ for %3$@?"),
					itemTitle, sellerName, [strongSelf starsText:price signed:NO]]
				: [NSString stringWithFormat:
						TGL(@"Stars.WillBeTakenFromYourBalance", @"%@ will be taken from your balance."),
					[strongSelf starsText:price signed:NO]];
			[strongSelf confirmWithTitle:TGL(@"Stars.Transfer.PayWithStars", @"Pay With Stars")
								 message:message
								  action:TGL(@"Checkout.PayNone", @"Pay")
								   block:^{
									   typeof(self) innerSelf = weakSelf;
									   if (!innerSelf || strongController.busy)
										   return;
									   strongController.busy = YES;
									   [strongController.tableView reloadData];
									   [[TGClient shared] payStarsPaymentForm:form completion:^(BOOL ok) {
										   typeof(self) doneSelf = weakSelf;
										   if (doneSelf)
											   [doneSelf finishAction:strongController
															  success:ok
															  failure:TGL(@"Stars.ThePaymentWasNotAccepted", @"The payment was not accepted.")];
									   }];
								   }];
		});
}

- (void)pushPaymentForm:(NSDictionary *)form {
	[self pushPaymentForm:form intoNavigation:self.navigationController];
}

- (void)pushPaymentForm:(NSDictionary *)form
		 intoNavigation:(UINavigationController *)nav {
	NSString *title = form[@"title"];
	if (![title isKindOfClass:[NSString class]] || !title.length)
		title = TGL(@"Watch.Message.Invoice", @"Invoice");
	BOOL isStars = [form[@"isStars"] boolValue];

	NSString *description = form[@"description"];
	if (![description isKindOfClass:[NSString class]] || !description.length)
		description = nil;

	NSArray *pairs = [self pairsForPaymentForm:form];
	TGStarsDetailViewController *controller =
		[[TGStarsDetailViewController alloc] initWithTitle:title pairs:pairs comment:description];
	if (self.explicitNavigationController)
		controller.retainedHost = self;
	if (isStars) {
		long long price = [form[@"starCount"] longLongValue];
		NSDictionary *payAction = [self payWithStarsActionForForm:form price:price controller:controller];
		[controller setActions:@[ payAction ]];
		controller.actionsComment = TGL(@"Stars.Invoice.ExpiresPaySoonAfterOpening", @"The invoice expires, so pay it soon after opening it.");
	} else {
		NSString *providerType = form[@"providerType"];
		NSString *providerUrl = form[@"providerUrl"];
		if ([providerType isEqualToString:@"paymentProviderOther"] && providerUrl.length) {
			NSDictionary *payAction = [self payWithHostedPageActionForForm:form url:providerUrl controller:controller];
			[controller setActions:@[ payAction ]];
			controller.actionsComment = TGL(@"Stars.Invoice.YouWillPayOnTheProvidersPage", @"You will pay on the provider's own page.");
		} else {
			controller.actionsComment = nil;
			controller.comment = description.length
				? [NSString stringWithFormat:@"%@\n\n%@", description, TGL(@"Stars.Invoice.NeedsACardEnteredDirectly", @"This invoice needs a card entered directly with the provider, which this app cannot do yet.")]
				: TGL(@"Stars.Invoice.NeedsACardEnteredDirectly", @"This invoice needs a card entered directly with the provider, which this app cannot do yet.");
		}
	}
	[nav pushViewController:controller animated:YES];
}

- (NSDictionary *)payWithHostedPageActionForForm:(NSDictionary *)form
											 url:(NSString *)url
									  controller:(TGStarsDetailViewController *)controller {
	__weak TGStarsDetailViewController *weakController = controller;
	NSString *priceLabel = @"";
	NSArray *pairs = [self pairsForPaymentForm:form];
	if (pairs.count && [pairs[0] isKindOfClass:[NSArray class]] &&
		[pairs[0] count] > 1)
		priceLabel = pairs[0][1];
	return TGStarsAction(TGL(@"Checkout.PayNone", @"Pay"), priceLabel, NO, ^{
		TGStarsDetailViewController *strongController = weakController;
		if (!strongController || strongController.busy)
			return;
		strongController.busy = YES;
		[strongController.tableView reloadData];
		TGPaymentWebViewController *web =
			[[TGPaymentWebViewController alloc] initWithURLString:url];
		[strongController.navigationController pushViewController:web animated:YES];
	});
}

+ (void)presentInvoiceNamed:(NSString *)name
		 fromViewController:(UIViewController *)presenter {
	UINavigationController *nav = presenter.navigationController;
	if (!nav || !name.length)
		return;
	[[TGClient shared] paymentFormForInvoiceName:name
									  completion:^(NSDictionary *form) {
										  if (![form isKindOfClass:[NSDictionary class]])
											  return;
										  TGStarsViewController *host = [[TGStarsViewController alloc] init];
										  host.explicitNavigationController = nav;
										  [host pushPaymentForm:form intoNavigation:nav];
									  }];
}

+ (void)presentInvoiceForMessage:(int64_t)messageId
							chat:(int64_t)chatId
			  fromViewController:(UIViewController *)presenter {
	UINavigationController *nav = presenter.navigationController;
	if (!nav)
		return;
	TGClient *client = [TGClient shared];
	[client paymentFormForMessage:messageId
						   inChat:chatId
					   completion:^(NSDictionary *form) {
						   if (![form isKindOfClass:[NSDictionary class]]) {
							   NSString *message = TGL(@"Chat.ErrorInvoiceNotFound", @"Invoice not found.");
							   TGAlertView *alert = [[TGAlertView alloc] initWithTitle:@""
																			   message:message
																	 cancelButtonTitle:nil
																		 okButtonTitle:TGL(@"Common.OK", @"OK")
																	   completionBlock:nil];
							   [alert show];
							   return;
						   }
						   TGStarsViewController *host = [[TGStarsViewController alloc] init];
						   host.explicitNavigationController = nav;
						   [host pushPaymentForm:form intoNavigation:nav];
					   }];
}

+ (void)presentReceiptForMessage:(int64_t)messageId
							chat:(int64_t)chatId
			  fromViewController:(UIViewController *)presenter {
	UINavigationController *nav = presenter.navigationController;
	if (!nav)
		return;
	TGClient *client = [TGClient shared];
	[client paymentReceiptForMessage:messageId
							  inChat:chatId
						  completion:^(NSDictionary *receipt) {
							  if (![receipt isKindOfClass:[NSDictionary class]]) {
								  NSString *message = TGL(@"Stars.TheReceiptIsNotAvailable", @"The receipt is not available.");
								  TGAlertView *alert = [[TGAlertView alloc] initWithTitle:@""
																				  message:message
																		cancelButtonTitle:nil
																			okButtonTitle:TGL(@"Common.OK", @"OK")
																		  completionBlock:nil];
								  [alert show];
								  return;
							  }
							  TGStarsViewController *host = [[TGStarsViewController alloc] init];
							  host.explicitNavigationController = nav;
							  [host pushReceipt:receipt intoNavigation:nav];
						  }];
}

static NSMutableSet *TGPendingPaidMediaUnlocks;

static NSString *TGPaidMediaUnlockKey(int64_t chatId, int64_t messageId) {
	return [NSString stringWithFormat:@"%lld:%lld", chatId, messageId];
}

+ (void)resetPaidMediaUnlocksForAccountSwitch {
	[TGPendingPaidMediaUnlocks removeAllObjects];
}

+ (void)presentPaidMediaUnlockForMessage:(int64_t)messageId
									chat:(int64_t)chatId
							   starCount:(long long)starCount
					  fromViewController:(UIViewController *)presenter {
	TGStarsViewController *host = [[TGStarsViewController alloc] init];
	[host confirmWithTitle:TGL(@"Stars.Transfer.UnlockTitle", @"Unlock Media")
				   message:[NSString stringWithFormat:
								   TGL(@"Stars.Transfer.UnlockInfo", @"%@ will be taken from your balance to reveal this media."),
							   [host starsText:starCount signed:NO]]
					action:TGL(@"Stars.Transfer.Pay", @"Confirm and Pay")
					 block:^{
						 NSString *key = TGPaidMediaUnlockKey(chatId, messageId);
						 if (!TGPendingPaidMediaUnlocks)
							 TGPendingPaidMediaUnlocks = [NSMutableSet set];
						 if ([TGPendingPaidMediaUnlocks containsObject:key])
							 return;
						 [TGPendingPaidMediaUnlocks addObject:key];
						 TGClient *client = [TGClient shared];
						 [client unlockPaidMediaInMessage:messageId
												   inChat:chatId
											   completion:^(BOOL ok) {
												   [TGPendingPaidMediaUnlocks removeObject:key];
												   if (ok)
													   return;
												   NSString *message = TGL(@"Stars.MediaCouldNotBeUnlocked", @"This media could not be unlocked.");
												   TGAlertView *alert = [[TGAlertView alloc] initWithTitle:@""
																								   message:message
																						 cancelButtonTitle:nil
																							 okButtonTitle:TGL(@"Common.OK", @"OK")
																						   completionBlock:nil];
												   [alert show];
											   }];
					 }];
}

- (NSArray *)pairsForReceipt:(NSDictionary *)receipt {
	BOOL isStars = [receipt[@"isStars"] boolValue];
	NSMutableArray *pairs = [NSMutableArray array];
	NSString *currency = receipt[@"currency"];
	if (isStars) {
		[pairs addObject:@[ TGL(@"Chat.PostSuggestion.TablePrice", @"Price"), [self starsText:[receipt[@"starCount"] longLongValue] signed:NO] ]];
	} else {
		if ([currency isKindOfClass:[NSString class]] && currency.length)
			[pairs addObject:@[ TGL(@"Chat.PostSuggestion.TablePrice", @"Price"), [NSString stringWithFormat:@"%@ %@", currency, TGPayDecimalAmount([receipt[@"totalAmount"] longLongValue], currency)] ]];
	}
	NSArray *parts = receipt[@"priceParts"];
	if ([parts isKindOfClass:[NSArray class]]) {
		for (NSDictionary *part in parts) {
			if (![part isKindOfClass:[NSDictionary class]])
				continue;
			NSString *label = part[@"label"];
			if (![label isKindOfClass:[NSString class]] || !label.length)
				continue;
			[pairs addObject:@[ label, TGPayDecimalAmount([part[@"amount"] longLongValue], currency) ]];
		}
	}
	NSTimeInterval date = [receipt[@"date"] doubleValue];
	if (date > 0) {
		[pairs addObject:@[ TGL(@"Stars.Transaction.Date", @"Date"),
			[TGDateUtils stringForFullDateAndTime:(int)date] ]];
	}
	NSString *credentialsTitle = receipt[@"credentialsTitle"];
	if ([credentialsTitle isKindOfClass:[NSString class]] && credentialsTitle.length)
		[pairs addObject:@[ TGL(@"Stars.Invoice.PaidWith", @"Paid With"), credentialsTitle ]];
	NSString *shippingOption = receipt[@"shippingOption"];
	if ([shippingOption isKindOfClass:[NSString class]] && shippingOption.length)
		[pairs addObject:@[ TGL(@"Checkout.ShippingMethod", @"Shipping Method"), shippingOption ]];
	int64_t sellerId = [receipt[@"sellerBotUserId"] longLongValue];
	if (sellerId) {
		NSString *seller = [[TGClient shared] nameForUserId:sellerId];
		if (seller.length)
			[pairs addObject:@[ TGL(@"Stars.Invoice.Seller", @"Seller"), seller ]];
	}
	NSString *transactionId = receipt[@"transactionId"];
	if ([transactionId isKindOfClass:[NSString class]] && transactionId.length)
		[pairs addObject:@[ TGL(@"Stars.Transaction.Id", @"Transaction ID"), transactionId ]];
	return pairs;
}

- (void)pushReceipt:(NSDictionary *)receipt intoNavigation:(UINavigationController *)nav {
	NSString *title = receipt[@"title"];
	if (![title isKindOfClass:[NSString class]] || !title.length)
		title = TGL(@"Checkout.Receipt.Title", @"Receipt");
	NSString *description = receipt[@"description"];
	if (![description isKindOfClass:[NSString class]] || !description.length)
		description = nil;
	NSArray *pairs = [self pairsForReceipt:receipt];
	TGStarsDetailViewController *controller =
		[[TGStarsDetailViewController alloc] initWithTitle:title pairs:pairs comment:description];
	if (self.explicitNavigationController)
		controller.retainedHost = self;
	[nav pushViewController:controller animated:YES];
}

@end
