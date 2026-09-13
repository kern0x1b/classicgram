#import "TGPremiumViewController.h"
#import "TGPremiumViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGHexColour.h"

@implementation TGPremiumViewController (Cells)

- (UITableViewCell *)plainCellInTable:(UITableView *)tableView
								style:(UITableViewCellStyle)style
							  reuseId:(NSString *)reuseId {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:reuseId];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.imageView.image = nil;
	cell.detailTextLabel.text = @"";
	if ([cell.detailTextLabel respondsToSelector:@selector(setAttributedText:)])
		cell.detailTextLabel.attributedText = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.font = [UIFont systemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.shadowColor = nil;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	[[TGTheme shared] styleCell:cell];
	return cell;
}

- (UITableViewCell *)commentCellInTable:(UITableView *)tableView text:(NSString *)text {
	static NSString *reuseId = @"TGPremiumComment";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
	UILabel *label = nil;
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuseId];
		cell.backgroundColor = [UIColor clearColor];
		cell.backgroundView = nil;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		CGRect content = cell.contentView.bounds;
		CGRect labelFrame = CGRectMake(12, 7, content.size.width - 24, content.size.height - 14);
		label = [[UILabel alloc] initWithFrame:labelFrame];
		label.tag = 4001;
		label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		label.textAlignment = NSTextAlignmentCenter;
		label.font = [self commentFont];
		label.backgroundColor = [UIColor clearColor];
		label.numberOfLines = 0;
		[cell.contentView addSubview:label];
	} else {
		label = (UILabel *)[cell.contentView viewWithTag:4001];
	}

	label.textColor = TGColourFromHex(0x697487);
	label.shadowColor = TGColourFromHex(0xdae0e8);
	label.shadowOffset = CGSizeMake(0, 1);
	label.text = text;
	return cell;
}

- (UITableViewCell *)statusCellInTable:(UITableView *)tableView text:(NSString *)text {
	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleDefault
										   reuseId:@"TGPremiumStatus"];
	cell.textLabel.text = text;
	cell.textLabel.font = [UIFont systemFontOfSize:15];
	cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	return cell;
}

- (NSString *)formattedNumber:(NSNumber *)value {
	if (![value isKindOfClass:[NSNumber class]])
		return @"-";
	long long raw = [value longLongValue];
	if (raw >= 1000) {
		static NSNumberFormatter *formatter = nil;
		if (!formatter) {
			formatter = [[NSNumberFormatter alloc] init];
			formatter.numberStyle = NSNumberFormatterDecimalStyle;
		}
		NSString *text = [formatter stringFromNumber:@(raw)];
		if (text.length)
			return text;
	}
	return [NSString stringWithFormat:@"%lld", raw];
}

- (NSString *)formattedSize:(long long)bytes {
	if (bytes <= 0)
		return @"-";
	double mb = bytes / (1024.0 * 1024.0);
	if (mb >= 1024.0)
		return [NSString stringWithFormat:@"%.0f GB", mb / 1024.0];
	return [NSString stringWithFormat:@"%.0f MB", mb];
}

- (void)setComparisonOnCell:(UITableViewCell *)cell
					   free:(NSString *)freeValue
					premium:(NSString *)premiumValue {
	NSString *plain = [NSString stringWithFormat:@"%@ → %@", freeValue, premiumValue];
	UIColor *freeColour = [[TGTheme shared] secondaryTextColour];
	UIColor *premiumColour = [[TGTheme shared] cellDetailColour];

	if (![cell.detailTextLabel respondsToSelector:@selector(setAttributedText:)] || !NSClassFromString(@"NSMutableAttributedString")) {
		cell.detailTextLabel.text = plain;
		cell.detailTextLabel.textColor = premiumColour;
		return;
	}

	NSMutableAttributedString *value =
		[[NSMutableAttributedString alloc] initWithString:plain];
	[value addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:15]
				  range:NSMakeRange(0, plain.length)];
	[value addAttribute:NSForegroundColorAttributeName value:freeColour
				  range:NSMakeRange(0, freeValue.length + 3)];
	[value addAttribute:NSForegroundColorAttributeName value:premiumColour
				  range:NSMakeRange(freeValue.length + 3, plain.length - freeValue.length - 3)];
	cell.detailTextLabel.attributedText = value;
}

