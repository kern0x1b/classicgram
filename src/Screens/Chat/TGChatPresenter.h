#import <Foundation/Foundation.h>

@interface TGChatPresenter : NSObject

- (uint32_t)sideRevisionForMessageId:(int64_t)messageId;

@end
