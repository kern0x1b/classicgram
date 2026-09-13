#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Calls)

#pragma mark - call history

- (void)callHistoryOnlyMissed:(BOOL)onlyMissed
					   offset:(NSString *)offset
						limit:(NSInteger)limit
				   completion:(void (^ _Nullable)(NSArray *calls, NSString *nextOffset, BOOL failed))completion;

- (void)clearCallHistoryForEveryone:(BOOL)forEveryone
						 completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - after a call: rating

- (void)rateCallId:(int32_t)callId
			rating:(NSInteger)rating
		   comment:(NSString *)comment
		  problems:(NSArray *)problems
		completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)sendCallDebugInformation:(NSString *)information
					   forCallId:(int32_t)callId
					  completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - placing and ending a call

- (void)createCallToUserId:(int64_t)userId
					  video:(BOOL)video
				 completion:(void (^ _Nullable)(int32_t callId, BOOL success))completion;

- (void)acceptCallId:(int32_t)callId;

- (void)discardCallId:(int32_t)callId
			 duration:(NSInteger)duration
				video:(BOOL)video
	   isDisconnected:(BOOL)isDisconnected
		 connectionId:(int64_t)connectionId;

- (void)sendSignalingData:(NSString *)base64Data forCallId:(int32_t)callId;

@end

NS_ASSUME_NONNULL_END
