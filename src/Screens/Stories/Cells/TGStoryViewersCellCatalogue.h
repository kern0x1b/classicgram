#import <Foundation/Foundation.h>
#import "TGStoryViewersItem.h"

@interface TGStoryViewersCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGStoryViewersRowKind)kind;
+ (Class)cellClassForKind:(TGStoryViewersRowKind)kind;

@end
