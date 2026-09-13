#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSDictionary *TGUSFlatEmojiStatusIcon(NSDictionary * _Nullable sticker,
	long long customEmojiId,
	long long expires,
	BOOL isGift,
	NSString * _Nullable giftTitle);

NSString *TGUSLastSeenText(long long wasOnline);

NSDictionary *TGUSStatusInfoForType(NSString *type, long long wasOnline, BOOL hiddenByMyPrivacy);

NSArray<NSNumber *> *TGUSMergePickableEmojiStatusIds(NSArray<NSNumber *> *themedIds,
	NSArray<NSNumber *> *recentIds,
	NSArray<NSNumber *> *defaultIds,
	NSUInteger cap);

NS_ASSUME_NONNULL_END
