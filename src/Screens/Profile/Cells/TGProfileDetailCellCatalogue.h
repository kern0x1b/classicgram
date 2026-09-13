#import <Foundation/Foundation.h>
#import "TGProfileDetailItem.h"

@interface TGProfileDetailCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGProfileDetailRowKind)kind;

+ (Class)cellClassForKind:(TGProfileDetailRowKind)kind;

@end
