#import "TGClient+Private.h"
#import "TGClient+Network.h"
#import "TGFlattenNetwork.h"
#import "TGLocalization.h"

@interface TGClient (NetworkInternal)
- (void)tgNetworkAutoDownloadPresetsWithCompletion:(void (^)(NSDictionary *presets))completion;
- (void)tgNetworkApplyAutoDownloadSettings:(NSDictionary *)settings
						toEveryNetworkKind:(void (^)(BOOL ok))completion;
- (void)tgNetworkConnectionStateTick:(NSTimer *)timer;
@end

NSString *const TGProxyListDidChangeNotification = @"TGProxyListDidChangeNotification";
NSString *const TGConnectionStateDidChangeNotification = @"TGConnectionStateDidChangeNotification";
NSString *const TGConnectionStateKey = @"state";
NSString *const TGConnectionStateTitleKey = @"title";

static NSInteger TGNetStateObservers = 0;
static NSTimer *TGNetStateTimer = nil;
static TGConnectionState TGNetLastState = TGConnectionStateUnknown;
static BOOL TGNetHasLastState = NO;

static void TGNetPostProxyListChanged(id client) {
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	[centre postNotificationName:TGProxyListDidChangeNotification object:client];
}

static NSString *TGNetString(id value) {
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return value;
}

static NSNumber *TGNetNumber(id value) {
	if (![value isKindOfClass:[NSNumber class]])
		return @0;
	return value;
}

static NSNumber *TGNetBool(id value) {
	if (![value isKindOfClass:[NSNumber class]])
		return @NO;
	return [value boolValue] ? @YES : @NO;
}

static NSArray *TGNetArray(id value) {
	if (![value isKindOfClass:[NSArray class]])
		return [NSArray array];
	return value;
}

static NSDictionary *TGNetDict(id value) {
	if (![value isKindOfClass:[NSDictionary class]])
		return nil;
	return value;
}

static NSDictionary *TGNetProxyObject(NSDictionary *proxy) {
	if (![proxy isKindOfClass:[NSDictionary class]])
		return nil;
	return @{@"@type" : @"proxy",
		@"server" : TGNetString(proxy[@"server"]),
		@"port" : TGNetNumber(proxy[@"port"]),
		@"type" : TGNetProxyTypeObject(proxy)};
}

static NSString *TGNetErrorMessage(NSDictionary *result) {
	NSString *message = result[@"message"];
	return [message isKindOfClass:[NSString class]] ? message : nil;
}

@implementation TGClient (Network)

#pragma mark - proxy list

- (void)proxiesWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getProxies"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSMutableArray *out = [NSMutableArray array];
		if (!TGResultIsError(result)) {
			for (id item in TGNetArray(result[@"proxies"])) {
				NSDictionary *proxy = TGNetAddedProxyDict(TGNetDict(item));
				if (proxy)
					[out addObject:proxy];
			}
		}
		completion(out);
	}];
}

- (void)addProxy:(NSDictionary *)proxy
		  enable:(BOOL)enable
	  completion:(void (^)(NSDictionary *, NSString *))completion {
	NSDictionary *object = TGNetProxyObject(proxy);
	if (!object) {
		if (completion)
			completion(nil, nil);
		return;
	}
	[self request:@{@"@type" : @"addProxy",
		@"proxy" : object,
		@"enable" : enable ? @YES : @NO,
		@"comment" : TGNetString(proxy[@"comment"])}
		completion:^(NSDictionary *result) {
			if (!TGResultIsError(result))
				TGNetPostProxyListChanged(self);
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, TGNetErrorMessage(result));
				return;
			}
			completion(TGNetAddedProxyDict(result), nil);
		}];
}

- (void)editProxy:(NSInteger)proxyId
			   to:(NSDictionary *)proxy
		   enable:(BOOL)enable
	   completion:(void (^)(NSDictionary *, NSString *))completion {
	NSDictionary *object = TGNetProxyObject(proxy);
	if (!object) {
		if (completion)
			completion(nil, nil);
		return;
	}
	[self request:@{@"@type" : @"editProxy",
		@"proxy_id" : @(proxyId),
		@"proxy" : object,
		@"enable" : enable ? @YES : @NO,
		@"comment" : TGNetString(proxy[@"comment"])}
		completion:^(NSDictionary *result) {
			if (!TGResultIsError(result))
				TGNetPostProxyListChanged(self);
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, TGNetErrorMessage(result));
				return;
			}
			completion(TGNetAddedProxyDict(result), nil);
		}];
}

