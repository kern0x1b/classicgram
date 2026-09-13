#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void TGASApplyFill(NSMutableDictionary *out, NSDictionary * _Nullable fill);
NSDictionary * _Nullable TGASBackgroundRow(id _Nullable object);
NSDictionary *TGASFillFromRow(NSDictionary * _Nullable row);
NSDictionary *TGASBackgroundTypeForKind(NSString * _Nullable kind);
NSArray *TGASWebDomainExceptions(id _Nullable rawList);
NSDictionary * _Nullable TGASThemeColoursFromSettings(NSDictionary * _Nullable settings);

NS_ASSUME_NONNULL_END
