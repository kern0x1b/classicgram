#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Payments)

#pragma mark - star balance

- (void)starBalanceWithCompletion:(void (^ _Nullable)(long long stars))completion;

- (long long)cachedStarBalance;

- (void)resetStarBalanceCacheForAccountSwitch;

- (void)starPaymentOptionsWithCompletion:(void (^ _Nullable)(NSArray *options))completion;

- (void)starGiftPaymentOptionsForUser:(int64_t)userId
						   completion:(void (^ _Nullable)(NSArray *options))completion;

#pragma mark - star subscriptions

- (void)starSubscriptionsOnlyExpiring:(BOOL)onlyExpiring
							   offset:(NSString *)offset
						   completion:(void (^ _Nullable)(NSDictionary *page))completion;

- (void)setStarSubscription:(NSString *)subscriptionId
				   canceled:(BOOL)canceled
				 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)reuseStarSubscription:(NSString *)subscriptionId
				   completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - star transactions

- (void)starTransactionsWithDirection:(NSString *)direction
							   offset:(NSString *)offset
								limit:(NSInteger)limit
						   completion:(void (^ _Nullable)(NSArray *transactions, NSString *nextOffset))completion;

#pragma mark - payment forms

- (void)paymentFormForMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSDictionary *form))completion;

- (void)paymentFormForInvoiceName:(NSString *)name
					   completion:(void (^ _Nullable)(NSDictionary *form))completion;

- (void)paymentFormForPremiumGiftToUser:(int64_t)userId
							   currency:(NSString *)currency
								 amount:(long long)amount
							 monthCount:(NSInteger)monthCount
								   text:(NSString *)text
							 completion:(void (^ _Nullable)(NSDictionary *form))completion;

- (void)payStarsPaymentForm:(NSDictionary *)form
				 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)unlockPaidMediaInMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)validateOrderInfo:(NSDictionary *)orderInfo
		   forPaymentForm:(NSDictionary *)form
					 save:(BOOL)save
			   completion:(void (^ _Nullable)(NSString *orderInfoId, NSArray *shippingOptions))completion;

- (void)payCardPaymentForm:(NSDictionary *)form
		savedCredentialsId:(NSString *)savedCredentialsId
		newCredentialsData:(NSString *)newCredentialsData
			 allowSaveCard:(BOOL)allowSave
			   orderInfoId:(NSString *)orderInfoId
		  shippingOptionId:(NSString *)shippingOptionId
				 tipAmount:(long long)tipAmount
				completion:(void (^ _Nullable)(BOOL ok, NSString *verificationUrl))completion;

- (void)paymentReceiptForMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(NSDictionary *receipt))completion;

- (void)clearSavedPaymentInfoWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - gift catalogue

- (void)availableGiftsWithCompletion:(void (^ _Nullable)(NSArray *gifts))completion;

- (void)sendGiftWithId:(long long)giftId
				toUser:(int64_t)userId
				  text:(NSString *)text
			 isPrivate:(BOOL)isPrivate
		 payForUpgrade:(BOOL)payForUpgrade
			completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)sendGiftWithId:(long long)giftId
				toChat:(int64_t)chatId
				  text:(NSString *)text
			 isPrivate:(BOOL)isPrivate
		 payForUpgrade:(BOOL)payForUpgrade
			completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

#pragma mark - received gifts

- (void)receivedGiftsForUser:(int64_t)userId
				collectionId:(int32_t)collectionId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *gifts, NSString *nextOffset, NSInteger total))completion;

- (void)receivedGiftsForChat:(int64_t)chatId
				collectionId:(int32_t)collectionId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *gifts, NSString *nextOffset, NSInteger total))completion;

- (void)receivedGiftWithId:(NSString *)giftId
				completion:(void (^ _Nullable)(NSDictionary *gift))completion;

- (void)setReceivedGift:(NSString *)giftId
				   saved:(BOOL)saved
			  completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)sellReceivedGift:(NSString *)giftId completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)setPinnedGiftIds:(NSArray *)giftIds
			  completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)pinnedGiftIdsForCurrentUserWithCompletion:(void (^ _Nullable)(NSArray<NSString *> *pinnedGiftIds))completion;

- (void)setChat:(int64_t)chatId
	giftNotificationsEnabled:(BOOL)enabled
				  completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)chatGiftNotificationsEnabledForChat:(int64_t)chatId
								  completion:(void (^ _Nullable)(BOOL enabled))completion;

