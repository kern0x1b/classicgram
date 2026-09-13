#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGStickersPage) {
	TGStickersPageRoot = 0,
	TGStickersPageTrending = 1,
	TGStickersPageArchived = 2,
	TGStickersPageFavourites = 3,
	TGStickersPageSet = 4
};

@interface TGStickersViewController : UIViewController

@property (nonatomic, assign) TGStickersPage page;

@property (nonatomic, assign) int64_t setId;

@property (nonatomic, strong) NSDictionary *set;

@end
