#import "tg_sticker_favourite_action_tests.h"

#import "../../src/Screens/Stickers/TGStickerFavouriteAction.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGStickerFavouriteActionTestAFailedReadOffersNeither(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGStickerFavouriteActionFor(NO, YES) == TGStickerFavouriteActionUnknown,
			"when the favourites could not be read the menu offers neither: it used to offer "
			"Add to Favourites for a sticker already in them, and the tap acted on the account");
	TGTestExpectTrue(&outcome,
			TGStickerFavouriteActionFor(YES, YES) == TGStickerFavouriteActionUnknown,
			"a failure wins over whatever the flag happened to be");
	TGTestExpectTrue(&outcome,
			TGStickerFavouriteActionFor(YES, NO) == TGStickerFavouriteActionRemove,
			"a sticker known to be a favourite offers Remove");
	TGTestExpectTrue(&outcome,
			TGStickerFavouriteActionFor(NO, NO) == TGStickerFavouriteActionAdd,
			"and one known not to be offers Add");

	return outcome;
}
