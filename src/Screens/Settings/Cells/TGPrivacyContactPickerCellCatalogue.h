#import <UIKit/UIKit.h>
#import "TGPrivacyContactPickerItem.h"

@interface TGPrivacyContactPickerCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGPrivacyContactPickerRowKind)kind;
+ (Class)cellClassForKind:(TGPrivacyContactPickerRowKind)kind;

@end
