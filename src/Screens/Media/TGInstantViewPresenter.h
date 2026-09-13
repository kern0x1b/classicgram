#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class TGInstantViewItem;

@interface TGInstantViewPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGInstantViewItem *)itemAtRow:(NSInteger)row;
- (void)updateWithBlocks:(NSArray *)blocks width:(CGFloat)width;

@end
