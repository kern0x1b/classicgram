#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGSavedPreview(NSDictionary * _Nullable message);
NSArray *TGSavedMessageTags(NSDictionary * _Nullable message);
NSNumber * _Nullable TGSavedTagCustomEmojiId(NSDictionary * _Nullable tag);
NSDictionary * _Nullable TGSavedFlattenTopic(NSDictionary * _Nullable topic,
		NSString * _Nullable (^ _Nullable resolveChatName)(int64_t chatId));

NS_ASSUME_NONNULL_END
