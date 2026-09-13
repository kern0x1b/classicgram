#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGProxyListDidChangeNotification;

extern NSString *const TGConnectionStateDidChangeNotification;
extern NSString *const TGConnectionStateKey;
extern NSString *const TGConnectionStateTitleKey;

@interface TGClient (Network)

#pragma mark - proxy list

- (void)proxiesWithCompletion:(void (^ _Nullable)(NSArray *proxies))completion;

- (void)addProxy:(NSDictionary *)proxy
		  enable:(BOOL)enable
	  completion:(void (^ _Nullable)(NSDictionary *_Nullable added, NSString *_Nullable errorMessage))completion;

- (void)editProxy:(NSInteger)proxyId
			   to:(NSDictionary *)proxy
		   enable:(BOOL)enable
	   completion:(void (^ _Nullable)(NSDictionary *_Nullable edited, NSString *_Nullable errorMessage))completion;

- (void)enableProxy:(NSInteger)proxyId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)disableProxyWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)removeProxy:(NSInteger)proxyId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)activeProxyWithCompletion:(void (^ _Nullable)(NSDictionary *proxy))completion;

- (void)activeProxyIdWithCompletion:(void (^ _Nullable)(NSInteger proxyId))completion;

- (void)setProxy:(NSInteger)proxyId
		 enabled:(BOOL)enabled
	  completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - proxy checks

- (void)pingProxy:(nullable NSDictionary *)proxy
	   completion:(void (^ _Nullable)(double seconds))completion;

- (void)pingAllProxiesWithCompletion:(void (^ _Nullable)(NSDictionary *secondsByProxyId))completion;

- (void)testProxy:(NSDictionary *)proxy
			 dcId:(NSInteger)dcId
		  timeout:(double)timeout
	   completion:(void (^ _Nullable)(BOOL reachable))completion;

#pragma mark - proxy links

- (void)proxyLinkFor:(NSDictionary *)proxy
		  completion:(void (^ _Nullable)(NSString *link))completion;

- (void)proxyFromLink:(NSString *)link
		   completion:(void (^ _Nullable)(NSDictionary *proxy))completion;

#pragma mark - network type

- (void)setNetworkTypeKind:(NSString *)kind;

#pragma mark - data usage

- (void)resetNetworkStatisticsWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)addCallStatisticsSent:(long long)sentBytes
					 received:(long long)receivedBytes
					 duration:(double)seconds
				  networkKind:(NSString *)kind;

#pragma mark - auto-download

- (void)autoDownloadPresetsWithCompletion:(void (^ _Nullable)(NSDictionary *presets))completion;

- (void)setAutoDownloadSettings:(NSDictionary *)settings
					networkKind:(NSString *)kind
					 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setDataSaverEnabled:(BOOL)enabled completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setUseLessDataForCalls:(BOOL)useLess completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - diagnostics

- (void)optionNamed:(NSString *)name completion:(void (^ _Nullable)(id value))completion;

- (void)setOptionNamed:(NSString *)name
				 value:(id)value
			 isBoolean:(BOOL)isBoolean;

- (NSString *)connectionStateTitle;

- (NSString *)connectionStateTitleForState:(TGConnectionState)state;

- (void)beginBroadcastingConnectionState;

- (void)endBroadcastingConnectionState;

@end

NS_ASSUME_NONNULL_END
