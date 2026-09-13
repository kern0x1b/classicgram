#import "TGPremiumViewController.h"
#import "TGFriendlyError.h"
#import "TGPremiumViewControllerInternal.h"
#import "TGPremiumListViewController.h"
#import "TGLocalization.h"
#import "TGClient+Premium.h"
#import "TGAlertView.h"

@implementation TGPremiumViewController (Taps)

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if ([self isCommentRow:indexPath])
		return;

	if (indexPath.section == TGPremiumSectionLimits && self.limits.count) {
		id rawLimit = self.limits[indexPath.row];
		if (![rawLimit isKindOfClass:[NSDictionary class]])
			return;
		[self showLimitDetail:rawLimit];
		return;
	}

	if (indexPath.section == TGPremiumSectionBoosts && self.slotsLoaded) {
		switch (indexPath.row) {
			case 0:
			case 1:
				[self pushListWithMode:TGPremiumListBoostLevels title:TGL(@"Premium.BoostLevels", @"Boost Levels")];
				break;
			default:
				[self pushListWithMode:TGPremiumListGiveaways title:TGL(@"Premium.Giveaways", @"Giveaways")];
				break;
		}
		return;
	}

	if (indexPath.section == TGPremiumSectionFeatures && self.features.count) {
		if (indexPath.row == (NSInteger)self.features.count) {
			[self pushListWithMode:TGPremiumListBusiness title:TGL(@"Premium.Business", @"Telegram Business")];
			return;
		}
		id rawFeature = self.features[indexPath.row];
		if (![rawFeature isKindOfClass:[NSDictionary class]])
			return;
		NSDictionary *feature = rawFeature;
		if (![self featureIsSupported:feature])
			return;
		NSString *type = feature[@"type"];
		if ([type isKindOfClass:[NSString class]] && type.length)
			[[TGClient shared] viewPremiumFeature:type];
		NSString *subtitle = feature[@"subtitle"];
		if (![subtitle isKindOfClass:[NSString class]] || !subtitle.length)
			return;
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:feature[@"title"]
							 message:subtitle
					   cancelButtonTitle:TGL(@"Common.OK", @"OK")
						   okButtonTitle:nil
						 completionBlock:nil];
		[alert show];
		return;
	}

	if (indexPath.section != TGPremiumSectionGiftCode)
		return;

	[self pushListWithMode:TGPremiumListGiftCodes title:TGL(@"Premium.GiftCodes", @"Gift Codes")];
}

- (void)pushListWithMode:(NSInteger)mode title:(NSString *)title {
	TGPremiumListViewController *list = [[TGPremiumListViewController alloc]
		initWithMode:mode
			  chatId:0
			   title:title];
	[self.navigationController pushViewController:list animated:YES];
}

- (void)showLimitDetail:(NSDictionary *)limit {
	NSString *type = [limit[@"type"] isKindOfClass:[NSString class]] ? limit[@"type"] : @"";
	NSString *title = [limit[@"title"] isKindOfClass:[NSString class]] && [limit[@"title"] length] ? limit[@"title"] : type;
	if (!type.length)
		return;
	BOOL premium = [[TGClient shared] isPremiumAccount];
	[[TGClient shared] premiumLimit:type completion:^(NSDictionary *fresh) {
		NSDictionary *shown = [fresh isKindOfClass:[NSDictionary class]] ? fresh : limit;
		NSString *message = [NSString stringWithFormat:
				TGL(@"Premium.WithoutPremiumWithPremiumThisAccount", @"Without Premium: %d\nWith Premium: %d\n\nThis account: %d"),
			(int)[shown[@"default"] integerValue],
			(int)[shown[@"premium"] integerValue],
			(int)[shown[premium ? @"premium" : @"default"] integerValue]];
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:title
							 message:message
					   cancelButtonTitle:TGL(@"Common.OK", @"OK")
						   okButtonTitle:nil
						 completionBlock:nil];
		[alert show];
	}];
}

- (void)checkCode:(NSString *)code {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] checkGiftCode:code completion:^(NSDictionary *info) {
		if (![info isKindOfClass:[NSDictionary class]]) {
			TGAlertView *alert = [TGAlertView alloc];
			alert = [alert initWithTitle:TGL(@"GiftLink.Title", @"Gift Code")
								  message:TGL(@"Login.InvalidCodeError", @"Invalid code, please try again.")
						cancelButtonTitle:TGL(@"Common.OK", @"OK")
							okButtonTitle:nil
						  completionBlock:nil];
			[alert show];
			return;
		}
		NSMutableString *message = [NSMutableString string];
		NSInteger months = [info[@"months"] integerValue];
		NSInteger days = [info[@"days"] integerValue];
		if (months > 0)
			[message appendFormat:@"%@\n", TGLPlural(@"Premium.MonthsOfPremium", months, @"%@ month of Premium", @"%@ months of Premium")];
		else if (days > 0)
			[message appendFormat:@"%@\n", TGLPlural(@"Premium.DaysOfPremium", days, @"%@ day of Premium", @"%@ days of Premium")];
		if ([info[@"fromGiveaway"] boolValue])
			[message appendFormat:@"%@\n", TGL(@"Premium.FromAGiveaway", @"From a giveaway")];
		NSString *created = TGPremiumDateText(info[@"creationDate"]);
		if (created.length)
			[message appendFormat:@"%@\n", [NSString stringWithFormat:TGL(@"Premium.CreatedDate", @"Created %@"), created]];

		if ([info[@"used"] boolValue]) {
			NSString *usedDate = TGPremiumDateText(info[@"useDate"]);
			[message appendString:usedDate.length
				? [NSString stringWithFormat:TGL(@"GiftLink.UsedFooter", @"This link was used on %@."), usedDate]
				: TGL(@"Premium.AlreadyUsed", @"Already used")];
			TGAlertView *alert = [TGAlertView alloc];
			alert = [alert initWithTitle:TGL(@"GiftLink.Title", @"Gift Code")
								 message:message
						   cancelButtonTitle:TGL(@"Common.OK", @"OK")
							   okButtonTitle:nil
							 completionBlock:nil];
			[alert show];
			return;
		}

		[message appendString:TGL(@"GiftLink.NotUsedFooter", @"This link hasn't been used yet.")];
		void (^applied)(BOOL, NSString *) = ^(BOOL ok, NSString *error) {
			NSString *failure = TGFriendlyErrorText(error, TGL(@"Premium.TheCodeCouldNotBeRedeemed", @"The code could not be redeemed."));
			NSString *resultTitle = TGL(@"GiftLink.Title", @"Gift Code");
			NSString *resultText = ok ? TGL(@"Premium.TheCodeWasAppliedToThis", @"The code was applied to this account.") : failure;
			TGAlertView *result = [TGAlertView alloc];
			result = [result initWithTitle:resultTitle
								   message:resultText
							 cancelButtonTitle:TGL(@"Common.OK", @"OK")
								 okButtonTitle:nil
							   completionBlock:nil];
			[result show];
			if (ok)
				[weakSelf reloadTapped];
		};
		void (^redeem)(bool) = ^(bool okPressed) {
			if (!okPressed)
				return;
			[[TGClient shared] applyGiftCode:code completion:applied];
		};
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:TGL(@"GiftLink.Title", @"Gift Code")
							 message:message
				   cancelButtonTitle:TGL(@"Common.Close", @"Close")
					   okButtonTitle:TGL(@"GiftLink.UseLink", @"Use Link")
					 completionBlock:redeem];
		[alert show];
	}];
}

@end
