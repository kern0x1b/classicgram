#import "TGGroupedCaption.h"

CGFloat TGGroupedFooterHeight(NSString *caption, CGFloat measured) {
	if (!caption.length)
		return 1;
	return measured > 0 ? measured : 1;
}

CGFloat TGActionRowHeight(void) {
	return 45.0f;
}

CGRect TGActionRowButtonFrame(CGFloat rowWidth) {
	CGFloat width = MAX(0.0f, rowWidth - 18.0f);
	return CGRectMake(9.0f, 0.0f, width, TGActionRowHeight());
}

UIFont *TGGroupedRowTitleFont(void) {
	return [UIFont boldSystemFontOfSize:17];
}

UIFont *TGGroupedRowValueFont(void) {
	return [UIFont systemFontOfSize:16];
}
