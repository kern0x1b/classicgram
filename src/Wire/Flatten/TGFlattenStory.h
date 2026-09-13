#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

int64_t TGStorySenderId(NSDictionary *_Nullable sender);

NSDictionary *_Nullable TGStoryAreaFlattened(NSDictionary *_Nullable raw);
NSDictionary *_Nullable TGStoryFlattened(NSDictionary *_Nullable raw);
NSArray *TGStoriesFlattened(NSArray *_Nullable list);
NSDictionary *_Nullable TGStoryAlbumFlattened(NSDictionary *_Nullable raw);

NSString *TGStoryErrorText(NSDictionary *_Nullable error);
NSString *TGStoryLimitReason(NSString *_Nullable type);

NSDictionary *TGStoryPrivacyRules(NSString *_Nullable privacy, NSArray *_Nullable userIds);
NSString *TGStoryPrivacyName(NSDictionary *_Nullable settings);

NSString *TGStoryReactionEmoji(NSDictionary *_Nullable type);
NSNumber *_Nullable TGStoryLargestPhotoId(NSDictionary *_Nullable photo);
NSString *TGStoryNetworkType(NSString *_Nullable type);

NS_ASSUME_NONNULL_END
