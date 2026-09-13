#import "TGCallService.h"
#import "TGClient+Calls.h"
#import "TGClient+GroupCalls.h"

@implementation TGCallService

+ (void)clearCallHistoryForEveryone:(BOOL)forEveryone
						 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] clearCallHistoryForEveryone:forEveryone completion:completion];
}

+ (void)callHistoryOnlyMissed:(BOOL)onlyMissed
					   offset:(NSString *)offset
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *calls, NSString *nextOffset, BOOL failed))completion {
	[[TGClient shared] callHistoryOnlyMissed:onlyMissed offset:offset limit:limit completion:completion];
}

+ (void)rateCallId:(int32_t)callId
			rating:(NSInteger)rating
		   comment:(NSString *)comment
		  problems:(NSArray *)problems
		completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] rateCallId:callId rating:rating comment:comment problems:problems completion:completion];
}

+ (void)sendCallDebugInformation:(NSString *)information
					   forCallId:(int32_t)callId
					  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] sendCallDebugInformation:information forCallId:callId completion:completion];
}

+ (void)groupCallInfo:(int32_t)groupCallId
		   completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] groupCallInfo:groupCallId completion:completion];
}

@end
