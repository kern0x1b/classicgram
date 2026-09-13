#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSDictionary *_Nullable TGFlattenSticker(id _Nullable object);
NSArray *TGFlattenStickers(id _Nullable list);
BOOL TGIsFlattenableSticker(id _Nullable object);
NSArray *TGFlattenStickerRange(id _Nullable list, NSUInteger location, NSUInteger length);
NSUInteger TGCountFlattenableStickers(id _Nullable list);
NSDictionary *_Nullable TGFlattenStickerSet(id _Nullable object);

NS_ASSUME_NONNULL_END
