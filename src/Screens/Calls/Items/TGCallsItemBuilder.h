#import <Foundation/Foundation.h>
#import "TGCallsItem.h"

@interface TGCallsItemBuilder : NSObject

+ (TGCallsItem *)itemFromGroup:(NSDictionary *)group;

@end
