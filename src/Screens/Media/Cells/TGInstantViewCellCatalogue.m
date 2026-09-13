#import "TGInstantViewCellCatalogue.h"
#import "TGInstantViewBlockCell.h"

@implementation TGInstantViewCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGInstantViewRowKind)kind {
	switch (kind) {
		case TGInstantViewRowKindDivider:
			return @"TGInstantViewRow.Divider";
		case TGInstantViewRowKindMedia:
			return @"TGInstantViewRow.Media";
		case TGInstantViewRowKindUnsupported:
			return @"TGInstantViewRow.Unsupported";
		case TGInstantViewRowKindText:
			return @"TGInstantViewRow.Text";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGInstantViewRowKind)kind {
	switch (kind) {
		case TGInstantViewRowKindDivider:
		case TGInstantViewRowKindMedia:
		case TGInstantViewRowKindUnsupported:
		case TGInstantViewRowKindText:
			return [TGInstantViewBlockCell class];
	}
	return nil;
}

@end
