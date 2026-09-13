#import <UIKit/UIKit.h>

@interface TGChatViewController : UIViewController <UITextFieldDelegate,
									  UIImagePickerControllerDelegate, UINavigationControllerDelegate,
									  UIActionSheetDelegate>

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, assign) BOOL group;

@property (nonatomic, assign) int64_t threadId;
@property (nonatomic, assign) int64_t savedTopicId;
@property (nonatomic, assign) int64_t savedTopicOriginChatId;
@property (nonatomic, assign) int64_t directMessagesTopicId;
@property (nonatomic, assign) int64_t focusMessageId;
@property (nonatomic, assign) int64_t paidMessageStarCount;
@end

@interface TGChatViewController (Public)

- (BOOL)scrollToMessageId:(int64_t)messageId;

- (void)simulateTapOnRow:(NSInteger)row;
- (void)simulateTapOnDayPlate;

- (void)showPinnedBannerMenu;

- (void)simulateComposerText:(NSString *)text;

@end
