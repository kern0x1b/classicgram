#import "TGOwnedSetsCellCatalogue.h"
#import "TGOwnedSetsCreateCell.h"
#import "TGOwnedSetsSetCell.h"

@implementation TGOwnedSetsCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGOwnedSetsRowKind)kind {
	switch (kind) {
		case TGOwnedSetsRowKindCreate:
			return @"TGOwnedSetsRow.Create";
		case TGOwnedSetsRowKindSet:
			return @"TGOwnedSetsRow.Set";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGOwnedSetsRowKind)kind {
	switch (kind) {
		case TGOwnedSetsRowKindCreate:
			return [TGOwnedSetsCreateCell class];
		case TGOwnedSetsRowKindSet:
			return [TGOwnedSetsSetCell class];
	}
	return nil;
}

+ (UITableViewCellStyle)cellStyleForKind:(TGOwnedSetsRowKind)kind {
	switch (kind) {
		case TGOwnedSetsRowKindCreate:
			return UITableViewCellStyleDefault;
		case TGOwnedSetsRowKindSet:
			return UITableViewCellStyleSubtitle;
	}
	return UITableViewCellStyleDefault;
}

@end
