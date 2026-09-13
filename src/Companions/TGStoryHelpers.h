#import <UIKit/UIKit.h>

extern const CGFloat kStoryStripHeight;
extern const CGFloat kStoryStripInset;
extern const CGFloat kStoryStripGap;
extern const CGFloat kStoryStatusBarHeight;
extern const CGFloat kStoryPanelHeight;
extern const CGFloat kStoryPanelButtonSize;
extern const CGFloat kStoryPanelButtonInset;
extern const CGFloat kStoryPanelButtonTop;
extern const CGFloat kStoryPlateHeight;
extern const CGFloat kStoryPlateTop;
extern const CGFloat kStoryPlateLeft;
extern const CGFloat kStoryFooterHeight;
extern const CGFloat kStoryFooterInset;
extern const CGFloat kStoryFooterBottom;
extern const CGFloat kStoryCaptionHeight;
extern const NSInteger kStoryPhotoPixels;
extern const CGFloat kStoryPageGap;
extern const CGFloat kStoryOverscroll;
extern const CGFloat kStoryDismissDistance;
extern const CGFloat kStoryDismissVelocity;
extern const NSTimeInterval kStoryDuration;
extern const NSTimeInterval kStoryTick;
extern const NSUInteger kStoryPageQueueLimit;

UIImage *TGStoryStretch(NSString *name, NSInteger leftCap);
NSString *TGStoryAgeText(int date);
NSString *TGStoryString(NSDictionary *story, NSString *key);
NSInteger TGStoryNumber(NSDictionary *story, NSString *key);
int64_t TGStoryChatId(NSDictionary *story, NSString *key);
BOOL TGStoryFlag(NSDictionary *story, NSString *key);
NSDictionary *TGStoryPosterEntry(int64_t chatId, NSString *title, NSDictionary *active);
