#import "TGSupergroupUsernamesCellCatalogue.h"
#import "TGSupergroupUsernameRowCell.h"

@implementation TGSupergroupUsernamesCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGSupergroupUsernamesRowKind)kind {
	switch (kind) {
		case TGSupergroupUsernamesRowKindUsername:
			return @"TGSupergroupUsernamesRow.Username";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGSupergroupUsernamesRowKind)kind {
	switch (kind) {
		case TGSupergroupUsernamesRowKindUsername:
			return [TGSupergroupUsernameRowCell class];
	}
	return nil;
}

@end
