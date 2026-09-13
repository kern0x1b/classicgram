#import <UIKit/UIKit.h>

@interface TGStickerTilesCell : UITableViewCell

@property (nonatomic, strong) NSMutableArray *tiles;

- (UIButton *)tileAtIndex:(NSInteger)index;
- (void)hideTilesFromIndex:(NSInteger)index;

@end
