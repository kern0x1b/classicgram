#import "TGClient+ChatState.h"
#import "TGFriendlyError.h"
#import "TGStarsViewController.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Premium.h"
#import "TGClient+Payments.h"
#import "TGClient+Privacy.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGForwardPicker.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
@implementation TGStarsViewController (PaidMessages)

- (void)editPaidMessagePrice {
	int64_t myId = [[TGClient shared].me[@"id"] longLongValue];
	if (!myId) {
		[self showMessage:TGL(@"Stars.ThisAccountIsNotReadyYet", @"This account is not ready yet.")];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self promptWithTitle:TGL(@"GroupInfo.Permissions.ChargeForMessages", @"Charge for Messages")
				  message:TGL(@"Stars.StarsAStrangerPaysToSend", @"Stars a stranger pays to send you one message. Enter 0 to charge nothing.")
			  placeholder:TGL(@"PeerInfo.BotBalance.Stars", @"Stars")
				  numeric:YES
				maxLength:0
			  actionTitle:TGL(@"Conversation.LinkDialogSave", @"Save")
				  handler:^(NSString *text) {
					  typeof(self) strongSelf = weakSelf;
					  if (!strongSelf)
						  return;
					  long long stars = [text longLongValue];
					  if (stars < 0)
						  return;
					  [[TGClient shared] setNewChatPrivacyStarCount:stars completion:nil];
					  [strongSelf showMessage:stars > 0
							  ? [NSString stringWithFormat:TGL(@"Stars.PaidMessages.StrangersNowPay", @"Strangers now pay %@ per message."),
									[strongSelf starsText:stars signed:NO]]
							  : TGL(@"Stars.PaidMessages.AnybodyMayWriteFree", @"Anybody may write to you for free.")];
				  }];
}

- (void)allowFreeMessagesFromUser:(int64_t)userId
							 name:(NSString *)name
							stars:(long long)stars
						   refund:(BOOL)refund {
	__weak typeof(self) weakSelf = self;
	NSString *contactName = name.length ? name : TGL(@"Stars.PaidMessages.ThisContact", @"This contact");
	[self confirmWithTitle:TGL(@"Chat.PaidMessage.RemoveFee.Title", @"Write for Free")
				   message:[NSString stringWithFormat:
								   TGL(@"Chat.PaidMessage.RemoveFee.Text", @"Are you sure you want to allow %@ to message you for free?"),
							   contactName]
					action:refund
			? [NSString stringWithFormat:TGL(@"Chat.PaidMessage.RemoveFee.Refund", @"Refund already paid %@"), [self starsText:stars signed:NO]]
			: TGL(@"Chat.PaidMessage.RemoveFee.Yes", @"Yes")
					 block:^{
						 typeof(self) strongSelf = weakSelf;
						 if (!strongSelf)
							 return;
						 [[TGClient shared] allowUnpaidMessagesFromUser:userId
														  refundPayments:refund
															  completion:^(BOOL ok, NSString *error) {
							 typeof(self) doneSelf = weakSelf;
							 if (!doneSelf)
								 return;
							 if (!ok) {
								 [doneSelf showMessage:TGFriendlyErrorText(error, TGL(@"Stars.PaidMessages.RemoveFeeFailed", @"This fee could not be removed."))];
								 return;
							 }
							 [doneSelf.navigationController popViewControllerAnimated:YES];
							 [doneSelf showMessage:refund
									 ? TGL(@"Stars.PaidMessages.TheStarsWereReturnedAndThisContact", @"The stars were returned and this contact writes for free.")
									 : TGL(@"Stars.PaidMessages.ThisContactWritesForFree", @"This contact writes for free.")];
						 }];
					 }];
}

