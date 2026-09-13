#import <UIKit/UIKit.h>
#import "TGStarsListItem.h"

@interface TGStarsListCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGStarsListRowKind)kind;
+ (Class)cellClassForKind:(TGStarsListRowKind)kind;
+ (UITableViewCellStyle)cellStyleForKind:(TGStarsListRowKind)kind;

@end
