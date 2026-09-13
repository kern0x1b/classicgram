#import "TGStarsViewController.h"
#import "TGFriendlyError.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Payments.h"
#import "TGWebViewController.h"
#import "TGForwardPicker.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGFlattenPayments.h"
@implementation TGStarsViewController (Taps)

- (NSArray *)pairsForTransaction:(NSDictionary *)transaction {
	NSMutableArray *pairs = [NSMutableArray array];
	long long stars = [transaction[@"stars"] longLongValue];
	long long starsNanos = [transaction[@"starsNanos"] longLongValue];
	BOOL isNegative = stars < 0 || (stars == 0 && starsNanos < 0);
	[pairs addObject:@[ isNegative ? TGL(@"Stars.Transaction.Spent", @"Spent") : TGL(@"Stars.Transaction.Earned", @"Earned"),
		[self starsText:(isNegative ? -stars : stars) nanos:starsNanos signed:NO] ]];

	NSString *date = [self dateTextFromValue:transaction[@"date"]];
	if (date.length)
		[pairs addObject:@[ TGL(@"Stars.Transaction.Date", @"Date"), date ]];

	NSString *type = transaction[@"type"];
	if ([type isKindOfClass:[NSString class]] && type.length)
		[pairs addObject:@[ TGL(@"Stars.Transaction.TypeLabel", @"Type"), TGPayHumanType(type) ]];

	NSString *withdrawalState = transaction[@"withdrawalState"];
	if ([withdrawalState isKindOfClass:[NSString class]] && withdrawalState.length) {
		NSString *statusText;
		if ([withdrawalState isEqualToString:@"succeeded"])
			statusText = TGL(@"Stars.Transaction.Withdrawal.Succeeded", @"Completed");
		else if ([withdrawalState isEqualToString:@"failed"])
			statusText = TGL(@"Stars.Transaction.Withdrawal.Failed", @"Failed");
		else
			statusText = TGL(@"Stars.Transaction.Withdrawal.Pending", @"In Progress");
		[pairs addObject:@[ TGL(@"Gift.View.Status", @"Status"), statusText ]];
	}

	if ([self transactionIsRefund:transaction])
		[pairs addObject:@[ TGL(@"Stars.Transaction.Refunded", @"Refunded"), TGL(@"Common.Yes", @"Yes") ]];

	NSString *transactionId = transaction[@"id"];
	if (![transactionId isKindOfClass:[NSString class]])
		transactionId = nil;
	if (transactionId.length)
		[pairs addObject:@[ TGL(@"Stars.Transaction.Id", @"Transaction ID"), transactionId ]];

	return pairs;
}

- (void)pushTransactionDetails:(NSDictionary *)transaction {
	NSString *transactionId = transaction[@"id"];
	if (![transactionId isKindOfClass:[NSString class]])
		transactionId = nil;

	NSString *title = [self counterpartyForTransaction:transaction];
	NSString *comment = transaction[@"description"];
	if (![comment isKindOfClass:[NSString class]] || !comment.length)
		comment = nil;

	TGStarsDetailViewController *controller = [TGStarsDetailViewController alloc];
	controller = [controller initWithTitle:title
									 pairs:[self pairsForTransaction:transaction]
								   comment:comment];

	[self.navigationController pushViewController:controller animated:YES];
}

- (void)finishAction:(TGStarsDetailViewController *)controller
			 success:(BOOL)success
			 failure:(NSString *)failureMessage {
	controller.busy = NO;
	if (!success) {
		[controller.tableView reloadData];
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Stars.Intro.Title", @"Telegram Stars")
							 message:failureMessage
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
					   okButtonTitle:nil
					 completionBlock:nil];
		[alert show];
		return;
	}
	if (self.explicitNavigationController) {
		[controller.navigationController popViewControllerAnimated:YES];
		return;
	}
	if (controller.navigationController == self.navigationController)
		[self.navigationController popToViewController:self animated:YES];
	[self reloadTapped];
}

- (void)confirmWithTitle:(NSString *)title
				 message:(NSString *)message
				  action:(NSString *)actionTitle
				   block:(void (^)(void))block {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:title
						 message:message
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   okButtonTitle:actionTitle
				 completionBlock:^(bool okButtonPressed) {
					 if (okButtonPressed && block)
						 block();
				 }];
	[alert show];
}

- (void)promptGiftMessageAndPrivacyWithCompletion:(void (^)(NSString *text, BOOL isPrivate))completion {
	__weak typeof(self) weakSelf = self;
	__block TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Gift.Send.Customize.MessagePlaceholder", @"Message (optional)")
						 message:nil
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   okButtonTitle:TGL(@"Common.Next", @"Next")
				 completionBlock:^(bool ok) {
					 if (!ok)
						 return;
					 NSString *text = @"";
					 if ([alert respondsToSelector:@selector(textFieldAtIndex:)]) {
						 UITextField *field = [alert textFieldAtIndex:0];
						 if (field.text.length)
							 text = [field.text stringByTrimmingCharactersInSet:
									 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
					 }
					 [weakSelf promptGiftPrivacyForText:text completion:completion];
				 }];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert show];
}

