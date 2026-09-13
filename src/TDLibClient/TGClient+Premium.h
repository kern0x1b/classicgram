#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGSpeechRecognitionTrialDidChangeNotification;

@interface TGClient (Premium)

#pragma mark - account state

- (BOOL)isPremiumAccount;

+ (BOOL)isPremiumUser:(NSDictionary *)user;

- (void)premiumSubscriptionWithCompletion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)premiumOptionsWithCompletion:(void (^ _Nullable)(NSDictionary *options))completion;

#pragma mark - limits

- (void)premiumLimit:(NSString *)limitType
		  completion:(void (^ _Nullable)(NSDictionary *limit))completion;

- (void)premiumLimitsWithCompletion:(void (^ _Nullable)(NSArray *limits))completion;

- (void)effectivePremiumLimit:(NSString *)limitType
				   completion:(void (^ _Nullable)(NSInteger value))completion;

#pragma mark - feature catalogue

- (void)premiumFeaturesWithCompletion:(void (^ _Nullable)(NSArray *features))completion;

- (void)businessFeaturesWithCompletion:(void (^ _Nullable)(NSArray *features))completion;

- (void)viewPremiumFeature:(NSString *)featureType;

- (void)clickPremiumSubscriptionButton;

- (void)premiumInfoStickerForMonths:(NSInteger)monthCount
						 completion:(void (^ _Nullable)(NSDictionary *sticker))completion;

#pragma mark - gift codes

- (void)checkGiftCode:(NSString *)code
		   completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)applyGiftCode:(NSString *)code
		   completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)redeemGiftCode:(NSString *)code
			completion:(void (^ _Nullable)(BOOL ok, NSDictionary *info, NSString *error))completion;

#pragma mark - gifting premium

- (void)premiumGiftPaymentOptionsWithCompletion:(void (^ _Nullable)(NSArray *options))completion;

- (void)giftPremiumToUser:(int64_t)userId
				   months:(NSInteger)months
					stars:(long long)stars
				  message:(NSString *)message
			   completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

#pragma mark - giveaways

- (void)giveawayInfoForMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)launchPrepaidGiveaway:(long long)giveawayId
					   inChat:(int64_t)chatId
				  winnerCount:(NSInteger)winnerCount
				  winnersDate:(NSTimeInterval)winnersDate
			   onlyNewMembers:(BOOL)onlyNewMembers
			 hasPublicWinners:(BOOL)hasPublicWinners
				 countryCodes:(NSArray *)countryCodes
			 prizeDescription:(NSString *)prizeDescription
						stars:(long long)stars
				   completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

- (void)accountGiftCodesWithLimit:(NSInteger)limit
					   completion:(void (^ _Nullable)(NSArray *codes))completion;

- (void)enteredGiveawaysWithLimit:(NSInteger)limit
					   completion:(void (^ _Nullable)(NSArray *giveaways))completion;

#pragma mark - channel boosts

- (void)chatBoostStatusForChat:(int64_t)chatId
					completion:(void (^ _Nullable)(NSDictionary *status))completion;

- (void)chatBoostLinkForChat:(int64_t)chatId
				  completion:(void (^ _Nullable)(NSString *url, BOOL isPublic))completion;

- (void)availableBoostSlotsWithCompletion:(void (^ _Nullable)(NSArray *slots))completion;

- (void)boostersInChat:(int64_t)chatId
		 onlyGiftCodes:(BOOL)onlyGiftCodes
				offset:(NSString *)offset
				 limit:(NSInteger)limit
			completion:(void (^ _Nullable)(NSDictionary *page))completion;

- (void)boostFeaturesForChannel:(BOOL)isChannel
					 completion:(void (^ _Nullable)(NSArray *levels))completion;

#pragma mark - stars

- (void)starTransactionsWithOffset:(NSString *)offset
							 limit:(NSInteger)limit
						completion:(void (^ _Nullable)(NSDictionary *page))completion;

#pragma mark - affiliate programs

- (void)connectedAffiliateProgramsWithCompletion:(void (^ _Nullable)(NSArray *programs))completion;

- (void)suggestedAffiliateProgramsWithCompletion:(void (^ _Nullable)(NSArray *programs))completion;

- (void)connectAffiliateProgramForBot:(int64_t)botUserId
						   completion:(void (^ _Nullable)(NSString *url, NSString *error))completion;

- (void)disconnectAffiliateProgramWithUrl:(NSString *)url
							   completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - voice recognition

- (void)recognizeSpeechInMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(BOOL ok, NSString *error))completion;

+ (NSDictionary *)speechRecognitionFromMessage:(NSDictionary *)message;

- (void)handleUpdateSpeechRecognitionTrial:(NSDictionary *)update;
- (void)clearSpeechRecognitionTrialForAccountSwitch;

@end

NS_ASSUME_NONNULL_END
