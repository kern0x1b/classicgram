#import "TGNewGroupMembersItemBuilder.h"
#import "TGNewGroupMembersCellCatalogue.h"

@implementation TGNewGroupMembersItemBuilder

+ (TGNewGroupMembersItem *)itemFromUser:(NSDictionary *)user
							  titleText:(NSString *)titleText
							   selected:(NSArray *)selected {
	NSNumber *userId = [user[@"id"] isKindOfClass:[NSNumber class]] ? user[@"id"] : nil;
	BOOL isSelected = userId && [selected containsObject:userId];

	return [[TGNewGroupMembersItem alloc] initWithKind:TGNewGroupMembersRowKindContact
									   reuseIdentifier:[TGNewGroupMembersCellCatalogue reuseIdentifierForKind:TGNewGroupMembersRowKindContact]
											 cellClass:[TGNewGroupMembersCellCatalogue cellClassForKind:TGNewGroupMembersRowKindContact]
												userId:userId.longLongValue
											 titleText:titleText
											isSelected:isSelected];
}

@end
