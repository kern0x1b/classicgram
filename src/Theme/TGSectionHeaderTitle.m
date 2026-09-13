#import "TGSectionHeaderTitle.h"

NSString *TGSectionHeaderTitle(NSString *title, NSInteger rowCount) {
	if (rowCount <= 0)
		return nil;
	return [title isKindOfClass:[NSString class]] ? title : nil;
}
