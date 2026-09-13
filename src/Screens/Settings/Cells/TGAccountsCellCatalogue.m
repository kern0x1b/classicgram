#import "TGAccountsCellCatalogue.h"
#import "TGAccountRowCell.h"

@implementation TGAccountsCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGAccountsRowKind)kind {
	switch (kind) {
		case TGAccountsRowKindAccount:
			return @"TGAccountsRow.Account";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGAccountsRowKind)kind {
	switch (kind) {
		case TGAccountsRowKindAccount:
			return [TGAccountRowCell class];
	}
	return nil;
}

@end
