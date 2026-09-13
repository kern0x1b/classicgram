#import <Foundation/Foundation.h>

@class TGSearchResultItem;

@interface TGSearchResultsPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfSections;

- (TGSearchResultItem *)itemInSection:(NSInteger)section row:(NSInteger)row;
- (void)updateWithSections:(NSArray *)sections;

@end
