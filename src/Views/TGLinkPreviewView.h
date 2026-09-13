#import <UIKit/UIKit.h>

@interface TGLinkPreviewView : UIView
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *buttonTitleOverride;
@property (nonatomic, copy) void (^onOpen)(NSString *url);
@property (nonatomic, copy) void (^onInstantView)(NSString *url);
@property (nonatomic, copy) void (^onOpenMedia)(NSString *url);
+ (CGSize)sizeForPreview:(NSDictionary *)preview
				   image:(UIImage *)image
				maxWidth:(CGFloat)maxWidth;
- (void)configureWithPreview:(NSDictionary *)preview
					   image:(UIImage *)image
					outgoing:(BOOL)outgoing
					maxWidth:(CGFloat)maxWidth;
@end
