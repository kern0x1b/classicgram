#import "TGCallContent.h"

@implementation TGCallContent

- (instancetype)initWithState:(TGCallContentState)state
				  isGroupCall:(BOOL)isGroupCall {
	self = [super init];
	if (self != nil) {
		_state = state;
		_groupCall = isGroupCall;
	}
	return self;
}

@end
