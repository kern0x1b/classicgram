#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSDictionary * _Nullable TGChGraph(NSString *key, NSString *title, id _Nullable raw);
NSDictionary * _Nullable TGChValue(NSString *key, NSString *title, id _Nullable raw);
void TGChAddGraphs(NSMutableArray *out, NSDictionary *stats, NSArray *pairs);
void TGChAddValues(NSMutableArray *out, NSDictionary *stats, NSArray *pairs);
NSDictionary *TGChBoostSlot(long long currentlyBoostedChatId, long long cooldownUntilDate, NSTimeInterval now);
NSDictionary * _Nullable TGChPointsFromGraphJson(NSString *json, NSUInteger maxPoints);

NS_ASSUME_NONNULL_END
