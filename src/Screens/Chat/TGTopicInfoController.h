#import <UIKit/UIKit.h>

@interface TGTopicInfoController : UITableViewController <UIAlertViewDelegate>

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int32_t topicId;
@property (nonatomic, copy) NSString *topicName;
@property (nonatomic, assign) BOOL canPinMessages;
@property (nonatomic, strong) NSDictionary *topic;
@property (nonatomic, strong) NSArray *details;
@property (nonatomic, strong) NSArray *recent;

@end