- (void)pushPaidMessageDetailForUser:(int64_t)userId name:(NSString *)name {
	NSString *title = name.length ? name : TGL(@"Attachment.Contact", @"Contact");
	NSArray *pairs = @[ @[ TGL(@"Checkout.TotalPaidAmount", @"Paid So Far"), @"..." ] ];
	TGStarsDetailViewController *controller =
		[[TGStarsDetailViewController alloc] initWithTitle:title pairs:pairs comment:nil];
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	[self.navigationController pushViewController:controller animated:YES];
	[[TGClient shared] paidMessageRevenueFromUser:userId completion:^(long long stars) {
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (!strongSelf || !strongController)
			return;
		strongController.pairs = @[ @[ TGL(@"Checkout.TotalPaidAmount", @"Paid So Far"),
			[strongSelf starsText:stars signed:NO] ] ];
		NSMutableArray *actions = [NSMutableArray array];
		[actions addObject:TGStarsAction(TGL(@"Stars.PaidMessages.LetThemWriteForFree", @"Let Them Write for Free"), nil, NO, ^{
			typeof(self) innerSelf = weakSelf;
			if (innerSelf)
				[innerSelf allowFreeMessagesFromUser:userId name:name stars:0 refund:NO];
		})];
		if (stars > 0) {
			[actions addObject:TGStarsAction(TGL(@"Stars.PaidMessages.FreeAndRefundStars", @"Free and Refund Stars"), nil, YES, ^{
				typeof(self) innerSelf = weakSelf;
				if (innerSelf)
					[innerSelf allowFreeMessagesFromUser:userId name:name stars:stars refund:YES];
			})];
		}
		strongController.actions = actions;
		strongController.actionsComment =
			TGL(@"Stars.PaidMessages.AllowingAContactCannotBeUndone", @"Allowing a contact cannot be undone from here.");
		[strongController.tableView reloadData];
	}];
}

- (void)pushPaidMessages {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:TGL(@"GroupInfo.Permissions.ChargeForMessages", @"Charge for Messages")];
	list.comment = TGL(@"Privacy.Messages.ChargeForMessagesInfo", @"Strangers pay stars to write to you. A contact you allow always writes for free.");
	__weak typeof(self) weakSelf = self;
	[list appendRow:TGStarsRow(TGL(@"Stars.PaidMessages.PricePerMessage", @"Price per Message"), nil, nil, ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf editPaidMessagePrice];
	})];
	[list appendRow:TGStarsRow(TGL(@"Stars.PaidMessages.FreeForAContact", @"Free for a Contact"), nil, nil, ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf pickUserWithTitle:TGL(@"Chat.PaidMessage.RemoveFee.Title", @"Write for Free")
							  handler:^(int64_t userId, NSString *name) {
								  typeof(self) innerSelf = weakSelf;
								  if (innerSelf)
									  [innerSelf pushPaidMessageDetailForUser:userId name:name];
							  }];
	})];
	[self.navigationController pushViewController:list animated:YES];
}

- (void)pushAffiliatePrograms {
	TGStarsListViewController *list = [[TGStarsListViewController alloc]
		initWithTitle:TGL(@"AffiliateSetup.TitleJoin", @"Affiliate Programs")];
	list.comment = TGL(@"AffiliateSetup.TextJoin", @"Share a bot's referral link and earn Telegram Stars whenever someone you referred spends there. Connecting costs nothing.");
	list.emptyText = TGL(@"AffiliateSetup.SuggestedSectionEmpty", @"No affiliate programs found");
	list.loading = YES;
	[self.navigationController pushViewController:list animated:YES];
	[self reloadAffiliateProgramsInto:list];
}

- (void)reloadAffiliateProgramsInto:(TGStarsListViewController *)list {
	list.rows = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[[TGClient shared] connectedAffiliateProgramsWithCompletion:^(NSArray *connected) {
		typeof(self) strongSelf = weakSelf;
		TGStarsListViewController *strongList = weakList;
		if (!strongSelf || !strongList)
			return;
		NSMutableSet *connectedIds = [NSMutableSet set];
		for (NSDictionary *program in connected) {
			[connectedIds addObject:program[@"botUserId"]];
			if ([program[@"disconnected"] boolValue])
				continue;
			[strongList appendRow:[strongSelf connectedAffiliateRow:program]];
		}
		[[TGClient shared] suggestedAffiliateProgramsWithCompletion:^(NSArray *suggested) {
			typeof(self) innerSelf = weakSelf;
			TGStarsListViewController *innerList = weakList;
			if (!innerSelf || !innerList)
				return;
			for (NSDictionary *found in suggested) {
				if ([connectedIds containsObject:found[@"botUserId"]])
					continue;
				[innerList appendRow:[innerSelf suggestedAffiliateRow:found]];
			}
			[innerList finishLoadingWithMore:NO];
		}];
	}];
}

