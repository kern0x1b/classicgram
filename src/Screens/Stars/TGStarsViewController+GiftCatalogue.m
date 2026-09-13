#import "TGStarsViewController.h"
#import "TGFriendlyError.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Payments.h"
#import "TGClient+ChatList.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGForwardPicker.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
@implementation TGStarsViewController (GiftCatalogue)

- (void)pushUpgradePreviewForGiftId:(long long)giftId title:(NSString *)title {
	TGStarsDetailViewController *detailAlloc = [TGStarsDetailViewController alloc];
	TGStarsDetailViewController *controller =
		[detailAlloc initWithTitle:TGL(@"Gift.Upgrade.Title", @"Upgrade Gift")
							 pairs:@[ @[ TGL(@"Channel.NotificationLoading", @"Loading…"), @"..." ] ]
						   comment:nil];
	__weak TGStarsDetailViewController *weakController = controller;
	__weak typeof(self) weakSelf = self;
	[self.navigationController pushViewController:controller animated:YES];
	TGClient *client = [TGClient shared];
	[client giftUpgradePreviewForGiftId:giftId
							 completion:^(NSDictionary *preview) {
								 typeof(self) strongSelf = weakSelf;
								 TGStarsDetailViewController *strongController = weakController;
								 if (!strongSelf || !strongController)
									 return;
								 if (![preview isKindOfClass:[NSDictionary class]]) {
									 strongController.pairs = @[ @[ TGL(@"Stars.GiftCatalogue.Preview", @"Preview"), TGL(@"Gift.View.UnavailableTitle", @"Unavailable") ] ];
									 [strongController.tableView reloadData];
									 return;
								 }
								 NSMutableArray *pairs = [NSMutableArray array];
								 [pairs addObject:@[ TGL(@"Gift.View.Title", @"Gift"), title.length ? title : TGL(@"Gift.View.Title", @"Gift") ]];
								 long long stars = [preview[@"starCount"] longLongValue];
								 if (stars > 0)
									 [pairs addObject:@[ TGL(@"Stars.GiftCatalogue.UpgradePrice", @"Upgrade Price"), [strongSelf starsText:stars signed:NO] ]];
								 NSArray *keys = @[ @"models", @"symbols", @"backdrops" ];
								 NSArray *labels = @[ TGL(@"Gift.Variants.Models", @"Models"), TGL(@"Gift.Variants.Symbols", @"Symbols"), TGL(@"Gift.Variants.Backdrops", @"Backdrops") ];
								 for (NSInteger index = 0; index < keys.count; index++) {
									 NSArray *values = preview[keys[index]];
									 NSInteger count = [values isKindOfClass:[NSArray class]]
										 ? (NSInteger)values.count
										 : 0;
									 [pairs addObject:@[ labels[index],
										 [NSString stringWithFormat:@"%d", (int)count] ]];
								 }
								 strongController.pairs = pairs;
								 strongController.comment = TGL(@"Stars.GiftCatalogue.UpgradedGiftPicksAtRandom", @"An upgraded gift picks one model, symbol and backdrop at random.");
								 [strongController.tableView reloadData];
							 }];
}

- (void)pushResaleListingsForGiftId:(long long)giftId title:(NSString *)title {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:TGL(@"Gift.Options.Gift.Filter.Resale", @"Resale")];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.GiftCatalogue.NothingOnSale", @"Nothing on Sale");
	list.comment = TGL(@"Stars.GiftCatalogue.BuyingSpendsStarsImmediately", @"Buying spends stars from your balance immediately.");
	[self.navigationController pushViewController:list animated:YES];
	[self loadResaleListingsInto:list giftId:giftId offset:@""];
}

