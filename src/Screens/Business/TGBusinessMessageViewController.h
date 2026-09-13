#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGBusinessMessageKind) {
	TGBusinessMessageGreeting = 0,
	TGBusinessMessageAway = 1,
};

@interface TGBusinessMessageViewController : UITableViewController

- (instancetype)initWithKind:(TGBusinessMessageKind)kind;

@end
