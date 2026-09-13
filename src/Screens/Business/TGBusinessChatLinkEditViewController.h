#import <UIKit/UIKit.h>

@interface TGBusinessChatLinkEditViewController : UIViewController

- (instancetype)initWithLink:(NSDictionary *)link;

@property (nonatomic, copy) void (^onSaved)(void);

@end
