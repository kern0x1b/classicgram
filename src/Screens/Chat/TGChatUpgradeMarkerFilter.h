#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

BOOL TGMessageIsChatUpgradeMarker(NSDictionary *message);
NSArray *TGMessagesWithChatUpgradeMarkersRemoved(NSArray *messages);

NS_ASSUME_NONNULL_END
