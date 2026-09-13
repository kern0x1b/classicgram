#import "TGMessageRowCell.h"
#import "TGEmoji.h"
#import "TGReplySwipeRecognizer.h"

@class TGQuoteBadgeView;
@class TGLinkPreviewView;
@class TGReactionChipsView;

@interface TGBubbleCellBase : TGMessageRowCell <TGReplySwipeCell>

@property (nonatomic, strong, readonly) UIView *bubble;
@property (nonatomic, strong, readonly) UIImageView *bubbleArtwork;
@property (nonatomic, strong, readonly) UIImageView *tail;
@property (nonatomic, strong, readonly) TGEmojiLabel *sender;
@property (nonatomic, strong, readonly) UIImageView *senderAvatar;
@property (nonatomic, strong, readonly) UIImageView *plate;
@property (nonatomic, strong, readonly) UILabel *plateTime;
@property (nonatomic, strong, readonly) UILabel *plateViews;
@property (nonatomic, strong, readonly) UIImageView *plateEye;
@property (nonatomic, strong, readonly) UIImageView *plateTicks;
@property (nonatomic, strong) UIView *replyArrow;
@property (nonatomic, strong) UIView *replyArrowPlate;
@property (nonatomic, strong, readonly) TGReplySwipeRecognizer *replySwipe;

@property (nonatomic, assign) int64_t avatarUserId;
@property (nonatomic, assign) int64_t avatarChatId;
@property (nonatomic, assign) int64_t forwardChatId;
@property (nonatomic, assign) int64_t forwardMessageId;
@property (nonatomic, assign) int64_t forwardUserId;

- (TGQuoteBadgeView *)quoteBadge;
- (TGEmojiLabel *)forwardLabel;
- (UIButton *)forwardJumpButton;
- (TGLinkPreviewView *)linkPreview;
- (UILabel *)signatureLabel;
- (TGReactionChipsView *)reactionChips;

- (NSString *)tg_accessibilityLabelWithParts:(NSArray<NSString *> *)parts;

@end
