#import <UIKit/UIKit.h>

@interface TGQRCodeViewController : UIViewController
- (id)initWithLink:(NSString *)link caption:(NSString *)caption;
- (id)initWithLink:(NSString *)link
		   caption:(NSString *)caption
		 expiresIn:(NSInteger)expiresIn
	   refreshLink:(void (^)(void (^completion)(NSString *link, NSInteger expiresIn)))refreshLink;
@end
