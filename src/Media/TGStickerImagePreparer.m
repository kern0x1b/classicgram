#import "TGStickerImagePreparer.h"
#import "TGLocalization.h"
#import "WebP.framework/Headers/encode.h"

static const NSInteger kStickerSide = 512;
static const NSUInteger kStickerMaxBytes = 512 * 1024;

static NSError *TGStickerPrepError(NSInteger code, NSString *message) {
	return [NSError errorWithDomain:@"TGStickerImagePreparer" code:code
						   userInfo:@{NSLocalizedDescriptionKey : message ?: @""}];
}

@implementation TGStickerImagePreparer

+ (CGSize)targetSizeForImage:(UIImage *)image {
	CGImageRef cgImage = image.CGImage;
	CGFloat width = cgImage ? (CGFloat)CGImageGetWidth(cgImage) : image.size.width;
	CGFloat height = cgImage ? (CGFloat)CGImageGetHeight(cgImage) : image.size.height;
	if (width <= 0 || height <= 0)
		return CGSizeMake(kStickerSide, kStickerSide);

	CGFloat longSide = MAX(width, height);
	CGFloat scale = kStickerSide / longSide;
	NSInteger targetWidth = MAX(1, (NSInteger)lround(width * scale));
	NSInteger targetHeight = MAX(1, (NSInteger)lround(height * scale));
	if (width >= height)
		targetWidth = kStickerSide;
	else
		targetHeight = kStickerSide;
	return CGSizeMake(targetWidth, targetHeight);
}

+ (uint8_t *)rgbaBytesForImage:(UIImage *)image targetSize:(CGSize)size stride:(size_t *)outStride {
	size_t width = (size_t)size.width;
	size_t height = (size_t)size.height;
	size_t stride = width * 4;
	uint8_t *pixels = calloc(height * stride, 1);
	if (!pixels)
		return NULL;

	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, stride, space,
		kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(space);
	if (!context) {
		free(pixels);
		return NULL;
	}

	CGContextTranslateCTM(context, 0, (CGFloat)height);
	CGContextScaleCTM(context, 1.0f, -1.0f);
	UIGraphicsPushContext(context);
	[image drawInRect:CGRectMake(0, 0, width, height)];
	UIGraphicsPopContext();
	CGContextRelease(context);

	if (outStride)
		*outStride = stride;
	return pixels;
}

+ (NSString *)stickerFilePathFromImage:(UIImage *)image error:(NSError **)error {
	if (!image) {
		if (error)
			*error = TGStickerPrepError(1, TGL(@"Stickers.PrepareNoImage", @"No image supplied."));
		return nil;
	}

	CGSize target = [self targetSizeForImage:image];
	size_t stride = 0;
	uint8_t *pixels = [self rgbaBytesForImage:image targetSize:target stride:&stride];
	if (!pixels) {
		if (error)
			*error = TGStickerPrepError(2, TGL(@"Stickers.PrepareRasteriseFailed", @"Could not rasterise the image."));
		return nil;
	}

	NSString *path = nil;
	float quality = 90.0f;
	for (NSInteger attempt = 0; attempt < 5 && !path; attempt++) {
		uint8_t *encoded = NULL;
		size_t encodedSize = WebPEncodeRGBA(pixels, (int)target.width, (int)target.height,
			(int)stride, quality, &encoded);
		if (encoded && encodedSize > 0 && encodedSize <= kStickerMaxBytes) {
			NSString *candidate = [NSTemporaryDirectory() stringByAppendingPathComponent:
					[NSString stringWithFormat:@"sticker-%08x.webp", arc4random()]];
			NSData *data = [NSData dataWithBytes:encoded length:encodedSize];
			if ([data writeToFile:candidate atomically:YES])
				path = candidate;
		}
		if (encoded)
			free(encoded);
		quality -= 20.0f;
	}
	free(pixels);

	if (path)
		return path;

	UIImage *scaled = [self scaledImage:image toSize:target];
	NSData *png = scaled ? UIImagePNGRepresentation(scaled) : nil;
	if (png.length > 0 && png.length <= kStickerMaxBytes) {
		NSString *candidate = [NSTemporaryDirectory() stringByAppendingPathComponent:
				[NSString stringWithFormat:@"sticker-%08x.png", arc4random()]];
		if ([png writeToFile:candidate atomically:YES])
			return candidate;
	}

	if (error)
		*error = TGStickerPrepError(3, TGL(@"Stickers.PrepareTooLarge", @"Could not encode a sticker file under 512 KB."));
	return nil;
}

+ (UIImage *)scaledImage:(UIImage *)image toSize:(CGSize)size {
	UIGraphicsBeginImageContextWithOptions(size, NO, 1.0f);
	[image drawInRect:CGRectMake(0, 0, size.width, size.height)];
	UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return scaled;
}

@end