- (void)promptGiftPrivacyForText:(NSString *)text
					  completion:(void (^)(NSString *text, BOOL isPrivate))completion {
	NSArray *actions = @[
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Stars.SendWithMyName", @"Send with My Name")
											action:@"named"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Conversation.InputTextAnonymousPlaceholder", @"Send Anonymously")
											action:@"anon"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel")
											action:@"cancel"
											  type:TGActionSheetActionTypeCancel],
	];
	__weak typeof(self) weakSelf = self;
	TGActionSheet *actionSheet = [TGActionSheet alloc];
	actionSheet = [actionSheet initWithTitle:nil
									 actions:actions
								 actionBlock:^(id target, NSString *action) {
									 (void)target;
									 typeof(self) strongSelf = weakSelf;
									 if (strongSelf)
										 strongSelf.currentActionSheet = nil;
									 if ([action isEqualToString:@"cancel"] || !completion)
										 return;
									 completion(text, [action isEqualToString:@"anon"]);
								 }
									  target:self];
	self.currentActionSheet = actionSheet;
	[actionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1)
						  inView:self.view];
}

- (NSDictionary *)giftVisibilityActionForGift:(NSDictionary *)gift
									   giftId:(NSString *)giftId
								   controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	BOOL saved = [gift[@"isSaved"] boolValue];
	return TGStarsAction(TGL(@"Stars.GiftDetail.OnMyProfile", @"On My Profile"), saved ? TGL(@"PeerInfo.Gifts.Displayed", @"Displayed") : TGL(@"PeerInfo.Gifts.Hidden", @"Hidden"), NO, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		[[TGClient shared] setReceivedGift:giftId saved:!saved completion:^(BOOL ok, NSString *error) {
			typeof(self) innerSelf = weakSelf;
			TGStarsDetailViewController *innerController = weakController;
			if (!innerSelf || !innerController)
				return;
			if (!ok)
				[innerSelf showMessage:TGFriendlyErrorText(error, TGL(@"Stars.TheGiftCouldNotBeUpdated", @"The gift could not be updated."))];
			[innerSelf refreshGiftDetail:innerController giftId:giftId fallback:gift];
		}];
	});
}

- (NSDictionary *)giftPinActionForGift:(NSDictionary *)gift
								giftId:(NSString *)giftId
							controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	BOOL pinned = [gift[@"isPinned"] boolValue];
	return TGStarsAction(TGL(@"Stars.GiftDetail.PinnedOnProfile", @"Pinned on Profile"), pinned ? TGL(@"Common.Yes", @"Yes") : TGL(@"Common.No", @"No"), NO, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		[[TGClient shared] pinnedGiftIdsForCurrentUserWithCompletion:^(NSArray<NSString *> *currentPinnedIds) {
			typeof(self) fetchSelf = weakSelf;
			TGStarsDetailViewController *fetchController = weakController;
			if (!fetchSelf || !fetchController)
				return;
			NSArray *newPinnedIds = [fetchSelf pinnedGiftIdsTogglingGift:giftId
																   pinned:!pinned
														 currentPinnedIds:currentPinnedIds ?: [NSArray array]];
			[[TGClient shared] setPinnedGiftIds:newPinnedIds
									  completion:^(BOOL ok, NSString *error) {
										  typeof(self) innerSelf = weakSelf;
										  TGStarsDetailViewController *innerController = weakController;
										  if (!innerSelf || !innerController)
											  return;
										  if (!ok)
											  [innerSelf showMessage:TGFriendlyErrorText(error, TGL(@"Stars.TheGiftCouldNotBeUpdated", @"The gift could not be updated."))];
										  [innerSelf refreshGiftDetail:innerController giftId:giftId fallback:gift];
									  }];
		}];
	});
}

- (NSDictionary *)giftCollectionActionForGiftId:(NSString *)giftId {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"PeerInfo.Gifts.Context.AddToCollection", @"Add to Collection"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf pushCollectionPickerForGift:giftId];
	});
}

