#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSDictionary * _Nullable TGBMarkup(NSDictionary * _Nullable message);
NSNumber * _Nullable TGBFileIdOfPhoto(NSDictionary * _Nullable photo);
NSNumber * _Nullable TGBFileIdOfThumbnail(NSDictionary * _Nullable owner);
NSNumber * _Nullable TGBFileIdOfDocument(NSDictionary * _Nullable owner, NSString * _Nullable key);

NS_ASSUME_NONNULL_END