- (void)enableProxy:(NSInteger)proxyId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"enableProxy", @"proxy_id" : @(proxyId)}
		completion:^(NSDictionary *result) {
			BOOL ok = !TGResultIsError(result);
			if (ok)
				TGNetPostProxyListChanged(self);
			if (completion)
				completion(ok);
		}];
}

- (void)disableProxyWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"disableProxy"} completion:^(NSDictionary *result) {
		BOOL ok = !TGResultIsError(result);
		if (ok)
			TGNetPostProxyListChanged(self);
		if (completion)
			completion(ok);
	}];
}

- (void)removeProxy:(NSInteger)proxyId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"removeProxy", @"proxy_id" : @(proxyId)}
		completion:^(NSDictionary *result) {
			BOOL ok = !TGResultIsError(result);
			if (ok)
				TGNetPostProxyListChanged(self);
			if (completion)
				completion(ok);
		}];
}

- (void)activeProxyWithCompletion:(void (^)(NSDictionary *))completion {
	[self proxiesWithCompletion:^(NSArray *proxies) {
		if (!completion)
			return;
		for (id item in proxies) {
			NSDictionary *proxy = TGNetDict(item);
			if (proxy && [TGNetBool(proxy[@"isEnabled"]) boolValue]) {
				completion(proxy);
				return;
			}
		}
		completion(nil);
	}];
}

- (void)activeProxyIdWithCompletion:(void (^)(NSInteger))completion {
	[self activeProxyWithCompletion:^(NSDictionary *proxy) {
		if (!completion)
			return;
		if (!proxy) {
			completion(-1);
			return;
		}
		completion([TGNetNumber(proxy[@"id"]) integerValue]);
	}];
}

- (void)setProxy:(NSInteger)proxyId
		 enabled:(BOOL)enabled
	  completion:(void (^)(BOOL))completion {
	if (enabled)
		[self enableProxy:proxyId completion:completion];
	else
		[self disableProxyWithCompletion:completion];
}

#pragma mark - proxy checks

- (void)pingProxy:(NSDictionary *)proxy
	   completion:(void (^)(double))completion {
	NSMutableDictionary *request = [NSMutableDictionary dictionary];
	[request setObject:@"pingProxy" forKey:@"@type"];
	NSDictionary *object = TGNetProxyObject(proxy);
	if (object)
		[request setObject:object forKey:@"proxy"];
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(-1.0);
			return;
		}
		completion([TGNetNumber(result[@"seconds"]) doubleValue]);
	}];
}

- (void)pingAllProxiesWithCompletion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	[self proxiesWithCompletion:^(NSArray *proxies) {
		NSMutableDictionary *results = [NSMutableDictionary dictionary];
		if (!proxies.count) {
			if (completion)
				completion(results);
			return;
		}
		__block NSUInteger remaining = proxies.count;
		for (NSDictionary *proxy in proxies) {
			NSNumber *proxyId = TGNetNumber(proxy[@"id"]);
			[weakSelf pingProxy:proxy completion:^(double seconds) {
				[results setObject:[NSNumber numberWithDouble:seconds] forKey:proxyId];
				remaining--;
				if (remaining == 0 && completion)
					completion(results);
			}];
		}
	}];
}

- (void)testProxy:(NSDictionary *)proxy
			 dcId:(NSInteger)dcId
		  timeout:(double)timeout
	   completion:(void (^)(BOOL))completion {
	NSDictionary *object = TGNetProxyObject(proxy);
	if (!object) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{@"@type" : @"testProxy",
		@"proxy" : object,
		@"dc_id" : @(dcId > 0 ? dcId : 2),
		@"timeout" : [NSNumber numberWithDouble:timeout > 0.0 ? timeout : 10.0]}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - proxy links

- (void)proxyLinkFor:(NSDictionary *)proxy
		  completion:(void (^)(NSString *))completion {
	NSDictionary *object = TGNetProxyObject(proxy);
	if (!object) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getInternalLink",
		@"type" : @{@"@type" : @"internalLinkTypeProxy",
			@"proxy" : object},
		@"is_http" : @YES}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSString *url = result[@"url"];
			completion([url isKindOfClass:[NSString class]] && url.length ? url : nil);
		}];
}

