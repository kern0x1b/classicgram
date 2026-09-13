#import "TGCacheTrim.h"

NSArray *TGCacheTrimKeys(NSArray *order, NSUInteger limit, NSUInteger keep) {
	if (![order isKindOfClass:[NSArray class]] || order.count <= limit)
		return @[];
	if (keep >= order.count)
		return @[];
	NSUInteger drop = order.count - keep;
	return [order subarrayWithRange:NSMakeRange(0, drop)];
}
