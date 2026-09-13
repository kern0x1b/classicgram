#import <UIKit/UIKit.h>

@interface TGStoryPage : UIView

@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, strong) NSNumber *itemId;
@property (nonatomic, strong) NSNumber *photoFileId;
@property (nonatomic, strong) NSNumber *videoFileId;
@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) NSString *videoPath;
@property (nonatomic, assign) CGFloat captionBottomInset;
@property (nonatomic, readonly) BOOL failed;

- (void)setStoryImage:(UIImage *)image animated:(BOOL)animated;
- (void)playVideoAtPath:(NSString *)path;
- (void)stopVideo;
- (void)pauseVideo;
- (void)resumeVideo;
- (void)setCaption:(NSString *)caption;
- (void)setAreas:(NSArray *)areas;
- (NSDictionary *)areaAtPoint:(CGPoint)point;
- (void)prepareForReuse;
- (CGRect)captionFrame;
- (void)beginLoading;
- (void)showFailure;
- (BOOL)isRetryPoint:(CGPoint)point;

@end
