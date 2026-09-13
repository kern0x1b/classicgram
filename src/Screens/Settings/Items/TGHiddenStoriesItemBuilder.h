#import <Foundation/Foundation.h>
#import "TGHiddenStoriesItem.h"

@interface TGHiddenStoriesItemBuilder : NSObject

+ (TGHiddenStoriesItem *)itemFromPoster:(NSDictionary *)poster;

@end
