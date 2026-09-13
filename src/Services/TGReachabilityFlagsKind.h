#import <Foundation/Foundation.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#define TGReachabilityFlagIsWWAN kSCNetworkReachabilityFlagsIsWWAN
#else
#define TGReachabilityFlagIsWWAN ((SCNetworkReachabilityFlags)(1 << 18))
#endif

extern NSString *TGReachabilityNetworkTypeKindForFlags(SCNetworkReachabilityFlags flags);
