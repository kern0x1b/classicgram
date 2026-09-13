#import <Foundation/Foundation.h>

@class TGStoryViewersItem;

@interface TGStoryViewersPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGStoryViewersItem *)itemAtRow:(NSInteger)row;
- (void)updateWithRows:(NSArray *)rows;

@end