- (NSDictionary *)giftTransferActionForGiftId:(NSString *)giftId
										price:(long long)transferPrice
										 name:(NSString *)giftLabel
							  nextTransferDate:(long long)nextTransferDate
								   controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(TGL(@"Stars.GiftDetail.TransferToAContact", @"Transfer to a Contact"),
		transferPrice > 0 ? [self starsText:transferPrice signed:NO] : TGL(@"Stars.SendMessage.PriceFree", @"Free"), NO, ^{
			typeof(self) strongSelf = weakSelf;
			TGStarsDetailViewController *strongController = weakController;
			if (!strongSelf || !strongController)
				return;
			if (nextTransferDate > (long long)[[NSDate date] timeIntervalSince1970]) {
				[strongSelf showMessage:[NSString stringWithFormat:
					TGL(@"Gift.Transfer.NotYetAvailable", @"You will be able to transfer this gift on %@."),
					[strongSelf dateTextFromValue:@(nextTransferDate)]]];
				return;
			}
			[strongSelf proceedIfEnoughStarsForPrice:transferPrice then:^{
				typeof(self) proceedSelf = weakSelf;
				if (!proceedSelf)
					return;
				[proceedSelf pickUserWithTitle:TGL(@"Gift.Transfer.Title", @"Transfer To")
									  handler:^(int64_t userId, NSString *name) {
									  typeof(self) innerSelf = weakSelf;
									  if (!innerSelf)
										  return;
									  NSString *priceText = [innerSelf starsText:transferPrice signed:NO];
									  [innerSelf confirmWithTitle:TGL(@"Gift.Transfer.Confirmation.Title", @"Transfer Gift")
														 message:transferPrice > 0
											  ? [NSString stringWithFormat:
														TGL(@"Gift.Transfer.Confirmation.Text", @"Do you want to transfer ownership of %1$@ to %2$@ for %3$@?"),
													giftLabel, name, priceText]
											  : [NSString stringWithFormat:
														TGL(@"Gift.Transfer.Confirmation.TextFree", @"Do you want to transfer ownership of %1$@ to %2$@?"),
													giftLabel, name]
														  action:transferPrice > 0
											  ? [NSString stringWithFormat:@"%@ %@", TGL(@"Gift.Transfer.Confirmation.Transfer", @"Transfer for"), priceText]
											  : TGL(@"Gift.Transfer.Confirmation.TransferFree", @"Transfer")
														   block:^{
															   typeof(self) sendSelf = weakSelf;
															   TGStarsDetailViewController *sendController = weakController;
															   if (!sendSelf || !sendController)
																   return;
															   sendController.busy = YES;
															   [sendController.tableView reloadData];
															   TGClient *client = [TGClient shared];
															   [client transferReceivedGift:giftId
																					 toUser:userId
																				  starCount:transferPrice
																				 completion:^(BOOL ok, NSString *error) {
																					 typeof(self) doneSelf = weakSelf;
																					 TGStarsDetailViewController *doneController = weakController;
																					 if (doneSelf && doneController)
																						 [doneSelf finishAction:doneController
																								   success:ok
																								   failure:TGFriendlyErrorText(error, TGL(@"Stars.TheGiftCouldNotBeTransferred", @"The gift could not be transferred."))];
																				 }];
														   }];
								  }];
				}];
		});
}

- (NSDictionary *)giftConvertActionForGiftId:(NSString *)giftId
									   price:(long long)sell
										name:(NSString *)name
								  controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	NSString *value = [self starsText:sell signed:NO];
	NSString *displayName = name.length ? name : TGL(@"Gift.View.Title", @"Gift");
	return TGStarsAction(TGL(@"Gift.Convert.Title", @"Convert to Stars"), value, YES, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		[strongSelf confirmWithTitle:TGL(@"Gift.Convert.Title", @"Convert to Stars")
							 message:[NSString stringWithFormat:
											 TGL(@"Gift.Convert.Text", @"Do you want to convert this gift from %1$@ to %2$@?\n\nThis will permanently destroy the gift."),
										 displayName, value]
							  action:TGL(@"Gift.Convert.Convert", @"Convert")
							   block:^{
								   typeof(self) innerSelf = weakSelf;
								   if (!innerSelf)
									   return;
								   strongController.busy = YES;
								   [strongController.tableView reloadData];
								   [[TGClient shared] sellReceivedGift:giftId completion:^(BOOL ok, NSString *error) {
									   typeof(self) doneSelf = weakSelf;
									   if (!doneSelf)
										   return;
									   [doneSelf finishAction:strongController
													  success:ok
													  failure:TGFriendlyErrorText(error, TGL(@"Stars.ThisGiftCanNoLongerBeConverted", @"This gift can no longer be converted."))];
								   }];
							   }];
	});
}

