#import "TGVideoFrameView.h"

@implementation TGVideoFrameView

+ (Class)layerClass {
	return [CALayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.backgroundColor = [UIColor blackColor];
		self.layer.contentsGravity = kCAGravityResizeAspect;
	}
	return self;
}

- (void)presentBGRABytes:(const uint8_t *)bytes width:(int)width height:(int)height bytesPerRow:(int)bytesPerRow {
	if (bytes == NULL || width <= 0 || height <= 0)
		return;

	NSData *copy = [NSData dataWithBytes:bytes length:(NSUInteger)bytesPerRow * (NSUInteger)height];
	CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)copy);
	CGImageRef image = CGImageCreate((size_t)width, (size_t)height, 8, 32, (size_t)bytesPerRow,
		colourSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
		provider, NULL, false, kCGRenderingIntentDefault);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colourSpace);
	if (image == NULL)
		return;

	dispatch_async(dispatch_get_main_queue(), ^{
		self.layer.contents = (__bridge id)image;
		CGImageRelease(image);
	});
}

- (void)clear {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.layer.contents = nil;
	});
}

@end