- (NSString *)affiliateBotName:(int64_t)botUserId {
	NSString *name = [[TGClient shared] nameForUserId:botUserId];
	return name.length ? name : TGL(@"Stars.Transaction.Subscription.Bot", @"Bot");
}

- (NSString *)affiliateDurationText:(NSDictionary *)program {
	NSInteger months = [program[@"months"] integerValue];
	if (months <= 0)
		return TGL(@"AffiliateProgram.DurationLifetime", @"Ongoing");
	return TGLPlural(@"AffiliateProgram.ValueLongMonths", months, @"%@ MONTH", @"%@ MONTHS");
}

- (NSString *)affiliatePercentBadgeText:(NSInteger)commission {
	if (commission % 10 == 0)
		return [NSString stringWithFormat:@"%ld%%", (long)(commission / 10)];
	return [NSString stringWithFormat:@"%.1f%%", commission / 10.0];
}

- (NSDictionary *)connectedAffiliateRow:(NSDictionary *)program {
	int64_t botUserId = [program[@"botUserId"] longLongValue];
	NSInteger commission = [program[@"commission"] integerValue];
	__weak typeof(self) weakSelf = self;
	return TGStarsBadgeRow([self affiliateBotName:botUserId],
		[self affiliatePercentBadgeText:commission],
		[self affiliateDurationText:program], ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf pushConnectedAffiliateDetail:program];
	});
}

- (NSDictionary *)suggestedAffiliateRow:(NSDictionary *)found {
	int64_t botUserId = [found[@"botUserId"] longLongValue];
	NSInteger commission = [found[@"commission"] integerValue];
	__weak typeof(self) weakSelf = self;
	return TGStarsBadgeRow([self affiliateBotName:botUserId],
		[self affiliatePercentBadgeText:commission],
		[self affiliateDurationText:found], ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf pushSuggestedAffiliateDetail:found];
	});
}

- (void)pushConnectedAffiliateDetail:(NSDictionary *)program {
	int64_t botUserId = [program[@"botUserId"] longLongValue];
	NSString *url = program[@"url"];
	NSArray *pairs = @[
		@[ TGL(@"AffiliateSetup.AlertApply.SectionCommission", @"Commission"),
			[NSString stringWithFormat:@"%.1f%%", [program[@"commission"] integerValue] / 10.0] ],
		@[ TGL(@"AffiliateSetup.SectionDuration", @"Duration"), [self affiliateDurationText:program] ],
	];
	TGStarsDetailViewController *controller = [[TGStarsDetailViewController alloc]
		initWithTitle:[self affiliateBotName:botUserId]
				pairs:pairs
			  comment:nil];
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	NSMutableArray *actions = [NSMutableArray array];
	[actions addObject:TGStarsAction(TGL(@"AffiliateProgram.ActionCopyLink", @"Copy Referral Link"), nil, NO, ^{
		if (url.length)
			[[UIPasteboard generalPasteboard] setString:url];
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf showMessage:TGL(@"AffiliateProgram.ToastLinkCopied.Title", @"Referral link copied.")];
	})];
	[actions addObject:TGStarsAction(TGL(@"AffiliateSetup.ProgramLeave", @"Disconnect"), nil, YES, ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf disconnectAffiliate:url controller:weakController];
	})];
	controller.actions = actions;
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)disconnectAffiliate:(NSString *)url controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	controller.busy = YES;
	[controller.tableView reloadData];
	[[TGClient shared] disconnectAffiliateProgramWithUrl:url completion:^(BOOL ok) {
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *innerController = weakController;
		if (!strongSelf)
			return;
		if (!ok) {
			if (innerController) {
				innerController.busy = NO;
				[innerController.tableView reloadData];
			}
			[strongSelf showMessage:TGL(@"Toast.CouldNotDisconnectBot", @"Could not disconnect the bot")];
			return;
		}
		if (innerController.navigationController)
			[innerController.navigationController popViewControllerAnimated:YES];
	}];
}

