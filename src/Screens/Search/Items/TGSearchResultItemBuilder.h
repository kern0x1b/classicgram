#import <Foundation/Foundation.h>
#import "TGSearchResultItem.h"

@interface TGSearchResultItemBuilder : NSObject

+ (TGSearchResultItem *)itemFromRow:(NSDictionary *)row isMessage:(BOOL)isMessage;

@end
