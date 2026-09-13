#import <Foundation/Foundation.h>
#import "TGStorageDownloadsItem.h"

@interface TGStorageDownloadsItemBuilder : NSObject

+ (TGStorageDownloadsItem *)itemForClearRow;
+ (TGStorageDownloadsItem *)itemForLoadingRow;
+ (TGStorageDownloadsItem *)itemForEmptyRow;
+ (TGStorageDownloadsItem *)itemForMoreRowLoading:(BOOL)loading;
+ (TGStorageDownloadsItem *)itemForEntry:(NSDictionary *)entry suggestedNames:(NSDictionary *)suggestedNames;

+ (NSString *)titleForEntry:(NSDictionary *)entry suggestedNames:(NSDictionary *)suggestedNames;
+ (NSString *)detailForEntry:(NSDictionary *)entry;

@end
