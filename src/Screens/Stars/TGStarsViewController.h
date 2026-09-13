#import <UIKit/UIKit.h>

@interface TGStarsViewController : UITableViewController

@property (nonatomic, assign) BOOL opensGiftCatalogue;
@property (nonatomic, assign) BOOL opensStarPacks;
@property (nonatomic, assign) int64_t giftPresetUserId;
@property (nonatomic, assign) int64_t giftPresetChatId;
@property (nonatomic, copy) NSString *giftPresetName;
@end

@interface TGStarsViewController (StarPacks)

+ (void)presentNotEnoughStarsAlertFromViewController:(UIViewController *)presenter;

@end

@interface TGStarsViewController (Invoices)

+ (void)presentInvoiceForMessage:(int64_t)messageId
							chat:(int64_t)chatId
			  fromViewController:(UIViewController *)presenter;
+ (void)presentInvoiceNamed:(NSString *)name
		 fromViewController:(UIViewController *)presenter;
+ (void)presentReceiptForMessage:(int64_t)messageId
							chat:(int64_t)chatId
			  fromViewController:(UIViewController *)presenter;
+ (void)presentPaidMediaUnlockForMessage:(int64_t)messageId
									chat:(int64_t)chatId
							   starCount:(long long)starCount
					  fromViewController:(UIViewController *)presenter;
+ (void)resetPaidMediaUnlocksForAccountSwitch;

@end
