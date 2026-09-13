#import <Foundation/Foundation.h>
#import "TGStarsListItem.h"

@interface TGStarsListItemBuilder : NSObject

+ (TGStarsListItem *)itemFromRow:(NSDictionary *)row;
+ (TGStarsListItem *)itemForStatusLoading:(BOOL)loading isMoreRow:(BOOL)isMoreRow emptyText:(NSString *)emptyText;

@end
