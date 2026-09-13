#import "TGDemoTransport.h"

#import "TGDemoData.h"

static NSMutableArray<NSString *> *TGDemoQueue(void) {
	static NSMutableArray *queue = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ queue = [NSMutableArray array]; });
	return queue;
}

static NSLock *TGDemoQueueLock(void) {
	static NSLock *lock = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ lock = [[NSLock alloc] init]; });
	return lock;
}

static void TGDemoEnqueue(NSString *json) {
	if (!json.length)
		return;
	[TGDemoQueueLock() lock];
	[TGDemoQueue() addObject:json];
	[TGDemoQueueLock() unlock];
}

static NSString *TGDemoDequeue(void) {
	NSString *json = nil;
	[TGDemoQueueLock() lock];
	if (TGDemoQueue().count) {
		json = TGDemoQueue()[0];
		[TGDemoQueue() removeObjectAtIndex:0];
	}
	[TGDemoQueueLock() unlock];
	return json;
}

static NSString *TGDemoEncode(NSDictionary *object) {
	NSError *error = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
	if (!data)
		return nil;
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSDictionary *TGDemoDecode(NSString *json) {
	NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
	if (!data)
		return nil;
	id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
	return [object isKindOfClass:NSDictionary.class] ? object : nil;
}

static NSDictionary *TGDemoErrorForRequest(NSDictionary *request) {
	return @{@"@type" : @"error",
		@"code" : @(404),
		@"message" : [NSString stringWithFormat:@"Demo mode does not answer %@",
			request[@"@type"] ?: @"this request"]};
}

NSString *TGDemoTransportReplyForRequestJSON(NSString *requestJSON) {
	NSDictionary *request = TGDemoDecode(requestJSON);
	if (!request)
		return nil;
	id extra = request[@"@extra"];
	NSDictionary *response = TGDemoResponseForRequest(request);
	if (!response) {
		if (!extra)
			return nil;
		response = TGDemoErrorForRequest(request);
	}
	if (!extra)
		return nil;
	NSMutableDictionary *withExtra = [response mutableCopy];
	withExtra[@"@extra"] = extra;
	return TGDemoEncode(withExtra);
}

void *TGDemoTransportCreate(void) {
	static int token = 0;
	for (NSDictionary *update in TGDemoStartupUpdates())
		TGDemoEnqueue(TGDemoEncode(update));
	return &token;
}

void TGDemoTransportSend(void *client, const char *request) {
	(void)client;
	if (!request)
		return;
	@autoreleasepool {
		NSString *json = [NSString stringWithUTF8String:request];
		if (!json)
			return;
		NSDictionary *decoded = TGDemoDecode(json);
		NSDictionary *fileUpdate = TGDemoFileUpdateForRequest(decoded);
		if (fileUpdate)
			TGDemoEnqueue(TGDemoEncode(fileUpdate));
		NSString *reply = TGDemoTransportReplyForRequestJSON(json);
		if (reply)
			TGDemoEnqueue(reply);
	}
}

static const NSTimeInterval kDemoReceiveWait = 0.05;

const char *TGDemoTransportReceive(void *client, double timeout) {
	(void)client;
	(void)timeout;
	static NSData *held = nil;
	NSString *json = TGDemoDequeue();
	if (!json) {
		[NSThread sleepForTimeInterval:kDemoReceiveWait];
		json = TGDemoDequeue();
		if (!json)
			return NULL;
	}
	NSMutableData *buffer = [[json dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
	[buffer appendBytes:"\0" length:1];
	held = buffer;
	return (const char *)held.bytes;
}

void TGDemoTransportDestroy(void *client) {
	(void)client;
	[TGDemoQueueLock() lock];
	[TGDemoQueue() removeAllObjects];
	[TGDemoQueueLock() unlock];
}
