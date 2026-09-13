#import <UIKit/UIKit.h>

@interface TGForwardPicker : UITableViewController
@property (nonatomic, copy) void (^onPicked)(NSArray *chatIds);
@property (nonatomic, assign) BOOL allowsMultiplePicks;
@property (nonatomic, copy) NSString *requiredKind;
@end
