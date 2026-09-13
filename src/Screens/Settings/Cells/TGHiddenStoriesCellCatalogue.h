#import <UIKit/UIKit.h>
#import "TGHiddenStoriesItem.h"

@interface TGHiddenStoriesCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGHiddenStoriesRowKind)kind;
+ (Class)cellClassForKind:(TGHiddenStoriesRowKind)kind;

@end