- (NSString *)affiliateJoinSubtitle:(NSDictionary *)found {
	int64_t botUserId = [found[@"botUserId"] longLongValue];
	NSString *botName = [self affiliateBotName:botUserId];
	NSString *commissionText = [self affiliatePercentBadgeText:[found[@"commission"] integerValue]];
	NSInteger months = [found[@"months"] integerValue];

	NSString *format;
	if (months <= 0) {
		format = TGL(@"AffiliateProgram.JoinSubtitleLifetime",
			@"{bot} will share {commission} of the revenue from each user you refer to it forever.");
	} else if (months < 12) {
		format = TGLPlural(@"AffiliateProgram.JoinSubtitleMonths", months,
			@"{bot} will share {commission} of the revenue from each user you refer to it for 1 month.",
			@"{bot} will share {commission} of the revenue from each user you refer to it for %d months.");
	} else {
		format = TGLPlural(@"AffiliateProgram.JoinSubtitleYears", months / 12,
			@"{bot} will share {commission} of the revenue from each user you refer to it for 1 year.",
			@"{bot} will share {commission} of the revenue from each user you refer to it for %d years.");
	}

	format = [format stringByReplacingOccurrencesOfString:@"{bot}" withString:botName];
	format = [format stringByReplacingOccurrencesOfString:@"{commission}" withString:commissionText];
	return format;
}

- (void)pushSuggestedAffiliateDetail:(NSDictionary *)found {
	int64_t botUserId = [found[@"botUserId"] longLongValue];
	NSArray *pairs = @[
		@[ TGL(@"AffiliateSetup.AlertApply.SectionCommission", @"Commission"),
			[NSString stringWithFormat:@"%.1f%%", [found[@"commission"] integerValue] / 10.0] ],
		@[ TGL(@"AffiliateSetup.SectionDuration", @"Duration"), [self affiliateDurationText:found] ],
	];
	TGStarsDetailViewController *controller = [[TGStarsDetailViewController alloc]
		initWithTitle:[self affiliateBotName:botUserId]
				pairs:pairs
			  comment:[self affiliateJoinSubtitle:found]];
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	controller.actions = @[ TGStarsAction(TGL(@"AffiliateProgram.ActionJoin", @"Connect"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf connectAffiliateProgram:botUserId controller:weakController];
	}) ];
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)connectAffiliateProgram:(int64_t)botUserId controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	controller.busy = YES;
	[controller.tableView reloadData];
	[[TGClient shared] connectAffiliateProgramForBot:botUserId completion:^(NSString *url, NSString *error) {
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *innerController = weakController;
		if (!strongSelf)
			return;
		if (!url.length) {
			if (innerController) {
				innerController.busy = NO;
				[innerController.tableView reloadData];
			}
			return;
		}
		[strongSelf showMessage:TGL(@"AffiliateProgram.ToastJoined.Text", @"You can now copy the referral link.")];
		if (innerController.navigationController)
			[innerController.navigationController popViewControllerAnimated:YES];
	}];
}

- (void)clearSavedPaymentInfo {
	__weak typeof(self) weakSelf = self;
	[self confirmWithTitle:TGL(@"Privacy.PaymentsClearInfo", @"Clear Saved Payment Info")
				   message:TGL(@"Privacy.PaymentsClearInfoHelp", @"The saved card and shipping details are forgotten.")
					action:TGL(@"WebSearch.RecentSectionClear", @"Clear")
					 block:^{
						 typeof(self) strongSelf = weakSelf;
						 if (!strongSelf)
							 return;
						 [[TGClient shared] clearSavedPaymentInfoWithCompletion:^(BOOL ok) {
							 typeof(self) innerSelf = weakSelf;
							 if (!innerSelf)
								 return;
							 NSString *cleared = TGL(@"Stars.PaidMessages.SavedPaymentDetailsWereCleared", @"Saved payment details were cleared.");
							 NSString *failed = TGL(@"Stars.PaidMessages.TheDetailsCouldNotBeCleared", @"The details could not be cleared.");
							 [innerSelf showMessage:ok ? cleared : failed];
						 }];
					 }];
}

@end
