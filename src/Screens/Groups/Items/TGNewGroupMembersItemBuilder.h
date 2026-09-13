#import <Foundation/Foundation.h>
#import "TGNewGroupMembersItem.h"

@interface TGNewGroupMembersItemBuilder : NSObject

+ (TGNewGroupMembersItem *)itemFromUser:(NSDictionary *)user
							  titleText:(NSString *)titleText
							   selected:(NSArray *)selected;

@end
