#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGAutosaveCategoryPhoto;
extern NSString *const TGAutosaveCategoryVideo;

NSString *_Nullable TGAutosaveCategoryForKind(NSString *_Nullable kind);

BOOL TGShouldAutosaveFile(NSDictionary *_Nullable scopeSettings,
		NSDictionary *_Nullable chatException,
		NSString *category,
		long long fileSize);

NS_ASSUME_NONNULL_END
