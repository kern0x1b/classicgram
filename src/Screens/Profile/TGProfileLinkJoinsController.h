#import <UIKit/UIKit.h>

@interface TGProfileLinkJoinsController : UITableViewController
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSString *link;
@property (nonatomic, strong) NSArray *members;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) BOOL exhausted;
@property (nonatomic, assign) NSInteger joinsGeneration;
@end
