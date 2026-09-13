#import "UIImage+WebP.h"
#import "WebP.framework/Headers/decode.h"

static void tgFreePixels(void *info, const void *data, size_t size) {
	free((void *)data);
}

@implementation UIImage (WebP)

+ (UIImage *)convertFromWebP:(NSString *)filePath
			  compressedData:(__autoreleasing NSData **)compressedData
					   error:(NSError **)error {
	NSData *data = [NSData dataWithContentsOfFile:filePath
										  options:NSDataReadingMappedIfSafe
											error:NULL];
	if (!data.length)
		return nil;
	if (compressedData)
		*compressedData = data;

	int width = 0, height = 0;
	if (!WebPGetInfo(data.bytes, data.length, &width, &height) ||
		width <= 0 || height <= 0)
		return nil;

	size_t stride = (size_t)width * 4;
	size_t size = stride * (size_t)height;
	uint8_t *pixels = malloc(size);
	if (!pixels)
		return nil;

	if (!WebPDecodeRGBAInto(data.bytes, data.length, pixels, size, (int)stride)) {
		free(pixels);
		return nil;
	}

	CGDataProviderRef provider =
		CGDataProviderCreateWithData(NULL, pixels, size, tgFreePixels);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGImageRef cgImage = CGImageCreate(width, height, 8, 32, stride, space,
		kCGBitmapByteOrderDefault | kCGImageAlphaLast,
		provider, NULL, NO, kCGRenderingIntentDefault);

	UIImage *image = cgImage ? [UIImage imageWithCGImage:cgImage] : nil;

	if (cgImage)
		CGImageRelease(cgImage);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);

	return image;
}

@end
