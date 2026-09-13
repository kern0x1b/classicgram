#import "TGStarsAction.h"
#import <UIKit/UIKit.h>
#import "TGStarsViewController.h"
#import "TGStarsListViewController.h"
#import "TGStarsDetailViewController.h"
#import "TGActionSheet.h"

enum {
	TGStarsSectionBalance = 0,
	TGStarsSectionTransactions,
	TGStarsSectionSubscriptions,
	TGStarsSectionGifts,
	TGStarsSectionGiftTools,
	TGStarsSectionMore,
	TGStarsSectionCount
};

enum {
	TGStarsGiftToolCatalogue = 0,
	TGStarsGiftToolCollections,
	TGStarsGiftToolSettings,
	TGStarsGiftToolChannel,
	TGStarsGiftToolCount
};

enum {
	TGStarsMoreStarPacks = 0,
	TGStarsMoreIncoming,
	TGStarsMoreOutgoing,
	TGStarsMorePaidMessages,
	TGStarsMoreAffiliatePrograms,
	TGStarsMoreClearPaymentInfo,
	TGStarsMoreCount
};

@interface TGStarsViewController ()
@property (nonatomic, strong) NSMutableArray *subscriptions;
@property (nonatomic, assign) BOOL subscriptionsLoaded;
@property (nonatomic, assign) BOOL subscriptionsLoading;
@property (nonatomic, strong) NSMutableArray *transactions;
@property (nonatomic, strong) NSMutableArray *gifts;
@property (nonatomic, strong) NSString *transactionsOffset;
@property (nonatomic, strong) NSString *giftsOffset;
@property (nonatomic, assign) BOOL transactionsLoaded;
@property (nonatomic, assign) BOOL transactionsFailed;
@property (nonatomic, assign) BOOL transactionsLoading;
@property (nonatomic, assign) BOOL giftsLoaded;
@property (nonatomic, assign) BOOL giftsLoading;
@property (nonatomic, assign) BOOL balanceKnown;
@property (nonatomic, assign) long long balance;
@property (nonatomic, assign) long long balanceNanos;
@property (nonatomic, assign) NSInteger giftTotal;
@property (nonatomic, assign) NSUInteger reloadEpoch;
@property (nonatomic, strong) NSArray *sectionHeaderViews;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, assign) BOOL cataloguePushed;
@property (nonatomic, assign) BOOL starPacksPushed;
@property (nonatomic, weak) UINavigationController *explicitNavigationController;
@end

extern const NSInteger kStarsPageSize;
extern const NSInteger kStarsGiftPageSize;
extern const NSInteger kStarsGiftCollectionNameMaxLength;

UIView *TGStarsSectionHeaderWithTitle(NSString *title, CGFloat width);
CGFloat TGStarsCommentHeight(NSString *comment, CGFloat width);
UIView *TGStarsCommentViewWithText(NSString *comment, CGFloat width);
NSDictionary *TGStarsRow(NSString *title,
	NSString *subtitle,
	NSString *value,
	void (^block)(void));
NSDictionary *TGStarsBadgeRow(NSString *title,
	NSString *badgeText,
	NSString *detailText,
	void (^block)(void));

@interface TGStarsViewController (Private)

- (void)pushGiftsOfChat:(int64_t)chatId;

- (void)pushChannelGifts;

- (void)loadTransactionsInto:(TGStarsListViewController *)list
				   direction:(NSString *)direction
					  offset:(NSString *)offset;

- (void)pushTransactionsWithDirection:(NSString *)direction title:(NSString *)title;

- (void)pushUpgradePreviewForGiftId:(long long)giftId title:(NSString *)title;

- (void)pushResaleListingsForGiftId:(long long)giftId title:(NSString *)title;

- (void)confirmBuyResoldGiftNamed:(NSString *)name price:(long long)price;

- (void)loadResaleListingsInto:(TGStarsListViewController *)list
						giftId:(long long)giftId
						offset:(NSString *)offset;

- (void)sendCatalogueGift:(NSDictionary *)gift
				   toUser:(int64_t)userId
					 name:(NSString *)name;

- (void)continueSendCatalogueGift:(NSDictionary *)gift
						   toUser:(int64_t)userId
							 name:(NSString *)name;

