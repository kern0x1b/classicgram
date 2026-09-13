#import "TGIcons.h"

@interface TGIcons (Internal)
+ (UIImage *)iconNamed:(NSString *)name draw:(void (^)(CGContextRef ctx, CGFloat s))draw;
@end

extern NSMutableDictionary *sCache;
extern NSCache *sAvatarCache;

UIImage *TGArtwork(NSString *name);
UIImage *TGArtworkTemplate(NSString *name);
UIImage *TGArtworkMasked(NSString *name, UIColor *colour, CGSize target);
NSCache *TGAvatarCache(void);
NSMapTable *TGWaveformHeightCache(void);
