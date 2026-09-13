#import <Foundation/Foundation.h>
#import "TGGroupMembersItem.h"

@interface TGGroupMembersItemBuilder : NSObject

+ (TGGroupMembersItem *)itemFromMember:(NSDictionary *)member;

@end
