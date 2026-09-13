#import <UIKit/UIKit.h>

@interface TGWallpaperGradientViewController : UITableViewController

@property (nonatomic, assign) NSInteger topColor;
@property (nonatomic, assign) NSInteger bottomColor;
@property (nonatomic, assign) NSInteger rotation;
@property (nonatomic, copy) void (^onApplied)(NSDictionary *background);

@end
