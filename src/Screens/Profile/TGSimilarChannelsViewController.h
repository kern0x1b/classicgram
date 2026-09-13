#import <UIKit/UIKit.h>

@interface TGSimilarChannelsViewController : UITableViewController
@property (nonatomic, copy) NSArray *chats;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, copy) void (^onPick)(NSDictionary *chat);
@end
