#import "TGMessageContent.h"

typedef NS_ENUM(NSInteger, TGCallContentState) {
	TGCallContentStateAnswered = 0,
	TGCallContentStateMissed,
	TGCallContentStateDeclined
};

@interface TGCallContent : TGMessageContent

@property (nonatomic, readonly) TGCallContentState state;
@property (nonatomic, readonly) BOOL groupCall;

- (instancetype)initWithState:(TGCallContentState)state
				  isGroupCall:(BOOL)isGroupCall NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
