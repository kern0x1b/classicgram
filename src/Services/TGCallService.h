#import <Foundation/Foundation.h>

@interface TGCallService : NSObject

+ (void)clearCallHistoryForEveryone:(BOOL)forEveryone
						 completion:(void (^)(BOOL ok))completion;

+ (void)callHistoryOnlyMissed:(BOOL)onlyMissed
					   offset:(NSString *)offset
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *calls, NSString *nextOffset, BOOL failed))completion;

+ (void)rateCallId:(int32_t)callId
			rating:(NSInteger)rating
		   comment:(NSString *)comment
		  problems:(NSArray *)problems
		completion:(void (^)(BOOL ok))completion;

+ (void)sendCallDebugInformation:(NSString *)information
					   forCallId:(int32_t)callId
					  completion:(void (^)(BOOL ok))completion;

+ (void)groupCallInfo:(int32_t)groupCallId
		   completion:(void (^)(NSDictionary *info))completion;

@end
