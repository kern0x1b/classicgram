#import "TGFlattenChannels.h"

static NSNumber *TGFCNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : @(0);
}

static NSString *TGFCString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSDictionary *TGFCDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

NSDictionary *TGChValue(NSString *key, NSString *title, id raw) {
	NSDictionary *v = TGFCDict(raw);
	if (!v)
		return nil;
	return @{
		@"key" : key,
		@"title" : title,
		@"value" : TGFCNumber(v[@"value"]),
		@"previous" : TGFCNumber(v[@"previous_value"]),
		@"growth" : TGFCNumber(v[@"growth_rate_percentage"]),
	};
}

NSDictionary *TGChGraph(NSString *key, NSString *title, id raw) {
	NSDictionary *g = TGFCDict(raw);
	if (!g)
		return nil;
	NSString *type = TGFCString(g[@"@type"]);
	if ([type isEqualToString:@"statisticalGraphData"]) {
		return @{
			@"key" : key,
			@"title" : title,
			@"json" : TGFCString(g[@"json_data"]),
			@"zoom_token" : TGFCString(g[@"zoom_token"]),
		};
	}
	if ([type isEqualToString:@"statisticalGraphAsync"]) {
		return @{
			@"key" : key,
			@"title" : title,
			@"token" : TGFCString(g[@"token"]),
		};
	}
	if ([type isEqualToString:@"statisticalGraphError"]) {
		return @{
			@"key" : key,
			@"title" : title,
			@"error" : TGFCString(g[@"error_message"]),
		};
	}
	return nil;
}

void TGChAddGraphs(NSMutableArray *out, NSDictionary *stats, NSArray *pairs) {
	for (NSInteger i = 0; i + 1 < pairs.count; i += 2) {
		NSString *key = pairs[i];
		NSString *title = pairs[i + 1];
		NSDictionary *g = TGChGraph(key, title, stats[key]);
		if (g)
			[out addObject:g];
	}
}

void TGChAddValues(NSMutableArray *out, NSDictionary *stats, NSArray *pairs) {
	for (NSInteger i = 0; i + 1 < pairs.count; i += 2) {
		NSDictionary *v = TGChValue(pairs[i], pairs[i + 1], stats[pairs[i]]);
		if (v)
			[out addObject:v];
	}
}

NSDictionary *TGChBoostSlot(long long currentlyBoostedChatId, long long cooldownUntilDate, NSTimeInterval now) {
	BOOL isFree = currentlyBoostedChatId == 0;
	BOOL isAvailable = (double)cooldownUntilDate <= now;
	return @{
		@"is_free" : @(isFree),
		@"is_available" : @(isAvailable),
		@"is_reassignable" : @(!isFree && isAvailable),
	};
}

NSDictionary *TGChPointsFromGraphJson(NSString *json, NSUInteger maxPoints) {
	NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
	if (!data.length)
		return nil;
	id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
	if (![parsed isKindOfClass:[NSDictionary class]])
		return nil;
	id columns = [(NSDictionary *)parsed objectForKey:@"columns"];
	if (![columns isKindOfClass:[NSArray class]])
		return nil;

	NSArray *xColumn = nil;
	NSMutableArray *dataColumns = [NSMutableArray array];
	for (id column in columns) {
		if (![column isKindOfClass:[NSArray class]] || [(NSArray *)column count] < 2)
			continue;
		NSString *key = [[(NSArray *)column objectAtIndex:0] isKindOfClass:[NSString class]]
			? [(NSArray *)column objectAtIndex:0]
			: nil;
		if ([key isEqualToString:@"x"])
			xColumn = column;
		else
			[dataColumns addObject:column];
	}
	if (!dataColumns.count)
		return nil;

	NSUInteger length = 0;
	for (NSArray *column in dataColumns)
		length = MAX(length, column.count);
	if (length < 2)
		return nil;

	NSMutableArray *points = [NSMutableArray array];
	for (NSUInteger i = 1; i < length; i++) {
		double sum = 0;
		BOOL any = NO;
		for (NSArray *column in dataColumns) {
			if (i >= column.count)
				continue;
			id value = column[i];
			if ([value isKindOfClass:[NSNumber class]]) {
				sum += [(NSNumber *)value doubleValue];
				any = YES;
			}
		}
		[points addObject:any ? @(sum) : @(0)];
	}
	if (maxPoints > 0 && points.count > maxPoints)
		[points removeObjectsInRange:NSMakeRange(0, points.count - maxPoints)];
	if (points.count < 2)
		return nil;

	NSNumber *firstX = nil;
	NSNumber *lastX = nil;
	if (xColumn.count >= 2) {
		NSUInteger total = xColumn.count - 1;
		NSUInteger firstIndex = total > points.count ? total - points.count + 1 : 1;
		id firstValue = xColumn[firstIndex];
		id lastValue = xColumn.lastObject;
		firstX = [firstValue isKindOfClass:[NSNumber class]] ? firstValue : nil;
		lastX = [lastValue isKindOfClass:[NSNumber class]] ? lastValue : nil;
	}

	return @{
		@"points" : points,
		@"firstX" : firstX ?: [NSNull null],
		@"lastX" : lastX ?: [NSNull null],
		@"seriesCount" : @(dataColumns.count),
	};
}
