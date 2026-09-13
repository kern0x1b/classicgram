#import "TGStickerSearchFooter.h"

#import "TGLocalization.h"

NSString *TGStickerSearchFooterText(BOOL failed, NSUInteger setCount) {
	if (setCount)
		return nil;
	if (failed)
		return TGL(@"Stickers.SearchFailed",
			@"Sticker sets could not be searched. Check the connection and try again.");
	return TGL(@"Stickers.NoStickersFound", @"No sticker sets found.");
}
