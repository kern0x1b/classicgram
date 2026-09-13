#import <UIKit/UIKit.h>
#import "TGNewGroupMembersItem.h"

@interface TGNewGroupMembersCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGNewGroupMembersRowKind)kind;
+ (Class)cellClassForKind:(TGNewGroupMembersRowKind)kind;

@end
