#import "TGPremiumViewController.h"
#import "TGPremiumViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"

static const CGFloat kPremiumSectionHeaderHeight = 46.0f;

@implementation TGPremiumViewController (Shape)

- (NSString *)titleForSection:(NSInteger)section {
	switch (section) {
		case TGPremiumSectionAccount:
			return TGL(@"Premium.SectionThisAccount", @"This account");
		case TGPremiumSectionLimits:
			return TGL(@"Premium.SectionLimits", @"Limits — now / with Premium");
		case TGPremiumSectionFeatures:
			return TGL(@"Premium.SectionFeatures", @"What Premium gives you");
		case TGPremiumSectionBoosts:
			return TGL(@"Premium.SectionBoosts", @"Channel boosts");
		default:
			return TGL(@"Premium.SectionGiftCode", @"Gift codes");
	}
}

- (NSString *)commentForSection:(NSInteger)section {
	if (section == TGPremiumSectionAccount) {
		NSString *terms = self.subscription[@"text"];
		if ([terms isKindOfClass:[NSString class]] && terms.length)
			return terms;
	}
	if (section == TGPremiumSectionFeatures && self.features.count)
		return TGL(@"Premium.DimmedRowsAreFeaturesThisClientCannotShow", @"Dimmed rows are features this client cannot show.");
	if (section == TGPremiumSectionGiftCode)
		return TGL(@"Premium.PremiumCannotBeBoughtHere", @"Premium cannot be bought here. A gift code from a giveaway or a friend can still be redeemed on this account."
				"friend can still be redeemed on this account.");
	if (section == TGPremiumSectionBoosts && self.slotsLoaded && !self.slots.count)
		return TGL(@"Premium.BoostSlotsComeWithAPremiumSubscription", @"Boost slots come with a Premium subscription.");
	return nil;
}

- (NSInteger)contentRowsInSection:(NSInteger)section {
	switch (section) {
		case TGPremiumSectionAccount:
			if (!self.optionsLoaded)
				return 1;
			return [self showsTranscriptionRow] ? 5 : 4;
		case TGPremiumSectionLimits:
			return self.limits.count ? (NSInteger)self.limits.count : 1;
		case TGPremiumSectionFeatures:
			return self.features.count ? (NSInteger)self.features.count + 1 : 1;
		case TGPremiumSectionBoosts:
			return self.slotsLoaded ? 3 : 1;
		default:
			return 1;
	}
}

- (BOOL)isCommentRow:(NSIndexPath *)indexPath {
	return [self commentForSection:indexPath.section] != nil && indexPath.row == [self contentRowsInSection:indexPath.section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return TGPremiumSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self contentRowsInSection:section] + ([self commentForSection:section] ? 1 : 0);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return kPremiumSectionHeaderHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *header = [self titleForSection:section];
	CGFloat width = tableView.bounds.size.width;
	return [[TGTheme shared] groupedHeaderViewWithTitle:header width:width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	UIView *spacer = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, tableView.bounds.size.width, 1)];
	spacer.backgroundColor = [UIColor clearColor];
	return spacer;
}

- (UIFont *)commentFont {
	return [UIFont systemFontOfSize:14];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isCommentRow:indexPath]) {
		CGFloat width = tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width;
		CGSize size = [[self commentForSection:indexPath.section]
				 sizeWithFont:[self commentFont]
			constrainedToSize:CGSizeMake(width - 12 * 2, 1000)
				lineBreakMode:NSLineBreakByWordWrapping];
		return size.height + 7 * 2;
	}
	return 44;
}

@end
