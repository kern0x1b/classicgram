#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface TGWebMStickerDecoder : NSObject

- (instancetype)initWithPath:(NSString *)path;

@property (nonatomic, readonly) NSUInteger frameCount;
@property (nonatomic, readonly) NSTimeInterval frameDuration;
@property (nonatomic, readonly) CGSize pixelSize;

- (CGImageRef)copyNextFrameFittingSide:(NSUInteger)side CF_RETURNS_RETAINED;
- (void)rewind;

@end
