#import "TGChatPresenter.h"

@implementation TGChatPresenter {
	NSMutableDictionary<NSNumber *, NSNumber *> *_sideRevisionByMessageId;
	uint32_t _globalTick;
	uint32_t _globalEpoch;
}

- (instancetype)init {
	self = [super init];
	if (!self)
		return nil;

	_sideRevisionByMessageId = [NSMutableDictionary dictionary];
	_globalTick = 1;
	_globalEpoch = 0;
	return self;
}

- (uint32_t)sideRevisionForMessageId:(int64_t)messageId {
	uint32_t own = [_sideRevisionByMessageId[@(messageId)] unsignedIntValue];
	return MAX(own, _globalEpoch);
}

@end