- (NSDictionary *)giftUpgradeActionForGiftId:(NSString *)giftId
									   price:(long long)upgrade
							prepaidStarCount:(long long)prepaidStarCount
								  controller:(TGStarsDetailViewController *)controller {
	BOOL isPrepaid = prepaidStarCount > 0;
	long long effectiveUpgrade = isPrepaid ? 0 : upgrade;
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	NSString *value = effectiveUpgrade > 0 ? [self starsText:effectiveUpgrade signed:NO] : TGL(@"Stars.SendMessage.PriceFree", @"Free");
	return TGStarsAction(TGL(@"Stars.GiftDetail.UpgradeToUnique", @"Upgrade to Unique"), value, NO, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		[strongSelf proceedIfEnoughStarsForPrice:effectiveUpgrade then:^{
			typeof(self) proceedSelf = weakSelf;
			TGStarsDetailViewController *proceedController = weakController;
			if (!proceedSelf || !proceedController)
				return;
			[proceedSelf confirmWithTitle:TGL(@"Gift.Upgrade.Title", @"Upgrade Gift")
								 message:isPrepaid
					? TGL(@"Stars.GiftDetail.UpgradeAlreadyPaidFor", @"This upgrade has already been paid for.")
					: (effectiveUpgrade > 0
					? [NSString stringWithFormat:
							  TGL(@"Stars.GiftDetail.TurnThisGiftIntoAUniqueCollectibleFor", @"Turn this gift into a unique collectible for %@?"), value]
					: TGL(@"Stars.GiftDetail.TurnThisGiftIntoAUniqueCollectible", @"Turn this gift into a unique collectible?"))
								  action:TGL(@"Gift.View.Upgrade", @"Upgrade")
								   block:^{
									   proceedController.busy = YES;
									   [proceedController.tableView reloadData];
									   TGClient *client = [TGClient shared];
									   [client upgradeReceivedGift:giftId
											   keepOriginalDetails:YES
														 starCount:effectiveUpgrade
														completion:^(NSDictionary *upgraded, NSString *error) {
															typeof(self) innerSelf = weakSelf;
															if (!innerSelf)
																return;
															[innerSelf finishAction:strongController
																			success:[upgraded isKindOfClass:[NSDictionary class]]
																			failure:TGFriendlyErrorText(error, TGL(@"Stars.TheUpgradeCouldNotBeCompleted", @"The upgrade could not be completed."))];
														}];
								   }];
		}];
	});
}

- (NSDictionary *)giftResalePriceActionForGiftId:(NSString *)giftId
										   price:(long long)resale
									  controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(resale > 0 ? TGL(@"Stars.GiftDetail.ChangeSalePrice", @"Change Sale Price") : TGL(@"Stars.GiftDetail.SellThisGift", @"Sell This Gift"),
		resale > 0 ? [self starsText:resale signed:NO] : nil, NO, ^{
			typeof(self) strongSelf = weakSelf;
			TGStarsDetailViewController *strongController = weakController;
			if (!strongSelf || !strongController)
				return;
			[strongSelf askResalePriceForGift:giftId controller:strongController];
		});
}

- (NSDictionary *)giftRemoveFromSaleActionForGiftId:(NSString *)giftId
										 controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(TGL(@"Stars.GiftDetail.RemoveFromSale", @"Remove From Sale"), nil, YES, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		[strongSelf confirmWithTitle:TGL(@"Gift.View.Resale.Unlist.Title", @"Unlist This Item?")
							 message:TGL(@"Gift.View.Resale.Unlist.Text", @"It will no longer be for sale.")
							  action:TGL(@"Gift.View.Resale.Unlist.Unlist", @"Unlist")
							   block:^{
								   typeof(self) innerSelf = weakSelf;
								   TGStarsDetailViewController *innerController = weakController;
								   if (!innerSelf || !innerController)
									   return;
								   innerController.busy = YES;
								   [innerController.tableView reloadData];
								   TGClient *client = [TGClient shared];
								   [client setResalePrice:0
										   forReceivedGift:giftId
												completion:^(BOOL ok, NSString *error) {
													typeof(self) doneSelf = weakSelf;
													if (!doneSelf)
														return;
													[doneSelf finishAction:innerController
																  success:ok
																  failure:TGFriendlyErrorText(error, TGL(@"Stars.TheListingCouldNotBeRemoved", @"The listing could not be removed."))];
												}];
							   }];
	});
}