- (void)sendCatalogueGift:(NSDictionary *)gift toChat:(int64_t)chatId;

- (void)continueSendCatalogueGift:(NSDictionary *)gift toChat:(int64_t)chatId;

- (NSArray *)pairsForCatalogueGift:(NSDictionary *)gift;

- (NSDictionary *)catalogueSendToContactActionForGift:(NSDictionary *)gift;

- (NSDictionary *)catalogueSendToChannelActionForGift:(NSDictionary *)gift;

- (NSDictionary *)catalogueUpgradePreviewActionForGiftId:(long long)giftId
												   title:(NSString *)title;

- (NSDictionary *)catalogueResaleActionForGiftId:(long long)giftId
										   title:(NSString *)title
										   count:(NSInteger)resaleCount;

- (void)pushCatalogueGift:(NSDictionary *)gift;

- (void)pushGiftCatalogue;

- (void)pushGiftsOfCollection:(int32_t)collectionId name:(NSString *)name all:(NSArray *)allCollections;

- (void)loadCollectionGiftsPage:(NSString *)offset
					   collectionId:(int32_t)collectionId
							 userId:(int64_t)userId
							   list:(TGStarsListViewController *)list
						 allGiftIds:(NSMutableArray *)allGiftIds;

- (void)showSheetForCollectionGift:(NSDictionary *)gift
					  collectionId:(int32_t)collectionId
						allGiftIds:(NSArray *)allGiftIds;

- (void)pushGiftPickerForCollection:(int32_t)collectionId;

- (NSDictionary *)collectionOpenActionForId:(int32_t)collectionId name:(NSString *)name all:(NSArray *)allCollections;

- (NSDictionary *)collectionAddGiftActionForId:(int32_t)collectionId;

- (NSDictionary *)collectionRenameActionForId:(int32_t)collectionId
								   controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)collectionMoveToTopActionForId:(int32_t)collectionId
											 all:(NSArray *)allCollections;

- (NSDictionary *)collectionDeleteActionForId:(int32_t)collectionId;

- (void)pushCollection:(NSDictionary *)collection all:(NSArray *)allCollections;

- (void)showCollectionLimitReachedAlert;

- (NSDictionary *)newCollectionRowForList:(TGStarsListViewController *)list count:(NSInteger)count;

- (void)fillCollectionsList:(TGStarsListViewController *)list;

- (void)pushGiftCollections;

- (void)pushCollectionPickerForGift:(NSString *)giftId;

- (void)configureGiftSettings:(TGStarsDetailViewController *)controller
					 settings:(NSDictionary *)settings;

- (void)pushGiftSettings;

- (NSArray *)pairsForPaymentForm:(NSDictionary *)form;

- (NSDictionary *)payWithStarsActionForForm:(NSDictionary *)form
									  price:(long long)price
								 controller:(TGStarsDetailViewController *)controller;

- (void)pushPaymentForm:(NSDictionary *)form;

- (void)pushPaymentForm:(NSDictionary *)form
		 intoNavigation:(UINavigationController *)nav;

- (NSDictionary *)payWithHostedPageActionForForm:(NSDictionary *)form
											 url:(NSString *)url
									  controller:(TGStarsDetailViewController *)controller;

+ (void)presentInvoiceForMessage:(int64_t)messageId
							chat:(int64_t)chatId
			  fromViewController:(UIViewController *)presenter;

+ (void)presentReceiptForMessage:(int64_t)messageId
							chat:(int64_t)chatId
			  fromViewController:(UIViewController *)presenter;

+ (void)presentPaidMediaUnlockForMessage:(int64_t)messageId
									chat:(int64_t)chatId
							   starCount:(long long)starCount
					  fromViewController:(UIViewController *)presenter;

- (NSArray *)pairsForReceipt:(NSDictionary *)receipt;

- (void)pushReceipt:(NSDictionary *)receipt intoNavigation:(UINavigationController *)nav;

- (void)editPaidMessagePrice;

- (void)allowFreeMessagesFromUser:(int64_t)userId
							 name:(NSString *)name
							stars:(long long)stars
						   refund:(BOOL)refund;

- (void)pushPaidMessageDetailForUser:(int64_t)userId name:(NSString *)name;