- (void)confirmBuyResoldGiftNamed:(NSString *)name price:(long long)price {
	__weak typeof(self) weakSelf = self;
	[self confirmWithTitle:TGL(@"Gift.Buy.Confirm.Title", @"Buy Gift")
				   message:[NSString stringWithFormat:
								   TGL(@"Gift.Buy.Resale.Confirm.Text", @"Buy this gift for %@?"),
							   [self starsText:price signed:NO]]
					action:TGL(@"Stars.GiftCatalogue.BuyButton", @"Buy")
					 block:^{
						 typeof(self) strongSelf = weakSelf;
						 if (!strongSelf)
							 return;
						 TGClient *client = [TGClient shared];
						 [client buyResoldGiftNamed:name
									   forStarCount:price
										 completion:^(BOOL ok, long long newPriceStarCount, NSString *error) {
											 typeof(self) innerSelf = weakSelf;
											 if (!innerSelf)
												 return;
											 if (!ok && newPriceStarCount > 0) {
												 [innerSelf confirmBuyResoldGiftNamed:name price:newPriceStarCount];
												 return;
											 }
											 [innerSelf finishSimpleAction:ok
																  failure:TGFriendlyErrorText(error, TGL(@"Stars.ThisGiftCouldNotBeBought", @"This gift could not be bought."))];
										 }];
					 }];
}

- (void)loadResaleListingsInto:(TGStarsListViewController *)list
						giftId:(long long)giftId
						offset:(NSString *)offset {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	TGClient *client = [TGClient shared];
	[client giftsForResaleWithGiftId:giftId
							  offset:offset
							   limit:kStarsGiftPageSize
						  completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total) {
							  typeof(self) strongSelf = weakSelf;
							  TGStarsListViewController *strongList = weakList;
							  if (!strongSelf || !strongList)
								  return;
							  if ([gifts isKindOfClass:[NSArray class]]) {
								  for (NSDictionary *gift in gifts) {
									  if (![gift isKindOfClass:[NSDictionary class]])
										  continue;
									  NSString *name = gift[@"name"];
									  if (![name isKindOfClass:[NSString class]] || !name.length)
										  continue;
									  long long price = [gift[@"resaleStarCount"] longLongValue];
									  NSNumber *number = gift[@"number"];
									  NSString *rowTitle = [number isKindOfClass:[NSNumber class]]
										  ? [NSString stringWithFormat:@"#%lld", [number longLongValue]]
										  : name;
									  NSString *priceText = [strongSelf starsText:price signed:NO];
									  NSDictionary *row = TGStarsRow(rowTitle, nil, priceText, ^{
										  typeof(self) innerSelf = weakSelf;
										  if (!innerSelf)
											  return;
										  [innerSelf confirmBuyResoldGiftNamed:name price:price];
									  });
									  [strongList appendRow:row];
								  }
							  }
							  NSString *next = [nextOffset isKindOfClass:[NSString class]] ? nextOffset : @"";
							  BOOL more = next.length > 0 && strongList.rows.count < (NSUInteger)total;
							  if (more) {
								  strongList.loadMoreBlock = ^{
									  typeof(self) innerSelf = weakSelf;
									  TGStarsListViewController *innerList = weakList;
									  if (innerSelf && innerList)
										  [innerSelf loadResaleListingsInto:innerList giftId:giftId offset:next];
								  };
							  } else {
								  strongList.loadMoreBlock = nil;
							  }
							  [strongList finishLoadingWithMore:more];
						  }];
}

- (void)sendCatalogueGift:(NSDictionary *)gift
				   toUser:(int64_t)userId
					 name:(NSString *)name {
	long long giftId = [gift[@"id"] longLongValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] canSendGiftWithId:giftId completion:^(BOOL canSend, NSString *reason) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!canSend) {
			NSString *fallback = TGL(@"Gift.Options.GiftLocked.Title", @"Gift Locked");
			[strongSelf showMessage:reason.length ? reason : fallback];
			return;
		}
		[strongSelf continueSendCatalogueGift:gift toUser:userId name:name];
	}];
}

