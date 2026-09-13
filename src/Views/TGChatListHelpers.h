#import <UIKit/UIKit.h>

extern const CGFloat kRowHeight;
extern const CGFloat kAvatar;
extern const CGFloat kAvatarRadius;
extern const CGFloat kAvatarLeft;
extern const CGFloat kTextLeft;

extern const CGFloat kSwipeButtonHeight;
extern const CGFloat kSwipeButtonMinWidth;
extern const CGFloat kSwipeEdgeDistance;
extern const CGFloat kSwipeButtonTop;
extern const CGFloat kSwipeButtonGap;

extern const CGFloat kPinBadgeWidth;
extern const CGFloat kPinBadgeHeight;

extern const CGFloat kStoryTrayHeight;
extern const CGFloat kStoryCellWidth;
extern const CGFloat kStoryAvatar;
extern const CGFloat kSearchBarHeight;
extern const CGFloat kFolderStripHeight;
extern const CGFloat kFolderChipHeight;
extern const CGFloat kFolderChipPadding;
extern const CGFloat kFolderChipGap;
extern const CGFloat kLoginBannerHeight;
extern const CGFloat kFolderBannerHeight;
extern const CGFloat kBirthdayBannerHeight;
extern const NSUInteger kRowDetailCacheLimit;
extern const NSInteger kAvatarPrefetchRows;
extern const NSInteger kAvatarRetainRows;
extern const CGFloat kArchivePullThreshold;

UIColor *TGChatListTitleColour(void);
UIColor *TGChatListMessageColour(void);
UIColor *TGChatListActionColour(void);
UIColor *TGChatListAuthorColour(void);

NSDictionary *TGReplyDictionary(id value);
NSArray *TGReplyArray(id value);
NSString *TGReplyString(id value);
NSArray *TGChatRows(id value);

UIImage *TGDialogListBadgeImage(BOOL highlighted);
UIImage *TGDialogListPinBadgeImage(BOOL highlighted);
UIImage *TGDialogListMentionBadgeImage(BOOL highlighted);
UIImage *TGDialogListReactionBadgeImage(BOOL highlighted);
UIImage *TGSwipePlateImage(BOOL destructive, BOOL highlighted);

UIImage *TGScopeBarBackgroundImage(void);
UIImage *TGTitleCaretImage(void);
UIImage *TGStoryScaledImage(UIImage *source, CGSize bounds);
