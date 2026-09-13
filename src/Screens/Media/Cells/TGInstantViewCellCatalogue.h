#import <Foundation/Foundation.h>
#import "TGInstantViewItem.h"

@interface TGInstantViewCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGInstantViewRowKind)kind;
+ (Class)cellClassForKind:(TGInstantViewRowKind)kind;

@end