- (void)proxyFromLink:(NSString *)link
		   completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getInternalLinkType",
		@"link" : TGNetString(link)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result) ||
				![TGNetString(result[@"@type"]) isEqualToString:@"internalLinkTypeProxy"]) {
				completion(nil);
				return;
			}
			completion(TGNetProxyDict(TGNetDict(result[@"proxy"]), nil));
		}];
}

#pragma mark - network type

- (void)setNetworkTypeKind:(NSString *)kind {
	[self send:@{@"@type" : @"setNetworkType",
		@"type" : @{@"@type" : TGNetNetworkTypeName(kind)}}];
}

#pragma mark - data usage

- (void)resetNetworkStatisticsWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"resetNetworkStatistics"}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)addCallStatisticsSent:(long long)sentBytes
					 received:(long long)receivedBytes
					 duration:(double)seconds
				  networkKind:(NSString *)kind {
	[self send:@{
		@"@type" : @"addNetworkStatistics",
		@"entry" : @{
			@"@type" : @"networkStatisticsEntryCall",
			@"network_type" : @{@"@type" : TGNetNetworkTypeName(kind)},
			@"sent_bytes" : [NSNumber numberWithLongLong:sentBytes],
			@"received_bytes" : [NSNumber numberWithLongLong:receivedBytes],
			@"duration" : [NSNumber numberWithDouble:seconds],
		},
	}];
}

#pragma mark - auto-download

- (void)tgNetworkAutoDownloadPresetsWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getAutoDownloadSettingsPresets"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSDictionary *low = TGNetSettingsDict(TGNetDict(result[@"low"]));
			NSDictionary *medium = TGNetSettingsDict(TGNetDict(result[@"medium"]));
			NSDictionary *high = TGNetSettingsDict(TGNetDict(result[@"high"]));
			if (TGResultIsError(result) || !low || !medium || !high) {
				completion(nil);
				return;
			}
			completion(@{@"low" : low, @"medium" : medium, @"high" : high});
		}];
}

- (void)autoDownloadPresetsWithCompletion:(void (^)(NSDictionary *))completion {
	[self tgNetworkAutoDownloadPresetsWithCompletion:completion];
}

- (void)setAutoDownloadSettings:(NSDictionary *)settings
					networkKind:(NSString *)kind
					 completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"setAutoDownloadSettings",
		@"settings" : TGNetSettingsObject(settings),
		@"type" : @{@"@type" : TGNetNetworkTypeName(kind)}}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)tgNetworkApplyAutoDownloadSettings:(NSDictionary *)settings
						toEveryNetworkKind:(void (^)(BOOL ok))completion {
	NSArray *kinds = [NSArray arrayWithObjects:@"mobile", @"mobileRoaming", @"wifi", @"other", nil];
	__block NSUInteger remaining = kinds.count;
	__block BOOL allOk = YES;
	for (NSString *kind in kinds) {
		[self setAutoDownloadSettings:settings networkKind:kind completion:^(BOOL ok) {
			if (!ok)
				allOk = NO;
			remaining--;
			if (remaining == 0 && completion)
				completion(allOk);
		}];
	}
}

- (void)setDataSaverEnabled:(BOOL)enabled completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self tgNetworkAutoDownloadPresetsWithCompletion:^(NSDictionary *presets) {
		NSDictionary *preset = TGNetDict(presets[enabled ? @"low" : @"high"]);
		if (!preset) {
			if (completion)
				completion(NO);
			return;
		}
		[weakSelf tgNetworkApplyAutoDownloadSettings:preset toEveryNetworkKind:completion];
	}];
}

