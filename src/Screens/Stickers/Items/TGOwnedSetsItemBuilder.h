#import <Foundation/Foundation.h>
#import "TGOwnedSetsItem.h"

@interface TGOwnedSetsItemBuilder : NSObject

+ (TGOwnedSetsItem *)itemForCreateRow;
+ (TGOwnedSetsItem *)itemFromSet:(NSDictionary *)set;

@end
