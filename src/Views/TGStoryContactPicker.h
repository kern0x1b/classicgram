#import <UIKit/UIKit.h>

@interface TGStoryContactPicker : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) void (^onPicked)(NSArray *userIds);
@property (nonatomic, copy) NSArray *preselected;
+ (void)presentFrom:(UIViewController *)host
			  title:(NSString *)title
		preselected:(NSArray *)preselected
			 picked:(void (^)(NSArray *userIds))picked;
@end
