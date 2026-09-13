#import "TGReactionPickerView.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGSnackbar.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGImageDecode.h"
#import "TGActionSheet.h"
#import "UIImage+WebP.h"
#import <QuartzCore/QuartzCore.h>
#import "TGReactionStripButton.h"

extern const CGFloat kStripHeight;
extern const CGFloat kStripButtonWidth;
extern const CGFloat kStripVisibleButtons;
extern const CGFloat kStripEmojiFontSize;
extern const NSTimeInterval kStripReopenSuppression;
extern const CGFloat kChipHeight;
extern const CGFloat kChipRadius;
extern const CGFloat kChipPadding;
extern const CGFloat kChipGap;
extern const CGFloat kChipRowGap;
extern const CGFloat kChipEmojiFontSize;
extern const CGFloat kChipCountFontSize;
extern const CGFloat kChipCountGap;
extern const CGFloat kChipGlyphSlot;
extern const CGFloat kChipGlyphSide;
extern const CGFloat kChipMinRowWidth;
extern const CGFloat kReactionIconSide;
extern NSString *const kPaidStarGlyph;
extern const NSInteger kPaidUndoSeconds;
extern const CGFloat kListRowHeight;
extern const CGFloat kListAvatarSide;
extern const CGFloat kListBarHeight;
extern const CGFloat kListGroupHeight;
extern const CGFloat kListGroupInset;
extern const CGFloat kListSeparatorWidth;
extern const NSInteger kListPageSize;
UIImage *TGReactionScaledIcon(UIImage *image, CGFloat side);
void TGReactionIconForEmoji(NSString *emoji, CGFloat side, void (^completion)(UIImage *icon));
void TGReactionIconForCustomEmoji(NSString *customEmojiId, CGFloat side, void (^completion)(UIImage *icon));
UIViewController *TGReactionOwningController(UIView *view);
UIImage *TGReactionStretch(NSString *name, int cap);

extern TGReactionPickerView *sOpenPicker;
extern NSTimeInterval sLastHideTime;
extern NSMutableDictionary *sReactionIcons;

@interface TGReactionPickerView () {
	UIView *_card;
	UIScrollView *_scrollView;
	UIImageView *_arrowTopView;
	UIImageView *_arrowBottomView;
	UIImageView *_topLineView;
	UIImageView *_bottomLineView;
	UIImageView *_topLineRightView;
	UIImageView *_bottomLineRightView;
	UIActivityIndicatorView *_spinner;
	UILabel *_noticeLabel;
	NSMutableArray *_buttons;
	NSMutableArray *_separators;
	CGRect _anchorRect;
	CGFloat _arrowLocation;
	BOOL _arrowOnTop;
	BOOL _dismissed;
	BOOL _loading;
	CGSize _hostSize;
	NSSet *_chosenEmoji;
	NSSet *_needsPremiumEmoji;
	NSArray *_existingReactionTypes;
	BOOL _canAddMore;
	BOOL _paidAllowed;
	BOOL _paidAnonymous;
	BOOL _paidPending;
	BOOL _paidSheetPresented;
	long long _starBalance;
	NSArray *_pendingEmoji;
	NSArray *_pendingChosen;
	NSArray *_pendingExistingReactionTypes;
	BOOL _pendingCanAddMore;
	id _backgroundDismissObserverToken;
	id _orientationDismissObserverToken;
}

@end

@interface TGReactionPickerView (Private)

+ (void)dismiss;

+ (instancetype)showForMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					  fromRect:(CGRect)rect
						inView:(UIView *)host
						picked:(TGReactionPickedBlock)picked;

- (id)initWithFrame:(CGRect)frame;

- (void)dealloc;

- (void)loadReactions;

- (void)applyChatRestrictionsTo:(NSArray *)emoji;

- (void)applyUsageTo:(NSArray *)emoji maxCount:(NSInteger)maxCount;

- (void)preparePaidWithEmoji:(NSArray *)emoji
					   chosen:(NSArray *)chosen
		existingReactionTypes:(NSArray *)existingReactionTypes
				   canAddMore:(BOOL)room;

- (void)paidLookupTimedOut;

- (void)finishPaidLookupAllowed:(BOOL)allowed balance:(long long)balance;

- (CGFloat)clampedWidth:(CGFloat)width;

- (void)addPlateOfWidth:(CGFloat)width;

- (void)showSpinner;

- (void)setEmoji:(NSArray *)emoji reason:(NSString *)reason;

- (void)setEmoji:(NSArray *)emoji
		  reason:(NSString *)reason
		  chosen:(NSArray *)chosen
	  canAddMore:(BOOL)canAddMore
existingReactionTypes:(NSArray *)existingReactionTypes;

- (void)buildNoticeWithText:(NSString *)text;

- (void)buildPlainCardOfWidth:(CGFloat)width;

- (void)clearContent;

- (void)positionCard;

- (void)layoutCard;

- (void)layoutSubviews;

- (void)emojiTapped:(TGReactionStripButton *)button;

- (void)longPressedReactionButton:(UILongPressGestureRecognizer *)recognizer;

- (void)showPaidSheet;

- (void)handlePaidAction:(NSString *)action;

- (void)sendPaidStars:(long long)stars;

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;

- (void)externalDismiss;

- (void)teardownAnimated:(BOOL)animated;

- (void)present;

@end
