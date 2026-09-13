#import <UIKit/UIKit.h>
#import "TGAccountUsernamesItem.h"

@interface TGAccountUsernamesCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGAccountUsernamesRowKind)kind;
+ (Class)cellClassForKind:(TGAccountUsernamesRowKind)kind;

@end
