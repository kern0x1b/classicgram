#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSData * _Nullable TGFilesDataFromBase64(id _Nullable value);
NSDictionary * _Nullable TGFileInfo(NSDictionary * _Nullable file);
NSDictionary * _Nullable TGFileOfMessageContent(NSDictionary * _Nullable content, long long preferredFileId);
NSDictionary * _Nullable TGBestPhotoSizeInSizesForWidthScale(NSArray * _Nullable sizes, CGFloat width, CGFloat scale);
NSDictionary * _Nullable TGDecodableThumbnail(NSDictionary * _Nullable thumbnail);

NS_ASSUME_NONNULL_END