- (void)setUseLessDataForCalls:(BOOL)useLess completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self tgNetworkAutoDownloadPresetsWithCompletion:^(NSDictionary *presets) {
		NSDictionary *medium = TGNetDict(presets[@"medium"]);
		if (!medium) {
			if (completion)
				completion(NO);
			return;
		}
		NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:medium];
		[settings setObject:useLess ? @YES : @NO forKey:@"useLessDataForCalls"];
		[weakSelf tgNetworkApplyAutoDownloadSettings:settings toEveryNetworkKind:completion];
	}];
}

#pragma mark - diagnostics

- (void)optionNamed:(NSString *)name completion:(void (^)(id))completion {
	[self request:@{@"@type" : @"getOption", @"name" : TGNetString(name)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSString *type = TGNetString(result[@"@type"]);
			if ([type isEqualToString:@"optionValueEmpty"]) {
				completion(nil);
				return;
			}
			id value = result[@"value"];
			if ([type isEqualToString:@"optionValueBoolean"]) {
				completion(TGNetBool(value));
				return;
			}
			if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
				completion(value);
				return;
			}
			completion(nil);
		}];
}

- (void)setOptionNamed:(NSString *)name
				 value:(id)value
			 isBoolean:(BOOL)isBoolean {
	if (!name.length)
		return;
	NSDictionary *object = nil;
	if (isBoolean) {
		object = @{@"@type" : @"optionValueBoolean", @"value" : TGNetBool(value)};
	} else if ([value isKindOfClass:[NSString class]]) {
		object = @{@"@type" : @"optionValueString", @"value" : value};
	} else if ([value isKindOfClass:[NSNumber class]]) {
		object = @{@"@type" : @"optionValueInteger", @"value" : value};
	} else {
		object = @{@"@type" : @"optionValueEmpty"};
	}
	[self send:@{@"@type" : @"setOption", @"name" : name, @"value" : object}];
}

- (NSString *)connectionStateTitle {
	switch (self.connectionState) {
		case TGConnectionStateWaitingForNetwork:
			return TGL(@"State.WaitingForNetwork", @"Waiting for network");
		case TGConnectionStateConnecting:
			return TGL(@"State.Connecting", @"Connecting...");
		case TGConnectionStateConnectingToProxy:
			return TGL(@"State.ConnectingToProxy", @"Connecting via proxy...");
		case TGConnectionStateUpdating:
			return TGL(@"State.Updating", @"Updating...");
		default:
			return nil;
	}
}

- (NSString *)connectionStateTitleForState:(TGConnectionState)state {
	switch (state) {
		case TGConnectionStateWaitingForNetwork:
			return TGL(@"State.WaitingForNetwork", @"Waiting for network");
		case TGConnectionStateConnecting:
			return TGL(@"State.Connecting", @"Connecting...");
		case TGConnectionStateConnectingToProxy:
			return TGL(@"State.ConnectingToProxy", @"Connecting via proxy...");
		case TGConnectionStateUpdating:
			return TGL(@"State.Updating", @"Updating...");
		default:
			return nil;
	}
}

- (void)tgNetworkConnectionStateTick:(NSTimer *)timer {
	TGConnectionState state = self.connectionState;
	if (TGNetHasLastState && state == TGNetLastState)
		return;
	TGNetHasLastState = YES;
	TGNetLastState = state;
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSNumber numberWithInteger:(NSInteger)state] forKey:TGConnectionStateKey];
	NSString *title = [self connectionStateTitleForState:state];
	if (title)
		[info setObject:title forKey:TGConnectionStateTitleKey];
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	[centre postNotificationName:TGConnectionStateDidChangeNotification
						  object:self
						userInfo:info];
}

- (void)beginBroadcastingConnectionState {
	TGNetStateObservers++;
	if (TGNetStateTimer)
		return;
	TGNetHasLastState = NO;
	TGNetStateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
													   target:self
													 selector:@selector(tgNetworkConnectionStateTick:)
													 userInfo:nil
													  repeats:YES];
	[self tgNetworkConnectionStateTick:nil];
}

- (void)endBroadcastingConnectionState {
	if (TGNetStateObservers > 0)
		TGNetStateObservers--;
	if (TGNetStateObservers > 0)
		return;
	[TGNetStateTimer invalidate];
	TGNetStateTimer = nil;
	TGNetHasLastState = NO;
}

@end
