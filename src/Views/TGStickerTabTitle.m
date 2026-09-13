#import "TGStickerTabTitle.h"

#import "TGStringTruncation.h"

NSString *TGStickerTabTitle(NSString *title) {
	if (![title isKindOfClass:[NSString class]])
		return @"";
	if (title.length <= 3)
		return title;
	return [TGSafeSubstringToIndex(title, 3) uppercaseString];
}
