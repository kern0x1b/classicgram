#import "TGMembersStatusText.h"
#import "TGDateUtils.h"
#import "TGLocalization.h"

NSString *TGMembersString(NSDictionary *m, NSString *key) {
	id value = [m objectForKey:key];
	return [value isKindOfClass:NSString.class] ? value : @"";
}

NSInteger TGMembersInteger(NSDictionary *m, NSString *key) {
	id value = [m objectForKey:key];
	if ([value isKindOfClass:NSNumber.class])
		return [value integerValue];
	if ([value isKindOfClass:NSString.class])
		return [value integerValue];
	return 0;
}

NSString *TGMembersShortDate(NSTimeInterval seconds) {
	return [TGDateUtils stringForShortDate:(int)seconds];
}

NSString *TGMembersStatusText(NSDictionary *member) {
	NSString *status = TGMembersString(member, @"status");

	if ([status isEqualToString:@"banned"]) {
		NSInteger until = TGMembersInteger(member, @"untilDate");
		if (until > 0)
			return [NSString stringWithFormat:TGL(@"GroupMembers.StatusBannedUntil", @"banned until %@"),
				TGMembersShortDate(until)];
		return TGL(@"GroupMembers.StatusRemoved", @"removed");
	}
	if ([status isEqualToString:@"restricted"]) {
		NSInteger until = TGMembersInteger(member, @"untilDate");
		if (until > 0)
			return [NSString stringWithFormat:TGL(@"GroupMembers.StatusRestrictedUntil", @"restricted until %@"),
				TGMembersShortDate(until)];
		return TGL(@"GroupMembers.StatusRestricted", @"restricted");
	}

	if ([status isEqualToString:@"member"]) {
		NSInteger until = TGMembersInteger(member, @"untilDate");
		if (until > 0)
			return [NSString stringWithFormat:TGL(@"GroupMembers.StatusMemberUntil", @"member until %@"),
				TGMembersShortDate(until)];
	}

	NSString *presence = TGMembersString(member, @"presenceText");
	if (presence.length)
		return presence;

	if ([status isEqualToString:@"creator"])
		return TGL(@"GroupInfo.LabelOwner", @"owner");
	if ([status isEqualToString:@"administrator"])
		return TGL(@"GroupInfo.LabelAdmin", @"admin");
	if ([status isEqualToString:@"left"])
		return TGL(@"GroupMembers.StatusLeft", @"left the group");
	return TGL(@"GroupMembers.StatusMember", @"member");
}

NSString *TGMembersRoleText(NSDictionary *member) {
	NSString *status = TGMembersString(member, @"status");
	if ([status isEqualToString:@"banned"] || [status isEqualToString:@"restricted"])
		return nil;

	NSString *customTitle = TGMembersString(member, @"customTitle");
	if (customTitle.length)
		return customTitle;
	if ([status isEqualToString:@"creator"])
		return TGL(@"GroupInfo.LabelOwner", @"owner");
	if ([status isEqualToString:@"administrator"])
		return TGL(@"GroupInfo.LabelAdmin", @"admin");
	return nil;
}

BOOL TGMembersStatusIsOnline(NSDictionary *member) {
	NSString *status = TGMembersString(member, @"status");
	if ([status isEqualToString:@"banned"] || [status isEqualToString:@"restricted"])
		return NO;
	if (![TGMembersString(member, @"presenceText") length])
		return NO;
	return [[member objectForKey:@"presenceIsOnline"] boolValue];
}

const CGFloat kMemberAvatar = 40.0f;

int64_t TGMembersUserId(NSDictionary *m) {
	id value = [m objectForKey:@"id"];
	return [value isKindOfClass:NSNumber.class] ? [value longLongValue] : 0;
}
