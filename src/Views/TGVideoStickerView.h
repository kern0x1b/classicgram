#import <UIKit/UIKit.h>

@interface TGVideoStickerView : UIView

- (BOOL)loadWebMFile:(NSString *)path;
- (void)play;
- (void)stop;

@property (nonatomic, readonly) BOOL loaded;
@property (nonatomic, assign) BOOL loopEnabled;

@end
