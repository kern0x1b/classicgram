#import "TGSearchResultCellCatalogue.h"
#import "TGSearchResultCell.h"
#import "TGSearchMessageCell.h"

@implementation TGSearchResultCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGSearchRowKind)kind {
	switch (kind) {
		case TGSearchRowKindGeneric:
			return @"TGSearchRow.Generic";
		case TGSearchRowKindMessage:
			return @"TGSearchRow.Message";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGSearchRowKind)kind {
	switch (kind) {
		case TGSearchRowKindGeneric:
			return [TGSearchResultCell class];
		case TGSearchRowKindMessage:
			return [TGSearchMessageCell class];
	}
	return nil;
}

@end
