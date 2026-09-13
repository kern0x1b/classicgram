#import <Foundation/Foundation.h>

@class TGStarsListItem;

@interface TGStarsListPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGStarsListItem *)itemAtRow:(NSInteger)row;
- (void)updateWithRows:(NSArray *)rows
			   loading:(BOOL)loading
		 moreAvailable:(BOOL)moreAvailable
			 emptyText:(NSString *)emptyText;

@end
