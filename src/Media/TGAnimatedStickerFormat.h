#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGAnimatedStickerFormat) {
	TGAnimatedStickerFormatUnknown = 0,
	TGAnimatedStickerFormatTGS,
	TGAnimatedStickerFormatWebM
};

TGAnimatedStickerFormat TGAnimatedStickerFormatOfBytes(NSData *bytes);
TGAnimatedStickerFormat TGAnimatedStickerFormatOfFile(NSString *path);
BOOL TGIsAnimatedStickerDocName(id docName);
