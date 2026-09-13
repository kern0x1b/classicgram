#import <UIKit/UIKit.h>

@interface TGCallViewController : UIViewController

- (instancetype)initWithUserId:(int64_t)userId name:(NSString *)name outgoing:(BOOL)outgoing video:(BOOL)video;

+ (void)presentForUserId:(int64_t)userId name:(NSString *)name outgoing:(BOOL)outgoing video:(BOOL)video;

@end
