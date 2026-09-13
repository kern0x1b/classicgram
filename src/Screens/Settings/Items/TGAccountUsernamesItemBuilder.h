#import <Foundation/Foundation.h>
#import "TGAccountUsernamesItem.h"

@interface TGAccountUsernamesItemBuilder : NSObject

+ (TGAccountUsernamesItem *)itemFromUsername:(NSString *)username
						  showsEditableBadge:(BOOL)showsEditableBadge;

@end
