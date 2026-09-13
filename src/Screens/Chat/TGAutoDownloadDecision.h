#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGAutoDownloadCategoryPhoto;
extern NSString *const TGAutoDownloadCategoryVideo;
extern NSString *const TGAutoDownloadCategoryOther;

NSString *TGAutoDownloadCategoryForKind(NSString *_Nullable kind);

BOOL TGShouldAutoDownloadFile(NSDictionary *_Nullable settings, NSString *category, long long fileSize);

NSDictionary *_Nullable TGAutoDownloadSettingsMergedForMobile(NSDictionary *_Nullable mobile,
		NSDictionary *_Nullable roaming);

NS_ASSUME_NONNULL_END
