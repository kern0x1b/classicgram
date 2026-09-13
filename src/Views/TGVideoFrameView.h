#import <UIKit/UIKit.h>

@interface TGVideoFrameView : UIView

- (void)presentBGRABytes:(const uint8_t *)bytes width:(int)width height:(int)height bytesPerRow:(int)bytesPerRow;
- (void)clear;

@end