- (void)continueSendCatalogueGift:(NSDictionary *)gift
						   toUser:(int64_t)userId
							 name:(NSString *)name {
	long long giftId = [gift[@"id"] longLongValue];
	long long price = [gift[@"starCount"] longLongValue];
	NSString *title = gift[@"title"];
	__weak typeof(self) weakSelf = self;
	[self proceedIfEnoughStarsForPrice:price then:^{
		typeof(self) proceedSelf = weakSelf;
		if (!proceedSelf)
			return;
		[proceedSelf promptGiftMessageAndPrivacyWithCompletion:^(NSString *text, BOOL isPrivate) {
			typeof(self) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf confirmWithTitle:TGL(@"PeerInfo.Gifts.SendGift", @"Send Gift")
								 message:[NSString stringWithFormat:TGL(@"Gift.Buy.Confirm.GiftText", @"Do you really want to buy %1$@ for %2$@ and gift it to %3$@?"),
											 [title isKindOfClass:[NSString class]] && title.length
												 ? title
												 : TGL(@"Stars.GiftCatalogue.ThisGift", @"this gift"),
											 [strongSelf starsText:price signed:NO],
											 name.length ? name : TGL(@"Stars.GiftCatalogue.ThisContactLowercase", @"this contact")]
								  action:TGL(@"MediaPicker.Send", @"Send")
								   block:^{
									   typeof(self) innerSelf = weakSelf;
									   if (!innerSelf)
										   return;
									   TGClient *client = [TGClient shared];
									   [client sendGiftWithId:giftId
													   toUser:userId
														 text:text
													isPrivate:isPrivate
												payForUpgrade:NO
												   completion:^(BOOL ok, NSString *error) {
													   typeof(self) doneSelf = weakSelf;
													   if (doneSelf)
														   [doneSelf finishSimpleAction:ok
																				failure:TGFriendlyErrorText(error, TGL(@"Stars.TheGiftCouldNotBeSent", @"The gift could not be sent."))];
												   }];
								   }];
		}];
	}];
}

- (void)sendCatalogueGift:(NSDictionary *)gift toChat:(int64_t)chatId {
	long long giftId = [gift[@"id"] longLongValue];
	__weak typeof(self) preflightWeakSelf = self;
	[[TGClient shared] canSendGiftWithId:giftId completion:^(BOOL canSend, NSString *reason) {
		typeof(self) strongSelf = preflightWeakSelf;
		if (!strongSelf)
			return;
		if (!canSend) {
			NSString *fallback = TGL(@"Gift.Options.GiftLocked.Title", @"Gift Locked");
			[strongSelf showMessage:reason.length ? reason : fallback];
			return;
		}
		[strongSelf continueSendCatalogueGift:gift toChat:chatId];
	}];
}

- (void)continueSendCatalogueGift:(NSDictionary *)gift toChat:(int64_t)chatId {
	long long giftId = [gift[@"id"] longLongValue];
	long long price = [gift[@"starCount"] longLongValue];
	NSString *title = gift[@"title"];
	NSString *chatTitle = [[TGClient shared] cachedTitleForChatId:chatId];
	__weak typeof(self) weakSelf = self;
	[self proceedIfEnoughStarsForPrice:price then:^{
		typeof(self) proceedSelf = weakSelf;
		if (!proceedSelf)
			return;
		[proceedSelf promptGiftMessageAndPrivacyWithCompletion:^(NSString *text, BOOL isPrivate) {
			typeof(self) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf confirmWithTitle:TGL(@"PeerInfo.Gifts.SendGift", @"Send Gift")
								 message:[NSString stringWithFormat:TGL(@"Gift.Buy.Confirm.GiftText", @"Do you really want to buy %1$@ for %2$@ and gift it to %3$@?"),
											 [title isKindOfClass:[NSString class]] && title.length
												 ? title
												 : TGL(@"Stars.GiftCatalogue.ThisGift", @"this gift"),
											 [strongSelf starsText:price signed:NO],
											 chatTitle.length ? chatTitle : TGL(@"HashtagSearch.ThisChat", @"this chat")]
								  action:TGL(@"MediaPicker.Send", @"Send")
								   block:^{
									   typeof(self) innerSelf = weakSelf;
									   if (!innerSelf)
										   return;
									   TGClient *client = [TGClient shared];
									   [client sendGiftWithId:giftId
													   toChat:chatId
														 text:text
													isPrivate:isPrivate
												payForUpgrade:NO
												   completion:^(BOOL ok, NSString *error) {
													   typeof(self) doneSelf = weakSelf;
													   if (doneSelf)
														   [doneSelf finishSimpleAction:ok
																				failure:TGFriendlyErrorText(error, TGL(@"Stars.TheGiftCouldNotBeSent", @"The gift could not be sent."))];
												   }];
								   }];
		}];
	}];
}

