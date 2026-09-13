#import <Foundation/Foundation.h>

@class TGConnectedWebsitesItem;

@interface TGConnectedWebsitesPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGConnectedWebsitesItem *)itemAtRow:(NSInteger)row;
- (void)updateWithSites:(NSArray *)sites;

@end
