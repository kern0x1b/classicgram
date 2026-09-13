#import <UIKit/UIKit.h>

UIImage *TGDecodeThumbnail(NSString *path, CGFloat maxPixelSize);
UIImage *TGDecodeSquareThumbnail(NSString *path, CGFloat side);
UIImage *TGImageWithinPixelLimit(UIImage *image, CGFloat maxPixelSize);
NSUInteger TGImageBitmapBytes(UIImage *image);
dispatch_queue_t TGImageDecodeQueue(void);
