#import <UIKit/UIKit.h>

@interface TGLottieView : UIView

- (BOOL)loadTGSFile:(NSString *)path;

- (void)play;
- (void)stop;

@property (nonatomic, readonly) BOOL loaded;
@property (nonatomic, assign) BOOL loopEnabled;

@end
