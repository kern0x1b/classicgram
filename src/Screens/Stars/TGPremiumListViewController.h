#import <UIKit/UIKit.h>

enum {
	TGPremiumListGiftCodes = 0,
	TGPremiumListGiveaways,
	TGPremiumListBoostLevels,
	TGPremiumListBoosters,
	TGPremiumListBusiness
};

@interface TGPremiumListViewController : UITableViewController

- (id)initWithMode:(NSInteger)mode chatId:(int64_t)chatId title:(NSString *)title;

@end