- (NSArray *)giftActionsFor:(NSDictionary *)gift
				 controller:(TGStarsDetailViewController *)controller {
	NSString *giftId = gift[@"giftId"];
	if (![giftId isKindOfClass:[NSString class]] || !giftId.length)
		return nil;

	NSMutableArray *actions = [NSMutableArray array];

	if ([gift[@"tgChannelGift"] boolValue])
		return actions;

	NSString *displayTitle = gift[@"title"];
	if (![displayTitle isKindOfClass:[NSString class]] || !displayTitle.length)
		displayTitle = TGL(@"Gift.View.Title", @"Gift");
	NSNumber *displayNumber = gift[@"number"];
	NSString *displayLabel = ([displayNumber isKindOfClass:[NSNumber class]] && [displayNumber longLongValue])
		? [NSString stringWithFormat:@"%@ #%lld", displayTitle, [displayNumber longLongValue]]
		: displayTitle;

	[actions addObject:[self giftVisibilityActionForGift:gift
												  giftId:giftId
											  controller:controller]];
	if ([gift[@"isUnique"] boolValue] && [gift[@"isSaved"] boolValue]) {
		[actions addObject:[self giftPinActionForGift:gift
											   giftId:giftId
										   controller:controller]];
	}
	[actions addObject:[self giftCollectionActionForGiftId:giftId]];

	if ([gift[@"isUnique"] boolValue] && [gift[@"canTransfer"] boolValue]) {
		[actions addObject:[self giftTransferActionForGiftId:giftId
													   price:[gift[@"transferStarCount"] longLongValue]
													name:displayLabel
											nextTransferDate:[gift[@"nextTransferDate"] longLongValue]
												  controller:controller]];
	}

	long long sell = [gift[@"sellStarCount"] longLongValue];
	if (sell > 0 && ![gift[@"isUnique"] boolValue]) {
		[actions addObject:[self giftConvertActionForGiftId:giftId
													  price:sell
													   name:displayLabel
												 controller:controller]];
	}

	long long upgrade = [gift[@"upgradeStarCount"] longLongValue];
	long long prepaidUpgrade = [gift[@"prepaidUpgradeStarCount"] longLongValue];
	if ([gift[@"canUpgrade"] boolValue] && ![gift[@"isUnique"] boolValue]) {
		[actions addObject:[self giftUpgradeActionForGiftId:giftId
													  price:upgrade
										   prepaidStarCount:prepaidUpgrade
												 controller:controller]];
	}

	if ([gift[@"isUnique"] boolValue]) {
		long long resale = [gift[@"resaleStarCount"] longLongValue];
		[actions addObject:[self giftResalePriceActionForGiftId:giftId
														  price:resale
													 controller:controller]];
		if (resale > 0) {
			[actions addObject:[self giftRemoveFromSaleActionForGiftId:giftId
															controller:controller]];
		}

		NSString *uniqueName = gift[@"name"];
		if ([uniqueName isKindOfClass:[NSString class]] && uniqueName.length) {
			[actions addObjectsFromArray:[self giftPublicLinkActionsForName:uniqueName]];
		}

		NSNumber *coloursId = gift[@"giftColoursId"];
		if ([coloursId isKindOfClass:[NSNumber class]]) {
			[actions addObject:[self giftUseColoursActionForId:[coloursId longLongValue]
													controller:controller]];
		}

		if ([gift[@"canTransfer"] boolValue]) {
			[actions addObject:[self giftWithdrawActionForGiftId:giftId controller:controller]];
		}
	}

	return actions;
}

- (NSArray *)giftPublicLinkActionsForName:(NSString *)name {
	NSString *link = [NSString stringWithFormat:@"https://t.me/nft/%@", name];
	__weak typeof(self) weakSelf = self;
	NSMutableArray *actions = [NSMutableArray array];
	[actions addObject:TGStarsAction(TGL(@"Gift.View.Context.CopyLink", @"Copy Link"), nil, NO, ^{
		[UIPasteboard generalPasteboard].string = link;
	})];
	[actions addObject:TGStarsAction(TGL(@"Gift.View.Context.Share", @"Share"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		UIActivityViewController *share = [[UIActivityViewController alloc]
			initWithActivityItems:@[ link ]
			applicationActivities:nil];
		[strongSelf presentViewController:share animated:YES completion:nil];
	})];
	return actions;
}

- (NSDictionary *)giftUseColoursActionForId:(long long)coloursId
								 controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(TGL(@"ProfileColorSetup.ApplyStyle", @"Use These Colours for My Profile"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		strongController.busy = YES;
		[strongController.tableView reloadData];
		[[TGClient shared] setProfileColoursFromGiftColoursId:coloursId completion:^(BOOL ok) {
			typeof(self) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			[innerSelf finishAction:strongController
							success:ok
							failure:TGL(@"Stars.TheProfileColoursCouldNotBeApplied", @"The profile colours could not be applied.")];
		}];
	});
}

- (NSDictionary *)giftWithdrawActionForGiftId:(NSString *)giftId
								   controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(TGL(@"Gift.Withdraw.Title", @"Withdraw as NFT"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		[strongSelf promptForPasswordWithTitle:TGL(@"TwoStepAuth.EnterPasswordTitle", @"Password")
									   message:TGL(@"Gift.Withdraw.EnterPassword.Text", @"Enter your 2-Step Verification password to withdraw this gift to the TON blockchain.")
								   actionTitle:TGL(@"Gift.Withdraw.Title", @"Withdraw as NFT")
									   handler:^(NSString *password) {
										   typeof(self) innerSelf = weakSelf;
										   TGStarsDetailViewController *innerController = weakController;
										   if (!innerSelf || !innerController)
											   return;
										   innerController.busy = YES;
										   [innerController.tableView reloadData];
										   TGClient *client = [TGClient shared];
										   [client withdrawalUrlForUpgradedGift:giftId
																	   password:password
																	 completion:^(NSString *url, NSString *error) {
																		 typeof(self) doneSelf = weakSelf;
																		 TGStarsDetailViewController *doneController = weakController;
																		 if (!doneSelf || !doneController)
																			 return;
																		 doneController.busy = NO;
																		 [doneController.tableView reloadData];
																		 if (!url.length) {
																			 [doneSelf showMessage:TGFriendlyErrorText(error, TGL(@"Stars.GiftDetail.TheWithdrawalLinkCouldNotBeCreated", @"The withdrawal link could not be created."))];
																			 return;
																		 }
																		 [TGWebViewController openURLString:url fromViewController:doneSelf];
																	 }];
									   }];
	});
}

