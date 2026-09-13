#import <UIKit/UIKit.h>

void TGOfferInviteLinkToRestrictedUsers(UIViewController *presenter,
										 int64_t chatId,
										 NSArray *userIds,
										 NSDictionary *namesByUserId,
										 void (^completion)(void));
