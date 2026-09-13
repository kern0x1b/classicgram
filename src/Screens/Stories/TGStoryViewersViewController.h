#import <UIKit/UIKit.h>

@interface TGStoryViewersViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, assign) NSInteger storyId;
@property (nonatomic, assign) int64_t chatId;
@end
