#import <Foundation/Foundation.h>

@class TGHiddenStoriesItem;

@interface TGHiddenStoriesPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGHiddenStoriesItem *)itemAtRow:(NSInteger)row;
- (void)updateWithPosters:(NSArray *)posters;

@end