- (void)giftSettingsWithCompletion:(void (^ _Nullable)(NSDictionary *settings))completion;
- (void)setGiftSettings:(NSDictionary *)settings
			  completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

#pragma mark - unique gifts

- (void)giftUpgradePreviewForGiftId:(long long)giftId
						 completion:(void (^ _Nullable)(NSDictionary *preview))completion;

- (void)upgradeReceivedGift:(NSString *)giftId
		keepOriginalDetails:(BOOL)keepOriginalDetails
				  starCount:(long long)starCount
				 completion:(void (^ _Nullable)(NSDictionary *gift, NSString *error))completion;

- (void)transferReceivedGift:(NSString *)giftId
					  toUser:(int64_t)userId
				   starCount:(long long)starCount
				  completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)dropOriginalDetailsOfGift:(NSString *)giftId
						starCount:(long long)starCount
					   completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

#pragma mark - resale

- (void)giftsForResaleWithGiftId:(long long)giftId
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^ _Nullable)(NSArray *gifts, NSString *nextOffset, NSInteger total))completion;

- (void)setResalePrice:(long long)starCount
	   forReceivedGift:(NSString *)giftId
			completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)buyResoldGiftNamed:(NSString *)name
			  forStarCount:(long long)starCount
				completion:(void (^ _Nullable)(BOOL ok, long long newPriceStarCount, NSString *error))completion;

#pragma mark - gift collections

- (void)giftCollectionsWithCompletion:(void (^ _Nullable)(NSArray *collections))completion;

- (void)giftCollectionCountMaxWithCompletion:(void (^ _Nullable)(NSInteger countMax))completion;

- (void)createGiftCollectionNamed:(NSString *)name
						  giftIds:(NSArray *)giftIds
					   completion:(void (^ _Nullable)(NSDictionary *collection))completion;

- (void)deleteGiftCollection:(int32_t)collectionId
				  completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;
- (void)renameGiftCollection:(int32_t)collectionId
						  to:(NSString *)name
				  completion:(void (^ _Nullable)(NSDictionary *collection))completion;
- (void)addGiftIds:(NSArray *)giftIds toCollection:(int32_t)collectionId
		completion:(void (^ _Nullable)(NSDictionary *collection))completion;
- (void)removeGiftIds:(NSArray *)giftIds fromCollection:(int32_t)collectionId
		   completion:(void (^ _Nullable)(NSDictionary *collection))completion;

- (void)reorderGiftCollections:(NSArray *)collectionIds
					 completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)reorderGifts:(NSArray *)giftIds inCollection:(int32_t)collectionId
		  completion:(void (^ _Nullable)(NSDictionary *collection))completion;

#pragma mark - gift extras

- (void)canSendGiftWithId:(long long)giftId
			   completion:(void (^ _Nullable)(BOOL canSend, NSString *reason))completion;

- (void)withdrawalUrlForUpgradedGift:(NSString *)giftId
							password:(NSString *)password
						  completion:(void (^ _Nullable)(NSString *url, NSString *error))completion;

- (void)setProfileColoursFromGiftColoursId:(long long)coloursId
								completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - paid messages

- (void)paidMessageRevenueFromUser:(int64_t)userId
						completion:(void (^ _Nullable)(long long stars))completion;

- (void)allowUnpaidMessagesFromUser:(int64_t)userId
					  refundPayments:(BOOL)refund
						  completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

#pragma mark - paid (star) reactions

- (void)addPaidReactionToMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					   starCount:(long long)starCount
					   anonymous:(BOOL)anonymous
					  completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)commitPaidReactionsOnMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
						   completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)cancelPaidReactionsOnMessage:(int64_t)messageId inChat:(int64_t)chatId;

- (BOOL)defaultPaidReactionIsAnonymous;
- (void)setDefaultPaidReactionAnonymous:(BOOL)anonymous;
- (void)applyServerDefaultPaidReactionType:(NSDictionary *)type;
- (void)resetPaidReactionDefaultCacheForAccountSwitch;

- (void)paidReactionSendersInChat:(int64_t)chatId
					   completion:(void (^ _Nullable)(NSArray *senders))completion;

#pragma mark - premium gifts and codes

@end

NS_ASSUME_NONNULL_END
