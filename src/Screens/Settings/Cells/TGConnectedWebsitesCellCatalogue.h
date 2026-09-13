#import <UIKit/UIKit.h>
#import "TGConnectedWebsitesItem.h"

@interface TGConnectedWebsitesCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGConnectedWebsitesRowKind)kind;
+ (Class)cellClassForKind:(TGConnectedWebsitesRowKind)kind;

@end
