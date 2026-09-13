#import "TGStarsListCellCatalogue.h"
#import "TGStarsListStatusCell.h"
#import "TGStarsListValueCell.h"
#import "TGStarsListSubtitleCell.h"

@implementation TGStarsListCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGStarsListRowKind)kind {
	switch (kind) {
		case TGStarsListRowKindStatus:
			return @"TGStarsListRow.Status";
		case TGStarsListRowKindValue:
			return @"TGStarsListRow.Value";
		case TGStarsListRowKindSubtitle:
			return @"TGStarsListRow.Subtitle";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGStarsListRowKind)kind {
	switch (kind) {
		case TGStarsListRowKindStatus:
			return [TGStarsListStatusCell class];
		case TGStarsListRowKindValue:
			return [TGStarsListValueCell class];
		case TGStarsListRowKindSubtitle:
			return [TGStarsListSubtitleCell class];
	}
	return nil;
}

+ (UITableViewCellStyle)cellStyleForKind:(TGStarsListRowKind)kind {
	switch (kind) {
		case TGStarsListRowKindStatus:
			return UITableViewCellStyleDefault;
		case TGStarsListRowKindValue:
			return UITableViewCellStyleValue1;
		case TGStarsListRowKindSubtitle:
			return UITableViewCellStyleSubtitle;
	}
	return UITableViewCellStyleDefault;
}

@end
