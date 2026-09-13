#import <Foundation/Foundation.h>

typedef enum {
	TGStickerFavouriteActionAdd = 0,
	TGStickerFavouriteActionRemove,
	TGStickerFavouriteActionUnknown
} TGStickerFavouriteAction;

TGStickerFavouriteAction TGStickerFavouriteActionFor(BOOL favourite, BOOL failed);
