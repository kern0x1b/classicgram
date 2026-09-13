#import <UIKit/UIKit.h>

CGImageRef UIGetScreenImage(void);

int main(int argc, char *argv[]) {
	@autoreleasepool {
		const char *outPath = argc > 1 ? argv[1] : "/tmp/screenshot.png";
		CGImageRef cgImage = UIGetScreenImage();
		if (!cgImage) {
			fprintf(stderr, "UIGetScreenImage returned NULL\n");
			return 1;
		}
		UIImage *image = [UIImage imageWithCGImage:cgImage];
		CGImageRelease(cgImage);
		NSData *png = UIImagePNGRepresentation(image);
		if (!png) {
			fprintf(stderr, "PNG encode failed\n");
			return 1;
		}
		BOOL ok = [png writeToFile:[NSString stringWithUTF8String:outPath] atomically:YES];
		if (!ok) {
			fprintf(stderr, "write failed: %s\n", outPath);
			return 1;
		}
		printf("wrote %s (%lu bytes)\n", outPath, (unsigned long)png.length);
		return 0;
	}
}
