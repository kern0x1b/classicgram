#import <UIKit/UIKit.h>
#import "TGOwnedSetsItem.h"

@interface TGOwnedSetsCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGOwnedSetsRowKind)kind;
+ (Class)cellClassForKind:(TGOwnedSetsRowKind)kind;
+ (UITableViewCellStyle)cellStyleForKind:(TGOwnedSetsRowKind)kind;

@end
