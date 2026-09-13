#import <Foundation/Foundation.h>

@class TGCallsItem;

@interface TGCallsPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGCallsItem *)itemAtRow:(NSInteger)row;
- (void)updateWithGroups:(NSArray *)groups;

@end
