#import "TGCallIce.h"
#import "TGCallStun.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

@interface TGCallIce ()
@property (nonatomic, strong) NSMutableArray *targets;
@property (nonatomic, strong) NSData *chosen;
@property (nonatomic, assign) int socketHandle;
@property (nonatomic, strong) NSTimer *checker;
@property (nonatomic, assign) uint64_t tieBreaker;
@property (nonatomic, assign) BOOL connectedOverRelay;
@end

@implementation TGCallIce

- (instancetype)init {
	if ((self = [super init])) {
		_targets = [NSMutableArray array];
		_socketHandle = -1;
		arc4random_buf(&_tieBreaker, sizeof(_tieBreaker));
	}
	return self;
}

- (BOOL)start {
	if (self.transport) {
		self.checker = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(sendChecks) userInfo:nil repeats:YES];
		return YES;
	}

	self.socketHandle = socket(AF_INET, SOCK_DGRAM, 0);
	if (self.socketHandle < 0)
		return NO;

	struct sockaddr_in local;
	memset(&local, 0, sizeof(local));
	local.sin_family = AF_INET;
	local.sin_addr.s_addr = htonl(INADDR_ANY);
	local.sin_port = 0;
	bind(self.socketHandle, (struct sockaddr *)&local, sizeof(local));

	[NSThread detachNewThreadSelector:@selector(readLoop) toTarget:self withObject:nil];
	self.checker = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(sendChecks) userInfo:nil repeats:YES];
	return YES;
}

- (void)addPeerCandidate:(NSString *)candidate {
	NSArray *parts = [candidate componentsSeparatedByString:@" "];
	if (parts.count < 6)
		return;

	NSString *ip = parts[4];
	int port = [parts[5] intValue];

	struct sockaddr_in target;
	memset(&target, 0, sizeof(target));
	target.sin_family = AF_INET;
	target.sin_port = htons((uint16_t)port);

	if (inet_pton(AF_INET, ip.UTF8String, &target.sin_addr) != 1)
		return;

	NSData *address = [NSData dataWithBytes:&target length:sizeof(target)];

	if (!self.peerAddress && [candidate rangeOfString:@"typ srflx"].location != NSNotFound)
		self.peerAddress = address;

	for (NSData *existing in self.targets)
		if ([existing isEqualToData:address])
			return;
	[self.targets addObject:address];
	NSLog(@"TGCallIce: will check %@:%d", ip, port);
}

- (void)sendChecks {
	if (!self.peerPwd.length)
		return;
	if (!self.transport && self.socketHandle < 0)
		return;

	NSString *username = [NSString stringWithFormat:@"%@:%@",
		self.peerUfrag ?: @"", self.localUfrag ?: @""];
	NSData *request = [TGCallStun bindingRequestWithUsername:username password:self.peerPwd tieBreaker:self.tieBreaker useCandidate:YES];

	if (self.transport) {
		self.transport(request);
		return;
	}

	NSArray *targets = self.chosen ? @[ self.chosen ] : self.targets;
	for (NSData *address in targets)
		sendto(self.socketHandle, request.bytes, request.length, 0,
			(const struct sockaddr *)address.bytes, (socklen_t)address.length);
}

- (void)readLoop {
	uint8_t buffer[2048];
	while (self.socketHandle >= 0) {
		struct sockaddr_in from;
		socklen_t fromLength = sizeof(from);
		ssize_t got = recvfrom(self.socketHandle, buffer, sizeof(buffer), 0,
			(struct sockaddr *)&from, &fromLength);
		if (got <= 0)
			break;

		NSData *packet = [NSData dataWithBytes:buffer length:got];
		NSData *address = [NSData dataWithBytes:&from length:sizeof(from)];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self handlePacket:packet from:address];
		});
	}
}

- (void)handleRelayedPacket:(NSData *)packet {
	int type = [TGCallStun messageTypeOf:packet];

	if (type == 0x0001) {
		NSData *response = [TGCallStun bindingResponseTo:packet
												password:self.localPwd
											 fromAddress:self.peerAddress];
		NSLog(@"TGCallIce: their check, our pwd %@, response %lu bytes, transport %@",
			self.localPwd.length ? @"set" : @"MISSING",
			(unsigned long)response.length, self.transport ? @"set" : @"MISSING");
		if (response && self.transport)
			self.transport(response);
		[self markConnected:nil];
		return;
	}
	if (type == 0x0101) {
		[self markConnected:nil];
		return;
	}
	if (type < 0 && self.onMedia)
		self.onMedia(packet);
}

- (void)handlePacket:(NSData *)packet from:(NSData *)address {
	int type = [TGCallStun messageTypeOf:packet];

	if (type == 0x0001) {
		NSData *response = [TGCallStun bindingResponseTo:packet
												password:self.localPwd
											 fromAddress:address];
		if (response)
			sendto(self.socketHandle, response.bytes, response.length, 0,
				(const struct sockaddr *)address.bytes, (socklen_t)address.length);
		[self markConnected:address];
		return;
	}

	if (type == 0x0101) {
		[self markConnected:address];
		return;
	}

	if (type < 0 && self.onMedia)
		self.onMedia(packet);
}

- (void)markConnected:(NSData *)address {
	NSLog(@"TGCallIce: markConnected, chosen %@, relay %d",
		self.chosen ? @"set" : @"nil", (int)self.connectedOverRelay);
	if (self.chosen || (!address && self.connectedOverRelay))
		return;

	if (!address) {
		self.connectedOverRelay = YES;
		NSLog(@"TGCallIce: connected over the reflector");
		if (self.onConnected)
			self.onConnected(@"reflector", 0);
		return;
	}
	self.chosen = address;

	const struct sockaddr_in *from = (const struct sockaddr_in *)address.bytes;
	char text[INET_ADDRSTRLEN] = {0};
	inet_ntop(AF_INET, &from->sin_addr, text, sizeof(text));
	NSLog(@"TGCallIce: connected to %s:%u", text, ntohs(from->sin_port));
	if (self.onConnected)
		self.onConnected([NSString stringWithUTF8String:text], ntohs(from->sin_port));
}

- (void)stop {
	[self.checker invalidate];
	self.checker = nil;
	int handle = self.socketHandle;
	self.socketHandle = -1;
	if (handle >= 0)
		close(handle);
}

@end