- (void)askResalePriceForGift:(NSString *)giftId
				   controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	__block TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Stars.SellGift.AmountTitle", @"Sale Price")
						 message:TGL(@"Stars.HowManyStarsShouldThisGift", @"How many stars should this gift cost?")
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   okButtonTitle:TGL(@"Wallpaper.Set", @"Set")
				 completionBlock:^(bool okButtonPressed) {
					 typeof(self) strongSelf = weakSelf;
					 TGStarsDetailViewController *strongController = weakController;
					 TGAlertView *strongAlert = alert;
					 alert = nil;
					 if (!okButtonPressed || !strongSelf || !strongController || !strongAlert)
						 return;
					 NSString *text = [[strongAlert textFieldAtIndex:0] text];
					 long long price = [text longLongValue];
					 if (price <= 0)
						 return;
					 strongController.busy = YES;
					 [strongController.tableView reloadData];
					 TGClient *client = [TGClient shared];
					 [client setResalePrice:price
							forReceivedGift:giftId
								 completion:^(BOOL ok, NSString *error) {
									 typeof(self) innerSelf = weakSelf;
									 if (!innerSelf)
										 return;
									 [innerSelf finishAction:strongController
													 success:ok
													 failure:TGFriendlyErrorText(error, TGL(@"Stars.ThePriceCouldNotBeSet", @"The price could not be set."))];
								 }];
				 }];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	UITextField *field = [alert textFieldAtIndex:0];
	field.keyboardType = UIKeyboardTypeNumberPad;
	field.placeholder = TGL(@"PeerInfo.BotBalance.Stars", @"Stars");
	[alert show];
}

- (NSArray *)pairsForSubscription:(NSDictionary *)subscription {
	NSMutableArray *pairs = [NSMutableArray array];
	long long stars = [subscription[@"stars"] longLongValue];
	long long period = [subscription[@"period"] longLongValue];
	if (stars > 0) {
		[pairs addObject:@[ TGL(@"Chat.PostSuggestion.TablePrice", @"Price"), [self starsText:stars signed:NO] ]];
		if (period > 0)
			[pairs addObject:@[ TGL(@"Stars.Subscription.Billed", @"Billed"), [NSString stringWithFormat:TGL(@"Stars.Subscription.EveryPeriod", @"every %@"), [self periodTextForSeconds:period]] ]];
	}

	NSString *date = [self dateTextFromValue:subscription[@"expirationDate"]];
	if (date.length)
		[pairs addObject:@[ [subscription[@"isCanceled"] boolValue] ? TGL(@"Stars.Transaction.Subscription.Status.Expires", @"Expires") : TGL(@"Stars.Transaction.Subscription.Status.Renews", @"Renews"),
			date ]];

	NSString *kind = subscription[@"kind"];
	if ([kind isKindOfClass:[NSString class]] && kind.length)
		[pairs addObject:@[ TGL(@"Stars.Transaction.TypeLabel", @"Type"), [kind isEqualToString:@"bot"] ? TGL(@"Stars.Transaction.Subscription.Bot", @"Bot") : TGL(@"Settings.PersonalChannelItem", @"Channel") ]];

	[pairs addObject:@[ TGL(@"Gift.View.Status", @"Status"), [subscription[@"isCanceled"] boolValue] ? TGL(@"Stars.Intro.Subscriptions.Cancelled", @"cancelled") : ([subscription[@"isExpiring"] boolValue] ? TGL(@"Stars.Subscription.Expiring", @"Expiring") : TGL(@"Stars.Subscription.Active", @"Active")) ]];

	return pairs;
}

- (NSDictionary *)subscriptionRejoinActionForId:(NSString *)subscriptionId
									 controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(TGL(@"Stars.Transaction.Subscription.JoinChannel", @"Join Channel"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		strongController.busy = YES;
		[strongController.tableView reloadData];
		TGClient *client = [TGClient shared];
		[client reuseStarSubscription:subscriptionId
						   completion:^(BOOL ok) {
							   typeof(self) innerSelf = weakSelf;
							   if (!innerSelf)
								   return;
							   [innerSelf finishAction:strongController
											   success:ok
											   failure:TGL(@"Stars.TheChannelCouldNotBeRejoined", @"The channel could not be rejoined.")];
						   }];
	});
}

