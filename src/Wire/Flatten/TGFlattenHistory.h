#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSArray *TGMergeRawMessages(NSArray *first, NSArray *second);
NSArray *TGHistoryOldestFirst(NSArray *newestFirst, NSInteger limit);

NS_ASSUME_NONNULL_END
