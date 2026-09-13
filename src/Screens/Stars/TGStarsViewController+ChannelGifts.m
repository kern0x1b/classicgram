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
@implementation TGStarsViewController (ChannelGifts)

- (void)pushGiftsOfChat:(int64_t)chatId {
	NSString *chatTitle = [[TGClient shared] cachedTitleForChatId:chatId];
	TGStarsListViewController *list = [[TGStarsListViewController alloc]
		initWithTitle:chatTitle.length ? chatTitle : TGL(@"PeerInfo.PaneGifts", @"Gifts")];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.ChannelGifts.NoGifts", @"No Gifts");
	list.comment = TGL(@"Stars.ChannelGifts.NotificationsReachEveryAdmin", @"Gift notifications reach every administrator of the channel.");
	[self.navigationController pushViewController:list animated:YES];
	[self loadChannelGiftsPage:@"" chatId:chatId list:list];
}

- (NSDictionary *)notifyToggleRowForChat:(int64_t)chatId
									 list:(TGStarsListViewController *)list
								  enabled:(BOOL)enabled {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	return TGStarsRow(TGL(@"PeerInfo.Gifts.ChannelNotify", @"Notify About New Gifts"), nil,
		enabled ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off"),
		^{
			typeof(self) innerSelf = weakSelf;
			TGStarsListViewController *innerList = weakList;
			if (!innerSelf || !innerList)
				return;
			BOOL newValue = !enabled;
			[[TGClient shared] setChat:chatId giftNotificationsEnabled:newValue completion:^(BOOL ok, NSString *error) {
				typeof(self) doneSelf = weakSelf;
				TGStarsListViewController *doneList = weakList;
				if (!doneSelf)
					return;
				if (!ok) {
					[doneSelf showMessage:TGFriendlyErrorText(error, TGL(@"Stars.ChannelGifts.NotifySettingFailed", @"This setting could not be saved."))];
					return;
				}
				[doneSelf showMessage:newValue
					? TGL(@"PeerInfo.Gifts.ChannelNotifyTooltip", @"You will receive a message from Telegram when your channel receives a gift.")
					: TGL(@"PeerInfo.Gifts.ChannelNotifyDisabledTooltip", @"You will not receive a message from Telegram when your channel receives a gift.")];
				if (doneList && doneList.rows.count) {
					doneList.rows[doneList.rows.count - 1] =
						[doneSelf notifyToggleRowForChat:chatId list:doneList enabled:newValue];
					[doneList.tableView reloadData];
				}
			}];
		});
}

- (void)loadChannelGiftsPage:(NSString *)offset chatId:(int64_t)chatId
						list:(TGStarsListViewController *)list {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[[TGClient shared] receivedGiftsForChat:chatId
							   collectionId:0
									 offset:offset
									  limit:kStarsGiftPageSize
								 completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total) {
									 (void)total;
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
											 NSString *sender = [strongSelf senderNameForGift:gift];
											 NSMutableDictionary *marked =
												 [NSMutableDictionary dictionaryWithDictionary:gift];
											 marked[@"tgChannelGift"] = @YES;
											 NSString *subtitle = sender.length ? [NSString stringWithFormat:TGL(@"Stars.ChannelGifts.FromSender", @"from %@"), sender] : TGL(@"Stars.ChannelGifts.FromAnonymous", @"from Anonymous");
											 void (^openGift)(void) = ^{
												 typeof(self) innerSelf = weakSelf;
												 if (innerSelf)
													 [innerSelf pushGiftDetails:marked];
											 };
											 [strongList appendRow:TGStarsRow(title, subtitle, nil, openGift)];
										 }
									 }
									 BOOL hasMore = [nextOffset isKindOfClass:[NSString class]] && nextOffset.length > 0;
									 if (hasMore) {
										 strongList.loadMoreBlock = ^{
											 typeof(self) innerSelf = weakSelf;
											 TGStarsListViewController *innerList = weakList;
											 if (innerSelf && innerList)
												 [innerSelf loadChannelGiftsPage:nextOffset chatId:chatId list:innerList];
										 };
										 [strongList finishLoadingWithMore:YES];
										 return;
									 }
									 [strongList finishLoadingWithMore:NO];
									 [[TGClient shared] chatGiftNotificationsEnabledForChat:chatId completion:^(BOOL enabled) {
										 typeof(self) rowSelf = weakSelf;
										 TGStarsListViewController *rowList = weakList;
										 if (!rowSelf || !rowList)
											 return;
										 [rowList appendRow:[rowSelf notifyToggleRowForChat:chatId list:rowList enabled:enabled]];
										 [rowList.tableView reloadData];
									 }];
								 }];
}

- (void)pushChannelGifts {
	__weak typeof(self) weakSelf = self;
	[self pickChatWithHandler:^(int64_t chatId) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf pushGiftsOfChat:chatId];
	}];
}

@end
