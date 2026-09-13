#import <Foundation/Foundation.h>

@class TGMessageItem;
@class TGMessageItemResolvedInputs;

@interface TGMessageItemBuilder : NSObject

+ (TGMessageItem *)itemFromFlatMessage:(NSDictionary *)flat
								chatId:(int64_t)chatId
					   reuseIdentifier:(NSString *)reuseIdentifier
						  albumMembers:(NSArray *)albumMembers
							  resolved:(TGMessageItemResolvedInputs *)resolved;

@end
