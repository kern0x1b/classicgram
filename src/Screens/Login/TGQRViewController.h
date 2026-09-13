#import <UIKit/UIKit.h>

@interface TGQRViewController : UIViewController
@property (nonatomic, copy) BOOL (^onCode)(NSString *payload);
@property (nonatomic, assign) BOOL deviceLinkSubject;
- (void)resumeScanning;
@end
