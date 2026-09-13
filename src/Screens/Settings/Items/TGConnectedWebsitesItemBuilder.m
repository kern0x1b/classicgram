#import "TGConnectedWebsitesItemBuilder.h"
#import "TGDateUtils.h"
#import "TGConnectedWebsitesCellCatalogue.h"
#import "TGLocalization.h"

static NSString *TGConnectedWebsitesDateText(long long stamp) {
	if (stamp <= 0)
		return nil;
	return [TGDateUtils stringForFullDate:(int)stamp];
}

@implementation TGConnectedWebsitesItemBuilder

+ (TGConnectedWebsitesItem *)itemFromSite:(NSDictionary *)site {
	id botName = site[@"botName"];
	id domain = site[@"domain"];
	NSString *titleText = [botName isKindOfClass:[NSString class]] && [botName length]
		? botName
		: ([domain isKindOfClass:[NSString class]] ? domain : TGL(@"Privacy.Website", @"Website"));

	NSMutableArray *firstLine = [NSMutableArray array];
	for (NSString *key in [NSArray arrayWithObjects:@"domain", @"browser", @"platform", nil]) {
		id value = site[key];
		if ([value isKindOfClass:[NSString class]] && [value length])
			[firstLine addObject:value];
	}
	NSMutableArray *secondLine = [NSMutableArray array];
	for (NSString *key in [NSArray arrayWithObjects:@"ip", @"location", nil]) {
		id value = site[key];
		if ([value isKindOfClass:[NSString class]] && [value length])
			[secondLine addObject:value];
	}
	NSString *loginDateText = TGConnectedWebsitesDateText([site[@"loginDate"] longLongValue]);
	if (loginDateText.length)
		[secondLine addObject:[NSString stringWithFormat:@"%@ %@",
				TGL(@"AuthSessions.LoggedInAt", @"Logged in"), loginDateText]];
	NSString *lastActiveText = TGConnectedWebsitesDateText([site[@"lastActive"] longLongValue]);
	if (lastActiveText.length)
		[secondLine addObject:[NSString stringWithFormat:@"%@ %@",
				TGL(@"AuthSessions.LastActiveAt", @"Last active"), lastActiveText]];
	NSMutableArray *lines = [NSMutableArray array];
	if (firstLine.count)
		[lines addObject:[firstLine componentsJoinedByString:@", "]];
	if (secondLine.count)
		[lines addObject:[secondLine componentsJoinedByString:@", "]];
	NSString *detailText = [lines componentsJoinedByString:@"\n"];

	id siteId = site[@"id"];
	int64_t resolvedSiteId = [siteId isKindOfClass:[NSNumber class]] ? [siteId longLongValue] : 0;

	NSString *reuseIdentifier = [TGConnectedWebsitesCellCatalogue reuseIdentifierForKind:TGConnectedWebsitesRowKindSite];
	Class cellClass = [TGConnectedWebsitesCellCatalogue cellClassForKind:TGConnectedWebsitesRowKindSite];
	TGConnectedWebsitesItem *item = [TGConnectedWebsitesItem alloc];
	item = [item initWithKind:TGConnectedWebsitesRowKindSite
			  reuseIdentifier:reuseIdentifier
					cellClass:cellClass
					   siteId:resolvedSiteId
					titleText:titleText
				   detailText:detailText];
	return item;
}

@end
