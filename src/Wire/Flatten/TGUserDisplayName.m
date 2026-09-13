#import "TGUserDisplayName.h"

#import "TGLocalization.h"

static NSString *TGUserDisplayNameString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSString *TGUserDisplayNameUsername(NSDictionary *user) {
	NSArray *active = user[@"usernames"][@"active_usernames"];
	if (![active isKindOfClass:NSArray.class] || !active.count)
		return @"";
	return TGUserDisplayNameString([active objectAtIndex:0]);
}

NSString *TGUserDisplayName(NSDictionary *user) {
	if (![user isKindOfClass:NSDictionary.class])
		return @"";
	NSString *joined = [NSString stringWithFormat:@"%@ %@",
		TGUserDisplayNameString(user[@"first_name"]),
		TGUserDisplayNameString(user[@"last_name"])];
	NSString *name = [joined stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceCharacterSet]];
	if (name.length)
		return name;
	NSString *username = TGUserDisplayNameUsername(user);
	if (username.length)
		return username;
	return TGL(@"User.DeletedAccount", @"Deleted Account");
}
