#import <Foundation/Foundation.h>
#import "TGConnectedWebsitesItem.h"

@interface TGConnectedWebsitesItemBuilder : NSObject

+ (TGConnectedWebsitesItem *)itemFromSite:(NSDictionary *)site;

@end
