#import <UIKit/UIKit.h>
#import "TGReusableView.h"

@interface TGRemoteImageView : UIImageView <TGReusableView>

@property (nonatomic, strong) NSString *reuseIdentifier;
@property (nonatomic, strong) NSNumber *fileId;
@property (nonatomic) bool fadeTransition;
@property (nonatomic) NSTimeInterval fadeTransitionDuration;

+ (void)tgPurgeMemoryCache;

- (UIImage *)currentImage;

- (void)loadWithFileId:(NSNumber *)fileId square:(CGFloat)side placeholder:(UIImage *)placeholder forceFade:(bool)forceFade;
- (void)loadWithFileId:(NSNumber *)fileId stableKey:(NSString *)stableKey square:(CGFloat)side placeholder:(UIImage *)placeholder forceFade:(bool)forceFade;
- (void)cancelLoading;

@end
