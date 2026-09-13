#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGForumsMessagePreview(NSDictionary * _Nullable message);
NSDictionary * _Nullable TGForumsFlattenTopic(NSDictionary * _Nullable topic, int64_t chatId);
int32_t TGForumsTopicIdForNotification(NSDictionary * _Nullable notification);

NS_ASSUME_NONNULL_END
