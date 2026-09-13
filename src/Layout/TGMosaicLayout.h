#import <UIKit/UIKit.h>

#define kMosaicMaxItems 10

enum {
	TGMosaicPositionNone = 0,
	TGMosaicPositionTop = 1,
	TGMosaicPositionBottom = 2,
	TGMosaicPositionLeft = 4,
	TGMosaicPositionRight = 8,
	TGMosaicPositionInside = 16
};

typedef struct {
	CGRect frame;
	NSUInteger position;
} TGMosaicTile;

#ifdef __cplusplus
extern "C" {
#endif

NSUInteger TGMosaicLayoutTiles(const CGSize *sizes,
	NSUInteger count,
	CGSize maxSize,
	CGFloat spacing,
	BOOL fillWidth,
	TGMosaicTile *outTiles,
	NSUInteger capacity,
	CGSize *outTotal);

#ifdef __cplusplus
}
#endif
