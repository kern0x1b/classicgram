#import "TGRequestExpiry.h"

NSArray *TGExpiredRequestKeys(NSDictionary *pendingRequests, NSTimeInterval now) {
	NSMutableArray *expired = [NSMutableArray array];
	for (NSString *key in pendingRequests) {
		NSDictionary *entry = pendingRequests[key];
		if (![entry isKindOfClass:[NSDictionary class]]) {
			[expired addObject:key];
			continue;
		}
		id deadline = entry[@"deadline"];
		if (![deadline isKindOfClass:[NSNumber class]] || [deadline doubleValue] <= now)
			[expired addObject:key];
	}
	return expired;
}
