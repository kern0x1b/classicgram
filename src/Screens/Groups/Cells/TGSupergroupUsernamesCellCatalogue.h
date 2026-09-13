#import <UIKit/UIKit.h>
#import "TGSupergroupUsernamesItem.h"

@interface TGSupergroupUsernamesCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGSupergroupUsernamesRowKind)kind;
+ (Class)cellClassForKind:(TGSupergroupUsernamesRowKind)kind;

@end
