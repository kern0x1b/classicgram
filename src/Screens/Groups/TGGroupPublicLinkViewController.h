#import <UIKit/UIKit.h>

@interface TGGroupPublicLinkViewController : UIViewController <UITableViewDataSource,
												 UITableViewDelegate, UITextFieldDelegate> {
	int64_t _chatId;
}

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UIView *footerView;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *publicChats;
@property (nonatomic, strong) NSString *existingUsername;
@property (nonatomic, strong) NSString *checkedUsername;
@property (nonatomic, assign) BOOL channel;
@property (nonatomic, assign) BOOL checkOk;
@property (nonatomic, assign) BOOL saving;
@property (nonatomic, assign) NSInteger checkGeneration;
@property (nonatomic, copy) void (^onChanged)(void);

- (id)initWithChatId:(int64_t)chatId username:(NSString *)username isChannel:(BOOL)isChannel;

@end
