#import "TGStarsViewController.h"
#import "TGFriendlyError.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Payments.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGForwardPicker.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
@implementation TGStarsViewController (GiftSettings)

- (void)configureGiftSettings:(TGStarsDetailViewController *)controller
					 settings:(NSDictionary *)settings {
	if (![settings isKindOfClass:[NSDictionary class]]) {
		controller.pairs = @[ @[ TGL(@"Settings.Title", @"Settings"), TGL(@"Gift.View.UnavailableTitle", @"Unavailable") ] ];
		controller.actions = nil;
		[controller.tableView reloadData];
		return;
	}
	NSArray *keys = @[ @"showGiftButton", @"unlimited", @"limited",
		@"upgraded", @"fromChannels", @"premiumSubscription" ];
	NSArray *labels = @[ TGL(@"Privacy.Gifts.ShowGiftButton", @"Show Gift Icon in Chats"),
		TGL(@"Privacy.Gifts.AcceptedTypes.Unlimited", @"Unlimited"),
		TGL(@"Privacy.Gifts.AcceptedTypes.Limited", @"Limited-Edition"),
		TGL(@"Privacy.Gifts.AcceptedTypes.Unique", @"Unique"),
		TGL(@"Privacy.Gifts.AcceptedTypes.Channel", @"From Channels"),
		TGL(@"Privacy.Gifts.AcceptedTypes.Premium", @"Premium Subscriptions") ];
	NSMutableArray *actions = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	for (NSInteger index = 0; index < keys.count; index++) {
		NSString *key = keys[index];
		BOOL on = [settings[key] boolValue];
		[actions addObject:TGStarsAction(labels[index], on ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off"), NO, ^{
			typeof(self) strongSelf = weakSelf;
			TGStarsDetailViewController *strongController = weakController;
			if (!strongSelf || !strongController)
				return;
			NSMutableDictionary *updated =
				[NSMutableDictionary dictionaryWithDictionary:settings];
			updated[key] = @(!on);
			[[TGClient shared] setGiftSettings:updated completion:^(BOOL ok, NSString *error) {
				typeof(self) settingsSelf = weakSelf;
				TGStarsDetailViewController *settingsController = weakController;
				if (!settingsSelf || !settingsController)
					return;
				if (!ok)
					[settingsSelf showMessage:TGFriendlyErrorText(error, TGL(@"Stars.TheSettingsCouldNotBeSaved", @"The settings could not be saved."))];
				[[TGClient shared] giftSettingsWithCompletion:^(NSDictionary *fresh) {
					typeof(self) innerSelf = weakSelf;
					TGStarsDetailViewController *innerController = weakController;
					if (innerSelf && innerController)
						[innerSelf configureGiftSettings:innerController settings:fresh];
				}];
			}];
		})];
	}
	controller.pairs = @[];
	controller.actions = actions;
	controller.actionsComment = TGL(@"Privacy.Gifts.AcceptedTypes.Info", @"Choose the types of gifts that you allow others to send you.");
	[controller.tableView reloadData];
}

- (void)pushGiftSettings {
	NSArray *loadingPairs = @[ @[ TGL(@"Channel.NotificationLoading", @"Loading…"), @"..." ] ];
	TGStarsDetailViewController *controller = [TGStarsDetailViewController alloc];
	controller = [controller initWithTitle:TGL(@"Privacy.Gifts", @"Gifts")
									 pairs:loadingPairs
								   comment:nil];
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	[self.navigationController pushViewController:controller animated:YES];
	[[TGClient shared] giftSettingsWithCompletion:^(NSDictionary *settings) {
		typeof(self) strongSelf = weakSelf;
		TGStarsDetailViewController *strongController = weakController;
		if (strongSelf && strongController)
			[strongSelf configureGiftSettings:strongController settings:settings];
	}];
}

@end
