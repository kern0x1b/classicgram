#import "TGProfileDetailCellCatalogue.h"
#import "TGProfileDetailCell.h"

@implementation TGProfileDetailCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGProfileDetailRowKind)kind {
	switch (kind) {
		case TGProfileDetailRowKindPlain:
			return @"TGProfileDetailRow.Plain";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGProfileDetailRowKind)kind {
	switch (kind) {
		case TGProfileDetailRowKindPlain:
			return [TGProfileDetailCell class];
	}
	return nil;
}

@end
