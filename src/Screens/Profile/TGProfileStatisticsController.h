#import <UIKit/UIKit.h>

#import "TGProfileChartView.h"

@interface TGProfileStatisticsController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) BOOL channelChat;
@property (nonatomic, strong) NSArray *values;
@property (nonatomic, strong) NSArray *topSenders;
@property (nonatomic, strong) NSArray *topAdmins;
@property (nonatomic, strong) NSArray *topInviters;
@property (nonatomic, strong) NSArray *graphs;
@property (nonatomic, strong) NSArray *recentInteractions;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSString *loadError;
@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) TGProfileChartView *chartView;
@property (nonatomic, strong) NSDictionary *boostStatus;
@property (nonatomic, strong) NSArray *boosters;
@end
