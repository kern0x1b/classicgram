#import <UIKit/UIKit.h>

@interface TGSecretChatViewController : UITableViewController <UIActionSheetDelegate>
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, copy) NSString *peerName;
@property (nonatomic, assign) int secretChatId;
@property (nonatomic, copy) NSString *stateText;
@property (nonatomic, copy) NSString *rawState;
@property (nonatomic, copy) NSString *sendText;
@property (nonatomic, assign) NSInteger ttl;
@property (nonatomic, assign) BOOL ttlKnown;
@property (nonatomic, assign) NSInteger defaultTtl;
@property (nonatomic, assign) BOOL defaultTtlKnown;
@property (nonatomic, assign) BOOL defaultTtlFailed;
@property (nonatomic, strong) NSArray *ladder;
@end
