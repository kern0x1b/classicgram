#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (GroupCalls)

- (void)groupCallInfo:(int32_t)groupCallId
		   completion:(void (^ _Nullable)(NSDictionary *info))completion;

@end

NS_ASSUME_NONNULL_END
