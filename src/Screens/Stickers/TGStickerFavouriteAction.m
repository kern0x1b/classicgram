#import "TGStickerFavouriteAction.h"

TGStickerFavouriteAction TGStickerFavouriteActionFor(BOOL favourite, BOOL failed) {
	if (failed)
		return TGStickerFavouriteActionUnknown;
	return favourite ? TGStickerFavouriteActionRemove : TGStickerFavouriteActionAdd;
}
