#import <Foundation/Foundation.h>
#import "TGMessageLayout.h"

@class TGMessageItem;
@class TGChatLayoutContext;

@interface TGMessageLayoutBuilder : NSObject

+ (TGMessageLayout *)layoutForItem:(TGMessageItem *)item
						   context:(TGChatLayoutContext *)context;

@end
