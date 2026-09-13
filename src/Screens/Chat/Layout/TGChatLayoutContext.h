#import <UIKit/UIKit.h>

@interface TGChatLayoutContext : NSObject

@property (nonatomic, readonly) CGFloat tableWidth;
@property (nonatomic, readonly) CGFloat baseFontSize;
@property (nonatomic, readonly) CGFloat screenScale;
@property (nonatomic, readonly) BOOL group;
@property (nonatomic, readonly) BOOL wideLayout;
@property (nonatomic, readonly) BOOL selecting;
@property (nonatomic, readonly) uint32_t generation;

- (instancetype)initWithTableWidth:(CGFloat)tableWidth
					  baseFontSize:(CGFloat)baseFontSize
					   screenScale:(CGFloat)screenScale
						   isGroup:(BOOL)isGroup
					  isWideLayout:(BOOL)isWideLayout
					   isSelecting:(BOOL)isSelecting
						generation:(uint32_t)generation NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
