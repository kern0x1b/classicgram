#import "TGCallRtcServers.h"
#import "TGBase64.h"

static NSString *const TGCallReflectorType = @"callServerTypeTelegramReflector";
static NSString *const TGCallWebrtcType = @"callServerTypeWebrtc";
static NSString *const TGCallVersionWithTcpReflectors = @"12.0.0";

static NSString *TGCallServerType(NSDictionary *server) {
	NSDictionary *type = [server[@"type"] isKindOfClass:NSDictionary.class] ? server[@"type"] : nil;
	NSString *name = type[@"@type"];
	return [name isKindOfClass:NSString.class] ? name : nil;
}

static NSString *TGCallServerString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSString *TGCallHexString(NSData *data) {
	NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
	const uint8_t *bytes = (const uint8_t *)data.bytes;
	for (NSUInteger index = 0; index < data.length; index++)
		[hex appendFormat:@"%02x", bytes[index]];
	return hex;
}

static NSArray *TGCallServerHosts(NSDictionary *server) {
	NSMutableArray *hosts = [NSMutableArray array];
	for (NSString *key in @[ @"ip_address", @"ipv6_address" ]) {
		NSString *host = TGCallServerString(server[key]);
		if (host.length)
			[hosts addObject:host];
	}
	return hosts;
}

static NSDictionary *TGCallRtcServer(NSUInteger identifier, NSString *host, id port, NSString *login, NSString *password, BOOL turn, BOOL tcp) {
	return @{
		@"id" : @(identifier),
		@"host" : host,
		@"port" : @([port intValue]),
		@"login" : login,
		@"password" : password,
		@"turn" : @(turn),
		@"tcp" : @(tcp),
	};
}

NSArray *TGCallRtcServers(NSArray *servers, NSString *version) {
	if (![servers isKindOfClass:NSArray.class])
		return @[];

	NSMutableArray *reflectorIds = [NSMutableArray array];
	for (NSDictionary *server in servers) {
		if (![server isKindOfClass:NSDictionary.class] || ![TGCallServerType(server) isEqualToString:TGCallReflectorType])
			continue;
		[reflectorIds addObject:@([server[@"id"] longLongValue])];
	}
	[reflectorIds sortUsingSelector:@selector(compare:)];

	NSMutableArray *result = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for (NSDictionary *server in servers) {
		if (![server isKindOfClass:NSDictionary.class] || [seen containsObject:server])
			continue;
		[seen addObject:server];
		NSDictionary *type = server[@"type"];
		NSString *kind = TGCallServerType(server);

		if ([kind isEqualToString:TGCallReflectorType]) {
			BOOL tcp = [type[@"is_tcp"] boolValue];
			if (tcp && ![version isEqualToString:TGCallVersionWithTcpReflectors])
				continue;
			NSUInteger identifier = [reflectorIds indexOfObject:@([server[@"id"] longLongValue])] + 1;
			NSString *peerTag = TGCallHexString(TGBase64Decode(type[@"peer_tag"]) ?: [NSData data]);
			for (NSString *host in TGCallServerHosts(server))
				[result addObject:TGCallRtcServer(identifier, host, server[@"port"], @"reflector", peerTag, YES, tcp)];
		} else if ([kind isEqualToString:TGCallWebrtcType]) {
			for (NSString *host in TGCallServerHosts(server)) {
				if ([type[@"supports_stun"] boolValue])
					[result addObject:TGCallRtcServer(0, host, server[@"port"], @"", @"", NO, NO)];
				if ([type[@"supports_turn"] boolValue])
					[result addObject:TGCallRtcServer(0, host, server[@"port"], TGCallServerString(type[@"username"]), TGCallServerString(type[@"password"]), YES, NO)];
			}
		}
	}
	return result;
}
