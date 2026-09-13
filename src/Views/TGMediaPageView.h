#import <UIKit/UIKit.h>

@interface TGMediaPageView : UIScrollView <UIScrollViewDelegate>

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, strong) NSNumber *loadingFileId;
@property (nonatomic, assign) BOOL showingMinithumb;
@property (nonatomic, assign) CGSize imageSize;

- (void)setPageImage:(UIImage *)image;
- (void)setPageImage:(UIImage *)image crossfade:(BOOL)crossfade;
- (void)resetZoom;
- (void)layoutImage;
- (BOOL)isZoomed;
- (BOOL)canZoom;
- (void)centerContents;

@end
