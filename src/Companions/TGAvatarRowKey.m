#import "TGAvatarRowKey.h"

BOOL TGAvatarRowKeyMatches(NSNumber *rowKey, NSNumber *changedKey) {
	if (![rowKey isKindOfClass:[NSNumber class]] || ![changedKey isKindOfClass:[NSNumber class]])
		return NO;
	if ([changedKey longLongValue] == 0)
		return NO;
	return [rowKey longLongValue] == [changedKey longLongValue];
}
