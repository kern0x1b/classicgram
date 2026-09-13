#import "TGNewGroupMembersCellCatalogue.h"
#import "TGNewGroupMemberRowCell.h"

@implementation TGNewGroupMembersCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGNewGroupMembersRowKind)kind {
	switch (kind) {
		case TGNewGroupMembersRowKindContact:
			return @"TGNewGroupMembersRow.Contact";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGNewGroupMembersRowKind)kind {
	switch (kind) {
		case TGNewGroupMembersRowKindContact:
			return [TGNewGroupMemberRowCell class];
	}
	return nil;
}

@end