- (void)pushPaidMessages;

- (void)pushAffiliatePrograms;

- (void)reloadAffiliateProgramsInto:(TGStarsListViewController *)list;

- (NSString *)affiliateBotName:(int64_t)botUserId;

- (NSString *)affiliateDurationText:(NSDictionary *)program;

- (NSDictionary *)connectedAffiliateRow:(NSDictionary *)program;

- (NSDictionary *)suggestedAffiliateRow:(NSDictionary *)found;

- (void)pushConnectedAffiliateDetail:(NSDictionary *)program;

- (void)disconnectAffiliate:(NSString *)url controller:(TGStarsDetailViewController *)controller;

- (void)pushSuggestedAffiliateDetail:(NSDictionary *)found;

- (void)connectAffiliateProgram:(int64_t)botUserId controller:(TGStarsDetailViewController *)controller;

- (void)clearSavedPaymentInfo;

- (UIView *)sheetHostView;

- (void)showMessage:(NSString *)message;

- (void)finishSimpleAction:(BOOL)success failure:(NSString *)failureMessage;

- (void)proceedIfEnoughStarsForPrice:(long long)price then:(void (^)(void))block;

- (void)promptWithTitle:(NSString *)title
				message:(NSString *)message
			placeholder:(NSString *)placeholder
				numeric:(BOOL)numeric
			  maxLength:(NSInteger)maxLength
			actionTitle:(NSString *)actionTitle
				handler:(void (^)(NSString *text))handler;

- (void)promptForPasswordWithTitle:(NSString *)title
						   message:(NSString *)message
					   actionTitle:(NSString *)actionTitle
						   handler:(void (^)(NSString *password))handler;

- (NSString *)nameFromUser:(NSDictionary *)user;

- (void)pickUserWithTitle:(NSString *)title
				  handler:(void (^)(int64_t userId, NSString *name))handler;

- (void)pickChatWithHandler:(void (^)(int64_t chatId))handler;

- (NSString *)priceTextForOption:(NSDictionary *)option;

- (void)fillList:(TGStarsListViewController *)list withOptions:(NSArray *)options;

- (void)pushStarPacksForUser:(int64_t)userId name:(NSString *)name;

- (void)pushStarPacks;

- (NSArray *)pairsForTransaction:(NSDictionary *)transaction;

- (void)pushTransactionDetails:(NSDictionary *)transaction;

- (void)finishAction:(TGStarsDetailViewController *)controller
			 success:(BOOL)success
			 failure:(NSString *)failureMessage;

- (void)confirmWithTitle:(NSString *)title
				 message:(NSString *)message
				  action:(NSString *)actionTitle
				   block:(void (^)(void))block;

- (void)promptGiftMessageAndPrivacyWithCompletion:(void (^)(NSString *text, BOOL isPrivate))completion;
- (void)promptGiftPrivacyForText:(NSString *)text
					  completion:(void (^)(NSString *text, BOOL isPrivate))completion;

- (NSDictionary *)giftVisibilityActionForGift:(NSDictionary *)gift
									   giftId:(NSString *)giftId
								   controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)giftPinActionForGift:(NSDictionary *)gift
								giftId:(NSString *)giftId
							controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)giftCollectionActionForGiftId:(NSString *)giftId;

- (NSDictionary *)giftTransferActionForGiftId:(NSString *)giftId
										price:(long long)transferPrice
										 name:(NSString *)giftLabel
							  nextTransferDate:(long long)nextTransferDate
								   controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)giftConvertActionForGiftId:(NSString *)giftId
									   price:(long long)sell
										name:(NSString *)name
								  controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)giftUpgradeActionForGiftId:(NSString *)giftId
									   price:(long long)upgrade
							prepaidStarCount:(long long)prepaidStarCount
								  controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)giftResalePriceActionForGiftId:(NSString *)giftId
										   price:(long long)resale
									  controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)giftRemoveFromSaleActionForGiftId:(NSString *)giftId
										 controller:(TGStarsDetailViewController *)controller;

- (NSArray *)giftActionsFor:(NSDictionary *)gift
				 controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)giftUseColoursActionForId:(long long)coloursId
								 controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)giftWithdrawActionForGiftId:(NSString *)giftId
								   controller:(TGStarsDetailViewController *)controller;

