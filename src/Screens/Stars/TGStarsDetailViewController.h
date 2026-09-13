#import <UIKit/UIKit.h>
#import "TGStarsViewController.h"

@interface TGStarsDetailViewController : UITableViewController

- (id)initWithTitle:(NSString *)title
			  pairs:(NSArray *)pairs
			comment:(NSString *)comment;

@property (nonatomic, strong) NSArray *pairs;
@property (nonatomic, strong) NSString *comment;
@property (nonatomic, strong) NSArray *actions;
@property (nonatomic, strong) NSString *actionsComment;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, strong) TGStarsViewController *retainedHost;

@end
