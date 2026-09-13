#import <UIKit/UIKit.h>

@interface TGProfileBoostsController : UITableViewController
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) BOOL channel;
@property (nonatomic, strong) NSDictionary *status;
@property (nonatomic, strong) NSArray *boosters;
@property (nonatomic, copy) NSString *boostersOffset;
@property (nonatomic, assign) NSInteger boostersTotal;
@property (nonatomic, assign) BOOL boostersPending;
@property (nonatomic, assign) BOOL boostersExhausted;
@property (nonatomic, assign) NSInteger boostersGeneration;
@property (nonatomic, strong) NSString *boostLink;
@property (nonatomic, strong) NSDictionary *nextLevelFeatures;
@property (nonatomic, strong) NSArray *featureTable;
@end
