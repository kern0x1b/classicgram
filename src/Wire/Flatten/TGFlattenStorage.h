#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGStorageNetworkTypeName(NSString * _Nullable type);
NSString *TGStorageNetworkShortName(NSString * _Nullable tdName);
long long TGStorageFreedBytes(NSDictionary * _Nullable stats);
NSDictionary *TGStorageSizesByFileType(NSDictionary * _Nullable stats);
NSArray *TGStorageChatRowsWithTitles(NSArray * _Nullable rows, NSDictionary * _Nullable titles);
NSArray *TGStorageChatIdsMissingTitles(NSArray * _Nullable rows);
NSDictionary *TGStorageNormalizedAutoDownload(NSDictionary * _Nullable values);
NSDictionary *TGStorageAutoDownloadFromPreset(NSDictionary * _Nullable preset);

NS_ASSUME_NONNULL_END
