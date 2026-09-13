#import <UIKit/UIKit.h>
#import "TGLoginCoordinator.h"
#import "TGPerfLogging.h"

void TGMarkLaunchStage(NSString *stage);
void TGMarkOpenStage(NSString *stage);
void TGBeginOpenTiming(void);
void TGBeginOpenTimingFromTap(void);
void TGMarkFirstFrame(NSString *stage);
void TGRedirectLogToFile(void);
void TGNoteImageReady(NSTimeInterval when);
void TGMarkOpenFrame(NSString *stage);
void TGMarkOpenSettledFrame(NSString *stage);

unsigned long long TGResidentBytes(void);
void TGMemMark(NSString *tag);

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, strong) TGLoginCoordinator *loginCoordinator;

@property (nonatomic, strong) NSOperationQueue *syncData;

@property (nonatomic, strong) NSString *smallPhotoCache;
@property (nonatomic, strong) NSString *peerPhotoCache;
@property (nonatomic, strong) NSString *imagesCache;
@property (nonatomic, strong) NSString *filesCache;
@property (nonatomic, strong) NSString *thumbDocCache;

@property (nonatomic, copy) NSString *currentPhoneNumber;
@property (nonatomic, copy) NSString *pendingBotStartLink;
@property (nonatomic, strong) NSDate *lastHarnessCommandDate;
@property (nonatomic, copy) NSString *pendingLanguagePackId;
@property (nonatomic, copy) NSString *pendingInviteLink;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, assign) BOOL showNotifications;
@property (nonatomic, assign) BOOL deferredUIBuild;
@property (nonatomic, assign) FILE *log;

- (void)showMessage:(NSString *)msg;
- (void)showMainUI;
- (void)showLoginUI;
- (void)openChatFromNotification:(int64_t)chatId;
- (void)openChatFromNotification:(int64_t)chatId focusMessageId:(int64_t)messageId;

@end
