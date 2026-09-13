#import <Foundation/Foundation.h>
#import "TGPrivacyContactPickerItem.h"

@interface TGPrivacyContactPickerItemBuilder : NSObject

+ (TGPrivacyContactPickerItem *)itemFromUser:(NSDictionary *)user chosen:(NSArray *)chosen;

@end
