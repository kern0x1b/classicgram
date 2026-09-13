#import "AppDelegate.h"
#import "TGAuthState.h"

extern const NSInteger kAppLanguagePackAlertTag;
extern const NSInteger kAppJoinLinkAlertTag;

extern volatile BOOL TGStackSamplingOn;
extern void TGStartMemorySampler(void);
extern void TGMemZoneReport(NSString *tag);
extern void TGRegionReport(NSString *tag);
extern void TGEmojiPurgeImages(void);

@protocol TGTabBarHitTesting <NSObject>
- (int)indexForLocation:(CGPoint)location;
- (int)tabForSlot:(int)slot;
@end

@interface AppDelegate (Private)

- (void)handleBotStartLinkURL:(NSURL *)url;
- (void)startPendingAppBotLink:(NSString *)link;
- (void)handleChatFolderInviteLinkURL:(NSURL *)url;
- (BOOL)handleAppURL:(NSURL *)url;
- (BOOL)handleDebugHarnessURL:(NSURL *)url;
- (void)installHarnessCommandWatcher;
- (BOOL)handleTelegramLinkURL:(NSURL *)url host:(NSString *)host;
- (void)resolveAndHandleTelegramLinkURL:(NSURL *)url;
- (void)openPublicChatLinkWithInfo:(NSDictionary *)info;
- (void)openMessageLinkURL:(NSString *)link;
- (void)openChatInviteLinkURL:(NSString *)link;
- (void)joinChatByInviteLinkURL:(NSString *)link;
- (void)openUserTokenLinkURL:(NSString *)token;
- (void)resolveAndHandleStickerSetLinkURL:(NSURL *)url;
- (void)openStickerSetLinkWithName:(NSString *)name;
- (void)resolveAndHandleProxyLinkURL:(NSURL *)url;
- (void)resolveAndHandleLanguagePackLinkURL:(NSURL *)url;
- (void)handleLanguagePackAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex;
- (void)handleJoinLinkAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex;
- (void)showLinkCouldNotBeOpenedToast;
- (UIViewController *)topControllerOnScreen;
- (UIViewController *)presentedControllerOnScreen;
- (UITabBarController *)tabControllerForHarness;
- (UITableView *)firstTableViewIn:(UIView *)root;
- (UIScrollView *)deepestScrollViewIn:(UIView *)root;
- (UIView *)firstResponderUnder:(UIView *)view;
- (UISearchBar *)searchBarUnder:(UIView *)view;
- (void)fireGestureRecognizer:(UIGestureRecognizer *)recognizer;
- (UINavigationController *)navigationControllerForPush;
- (void)openChatFromNotification:(int64_t)chatId
					focusMessageId:(int64_t)messageId
						  threadId:(int64_t)threadId;
- (void)applyAuthState:(TGAuthState)state;
- (void)adoptSystemLanguagePackIfNeeded;

@end
