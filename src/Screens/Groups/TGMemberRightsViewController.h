#import <UIKit/UIKit.h>

@interface TGMemberRightsViewController : UIViewController <UITableViewDataSource,
											  UITableViewDelegate, UIActionSheetDelegate, UITextFieldDelegate> {
	int64_t _chatId;
	int64_t _userId;
	BOOL _restricting;
	BOOL _defaults;
	BOOL _banning;
	BOOL _customTitleEdited;
}

@property (nonatomic, strong) NSString *memberName;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *keys;
@property (nonatomic, strong) NSMutableDictionary *values;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) NSInteger untilDate;
@property (nonatomic, assign) BOOL editable;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL saving;
@property (nonatomic, assign) BOOL canTransferOwnership;
@property (nonatomic, assign) BOOL basicGroupAdmin;
@property (nonatomic, strong) NSString *customTitle;
@property (nonatomic, strong) UITextField *customTitleField;
@property (nonatomic, copy) void (^onSaved)(void);
@property (nonatomic, copy) void (^onTransferOwnership)(void);

- (id)initWithChatId:(int64_t)chatId userId:(int64_t)userId
				name:(NSString *)name
		 restricting:(BOOL)restricting;
- (id)initWithDefaultPermissionsOfChat:(int64_t)chatId;
- (id)initForBanningWithChatId:(int64_t)chatId userId:(int64_t)userId name:(NSString *)name;

@end
