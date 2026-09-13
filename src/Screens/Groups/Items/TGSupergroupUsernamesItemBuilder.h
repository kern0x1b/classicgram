#import <Foundation/Foundation.h>
#import "TGSupergroupUsernamesItem.h"

@interface TGSupergroupUsernamesItemBuilder : NSObject

+ (TGSupergroupUsernamesItem *)itemFromUsername:(NSString *)username badgeText:(NSString *)badgeText;

@end
