#import "tg_call_rtc_servers_tests.h"
#import "../../src/Wire/Flatten/TGCallRtcServers.h"

static NSDictionary *TGTestReflector(id identifier, NSString *ip, NSString *ipv6, BOOL tcp) {
	return @{
		@"@type" : @"callServer",
		@"id" : identifier,
		@"ip_address" : ip,
		@"ipv6_address" : ipv6,
		@"port" : @(1400),
		@"type" : @{@"@type" : @"callServerTypeTelegramReflector", @"peer_tag" : @"AAECAwQFBgcICQoLDA0ODw==", @"is_tcp" : @(tcp)},
	};
}

TGTestOutcome TGCallRtcServersTestReflectorBecomesTurnWithHexPeerTag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *result = TGCallRtcServers(@[ TGTestReflector(@"7", @"91.108.9.1", @"", NO) ], @"9.0.0");
	NSDictionary *server = result.firstObject;

	TGTestExpectTrue(&outcome, result.count == 1, "one reflector with one address must give exactly one server");
	TGTestExpectTrue(&outcome, [server[@"turn"] boolValue] && ![server[@"tcp"] boolValue],
			"a UDP reflector is offered to tgcalls as a UDP TURN server");
	TGTestExpectTrue(&outcome, [server[@"login"] isEqualToString:@"reflector"],
			"tgcalls recognises a Telegram reflector by the login \"reflector\"");
	TGTestExpectTrue(&outcome, [server[@"password"] isEqualToString:@"000102030405060708090a0b0c0d0e0f"],
			"the reflector's peer tag travels as its lowercase hex in the TURN password");
	TGTestExpectTrue(&outcome, [server[@"host"] isEqualToString:@"91.108.9.1"] && [server[@"port"] intValue] == 1400,
			"host and port must be copied from the call server");
	TGTestExpectTrue(&outcome, [server[@"id"] intValue] == 1, "the only reflector ranks first");

	return outcome;
}

TGTestOutcome TGCallRtcServersTestReflectorIdsAreRankedByServerId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *result = TGCallRtcServers(@[ TGTestReflector(@"900", @"10.0.0.2", @"", NO), TGTestReflector(@"15", @"10.0.0.1", @"", NO) ], @"9.0.0");

	TGTestExpectTrue(&outcome, result.count == 2, "both reflectors must be kept");
	TGTestExpectTrue(&outcome, [result[0][@"id"] intValue] == 2 && [result[1][@"id"] intValue] == 1,
			"reflector ids are the one-based rank of the server id, compared numerically, as Telegram-iOS numbers them");

	return outcome;
}

TGTestOutcome TGCallRtcServersTestReflectorWithBothAddressesYieldsTwoEntries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *result = TGCallRtcServers(@[ TGTestReflector(@"3", @"91.108.9.1", @"2001:b28:f23d::1", NO) ], @"9.0.0");

	TGTestExpectTrue(&outcome, result.count == 2, "an IPv4 and an IPv6 address give one server each");
	TGTestExpectTrue(&outcome, [result[1][@"host"] isEqualToString:@"2001:b28:f23d::1"] && [result[1][@"id"] intValue] == 1,
			"the IPv6 entry keeps the same reflector id");

	return outcome;
}

TGTestOutcome TGCallRtcServersTestTcpReflectorIsSkippedOutsideVersionTwelve(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *result = TGCallRtcServers(@[ TGTestReflector(@"3", @"91.108.9.1", @"", YES), TGTestReflector(@"4", @"91.108.9.2", @"", NO) ], @"9.0.0");

	TGTestExpectTrue(&outcome, result.count == 1 && [result[0][@"host"] isEqualToString:@"91.108.9.2"],
			"a TCP reflector only carries media for protocol 12.0.0");
	TGTestExpectTrue(&outcome, [result[0][@"id"] intValue] == 2, "the skipped TCP reflector still takes its rank");

	return outcome;
}

TGTestOutcome TGCallRtcServersTestTcpReflectorIsKeptForVersionTwelve(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *result = TGCallRtcServers(@[ TGTestReflector(@"3", @"91.108.9.1", @"", YES) ], @"12.0.0");

	TGTestExpectTrue(&outcome, result.count == 1 && [result[0][@"tcp"] boolValue] && [result[0][@"turn"] boolValue],
			"protocol 12.0.0 reaches a TCP reflector as a TCP TURN server");

	return outcome;
}

TGTestOutcome TGCallRtcServersTestWebrtcServerSplitsIntoStunAndTurn(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *webrtc = @{
		@"@type" : @"callServer",
		@"id" : @"11",
		@"ip_address" : @"149.154.1.1",
		@"ipv6_address" : @"",
		@"port" : @(3478),
		@"type" : @{@"@type" : @"callServerTypeWebrtc", @"username" : @"user", @"password" : @"secret", @"supports_turn" : @YES, @"supports_stun" : @YES},
	};
	NSArray *result = TGCallRtcServers(@[ webrtc ], @"9.0.0");

	TGTestExpectTrue(&outcome, result.count == 2, "a server that does both STUN and TURN is offered as both");
	TGTestExpectTrue(&outcome, ![result[0][@"turn"] boolValue] && [result[0][@"login"] length] == 0 && [result[0][@"id"] intValue] == 0,
			"the STUN entry carries no credentials and no reflector id");
	TGTestExpectTrue(&outcome, [result[1][@"turn"] boolValue] && [result[1][@"login"] isEqualToString:@"user"] && [result[1][@"password"] isEqualToString:@"secret"],
			"the TURN entry carries the server's own credentials");

	return outcome;
}

TGTestOutcome TGCallRtcServersTestDuplicateServersAppearOnce(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *reflector = TGTestReflector(@"3", @"91.108.9.1", @"", NO);
	NSArray *result = TGCallRtcServers(@[ reflector, [reflector copy] ], @"9.0.0");

	TGTestExpectTrue(&outcome, result.count == 1, "the same call server listed twice is offered once");

	return outcome;
}

TGTestOutcome TGCallRtcServersTestMalformedInputYieldsNoServers(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCallRtcServers((id)[NSNull null], @"9.0.0").count == 0, "a non-array server list yields nothing");
	TGTestExpectTrue(&outcome, TGCallRtcServers(@[ @"junk", @{@"type" : @"x"} ], @"9.0.0").count == 0,
			"entries that are not call servers are ignored rather than crashing");

	return outcome;
}