- (NSArray *)pairsForCatalogueGift:(NSDictionary *)gift {
	NSMutableArray *pairs = [NSMutableArray array];
	[pairs addObject:@[ TGL(@"Chat.PostSuggestion.TablePrice", @"Price"), [self starsText:[gift[@"starCount"] longLongValue] signed:NO] ]];
	long long upgrade = [gift[@"upgradeStarCount"] longLongValue];
	if (upgrade > 0)
		[pairs addObject:@[ TGL(@"Gift.View.Upgrade", @"Upgrade"), [self starsText:upgrade signed:NO] ]];
	if ([gift[@"isPremium"] boolValue])
		[pairs addObject:@[ TGL(@"Premium.Premium", @"Premium"), TGL(@"Common.Yes", @"Yes") ]];
	NSInteger resaleCount = [gift[@"resaleCount"] integerValue];
	if (resaleCount > 0) {
		[pairs addObject:@[ TGL(@"Stars.GiftCatalogue.OnResale", @"On Resale"), [NSString stringWithFormat:@"%d", (int)resaleCount] ]];
		long long minResale = [gift[@"minResaleStarCount"] longLongValue];
		if (minResale > 0)
			[pairs addObject:@[ TGL(@"Gift.View.From", @"From"), [self starsText:minResale signed:NO] ]];
	}

	return pairs;
}

- (NSDictionary *)catalogueSendToContactActionForGift:(NSDictionary *)gift {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"Stars.GiftCatalogue.SendToAContact", @"Send to a Contact"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf pickUserWithTitle:TGL(@"PeerInfo.Gifts.SendGift", @"Send Gift")
							  handler:^(int64_t userId, NSString *name) {
								  typeof(self) innerSelf = weakSelf;
								  if (innerSelf)
									  [innerSelf sendCatalogueGift:gift toUser:userId name:name];
							  }];
	});
}

- (NSDictionary *)catalogueSendToChannelActionForGift:(NSDictionary *)gift {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"Stars.GiftCatalogue.SendToAChannel", @"Send to a Channel"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf pickChatWithHandler:^(int64_t chatId) {
			typeof(self) innerSelf = weakSelf;
			if (innerSelf)
				[innerSelf sendCatalogueGift:gift toChat:chatId];
		}];
	});
}

- (NSDictionary *)catalogueUpgradePreviewActionForGiftId:(long long)giftId
												   title:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"Gift.Upgrade.Title", @"Upgrade Gift"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf pushUpgradePreviewForGiftId:giftId title:title];
	});
}

- (NSDictionary *)catalogueResaleActionForGiftId:(long long)giftId
										   title:(NSString *)title
										   count:(NSInteger)resaleCount {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"Stars.GiftCatalogue.BuyFromResale", @"Buy From Resale"),
		[NSString stringWithFormat:@"%d", (int)resaleCount], NO, ^{
			typeof(self) strongSelf = weakSelf;
			if (strongSelf)
				[strongSelf pushResaleListingsForGiftId:giftId title:title];
		});
}

