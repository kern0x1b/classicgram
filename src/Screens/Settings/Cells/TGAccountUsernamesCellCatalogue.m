#import "TGAccountUsernamesCellCatalogue.h"
#import "TGAccountUsernameRowCell.h"

@implementation TGAccountUsernamesCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGAccountUsernamesRowKind)kind {
	switch (kind) {
		case TGAccountUsernamesRowKindUsername:
			return @"TGAccountUsernamesRow.Username";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGAccountUsernamesRowKind)kind {
	switch (kind) {
		case TGAccountUsernamesRowKindUsername:
			return [TGAccountUsernameRowCell class];
	}
	return nil;
}

@end