- (BOOL)featureIsSupported:(NSDictionary *)feature {
	id supported = feature[@"supported"];
	return ![supported isKindOfClass:[NSNumber class]] || [supported boolValue];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isCommentRow:indexPath])
		return [self commentCellInTable:tableView
								   text:[self commentForSection:indexPath.section]];

	if (indexPath.section == TGPremiumSectionAccount) {
		if (!self.optionsLoaded)
			return [self statusCellInTable:tableView text:TGL(@"Channel.NotificationLoading", @"Loading…")];
		UITableViewCell *cell = [self plainCellInTable:tableView
												 style:UITableViewCellStyleValue1
											   reuseId:@"TGPremiumOption"];
		switch (indexPath.row) {
			case 0:
				cell.textLabel.text = TGL(@"Premium.Premium", @"Premium");
				cell.detailTextLabel.text = [self.options[@"isPremium"] boolValue]
					? TGL(@"Stars.Subscription.Active", @"Active")
					: TGL(@"PrivacySettings.PasscodeOff", @"Off");
				break;
			case 1:
				cell.textLabel.text = TGL(@"Premium.FasterSpeed", @"Faster Download Speed");
				cell.detailTextLabel.text = [self.options[@"isPremium"] boolValue]
					? TGL(@"Stars.Subscription.Active", @"Active")
					: TGL(@"PrivacySettings.PasscodeOff", @"Off");
				break;
			case 2:
				cell.textLabel.text = TGL(@"Premium.UploadSize", @"Max upload size");
				cell.detailTextLabel.text = [self formattedSize:
						[self.options[@"maxUploadFileSize"] longLongValue]];
				break;
			case 3:
				cell.textLabel.text = TGL(@"PeerInfo.BotBalance.Stars", @"Stars");
				cell.detailTextLabel.text = [self formattedNumber:self.options[@"starCount"]];
				break;
			default:
				cell.textLabel.text = TGL(@"Premium.VoiceToText", @"Voice transcription");
				cell.detailTextLabel.text = [self transcriptionTrialText];
				break;
		}
		return cell;
	}

	if (indexPath.section == TGPremiumSectionLimits) {
		if (!self.limits.count)
			return [self statusCellInTable:tableView text:TGL(@"Channel.NotificationLoading", @"Loading…")];
		id rawLimit = self.limits[indexPath.row];
		if (![rawLimit isKindOfClass:[NSDictionary class]])
			return [self statusCellInTable:tableView text:@"-"];
		NSDictionary *limit = rawLimit;
		UITableViewCell *cell = [self plainCellInTable:tableView
												 style:UITableViewCellStyleValue1
											   reuseId:@"TGPremiumLimit"];
		NSString *title = limit[@"title"];
		cell.textLabel.text = [title isKindOfClass:[NSString class]] && title.length
			? title
			: limit[@"type"];
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		[self setComparisonOnCell:cell
							 free:[self formattedNumber:limit[@"default"]]
						  premium:[self formattedNumber:limit[@"premium"]]];
		return cell;
	}

	if (indexPath.section == TGPremiumSectionFeatures) {
		if (!self.features.count)
			return [self statusCellInTable:tableView text:TGL(@"Channel.NotificationLoading", @"Loading…")];
		if (indexPath.row == (NSInteger)self.features.count) {
			UITableViewCell *cell = [self plainCellInTable:tableView style:UITableViewCellStyleValue1 reuseId:@"TGPremiumBusiness"];
			cell.textLabel.text = TGL(@"Premium.Business", @"Telegram Business");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			return cell;
		}
		id rawFeature = self.features[indexPath.row];
		if (![rawFeature isKindOfClass:[NSDictionary class]])
			return [self statusCellInTable:tableView text:@"-"];
		NSDictionary *feature = rawFeature;
		UITableViewCell *cell = [self plainCellInTable:tableView
												 style:UITableViewCellStyleSubtitle
											   reuseId:@"TGPremiumFeature"];
		BOOL supported = [self featureIsSupported:feature];
		NSString *title = feature[@"title"];
		cell.textLabel.text = [title isKindOfClass:[NSString class]] && title.length
			? title
			: feature[@"type"];
		cell.textLabel.textColor = supported
			? [[TGTheme shared] primaryTextColour]
			: TGColourFromHex(0xb0b0b0);
		NSString *subtitle = feature[@"subtitle"];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
		if (supported) {
			cell.detailTextLabel.text = [subtitle isKindOfClass:[NSString class]] ? subtitle : @"";
			cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		} else {
			cell.detailTextLabel.text = TGL(@"Premium.NotAvailableInThisClient", @"Not available in this client");
			cell.detailTextLabel.textColor = [[TGTheme shared] groupedDisabledColour];
		}
		return cell;
	}

	if (indexPath.section == TGPremiumSectionBoosts) {
		if (!self.slotsLoaded)
			return [self statusCellInTable:tableView text:TGL(@"Channel.NotificationLoading", @"Loading…")];
		UITableViewCell *cell = [self plainCellInTable:tableView
												 style:UITableViewCellStyleValue1
											   reuseId:@"TGPremiumBoost"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		switch (indexPath.row) {
			case 0: {
				NSInteger free = 0;
				for (NSDictionary *slot in self.slots) {
					if ([slot isKindOfClass:[NSDictionary class]] && [slot[@"free"] boolValue])
						free++;
				}
				cell.textLabel.text = TGL(@"Premium.BoostSlots", @"Boost slots");
				cell.detailTextLabel.text = self.slots.count
					? [NSString stringWithFormat:TGL(@"Premium.FreeOfTotal", @"%@ free of %@"),
						  @(free), @(self.slots.count)]
					: TGL(@"GroupInfo.SharedMediaNone", @"None");
				break;
			}
			case 1:
				cell.textLabel.text = TGL(@"Premium.WhatBoostsUnlock", @"What Boosts Unlock");
				break;
			default:
				cell.textLabel.text = TGL(@"Premium.GiveawaysIEntered", @"Giveaways I Entered");
				break;
		}
		return cell;
	}

	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleValue1
										   reuseId:@"TGPremiumBoost"];
	cell.textLabel.text = TGL(@"Premium.GiftCodes", @"Gift Codes");
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

@end
