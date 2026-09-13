#import "TGPrivacyContactPickerCellCatalogue.h"
#import "TGPrivacyContactPickerRowCell.h"

@implementation TGPrivacyContactPickerCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGPrivacyContactPickerRowKind)kind {
	switch (kind) {
		case TGPrivacyContactPickerRowKindContact:
			return @"TGPrivacyContactPickerRow.Contact";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGPrivacyContactPickerRowKind)kind {
	switch (kind) {
		case TGPrivacyContactPickerRowKindContact:
			return [TGPrivacyContactPickerRowCell class];
	}
	return nil;
}

@end