- (void)askResalePriceForGift:(NSString *)giftId
				   controller:(TGStarsDetailViewController *)controller;

- (NSArray *)pairsForSubscription:(NSDictionary *)subscription;

- (NSDictionary *)subscriptionRejoinActionForId:(NSString *)subscriptionId
									 controller:(TGStarsDetailViewController *)controller;

- (NSDictionary *)subscriptionToggleActionForId:(NSString *)subscriptionId
									   canceled:(BOOL)canceled
									 controller:(TGStarsDetailViewController *)controller;

- (void)pushSubscriptionDetails:(NSDictionary *)subscription;

- (void)configureGiftDetail:(TGStarsDetailViewController *)controller
				   withGift:(NSDictionary *)gift;

- (NSArray *)pinnedGiftIdsTogglingGift:(NSString *)giftId
								 pinned:(BOOL)pinned
					   currentPinnedIds:(NSArray<NSString *> *)currentPinnedIds;

- (void)refreshGiftDetail:(TGStarsDetailViewController *)controller
				   giftId:(NSString *)giftId
				 fallback:(NSDictionary *)fallback;

- (void)pushGiftDetails:(NSDictionary *)gift;

- (void)handleTransactionsTapAtRow:(NSInteger)row;

- (void)handleGiftsTapAtRow:(NSInteger)row;

- (void)handleGiftToolsTapAtRow:(NSInteger)row;

- (void)handleMoreTapAtRow:(NSInteger)row;

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

- (id)init;

- (void)viewDidLoad;

- (void)viewWillAppear:(BOOL)animated;

- (void)viewDidAppear:(BOOL)animated;

- (void)generateSectionHeaders;

- (void)reloadTapped;

- (void)loadFirstPages;

- (void)loadSubscriptions;

- (void)loadMoreTransactions;

- (void)loadMoreGifts;

- (BOOL)hasMoreTransactions;

- (BOOL)hasMoreGifts;

- (NSString *)formattedNumber:(NSNumber *)value;

- (NSString *)starsText:(long long)stars signed:(BOOL)withSign;

- (NSString *)starsText:(long long)stars nanos:(long long)nanos signed:(BOOL)withSign;

- (NSString *)dateTextFromValue:(NSNumber *)value;

- (NSString *)counterpartyForTransaction:(NSDictionary *)transaction;

- (BOOL)transactionIsRefund:(NSDictionary *)transaction;

- (NSString *)subtitleForTransaction:(NSDictionary *)transaction;

- (NSString *)senderNameForGift:(NSDictionary *)gift;

- (NSString *)initialsForName:(NSString *)name;

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;

- (NSString *)commentForSection:(NSInteger)section;

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;

- (UITableViewCell *)plainCellInTable:(UITableView *)tableView
								style:(UITableViewCellStyle)style
							  reuseId:(NSString *)reuseId;

- (UITableViewCell *)balanceCellInTable:(UITableView *)tableView;

- (UITableViewCell *)statusCellInTable:(UITableView *)tableView text:(NSString *)text;

- (UITableViewCell *)moreCellInTable:(UITableView *)tableView loading:(BOOL)loading;

- (UILabel *)amountLabelWithStars:(long long)stars;

- (UILabel *)amountLabelWithStars:(long long)stars nanos:(long long)nanos;

- (UILabel *)valueLabelWithText:(NSString *)text;

- (UITableViewCell *)transactionCellInTable:(UITableView *)tableView
										row:(NSInteger)row;

- (UITableViewCell *)giftCellInTable:(UITableView *)tableView row:(NSInteger)row;

- (NSString *)periodTextForSeconds:(long long)seconds;

- (NSString *)titleForSubscription:(NSDictionary *)subscription;

- (NSString *)subtitleForSubscription:(NSDictionary *)subscription;

- (UITableViewCell *)subscriptionCellInTable:(UITableView *)tableView row:(NSInteger)row;

- (NSString *)menuTitleAtIndexPath:(NSIndexPath *)indexPath;

- (UITableViewCell *)menuCellInTable:(UITableView *)tableView
						 atIndexPath:(NSIndexPath *)indexPath;

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath;

@end
