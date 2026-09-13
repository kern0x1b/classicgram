#import <UIKit/UIKit.h>
#import "TGEmoji.h"

@interface TGChatCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) TGEmojiLabel *titleLabel;
@property (nonatomic, strong) TGEmojiLabel *previewLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *draftLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *badgeBackground;
@property (nonatomic, strong) UILabel *badge;
@property (nonatomic, strong) UIView *onlineDot;
@property (nonatomic, strong) UIImageView *tick;
@property (nonatomic, strong) UIImageView *pin;
@property (nonatomic, strong) UIImageView *mentionBadge;
@property (nonatomic, strong) UIImageView *reactionBadge;
@property (nonatomic, strong) UIImageView *arrow;
@property (nonatomic, strong) UIImageView *muteIcon;
@property (nonatomic, strong) UIImageView *pendingIndicator;
@property (nonatomic, strong) UIImageView *errorBadge;
@property (nonatomic, strong) UIImageView *groupIcon;
@property (nonatomic, strong) UILabel *folderTag;

@property (nonatomic, assign) long long chatId;

@property (nonatomic, strong) NSArray *swipeActions;
@property (nonatomic, copy) void (^onSwipeOpen)(void);
@property (nonatomic, copy) void (^onSwipeAction)(NSString *kind);
@property (nonatomic, readonly) BOOL swipeActionsVisible;

- (void)setSwipeActionsVisible:(BOOL)visible animated:(BOOL)animated;
- (void)setDateText:(NSString *)text suffix:(NSString *)suffix bold:(BOOL)bold;
- (void)applyTextSize;
@end
