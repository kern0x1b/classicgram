#import "TGFlattenContacts.h"
#import "TGDateUtils.h"
#import "TGLocalization.h"

static NSDictionary *TGFCDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGFCArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSString *TGFCString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGFCFileId(NSDictionary *file) {
	NSDictionary *f = TGFCDict(file);
	NSNumber *fid = [f[@"id"] isKindOfClass:NSNumber.class] ? f[@"id"] : nil;
	return fid;
}

NSString *TGFirstUsername(NSDictionary *user) {
	NSDictionary *names = TGFCDict(user[@"usernames"]);
	NSArray *active = TGFCArray(names[@"active_usernames"]);
	if (active.count && [active[0] isKindOfClass:NSString.class])
		return active[0];
	return TGFCString(names[@"editable_username"]);
}

NSDictionary *TGFlatUser(NSDictionary *u) {
	if (![u isKindOfClass:NSDictionary.class] ||
		![u[@"@type"] isEqualToString:@"user"])
		return nil;
	NSNumber *photo = TGFCFileId(TGFCDict(u[@"profile_photo"])[@"small"]);
	return @{
		@"id" : u[@"id"] ?: @(0),
		@"first_name" : TGFCString(u[@"first_name"]),
		@"last_name" : TGFCString(u[@"last_name"]),
		@"phone" : TGFCString(u[@"phone_number"]),
		@"username" : TGFirstUsername(u),
		@"photoFileId" : photo ?: (id)[NSNull null],
		@"isContact" : @([u[@"is_contact"] boolValue]),
		@"isMutualContact" : @([u[@"is_mutual_contact"] boolValue]),
		@"isCloseFriend" : @([u[@"is_close_friend"] boolValue]),
		@"isPremium" : @([u[@"is_premium"] boolValue]),
		@"restrictionReason" : TGFCString(TGFCDict(u[@"restriction_info"])[@"restriction_reason"]),
	};
}

NSString *TGProfileTabName(id tab) {
	NSString *type = TGFCString(TGFCDict(tab)[@"@type"]);
	if (![type hasPrefix:@"profileTab"] || type.length <= 10)
		return nil;
	return [[type substringFromIndex:10] lowercaseString];
}

static NSCalendar *TGFCGregorianCalendar(void) {
	static NSCalendar *calendar;
	if (!calendar)
		calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	return calendar;
}

NSDictionary *TGBirthdateInfo(id value) {
	NSDictionary *b = TGFCDict(value);
	NSInteger day = [b[@"day"] integerValue];
	NSInteger month = [b[@"month"] integerValue];
	if (day < 1 || month < 1 || month > 12)
		return nil;
	NSInteger year = [b[@"year"] integerValue];

	NSDateComponents *components = [[NSDateComponents alloc] init];
	components.day = day;
	components.month = month;
	components.year = year > 0 ? year : 2000;
	NSDate *date = [TGFCGregorianCalendar() dateFromComponents:components];

	int stamp = (int)[date timeIntervalSince1970];
	NSString *text = year > 0 ? [TGDateUtils stringForFullDate:stamp]
							  : [TGDateUtils stringForDayAndMonth:stamp];

	return @{@"day" : @(day),
		@"month" : @(month),
		@"year" : @(year),
		@"text" : text};
}

BOOL TGBirthdateIsToday(NSDictionary *birthdate) {
	NSDictionary *b = TGFCDict(birthdate);
	NSInteger day = [b[@"day"] integerValue];
	NSInteger month = [b[@"month"] integerValue];
	if (day < 1 || month < 1)
		return NO;
	NSDateComponents *now = [TGFCGregorianCalendar()
		components:(NSDayCalendarUnit | NSMonthCalendarUnit)
		  fromDate:[NSDate date]];
	return now.day == day && now.month == month;
}
