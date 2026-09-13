#import <UIKit/UIKit.h>

@interface TGSavedMessagesTagsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate, UITextFieldDelegate>

@property (nonatomic, assign) int64_t topicId;

@property (nonatomic, copy) NSString *topicTitle;

- (instancetype)initWithTopicId:(int64_t)topicId;

@end