- (NSDictionary *)subscriptionToggleActionForId:(NSString *)subscriptionId
									   canceled:(BOOL)canceled
									expiration:(NSString *)expirationDate
									 controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(
		canceled ? TGL(@"Stars.Transaction.Subscription.Renew", @"Renew Subscription") : TGL(@"Stars.Transaction.Subscription.Cancel", @"Cancel Subscription"),
		nil, !canceled, ^{
			typeof(self) strongSelf = weakSelf;
			TGStarsDetailViewController *strongController = weakController;
			if (!strongSelf || !strongController)
				return;
			void (^apply)(void) = ^{
				strongController.busy = YES;
				[strongController.tableView reloadData];
				TGClient *client = [TGClient shared];
				[client setStarSubscription:subscriptionId
								   canceled:!canceled
								 completion:^(BOOL ok) {
									 typeof(self) innerSelf = weakSelf;
									 if (!innerSelf)
										 return;
									 [innerSelf finishAction:strongController
													 success:ok
													 failure:TGL(@"Stars.TheSubscriptionCouldNotBeChanged", @"The subscription could not be changed.")];
								 }];
			};
			if (canceled) {
				apply();
				return;
			}
			[strongSelf confirmWithTitle:TGL(@"Stars.Transaction.Subscription.Cancel", @"Cancel Subscription")
								 message:[NSString stringWithFormat:
										  TGL(@"Stars.Transaction.Subscription.Active", @"If you cancel now, you can still access your subscription until %@"),
										  expirationDate]
								  action:TGL(@"Stars.Transaction.Subscription.Cancel", @"Cancel Subscription")
								   block:apply];
		});
}

- (void)pushSubscriptionDetails:(NSDictionary *)subscription {
	NSString *subscriptionId = subscription[@"id"];
	if (![subscriptionId isKindOfClass:[NSString class]])
		subscriptionId = nil;

	TGStarsDetailViewController *controller = [TGStarsDetailViewController alloc];
	controller = [controller initWithTitle:[self titleForSubscription:subscription]
									 pairs:[self pairsForSubscription:subscription]
								   comment:nil];

	if (subscriptionId.length) {
		NSMutableArray *actions = [NSMutableArray array];

		if ([subscription[@"canReuse"] boolValue]) {
			[actions addObject:[self subscriptionRejoinActionForId:subscriptionId
														controller:controller]];
		}

		[actions addObject:[self subscriptionToggleActionForId:subscriptionId
													  canceled:[subscription[@"isCanceled"] boolValue]
													expiration:[self dateTextFromValue:subscription[@"expirationDate"]]
													controller:controller]];

		controller.actions = actions;
	}

	[self.navigationController pushViewController:controller animated:YES];
}

- (void)configureGiftDetail:(TGStarsDetailViewController *)controller
				   withGift:(NSDictionary *)gift {
	controller.actions = [self giftActionsFor:gift controller:controller];
	controller.actionsComment = controller.actions.count
		? TGL(@"Stars.GiftDetail.HiddenGiftsVisibleOnlyToYou", @"Hidden gifts are visible only to you.")
		: nil;
	[controller.tableView reloadData];
}

- (NSArray *)pinnedGiftIdsTogglingGift:(NSString *)giftId
								 pinned:(BOOL)pinned
					   currentPinnedIds:(NSArray<NSString *> *)currentPinnedIds {
	NSMutableArray *ids = [NSMutableArray array];
	for (NSString *otherId in currentPinnedIds) {
		if (![otherId isKindOfClass:[NSString class]] || !otherId.length)
			continue;
		if ([otherId isEqualToString:giftId])
			continue;
		[ids addObject:otherId];
	}
	if (pinned)
		[ids insertObject:giftId atIndex:0];
	return ids;
}

- (void)refreshGiftDetail:(TGStarsDetailViewController *)controller
				   giftId:(NSString *)giftId
				 fallback:(NSDictionary *)fallback {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	[[TGClient shared] receivedGiftWithId:giftId completion:^(NSDictionary *gift) {
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		[strongSelf configureGiftDetail:strongController
							   withGift:[gift isKindOfClass:[NSDictionary class]]
				? gift
				: fallback];
	}];
}

