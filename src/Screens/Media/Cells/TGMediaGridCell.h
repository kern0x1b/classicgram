#import <UIKit/UIKit.h>

@class TGViewRecycler;
@class TGMediaGridCell;

@protocol TGMediaGridCellDelegate <NSObject>
- (void)gridCell:(TGMediaGridCell *)cell tappedItemAtIndex:(NSInteger)index;
@end

@interface TGMediaGridCell : UITableViewCell

@property (nonatomic, weak) TGViewRecycler *recycler;
@property (nonatomic, weak) id<TGMediaGridCellDelegate> gridDelegate;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) NSInteger baseIndex;
@property (nonatomic, strong) NSMutableArray *tiles;

@property (nonatomic, copy) UIImage * (^instantThumbnailProvider)(NSDictionary *item);

- (void)configureWithItems:(NSArray *)items baseIndex:(NSInteger)baseIndex;
- (void)releaseTiles;

@end
