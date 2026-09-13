#import <Foundation/Foundation.h>
#import "TGInstantViewItem.h"

@interface TGInstantViewItemBuilder : NSObject

+ (TGInstantViewRowKind)rowKindForBlock:(NSDictionary *)block;
+ (TGInstantViewItem *)itemFromBlock:(NSDictionary *)block height:(CGFloat)height width:(CGFloat)width;

@end
