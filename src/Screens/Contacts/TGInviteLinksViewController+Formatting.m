#import "TGInviteLinksViewController.h"
#import "TGDateUtils.h"
#import "TGInviteLinksViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGHexColour.h"

@implementation TGInviteLinksViewController (Formatting)

#pragma mark - formatting

- (NSString *)shortLink:(NSString *)link {
	if (![link isKindOfClass:[NSString class]] || !link.length)
		return @"";
	NSString *text = link;
	NSRange scheme = [text rangeOfString:@"://"];
	if (scheme.location != NSNotFound)
		text = [text substringFromIndex:scheme.location + scheme.length];
	return text;
}

- (NSString *)titleForLink:(NSDictionary *)link {
	NSString *name = link[@"name"];
	if ([name isKindOfClass:[NSString class]] && name.length)
		return name;
	return [self shortLink:link[@"link"]];
}

- (NSString *)dateText:(long long)stamp {
	if (stamp <= 0)
		return @"";
	return [TGDateUtils stringForShortDate:(int)stamp];
}

- (NSString *)subtitleForLink:(NSDictionary *)link revoked:(BOOL)revoked {
	NSMutableArray *parts = [NSMutableArray array];

	int64_t starCount = [link[@"subscriptionStarCount"] longLongValue];
	if (starCount > 0)
		[parts addObject:TGLPlural(@"InviteLink.SubscriptionStarsPerMonth",
			(NSInteger)starCount, @"%lld star/month", @"%lld stars/month")];

	NSInteger members = [link[@"memberCount"] integerValue];
	NSInteger limit = [link[@"memberLimit"] integerValue];
	if (limit > 0)
		[parts addObject:[NSString stringWithFormat:TGL(@"InviteLink.MembersJoinedOfLimit", @"%d of %d joined"),
							 (int)members, (int)limit]];
	else
		[parts addObject:TGLPlural(@"InviteLink.PeopleJoinedShort", members, @"%d joined", @"%d joined")];

	NSInteger pending = [link[@"pendingRequests"] integerValue];
	if (pending > 0)
		[parts addObject:TGLPlural(@"MemberRequests.PeopleRequestedShort", pending, @"%d requested", @"%d requested")];

	if (revoked) {
		[parts addObject:TGL(@"InviteLink.Revoked", @"revoked")];
	} else {
		long long expires = [link[@"expirationDate"] longLongValue];
		if (expires > 0) {
			NSTimeInterval left = (NSTimeInterval)expires - [[NSDate date] timeIntervalSince1970];
			if (left <= 0) {
				[parts addObject:TGL(@"InviteLink.Expired", @"expired")];
			} else if (left < 60 * 60 * 24) {
				long long remaining = (long long)left;
				NSString *duration = left < 60 * 60
					? TGLPlural(@"Call.ShortMinutes", (NSInteger)((remaining + 59) / 60), @"%d min", @"%d min")
					: TGLPlural(@"Map.ETAHours", (NSInteger)((remaining + 3599) / 3600), @"%d h", @"%d h");
				[parts addObject:[NSString stringWithFormat:TGL(@"InviteLink.ExpiresIn", @"expires in %@"), duration]];
			} else {
				[parts addObject:[NSString stringWithFormat:TGL(@"InviteLink.ExpiresOn", @"expires %@"),
									 [self dateText:expires]]];
			}
		}
	}
	return [parts componentsJoinedByString:@" - "];
}

- (NSString *)subtitleForRequest:(NSDictionary *)request {
	NSString *bio = request[@"bio"];
	if ([bio isKindOfClass:[NSString class]] && bio.length)
		return bio;
	NSString *date = [self dateText:[request[@"date"] longLongValue]];
	if (date.length)
		return [NSString stringWithFormat:TGL(@"InviteLink.RequestedOn", @"requested %@"), date];
	return TGL(@"InviteLink.WantsToJoin", @"wants to join");
}

#pragma mark - captions

- (UIColor *)captionColour {
	return TGColourFromHex(0x697487);
}

- (UILabel *)captionLabel {
	UILabel *label = [[UILabel alloc] init];
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont systemFontOfSize:14];
	label.textColor = [self captionColour];
	label.shadowColor = TGColourFromHex(0xdae0e8);
	label.shadowOffset = CGSizeMake(0, 1);
	return label;
}

- (NSString *)headerTitleForSection:(NSInteger)section {
	NSInteger kind = [self kindOfSection:section];
	if (kind == kInviteSectionPrimary)
		return TGL(@"InviteLink.InviteLink", @"Invite Link");
	if (kind == kInviteSectionRequests) {
		NSString *base = TGL(@"MemberRequests.Title", @"Member Requests");
		return self.requestTotal > (NSInteger)self.requests.count
			? [NSString stringWithFormat:@"%@ (%d)", base, (int)self.requestTotal]
			: base;
	}
	if (kind == kInviteSectionLinks)
		return TGL(@"InviteLink.AdditionalLinks", @"Additional Links");
	if (kind == kInviteSectionRevoked)
		return TGL(@"InviteLink.RevokedLinks", @"Revoked Links");
	return nil;
}

- (NSString *)footerTitleForSection:(NSInteger)section {
	NSInteger kind = [self kindOfSection:section];
	if (kind == kInviteSectionPrimary) {
		if (!self.loaded)
			return TGL(@"Channel.NotificationLoading", @"Loading…");
		if (self.failed)
			return TGL(@"InviteLink.LoadFailedFooter", @"The links could not be loaded. Leave this screen and open it again to retry.");
		if (!self.primaryLink.length)
			return TGL(@"InviteLink.NoLinkFooter", @"This chat has no invite link. Only an administrator with the right to invite users can make one.");
		if (!self.canManage)
			return TGL(@"InviteLink.PrimaryFooterViewOnly", @"Anyone with this link can join. Tap it to copy or share it.");
		return TGL(@"InviteLink.PrimaryFooterManage", @"Anyone with this link can join. Tap it to copy, share or revoke it.");
	}
	if (kind == kInviteSectionRequests)
		return self.canManage
			? TGL(@"InviteLink.RequestsFooterManage", @"Tap a person to approve or decline the request.")
			: TGL(@"InviteLink.RequestsFooterViewOnly", @"Only an administrator who may invite users can answer these requests.");
	if (kind == kInviteSectionLinks) {
		if (!self.loaded)
			return nil;
		if (!self.canManage)
			return self.links.count ? TGL(@"InviteLink.LinksFooterViewOnly", @"Tap a link to copy or share it.") : nil;
		if (!self.links.count)
			return TGL(@"InviteLink.NoAdditionalLinksFooter", @"You have no additional links yet. A new link can carry its own expiry and member limit.");
		return TGL(@"InviteLink.LinksFooterManage", @"Tap a link to copy, edit or revoke it, or swipe it away to revoke.");
	}
	if (kind == kInviteSectionRevoked)
		return TGL(@"InviteLink.RevokedFooter", @"A revoked link no longer works. Deleting it removes it from this list.");
	return nil;
}

@end
