#import <UIKit/UIKit.h>
#import "TGAccountsItem.h"

@interface TGAccountsCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGAccountsRowKind)kind;
+ (Class)cellClassForKind:(TGAccountsRowKind)kind;

@end
