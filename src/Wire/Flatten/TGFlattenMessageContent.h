#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger kSelfDestructViewOnce;

NSDictionary * _Nullable TGMCMediaInfo(NSDictionary * _Nullable message);
NSArray *TGMCFlattenEntities(id _Nullable rawEntities);
NSString *TGMCEntityKind(NSString * _Nullable typeName);
NSDictionary * _Nullable TGMCSelfDestruct(NSInteger seconds);
NSData *TGMCBase64(id _Nullable value);

NS_ASSUME_NONNULL_END