- (void)pushGiftDetails:(NSDictionary *)gift {
	NSMutableArray *pairs = [NSMutableArray array];

	if ([gift[@"isUnique"] boolValue]) {
		NSString *currency = gift[@"valueCurrency"];
		long long value = [gift[@"valueAmount"] longLongValue];
		if ([currency isKindOfClass:[NSString class]] && currency.length && value > 0)
			[pairs addObject:@[ TGL(@"Gift.View.Value", @"Value"),
				[NSString stringWithFormat:@"%.2f %@", value / 100.0, currency] ]];
	} else {
		long long stars = [gift[@"starCount"] longLongValue];
		if (stars > 0)
			[pairs addObject:@[ TGL(@"Gift.View.Value", @"Value"), [self starsText:stars signed:NO] ]];
	}

	NSString *sender = [self senderNameForGift:gift];
	[pairs addObject:@[ TGL(@"Gift.View.From", @"From"), sender.length ? sender : TGL(@"SendStarReactions.UserLabelAnonymous", @"Anonymous") ]];

	NSString *date = [self dateTextFromValue:gift[@"date"]];
	if (date.length)
		[pairs addObject:@[ TGL(@"Stars.Transaction.Date", @"Date"), date ]];

	if ([gift[@"isUnique"] boolValue]) {
		NSString *name = gift[@"name"];
		if ([name isKindOfClass:[NSString class]] && name.length)
			[pairs addObject:@[ TGL(@"Stars.GiftDetail.UniqueGift", @"Unique Gift"), name ]];
		else
			[pairs addObject:@[ TGL(@"Stars.GiftDetail.UniqueGift", @"Unique Gift"), TGL(@"Common.Yes", @"Yes") ]];
		NSNumber *number = gift[@"number"];
		if ([number isKindOfClass:[NSNumber class]] && [number longLongValue])
			[pairs addObject:@[ TGL(@"Gift.Store.Sort.Number", @"Number"), [NSString stringWithFormat:@"#%lld", [number longLongValue]] ]];
	}

	NSString *comment = gift[@"text"];
	if ([comment isKindOfClass:[NSString class]] && comment.length)
		comment = [NSString stringWithFormat:@"“%@”", comment];
	else
		comment = nil;

	NSString *title = gift[@"title"];
	if (![title isKindOfClass:[NSString class]] || !title.length)
		title = TGL(@"Gift.View.Title", @"Gift");

	TGStarsDetailViewController *controller = [TGStarsDetailViewController alloc];
	controller = [controller initWithTitle:title
									 pairs:pairs
								   comment:comment];
	controller.actions = [self giftActionsFor:gift controller:controller];
	controller.actionsComment = controller.actions.count
		? TGL(@"Stars.GiftDetail.HiddenGiftsVisibleOnlyToYou", @"Hidden gifts are visible only to you.")
		: nil;
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)handleTransactionsTapAtRow:(NSInteger)row {
	if (!self.transactions.count)
		return;
	if (row >= (NSInteger)self.transactions.count) {
		if (!self.transactionsLoading) {
			[self loadMoreTransactions];
			[self.tableView reloadData];
		}
		return;
	}
	[self pushTransactionDetails:self.transactions[row]];
}

- (void)handleGiftsTapAtRow:(NSInteger)row {
	if (!self.gifts.count)
		return;
	if (row >= (NSInteger)self.gifts.count) {
		if (!self.giftsLoading) {
			[self loadMoreGifts];
			[self.tableView reloadData];
		}
		return;
	}
	[self pushGiftDetails:self.gifts[row]];
}

- (void)handleGiftToolsTapAtRow:(NSInteger)row {
	switch (row) {
		case TGStarsGiftToolCatalogue:
			[self pushGiftCatalogue];
			break;
		case TGStarsGiftToolCollections:
			[self pushGiftCollections];
			break;
		case TGStarsGiftToolSettings:
			[self pushGiftSettings];
			break;
		default:
			[self pushChannelGifts];
			break;
	}
}

- (void)handleMoreTapAtRow:(NSInteger)row {
	switch (row) {
		case TGStarsMoreStarPacks:
			[self pushStarPacks];
			break;
		case TGStarsMoreIncoming:
			[self pushTransactionsWithDirection:@"incoming" title:TGL(@"Stars.Intro.Incoming", @"Incoming Payments")];
			break;
		case TGStarsMoreOutgoing:
			[self pushTransactionsWithDirection:@"outgoing" title:TGL(@"Stars.Intro.Outgoing", @"Outgoing Payments")];
			break;
		case TGStarsMorePaidMessages:
			[self pushPaidMessages];
			break;
		case TGStarsMoreAffiliatePrograms:
			[self pushAffiliatePrograms];
			break;
		default:
			[self clearSavedPaymentInfo];
			break;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == TGStarsSectionBalance)
		return;

	if (indexPath.section == TGStarsSectionTransactions) {
		[self handleTransactionsTapAtRow:indexPath.row];
		return;
	}

	if (indexPath.section == TGStarsSectionSubscriptions) {
		if (indexPath.row < (NSInteger)self.subscriptions.count)
			[self pushSubscriptionDetails:self.subscriptions[indexPath.row]];
		return;
	}

	if (indexPath.section == TGStarsSectionGiftTools) {
		[self handleGiftToolsTapAtRow:indexPath.row];
		return;
	}

	if (indexPath.section == TGStarsSectionMore) {
		[self handleMoreTapAtRow:indexPath.row];
		return;
	}

	[self handleGiftsTapAtRow:indexPath.row];
}

@end
