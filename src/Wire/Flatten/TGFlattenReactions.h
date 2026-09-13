#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGReactionUnavailability(NSDictionary * _Nullable reason);
NSString *TGReactionChipSignature(NSArray * _Nullable chips);
int64_t TGReactionSenderId(NSDictionary * _Nullable sender);

NSInteger TGReactionUserQuota(BOOL isPremium);
BOOL TGReactionHasRoomForMore(NSInteger chosenByCurrentUser,
							  NSInteger totalDistinctOnMessage,
							  NSInteger chatMaxReactionCount,
							  BOOL isPremium);
BOOL TGReactionTypeExistsOnMessage(NSString * _Nullable emoji,
									NSArray * _Nullable existingReactionTypes);

BOOL TGChatIsSavedMessages(int64_t chatId, int64_t savedMessagesChatId);
NSString * _Nullable TGSavedMessagesTagLookupKey(NSString * _Nullable emoji, int64_t customEmojiId);

NS_ASSUME_NONNULL_END
