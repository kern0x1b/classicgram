#import <UIKit/UIKit.h>

extern NSString *const TGMessageActionReact;
extern NSString *const TGMessageActionReply;
extern NSString *const TGMessageActionQuote;
extern NSString *const TGMessageActionEdit;
extern NSString *const TGMessageActionCopy;
extern NSString *const TGMessageActionSelectText;
extern NSString *const TGMessageActionCopyLink;
extern NSString *const TGMessageActionForward;
extern NSString *const TGMessageActionSaveImage;
extern NSString *const TGMessageActionSaveVideo;
extern NSString *const TGMessageActionSaveGif;
extern NSString *const TGMessageActionPin;
extern NSString *const TGMessageActionUnpin;
extern NSString *const TGMessageActionTranslate;
extern NSString *const TGMessageActionSummarize;
extern NSString *const TGMessageActionTranscribe;
extern NSString *const TGMessageActionSelect;
extern NSString *const TGMessageActionDeleteForMe;
extern NSString *const TGMessageActionDeleteForEveryone;
extern NSString *const TGMessageActionReport;
extern NSString *const TGMessageActionSeenBy;
extern NSString *const TGMessageActionViewAuthor;
extern NSString *const TGMessageActionFactCheck;
extern NSString *const TGMessageActionApprovePost;
extern NSString *const TGMessageActionDeclinePost;
extern NSString *const TGMessageActionSuggestPost;
extern NSString *const TGMessageActionSuggestPostEditMessage;
extern NSString *const TGMessageActionSetNotificationSound;

@interface TGMessageActionsSheet : NSObject

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;

@property (nonatomic, copy) NSString *messageText;

@property (nonatomic, assign) BOOL canQuoteText;

@property (nonatomic, copy) NSString *mediaKind;

@property (nonatomic, assign) BOOL pinned;

@property (nonatomic, assign) BOOL allowsSelection;

@property (nonatomic, assign) BOOL canTranscribe;

@property (nonatomic, assign) BOOL transcriptShown;

@property (nonatomic, assign) BOOL summaryShown;

@property (nonatomic, assign) BOOL translationShown;

@property (nonatomic, copy) NSString *factCheckText;

@property (nonatomic, assign, readonly) BOOL canGetViewers;

@property (nonatomic, assign, readonly) BOOL canGetReadDate;

+ (instancetype)sheetForMessage:(int64_t)messageId inChat:(int64_t)chatId;

- (void)presentAtPoint:(CGPoint)point
				inView:(UIView *)host
			completion:(void (^)(NSString *action))completion;

- (void)dismiss;

@end
