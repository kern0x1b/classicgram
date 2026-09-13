#import <Foundation/Foundation.h>

@class TGOwnedSetsItem;

@interface TGOwnedSetsPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfSets;

- (TGOwnedSetsItem *)createRowItem;
- (TGOwnedSetsItem *)itemAtSetRow:(NSInteger)row;
- (void)updateWithSets:(NSArray *)sets;

@end
