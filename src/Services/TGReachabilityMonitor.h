#import <Foundation/Foundation.h>
#import "TGReachabilityFlagsKind.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGReachabilityMonitor : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, readonly) NSString *currentNetworkTypeKind;

- (void)start;

@end

NS_ASSUME_NONNULL_END
