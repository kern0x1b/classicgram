#import <Foundation/Foundation.h>
#import "TGSearchResultItem.h"

@interface TGSearchResultCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGSearchRowKind)kind;
+ (Class)cellClassForKind:(TGSearchRowKind)kind;

@end
