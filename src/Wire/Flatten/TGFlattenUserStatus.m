#import "TGFlattenUserStatus.h"
#import "TGLocalization.h"
#import "TGDateUtils.h"

static NSDictionary *TGFUSDict(id value) {
	if (![value isKindOfClass:[NSDictionary class]])
		return nil;
	return value;
}

static NSString *TGFUSString(id value) {
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return value;
}

NSString *TGUSLastSeenText(long long wasOnline) {
	if (wasOnline <= 0)
		return TGL(@"LastSeen.ALongTimeAgo", @"last seen a long time ago");

	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)wasOnline];
	NSCalendar *cal = [NSCalendar currentCalendar];
	NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
	NSDate *dayOfDate = [cal dateFromComponents:[cal components:units fromDate:date]];
	NSDate *dayOfNow = [cal dateFromComponents:[cal components:units fromDate:[NSDate date]]];
	NSInteger delta = [cal components:NSDayCalendarUnit
							 fromDate:dayOfDate
							   toDate:dayOfNow
							  options:0]
						  .day;
	NSString *time = [TGDateUtils stringForShortTime:(int)wasOnline];

	if (delta <= 0)
		return [NSString stringWithFormat:TGL(@"LastSeen.TodayAt", @"last seen today at %@"), time];
	if (delta == 1)
		return [NSString stringWithFormat:TGL(@"LastSeen.YesterdayAt", @"last seen yesterday at %@"), time];
	if (delta < 7)
		return [NSString stringWithFormat:TGL(@"Presence.LastSeenOnWeekdayAt",
									 @"last seen on %@ at %@"),
			[TGDateUtils stringForWeekday:(int)wasOnline], time];
	return [NSString stringWithFormat:TGL(@"Presence.LastSeenOnDateAt", @"last seen %@ at %@"),
		[TGDateUtils stringForShortDate:(int)wasOnline], time];
}

NSDictionary *TGUSStatusInfoForType(NSString *type, long long wasOnline, BOOL hiddenByMyPrivacy) {
	if ([type isEqualToString:@"userStatusOnline"])
		return @{@"text" : TGL(@"Presence.online", @"online"), @"isOnline" : @YES, @"rank" : @(4000000000LL), @"wasOnline" : @(0), @"isApproximate" : @NO, @"hiddenByMyPrivacy" : @NO};
	if ([type isEqualToString:@"userStatusOffline"])
		return @{@"text" : TGUSLastSeenText(wasOnline), @"isOnline" : @NO, @"rank" : @(wasOnline), @"wasOnline" : @(wasOnline), @"isApproximate" : @NO, @"hiddenByMyPrivacy" : @NO};
	if ([type isEqualToString:@"userStatusRecently"])
		return @{@"text" : TGL(@"LastSeen.Lately", @"last seen recently"), @"isOnline" : @NO, @"rank" : @(3), @"wasOnline" : @(0), @"isApproximate" : @YES, @"hiddenByMyPrivacy" : @(hiddenByMyPrivacy)};
	if ([type isEqualToString:@"userStatusLastWeek"])
		return @{@"text" : TGL(@"LastSeen.WithinAWeek", @"last seen within a week"), @"isOnline" : @NO, @"rank" : @(2), @"wasOnline" : @(0), @"isApproximate" : @YES, @"hiddenByMyPrivacy" : @(hiddenByMyPrivacy)};
	if ([type isEqualToString:@"userStatusLastMonth"])
		return @{@"text" : TGL(@"LastSeen.WithinAMonth", @"last seen within a month"), @"isOnline" : @NO, @"rank" : @(1), @"wasOnline" : @(0), @"isApproximate" : @YES, @"hiddenByMyPrivacy" : @(hiddenByMyPrivacy)};

	return @{@"text" : @"", @"isOnline" : @NO, @"rank" : @(0), @"wasOnline" : @(0), @"isApproximate" : @NO, @"hiddenByMyPrivacy" : @NO};
}

NSDictionary *TGUSFlatEmojiStatusIcon(NSDictionary *sticker,
	long long customEmojiId,
	long long expires,
	BOOL isGift,
	NSString *giftTitle) {
	NSDictionary *s = TGFUSDict(sticker);
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"customEmojiId"] = @(customEmojiId);
	out[@"expires"] = @(expires);
	out[@"isGift"] = @(isGift);
	out[@"giftTitle"] = giftTitle ?: @"";
	out[@"emoji"] = TGFUSString(s[@"emoji"]);

	NSDictionary *thumbFile = TGFUSDict(TGFUSDict(s[@"thumbnail"])[@"file"]);
	if ([thumbFile[@"id"] isKindOfClass:NSNumber.class])
		out[@"thumbFileId"] = thumbFile[@"id"];

	NSDictionary *file = TGFUSDict(s[@"sticker"]);
	if ([file[@"id"] isKindOfClass:NSNumber.class])
		out[@"stickerFileId"] = file[@"id"];

	NSString *format = TGFUSString(TGFUSDict(s[@"format"])[@"@type"]);
	out[@"isAnimated"] = @([format isEqualToString:@"stickerFormatTgs"]);
	out[@"isTgs"] = @([format isEqualToString:@"stickerFormatTgs"]);
	return out;
}

NSArray<NSNumber *> *TGUSMergePickableEmojiStatusIds(NSArray<NSNumber *> *themedIds,
	NSArray<NSNumber *> *recentIds,
	NSArray<NSNumber *> *defaultIds,
	NSUInteger cap) {
	NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
	for (NSArray<NSNumber *> *tier in @[ themedIds ?: @[], recentIds ?: @[], defaultIds ?: @[] ]) {
		for (NSNumber *emojiId in tier) {
			if (emojiId.longLongValue && ![ids containsObject:emojiId])
				[ids addObject:emojiId];
		}
	}
	if (cap && ids.count > cap)
		[ids removeObjectsInRange:NSMakeRange(cap, ids.count - cap)];
	return ids;
}