- (void)pushCatalogueGift:(NSDictionary *)gift {
	NSString *title = gift[@"title"];
	if (![title isKindOfClass:[NSString class]] || !title.length)
		title = TGL(@"Gift.View.Title", @"Gift");
	long long giftId = [gift[@"id"] longLongValue];
	long long upgrade = [gift[@"upgradeStarCount"] longLongValue];
	NSInteger resaleCount = [gift[@"resaleCount"] integerValue];

	TGStarsDetailViewController *detailAlloc = [TGStarsDetailViewController alloc];
	TGStarsDetailViewController *controller =
		[detailAlloc initWithTitle:title
							 pairs:[self pairsForCatalogueGift:gift]
						   comment:nil];
	NSMutableArray *actions = [NSMutableArray array];

	if (self.giftPresetUserId) {
		int64_t presetUserId = self.giftPresetUserId;
		NSString *presetName = self.giftPresetName;
		__weak typeof(self) presetWeakSelf = self;
		[actions addObject:TGStarsAction(
							   [NSString stringWithFormat:TGL(@"Gift.Send.TitleTo", @"Gift to %@"),
								   presetName.length ? presetName : TGL(@"Stars.GiftCatalogue.ThisContact", @"This Contact")],
							   nil, NO, ^{
								   typeof(self) strongSelf = presetWeakSelf;
								   if (strongSelf)
									   [strongSelf sendCatalogueGift:gift toUser:presetUserId name:presetName];
							   })];
	} else if (self.giftPresetChatId) {
		int64_t presetChatId = self.giftPresetChatId;
		__weak typeof(self) presetWeakSelf = self;
		[actions addObject:TGStarsAction(
							   [NSString stringWithFormat:TGL(@"Gift.Send.TitleTo", @"Gift to %@"),
								   self.giftPresetName.length ? self.giftPresetName : TGL(@"Stars.GiftCatalogue.ThisChannel", @"This Channel")],
							   nil, NO, ^{
								   typeof(self) strongSelf = presetWeakSelf;
								   if (strongSelf)
									   [strongSelf sendCatalogueGift:gift toChat:presetChatId];
							   })];
	} else {
		[actions addObject:[self catalogueSendToContactActionForGift:gift]];
		[actions addObject:[self catalogueSendToChannelActionForGift:gift]];
	}

	if (upgrade > 0)
		[actions addObject:[self catalogueUpgradePreviewActionForGiftId:giftId title:title]];

	if (resaleCount > 0) {
		NSDictionary *resaleAction = [self catalogueResaleActionForGiftId:giftId
																	title:title
																	count:resaleCount];
		[actions addObject:resaleAction];
	}

	controller.actions = actions;
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)pushGiftCatalogue {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:TGL(@"Gift.Options.Gift.Title", @"Gift Catalogue")];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.GiftCatalogue.NoGiftsAvailable", @"No Gifts Available");
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[self.navigationController pushViewController:list animated:YES];
	[[TGClient shared] availableGiftsWithCompletion:^(NSArray *gifts) {
		typeof(self) strongSelf = weakSelf;
		TGStarsListViewController *strongList = weakList;
		if (!strongSelf || !strongList)
			return;
		if ([gifts isKindOfClass:[NSArray class]]) {
			for (NSDictionary *gift in gifts) {
				if (![gift isKindOfClass:[NSDictionary class]])
					continue;
				NSString *title = gift[@"title"];
				if (![title isKindOfClass:[NSString class]] || !title.length)
					title = TGL(@"Gift.View.Title", @"Gift");
				long long price = [gift[@"starCount"] longLongValue];
				NSString *subtitle = [strongSelf starsText:price signed:NO];
				NSInteger resaleCount = [gift[@"resaleCount"] integerValue];
				if (resaleCount > 0)
					subtitle = [NSString stringWithFormat:@"%@ · %@",
						subtitle, TGLPlural(@"Gift.Store.ForResale", resaleCount, @"%@ for resale", @"%@ for resale")];
				[strongList appendRow:TGStarsRow(title, subtitle, nil, ^{
					typeof(self) innerSelf = weakSelf;
					if (innerSelf)
						[innerSelf pushCatalogueGift:gift];
				})];
			}
		}
		[strongList finishLoadingWithMore:NO];
	}];
}

@end
