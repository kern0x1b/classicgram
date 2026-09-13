#import "TGLiveLocationRehydration.h"
#import "TGLiveLocationExpiry.h"

int64_t TGOwnActiveLiveLocationMessageId(NSArray<NSDictionary *> *messages, NSTimeInterval now) {
	int64_t bestMessageId = 0;
	double bestDate = -1;
	for (NSDictionary *m in messages) {
		if (![m isKindOfClass:NSDictionary.class])
			continue;
		if (![m[@"kind"] isEqualToString:@"messageLiveLocation"])
			continue;
		if (![m[@"outgoing"] boolValue])
			continue;
		if (TGLiveLocationHasExpired([m[@"livePeriod"] integerValue], [m[@"liveExpiresAt"] doubleValue], now))
			continue;
		double date = [m[@"date"] doubleValue];
		if (bestMessageId != 0 && date <= bestDate)
			continue;
		bestMessageId = [m[@"id"] longLongValue];
		bestDate = date;
	}
	return bestMessageId;
}
