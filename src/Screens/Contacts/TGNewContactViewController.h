#import <UIKit/UIKit.h>

@interface TGNewContactViewController : UITableViewController

@property (nonatomic, assign) int64_t peerUserId;
@property (nonatomic, copy) NSString *prefillFirstName;
@property (nonatomic, copy) NSString *prefillLastName;
@property (nonatomic, copy) NSString *prefillPhone;
@property (nonatomic, assign) BOOL offersShareException;
@property (nonatomic, assign) BOOL editingExistingContact;

@property (nonatomic, copy) void (^onDone)(BOOL saved, int64_t resolvedUserId);

@end
