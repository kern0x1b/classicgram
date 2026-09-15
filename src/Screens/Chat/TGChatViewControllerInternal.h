#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import <CoreLocation/CoreLocation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>
#import <AVFoundation/AVFoundation.h>
#import "TGChatViewController.h"
#import "TGVoiceRecorder.h"
#import "TGMusicPlayer.h"
#import "TGAudioMetadata.h"
#import "TGChatComposerState.h"
#import "TGFileStatusView.h"
#import "TGRichText.h"
#import "TGChatLayoutBridge.h"
#import "TGChatPresenter.h"
#import "TGMosaicTileView.h"
#import "TGChatInputTextView.h"
#import "TGReplySwipeRecognizer.h"

extern const NSTimeInterval kDeferredActionDelay;
extern const NSTimeInterval kTranscriptFallbackDelay;
extern const CGFloat kInputHeight;
extern const CGFloat kPadH;
extern const CGFloat kPadV;
extern const CGFloat kBubbleTailOverhang;
extern const CGFloat kBubbleMinW;
extern const CGFloat kBubbleMinH;
extern const CGFloat kForwardJumpSide;
extern const CGFloat kForwardJumpGap;
extern const CGFloat kSignatureHeight;
extern const CGFloat kSignatureTopGap;
extern const CGFloat kMapCardW;
extern const CGFloat kMapCardH;
extern const CGFloat kChipsBareTopPad;
extern const CGFloat kChipsBubbleTopPad;
extern const CGFloat kChipsBareBottomPad;
extern const CGFloat kChipsBubbleBottomPad;
extern const CGFloat kBubbleMaxW;
extern const CGFloat kBubbleReferenceWidth;
extern const CGFloat kBubbleBudgetAtReference;
extern const CGFloat kBubbleOutgoingTrim;
extern const CGFloat kBubbleAvatarTrim;
extern const NSUInteger kLargeEmojiTextLimit;
extern const CGFloat kViewsEyeHeight;
extern const CGFloat kStampLineHeight;
extern const CGFloat kBubbleTailCap;
extern const NSInteger kUnreadContextRows;
extern const NSInteger kRestoreContextRows;
extern const NSInteger kUnreadSlack;
extern const CGFloat kFloatingButtonGap;
extern const NSInteger kRichMessageCardTag;
extern const CGFloat kPollRow;
extern const CGFloat kChecklistRow;
extern const CGFloat kAudioPairHeight;
extern const CGFloat kAudioClockGap;
extern const CGFloat kAudioCoverDisc;
extern const CGFloat kFileCellPairHeight;
extern const CGFloat kVoiceDiscSide;
typedef struct {
	CGFloat leadPad;
	CGFloat trailPad;
	CGFloat eyeWidth;
	CGFloat eyeGap;
	CGFloat countWidth;
	CGFloat countGap;
	CGFloat timeWidth;
	CGFloat tickGap;
	CGFloat tickWidth;
	CGFloat width;
	CGFloat eyeOffset;
	CGFloat countOffset;
	CGFloat timeOffset;
	CGFloat tickOffset;
	BOOL showsViews;
	BOOL showsTicks;
} TGStampPlate;
UIImage *TGViewsEyeImage(UIColor *tint);
TGStampPlate TGStampPlateLayout(NSString *countText,
	NSString *timeText,
	UIFont *font,
	CGFloat tickWidth,
	CGFloat leadPad,
	CGFloat trailPad);
UIColor *TGMessageBodyColour(void);
UIColor *TGSenderColour(int64_t userId);
extern const CGFloat kFloatingButtonSide;
BOOL TGTextIsRightToLeft(NSString *text);
NSString *TGFoldLineBreaks(NSString *text);
UIColor *TGMessageLinkColour(void);
NSString *TGFormatByteCount(long long bytes);

@interface NSObject (TGReadingList)
+ (id)defaultReadingList;
- (BOOL)addReadingListItemWithURL:(NSURL *)url
							title:(NSString *)title
					  previewText:(NSString *)previewText
							error:(NSError **)error;
@end

@class TGStickerSuggestionStrip;
@class TGMentionSuggestionStrip;
@class TGVideoCaptureViewController;
@class TGMessageActionsSheet;
@class TGTextSelectionOverlay;
@class TGMessageRowCell;
@class TGInlineQueryResultStrip;
@class TGEmojiLabel;

extern const CGFloat kSystemPlateHeight;
extern const CGFloat kDayRowHeight;
extern const CGFloat kUnreadRowHeight;
extern const CGFloat kRetinaPixel;
extern const CGFloat kImageMax;
extern const NSUInteger kPictureMemoryBudget;
extern const NSUInteger kMaxLivePictures;

CGFloat TGMessageBaseFontSize(void);
UIColor *TGSystemPlateColour(void);
UIImage *TGUnreadDividerImage(void);
UIImage *TGUnreadArrowImage(void);

extern const NSInteger kVideoNoteOverlayTag;
extern const NSInteger kRoundNoteRimTag;
extern const NSInteger kRoundNoteBadgeTag;
extern const NSInteger kRoundNoteMuteTag;

extern const CGFloat kRoundNoteRimInset;
extern const CGFloat kRoundNoteRingWidth;
extern const CGFloat kRoundNoteBadgeSide;

CGFloat TGRoundNoteRimWidth(void);
UIColor *TGRoundNoteRimColour(void);
UIImage *TGRoundNoteMuteBadge(void);

UIColor *TGMessageBodyColour(void);
extern const NSInteger kAttachSheetTag;
extern const NSInteger kForwardSheetTag;
extern const NSInteger kReportSheetTag;
extern const NSInteger kSelectionDeleteSheetTag;
extern const NSInteger kLinkSheetTag;
extern const NSInteger kReportTextAlertTag;
extern const NSInteger kPastePhotoAlertTag;
extern const NSInteger kJoinLinkAlertTag;
extern const NSInteger kModerationSheetTag;
extern const NSInteger kModerationConfirmSheetTag;
extern const NSInteger kAttachMoreSheetTag;
extern const NSInteger kLocationSheetTag;
extern const NSInteger kTextToolsSheetTag;
extern const NSInteger kPinnedSheetTag;
extern const NSInteger kSelectionMoreSheetTag;
extern const NSInteger kVenueTitleAlertTag;
extern const NSInteger kVenueAddressAlertTag;
extern const NSInteger kChecklistAddAlertTag;
extern const NSInteger kAddLanguagePackAlertTag;
extern const NSInteger kPollAddOptionAlertTag;
extern const NSInteger kAiSuggestionAlertTag;
extern const NSInteger kAiRewriteStyleSheetTag;
extern const NSInteger kAlbumSelectionLimit;
extern const NSInteger kAlbumBatchLimit;
extern const NSInteger kBotMenuSheetTag;
extern const NSInteger kBotButtonsSheetTag;
extern const NSInteger kBotPasswordAlertTag;
extern const NSInteger kBotStartAlertTag;
extern const NSInteger kAllowBotAlertTag;
extern const NSInteger kTextLinksSheetTag;
extern const NSInteger kPeerMenuSheetTag;
extern const NSInteger kHeldLinkSheetTag;
extern const NSInteger kFailedMessageSheetTag;
extern const NSInteger kPinOptionsSheetTag;
extern const NSInteger kActionBarBlockSheetTag;
extern const NSInteger kActionBarReportAlertTag;
extern const NSInteger kActionBarSharePhoneAlertTag;
extern const NSInteger kEffectPickerSheetTag;
extern const NSInteger kFactCheckAlertTag;
extern const NSInteger kSendAsSheetTag;
extern const NSInteger kApprovePostAlertTag;
extern const NSInteger kDeclinePostAlertTag;
extern const NSInteger kSuggestPostPriceAlertTag;
extern const NSInteger kSuggestPostTimingSheetTag;
extern const NSInteger kChecklistEditAlertTag;
extern const NSInteger kChecklistDeleteTaskSheetTag;
extern const NSInteger kChecklistTaskMenuSheetTag;
extern const NSInteger kBankCardSheetTag;
extern const NSInteger kGroupBotCommandsPickSheetTag;
extern const NSInteger kQuoteOutdatedAlertTag;
extern const NSInteger kWallpaperRevertAlertTag;
extern const NSInteger kSuggestedPostDeleteWarningAlertTag;
extern const NSInteger kBotRequestPhoneAlertTag;
extern const NSInteger kBotRequestLocationAlertTag;

typedef NS_ENUM(NSInteger, TGComposeMode) {
	TGComposeModeNew = 0,
	TGComposeModeReply,
	TGComposeModeEdit
};

extern const NSInteger kHistoryPageLimit;
extern const CGFloat kOlderHistoryTriggerOffset;
extern const NSInteger kDayJumpContextRows;
extern const CGFloat kAlbumGap;
extern const CGFloat kMosaicMinTileSide;
extern const NSInteger kPinnedBannerHighlightTag;
extern const NSInteger kPinnedBannerCaptionTag;
extern const NSInteger kPinnedBannerBodyTag;
extern const CGFloat kAvatarSide;
extern const CGFloat kSenderAvatarRadius;
UIImage *TGImageDrawnAtPointSize(UIImage *source, CGSize points);
extern const CGFloat kComposeBannerHeight;
BOOL TGChatIsPad(void);

@interface TGChatViewController () <UISearchBarDelegate,
	CLLocationManagerDelegate,
	UIScrollViewDelegate,
	UIAlertViewDelegate,
	UITextViewDelegate,
	ABPeoplePickerNavigationControllerDelegate,
	MPMediaPickerControllerDelegate,
	UIGestureRecognizerDelegate,
	UISplitViewControllerDelegate,
	UIDocumentInteractionControllerDelegate,
	TGVoiceRecorderDelegate> {
	NSInteger _pressedRow;
}
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, assign) CGFloat laidOutWidth;
@property (nonatomic, strong) UIView *inputBar;
@property (nonatomic, strong) TGChatInputTextView *input;
@property (nonatomic, strong) NSMutableArray *pendingCustomEmojiRuns;
@property (nonatomic, strong) NSMutableArray *pendingMentionRuns;
@property (nonatomic, strong) NSMutableArray *pendingStyleEntities;
@property (nonatomic, strong) NSMutableArray *composerCustomEmojiOverlayViews;
@property (nonatomic, strong) TGMentionSuggestionStrip *mentionSuggestions;
@property (nonatomic, assign) NSRange mentionTriggerRange;
@property (nonatomic, assign) NSUInteger mentionQueryGeneration;
@property (nonatomic, strong) TGInlineQueryResultStrip *inlineQueryStrip;
@property (nonatomic, assign) NSUInteger inlineQueryGeneration;
@property (nonatomic, copy) NSString *inlineQueryActiveUsername;
@property (nonatomic, copy) NSString *inlineQueryActiveQuery;
@property (nonatomic, copy) NSString *inlineQueryResolvingUsername;
@property (nonatomic, strong) NSMutableSet *inlineQueryUnresolvedUsernames;
@property (nonatomic, assign) int64_t inlineQueryBotId;
@property (nonatomic, copy) NSString *inlineQueryNextOffset;
@property (nonatomic, assign) BOOL inlineQueryLoadingMore;
@property (nonatomic, copy) NSString *inlineQueryButtonParameter;
@property (nonatomic, strong) UIView *inputPlate;
@property (nonatomic, strong) UILabel *inputPlaceholder;
- (void)refreshSendAsPlaceholder;
@property (nonatomic, assign) CGFloat composerTextHeight;
@property (nonatomic, assign) CGFloat composerLineHeight;
@property (nonatomic, assign) CGFloat keyboardInset;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSArray *displayRows;
@property (nonatomic, strong) NSDictionary *albumsByRow;
@property (nonatomic, strong) NSDictionary *rowByMessageId;
@property (nonatomic, strong) TGChatLayoutBridge *layoutBridge;
@property (nonatomic, strong) TGChatPresenter *presenter;
@property (nonatomic, strong) NSMutableDictionary *stableMessageEntries;
@property (nonatomic, assign) CGFloat layoutContextWidth;
@property (nonatomic, assign) CGFloat layoutContextFontSize;
@property (nonatomic, assign) BOOL layoutContextIsGroup;
@property (nonatomic, assign) BOOL layoutContextIsWide;
@property (nonatomic, assign) BOOL layoutContextIsSelecting;
@property (nonatomic, assign) uint32_t layoutContextGeneration;
@property (nonatomic, strong) NSMutableDictionary *mosaics;
@property (nonatomic, strong) NSMutableDictionary *tileSizes;
@property (nonatomic, strong) NSMutableDictionary *tileBitmaps;
@property (nonatomic, strong) NSMutableSet *tileBitmapsRequested;
@property (nonatomic, strong) NSMutableDictionary *images;
@property (nonatomic, strong) NSMutableArray *imageOrder;
@property (nonatomic, assign) BOOL tableReloadPending;
@property (nonatomic, assign) BOOL fetchImagesPending;
@property (nonatomic, assign) BOOL pendingReloadAnchors;
@property (nonatomic, assign) BOOL pendingReloadFollows;
@property (nonatomic, assign) BOOL pendingScrollButtonUpdate;
@property (nonatomic, strong) NSMutableSet *imagesRequested;
@property (nonatomic, strong) NSMutableSet *photoFilesInFlight;
@property (nonatomic, strong) NSMutableSet *photoFilesCancelled;
@property (nonatomic, strong) NSMutableSet *photoFilesFailed;
@property (nonatomic, strong) NSMutableSet *filesBeingFetched;
@property (nonatomic, strong) NSMutableDictionary *minithumbnails;
@property (nonatomic, assign) NSRange photoWindow;
@property (nonatomic, assign) BOOL anchorToBottom;
@property (nonatomic, strong) NSMutableDictionary *lottiePaths;
@property (nonatomic, strong) NSMutableDictionary *stickerOutlineImages;
@property (nonatomic, strong) NSMutableSet *stickerOutlinesRequested;
@property (nonatomic, strong) NSMutableDictionary *maps;
@property (nonatomic, strong) NSMutableSet *mapsRequested;
@property (nonatomic, strong) NSMutableDictionary *quotes;
@property (nonatomic, strong) NSMutableSet *quotesRequested;
@property (nonatomic, strong) NSMutableSet *quotesMissing;
@property (nonatomic, strong) NSMutableSet *voiceFilesRequested;
@property (nonatomic, strong) NSDictionary *actionMessage;
@property (nonatomic, assign) int64_t replyToId;
@property (nonatomic, copy) NSString *replyQuoteText;
@property (nonatomic, copy) NSArray *replyQuoteEntities;
@property (nonatomic, assign) NSInteger replyQuotePosition;
@property (nonatomic, assign) int64_t editingId;
@property (nonatomic, assign) BOOL editingIsCaption;
@property (nonatomic, assign) BOOL editingCaptionAboveMedia;
@property (nonatomic, strong) NSDictionary *editingLinkPreviewOptions;
@property (nonatomic, copy) NSString *preEditDraftText;
@property (nonatomic, readonly) TGComposeMode composeMode;
@property (nonatomic, strong) UIView *composeBanner;
@property (nonatomic, strong) TGStickerSuggestionStrip *stickerSuggestions;
@property (nonatomic, strong) UIButton *micButton;
@property (nonatomic, assign) BOOL videoNoteMode;
@property (nonatomic, assign) BOOL micDidRecord;
@property (nonatomic, strong) UILongPressGestureRecognizer *micHold;
@property (nonatomic, strong) UIView *titleHeader;
@property (nonatomic, strong) UILabel *titleNameLabel;
@property (nonatomic, strong) UILabel *titleStatusLabel;
@property (nonatomic, copy) NSString *chatHeaderRestingSubtitle;
@property (nonatomic, copy) NSString *connectionStatusText;
@property (nonatomic, strong) UISearchBar *chatSearchBar;
@property (nonatomic, strong) NSArray *messagesBeforeSearch;
@property (nonatomic, assign) int64_t chatSearchNextFromMessageId;
@property (nonatomic, copy) NSString *chatSearchNextOffset;
@property (nonatomic, assign) BOOL chatSearchLoadingMore;
@property (nonatomic, assign) BOOL chatSearchExhausted;
@property (nonatomic, assign) NSInteger chatSearchGeneration;
@property (nonatomic, assign) int64_t chatSearchRestoreMessageId;
@property (nonatomic, assign) CGFloat chatSearchRestoreDelta;
@property (nonatomic, assign) BOOL chatSearchRestoreAtBottom;
@property (nonatomic, assign) NSInteger chatSearchTotalCount;
@property (nonatomic, assign) NSInteger chatSearchCurrentIndex;
@property (nonatomic, assign) BOOL chatSearchPendingOlderNav;
@property (nonatomic, strong) UIView *chatSearchNavBar;
@property (nonatomic, strong) UILabel *chatSearchCountLabel;
@property (nonatomic, strong) UIButton *chatSearchOlderButton;
@property (nonatomic, strong) UIButton *chatSearchNewerButton;
@property (nonatomic, strong) NSTimer *recordTimer;
@property (nonatomic, strong) UIView *recordPanel;
@property (nonatomic, strong) UILabel *recordClock;
@property (nonatomic, strong) UIView *recordDot;
@property (nonatomic, strong) TGVideoCaptureViewController *videoNoteShooter;
@property (nonatomic, assign) CGPoint micHoldOrigin;
@property (nonatomic, strong) AVPlayer *videoNotePlayer;
@property (nonatomic, strong) AVPlayerLayer *videoNoteLayer;
@property (nonatomic, strong) CAShapeLayer *videoNoteRing;
@property (nonatomic, strong) UIImageView *videoNoteMute;
@property (nonatomic, assign) BOOL videoNoteMuted;
@property (nonatomic, assign) NSTimeInterval videoNoteLength;
@property (nonatomic, strong) NSArray *videoNotePlaylist;
@property (nonatomic, assign) NSInteger videoNoteIndex;
@property (nonatomic, assign) int64_t videoNoteMessageId;
@property (nonatomic, assign) BOOL videoNoteAutoUnmute;
@property (nonatomic, assign) long long videoNoteDownloadingFileId;
@property (nonatomic, strong) NSTimer *videoNoteTicker;
@property (nonatomic, strong) id connectionStateObserverToken;
@property (nonatomic, strong) id themeChangedObserverToken;
@property (nonatomic, strong) id customEmojiObserverToken;
@property (nonatomic, strong) id chatActionObserverToken;
@property (nonatomic, strong) id messageObserverToken;
@property (nonatomic, strong) id animatedEmojiObserverToken;
@property (nonatomic, strong) id pollObserverToken;
@property (nonatomic, strong) id fileProgressObserverToken;
@property (nonatomic, strong) id keyboardWillShowObserverToken;
@property (nonatomic, strong) id keyboardWillHideObserverToken;
@property (nonatomic, strong) id keyboardWillChangeFrameObserverToken;
@property (nonatomic, strong) id backgroundFlushDraftObserverToken;
@property (nonatomic, strong) id terminateFlushDraftObserverToken;
@property (nonatomic, strong) id musicPlayerStateObserverToken;
@property (nonatomic, strong) id musicPlayerProgressObserverToken;
@property (nonatomic, strong) id audioMetadataObserverToken;
@property (nonatomic, strong) id interactionInfoObserverToken;
@property (nonatomic, strong) id customReactionEmojiObserverToken;
@property (nonatomic, strong) id fileStateObserverToken;
@property (nonatomic, strong) id savedMessagesTagsObserverToken;
@property (nonatomic, strong) id unreadCounterObserverToken;
@property (nonatomic, strong) id outgoingReadStateObserverToken;
@property (nonatomic, strong) id isTranslatableObserverToken;
@property (nonatomic, strong) id pinnedMessagesObserverToken;
@property (nonatomic, strong) id chatActionBarObserverToken;
@property (nonatomic, strong) id userBlockedStateObserverToken;
@property (nonatomic, strong) id composerPermissionsObserverToken;
@property (nonatomic, strong) id frozenStateObserverToken;
@property (nonatomic, strong) id chatMemberObserverToken;
@property (nonatomic, strong) id chatMuteStateObserverToken;
@property (nonatomic, strong) id secretChatStateObserverToken;
@property (nonatomic, strong) id videoChatObserverToken;
@property (nonatomic, strong) id videoNoteReachedEndObserverToken;
@property (nonatomic, strong) id videoNoteInterruptionObserverToken;
@property (nonatomic, strong) id userStatusObserverToken;
@property (nonatomic, strong) id chatBackgroundObserverToken;
@property (nonatomic, strong) id chatDraftObserverToken;
@property (nonatomic, strong) id chatThemeObserverToken;
@property (nonatomic, strong) id chatThemeCatalogObserverToken;
@property (nonatomic, strong) id chatMessageSenderObserverToken;
@property (nonatomic, strong) id hasScheduledMessagesObserverToken;
@property (nonatomic, strong) id mentionsUpdateObserverToken;
@property (nonatomic, strong) id reactionsUpdateObserverToken;
@property (nonatomic, strong) NSTimer *userStatusExpiryTimer;
@property (nonatomic, strong) NSMutableDictionary *senderAvatars;
@property (nonatomic, strong) NSMutableSet *senderAvatarsRequested;
@property (nonatomic, strong) NSMutableDictionary *senderChatAvatars;
@property (nonatomic, strong) NSMutableSet *senderChatAvatarsRequested;
@property (nonatomic, strong) UIView *downloadHUD;
@property (nonatomic, strong) UIActivityIndicatorView *downloadSpinner;
@property (nonatomic, strong) UILabel *downloadPercent;
@property (nonatomic, assign) long long downloadingFileId;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) EKEventStore *eventStore;
@property (nonatomic, strong) UIImageView *wallpaperView;
@property (nonatomic, copy) NSString *chatBackgroundId;
@property (nonatomic, assign) NSUInteger chatWallpaperLoadGeneration;
@property (nonatomic, assign) NSUInteger chatThemeLoadGeneration;
@property (nonatomic, strong) NSDictionary *chatThemeBackgroundRow;
@property (nonatomic, assign) BOOL chatThemeUnresolved;
@property (nonatomic, strong) UIButton *stickerButton;
@property (nonatomic, strong) UIView *stickerPanel;
@property (nonatomic, assign) BOOL stickerPanelSearching;
@property (nonatomic, assign) BOOL keyboardOnScreen;
@property (nonatomic, strong) NSMutableDictionary *reactionChips;
@property (nonatomic, strong) NSMutableSet *reactionChipsRequested;
@property (nonatomic, strong) NSMutableSet *quickReactionRequestsInFlight;
@property (nonatomic, strong) NSMutableDictionary *chipsRowSizes;
@property (nonatomic, strong) NSMutableDictionary *commentCounts;
@property (nonatomic, strong) NSMutableDictionary *viewCounts;
@property (nonatomic, strong) NSMutableDictionary *linkPreviews;
@property (nonatomic, strong) NSMutableSet *linkPreviewsRequested;
@property (nonatomic, copy) NSString *pendingLinkURL;
@property (nonatomic, strong) TGMessageActionsSheet *actionsSheet;
@property (nonatomic, strong) TGTextSelectionOverlay *textSelectionOverlay;
@property (nonatomic, assign) int64_t forwardMessageId;
@property (nonatomic, strong) NSArray *forwardIds;
@property (nonatomic, assign) int64_t pinMessageId;
@property (nonatomic, strong) UIDocumentInteractionController *documentInteraction;
@property (nonatomic, strong) NSArray *reportOptions;
@property (nonatomic, strong) NSArray *reportMessageIds;
@property (nonatomic, copy) NSString *reportSelectionOptionId;
@property (nonatomic, assign) int64_t factCheckMessageId;
@property (nonatomic, assign) int64_t suggestedPostMessageId;
@property (nonatomic, assign) int64_t suggestPostStarCount;
@property (nonatomic, assign) int64_t suggestPostMessageIdForSchedule;
@property (nonatomic, strong) NSDictionary *pendingDeleteMessage;
@property (nonatomic, assign) BOOL pendingDeleteForEveryone;
@property (nonatomic, assign) int64_t checklistAddMessageId;
@property (nonatomic, assign) int64_t pollAddMessageId;
@property (nonatomic, strong) NSMutableDictionary *pollPendingSelections;
@property (nonatomic, strong) NSMutableSet *pollVotesInFlight;
@property (nonatomic, assign) int64_t checklistEditMessageId;
@property (nonatomic, assign) int32_t checklistEditTaskId;
@property (nonatomic, assign) int64_t checklistDeleteMessageId;
@property (nonatomic, assign) int32_t checklistDeleteTaskId;
@property (nonatomic, assign) int64_t checklistMenuMessageId;
@property (nonatomic, assign) int32_t checklistMenuTaskId;
@property (nonatomic, copy) NSString *checklistMenuTaskText;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIView *emptyPlate;
@property (nonatomic, strong) UIImageView *emptyGlyph;
@property (nonatomic, assign) NSInteger unreadOnOpen;
@property (nonatomic, assign) BOOL unreadOnOpenKnown;
@property (nonatomic, strong) UIButton *backButtonView;
@property (nonatomic, assign) BOOL backButtonUnreadUpdateScheduled;
@property (nonatomic, assign) int64_t lastReadInboxOnOpen;
@property (nonatomic, assign) int64_t openAnchorFetchId;
@property (nonatomic, assign) int64_t openAnchorRestoreId;
@property (nonatomic, assign) NSInteger openAnchorNewerWanted;
@property (nonatomic, assign) CGFloat openAnchorRestoreDelta;
@property (nonatomic, assign) BOOL openAnchorIsUnread;
@property (nonatomic, assign) BOOL initialPlacementDone;
@property (nonatomic, assign) BOOL openedOnAnAnchor;
@property (nonatomic, assign) NSInteger cachedUnreadRow;
@property (nonatomic, strong) NSArray *cachedUnreadKey;
@property (nonatomic, strong) UIButton *scrollDownButton;
@property (nonatomic, strong) UILabel *scrollDownBadge;
@property (nonatomic, strong) NSDate *lastTypingSent;
@property (nonatomic, strong) TGChatComposerState *composerState;
@property (nonatomic, assign) BOOL slowModeRefreshScheduled;
@property (nonatomic, strong) NSDictionary *chatActionBar;
@property (nonatomic, strong) UIView *actionBarView;
@property (nonatomic, assign) CGFloat actionBarInset;
@property (nonatomic, strong) NSArray *actionBarActions;
@property (nonatomic, assign) int64_t pinnedMessageId;
@property (nonatomic, strong) NSDictionary *pinnedMessage;
@property (nonatomic, strong) NSArray *pinnedMessages;
@property (nonatomic, assign) NSInteger pinnedIndex;
@property (nonatomic, strong) UIView *pinnedBanner;
@property (nonatomic, assign) CGFloat pinnedBannerInset;
@property (nonatomic, strong) NSArray *messagesBeforePinnedList;
@property (nonatomic, strong) UIBarButtonItem *rightItemBeforePinnedList;
@property (nonatomic, strong) UIView *titleViewBeforePinnedList;
@property (nonatomic, assign) CGFloat shortContentInset;
@property (nonatomic, assign) BOOL deeperHistoryPending;
@property (nonatomic, assign) BOOL olderHistoryPending;
@property (nonatomic, assign) BOOL olderHistoryExhausted;
@property (nonatomic, assign) BOOL localHistoryShown;
@property (nonatomic, assign) BOOL networkHistoryShown;
@property (nonatomic, assign) BOOL hasCompletedInitialAppear;
@property (nonatomic, strong) NSArray *pendingPartialHistory;
@property (nonatomic, assign) BOOL partialHistoryScheduled;
@property (nonatomic, strong) UIButton *channelActionButton;
@property (nonatomic, assign) BOOL channelMuted;
@property (nonatomic, strong) UIImageView *titleMuteIcon;
@property (nonatomic, strong) UILabel *titleCredibilityLabel;
@property (nonatomic, strong) UIImageView *titlePremiumIcon;
@property (nonatomic, strong) UIView *channelActionBarView;
@property (nonatomic, strong) NSString *secretChatBlockedStatusText;
@property (nonatomic, assign) BOOL selecting;
@property (nonatomic, strong) NSMutableArray *selectedIds;
@property (nonatomic, strong) UIView *selectionPanel;
@property (nonatomic, assign) BOOL chatHasProtectedContentKnown;
@property (nonatomic, assign) BOOL chatHasProtectedContent;
@property (nonatomic, strong) id protectedContentObserver;
@property (nonatomic, strong) NSMutableSet *nonForwardableMessageIds;
@property (nonatomic, strong) NSMutableSet *nonSaveableMessageIds;
@property (nonatomic, strong) NSMutableSet *nonCopyableMessageIds;
@property (nonatomic, strong) NSMutableSet *nonDeletableForEveryoneMessageIds;
@property (nonatomic, strong) NSMutableSet *selectionPermissionsRequested;
@property (nonatomic, strong) NSMutableSet *forwardPermissionKnownMessageIds;
@property (nonatomic, strong) UIBarButtonItem *rightItemBeforeSelection;
@property (nonatomic, strong) UIView *titleViewBeforeSelection;
@property (nonatomic, assign) BOOL sendSilently;
@property (nonatomic, assign) BOOL sendMediaOnce;
@property (nonatomic, assign) NSInteger pendingSelfDestructSeconds;
@property (nonatomic, assign) int64_t pendingEffectId;
@property (nonatomic, copy) NSString *pendingEffectEmoji;
@property (nonatomic, copy) NSString *pendingAiSuggestion;
@property (nonatomic, strong) NSArray *pendingAiRewriteStyleNames;
@property (nonatomic, strong) NSArray *effectChoices;
@property (nonatomic, strong) NSArray *availableSenders;
@property (nonatomic, assign) int64_t currentSenderId;
@property (nonatomic, assign) BOOL currentSenderIsChat;
@property (nonatomic, assign) NSTimeInterval scheduledSendDate;
@property (nonatomic, assign) BOOL scheduleWhenOnline;
@property (nonatomic, strong) NSArray *scheduledMessages;
@property (nonatomic, strong) NSMutableDictionary *sendStates;
@property (nonatomic, strong) NSMutableSet *sendStatesRequested;
@property (nonatomic, strong) NSMutableSet *readMessageIds;
@property (nonatomic, strong) NSMutableDictionary *channelViewMetricsStart;
@property (nonatomic, strong) NSMutableArray *mentionIds;
@property (nonatomic, strong) UIButton *mentionButton;
@property (nonatomic, assign) BOOL draftRestored;
@property (nonatomic, copy) NSString *reportTextOptionId;
@property (nonatomic, assign) BOOL reportTextOptional;
@property (nonatomic, strong) UIView *datePickerPanel;
@property (nonatomic, strong) UIDatePicker *schedulePicker;
@property (nonatomic, strong) UIBarButtonItem *scheduleDoneButton;
@property (nonatomic, strong) UIImage *pendingPastedImage;
@property (nonatomic, strong) UILongPressGestureRecognizer *messageHold;
@property (nonatomic, strong) UITapGestureRecognizer *backgroundTap;
@property (nonatomic, strong) UIPanGestureRecognizer *inputBarDismissSwipe;
@property (nonatomic, assign) NSInteger swipingRow;
@property (nonatomic, weak) UITableViewCell<TGReplySwipeCell> *swipingCell;
@property (nonatomic, assign) CGFloat swipeOffset;
@property (nonatomic, assign) BOOL swipeArmed;
@property (nonatomic, assign) NSInteger pressedRow;
@property (nonatomic, assign) int64_t peerMenuUserId;
@property (nonatomic, copy) NSString *peerMenuName;
@property (nonatomic, copy) NSString *heldLinkURL;
@property (nonatomic, copy) NSString *bankCardNumber;
@property (nonatomic, strong) NSArray *bankCardActions;
@property (nonatomic, assign) int64_t failedMessageId;
@property (nonatomic, copy) NSArray *pendingQuoteRetryMessageIds;
@property (nonatomic, strong) NSMutableDictionary *translations;
@property (nonatomic, strong) NSMutableDictionary *translationEntities;
@property (nonatomic, strong) NSMutableDictionary *translationsPending;
@property (nonatomic, assign) NSUInteger translationRequestGeneration;
@property (nonatomic, strong) NSMutableSet *autoTranslatedMessageIds;
@property (nonatomic, strong) NSMutableDictionary *aiSummaries;
@property (nonatomic, strong) NSMutableDictionary *transcripts;
@property (nonatomic, strong) NSMutableSet *transcriptsPending;
@property (nonatomic, strong) NSMutableDictionary *bodyLayouts;
@property (nonatomic, strong) NSMutableArray *bodyLayoutOrder;
@property (nonatomic, strong) NSMutableSet *revealedSpoilers;
@property (nonatomic, strong) NSMutableSet *revealedMediaSpoilers;
@property (nonatomic, strong) NSMutableDictionary *expandedQuotes;
@property (nonatomic, copy) NSString *pendingInviteLink;
@property (nonatomic, copy) NSString *pendingLanguagePackId;
@property (nonatomic, assign) int64_t moderationUserId;
@property (nonatomic, copy) NSString *moderationName;
@property (nonatomic, strong) NSArray *moderationMessageIds;
@property (nonatomic, copy) NSString *pendingModerationAction;
@property (nonatomic, copy) NSString *attachMode;
@property (nonatomic, copy) NSString *locationMode;
@property (nonatomic, assign) int64_t liveLocationMessageId;
@property (nonatomic, assign) NSInteger liveLocationFailureCount;
@property (nonatomic, strong) NSTimer *liveLocationRefreshTimer;
@property (nonatomic, copy) NSString *venueTitle;
@property (nonatomic, copy) NSString *venueAddress;
@property (nonatomic, strong) CLLocation *venuePrefetchedLocation;
@property (nonatomic, copy) NSString *venueGeocodedAddress;
@property (nonatomic, strong) NSTimer *locationFetchTimeoutTimer;
@property (nonatomic, assign) BOOL markdownComposing;
@property (nonatomic, assign) int64_t reschedulingMessageId;
@property (nonatomic, assign) NSTimeInterval reschedulingSendDate;
@property (nonatomic, strong) NSMutableSet *mapTilesRequested;
@property (nonatomic, strong) NSArray *botButtons;
@property (nonatomic, assign) int64_t botButtonsMessageId;
@property (nonatomic, assign) BOOL botButtonsMessageInvoicePaid;
@property (nonatomic, assign) NSInteger botButtonsRow;
@property (nonatomic, strong) NSDictionary *pendingCallbackButton;
@property (nonatomic, strong) NSArray *inactiveChannelsList;
@property (nonatomic, strong) NSArray *recentInlineBotList;
@property (nonatomic, strong) NSNumber *inlineQueryId;
@property (nonatomic, copy) NSString *pendingBotStartLink;
@property (nonatomic, copy) NSString *sharePickerKind;
@property (nonatomic, assign) NSInteger sharePickerButtonId;
@property (nonatomic, assign) int64_t sharePickerMessageId;
@property (nonatomic, strong) NSMutableArray *reactionMessageIds;
@property (nonatomic, strong) UIButton *reactionButton;
@property (nonatomic, assign) BOOL chatIsWithBot;
@property (nonatomic, assign) BOOL chatCanReceiveGift;
@property (nonatomic, strong) NSArray *groupBotCommandGroups;
@property (nonatomic, strong) NSArray *tappedLinkTargets;
@property (nonatomic, strong) UIBarButtonItem *masterRevealItem;
@property (nonatomic, strong) UIPopoverController *masterPopover;
@property (nonatomic, strong) UIBarButtonItem *leftItemBeforeSplit;
@property (nonatomic, assign) BOOL leftItemBeforeSplitKnown;
@property (nonatomic, assign) CGFloat composeBannerInset;
@property (nonatomic, strong) UIActivityIndicatorView *historySpinner;
@property (nonatomic, assign) NSTimeInterval keyboardDuration;
@property (nonatomic, assign) UIViewAnimationCurve keyboardCurve;

- (void)installMessageHandler;
- (void)installAnimatedEmojiHandler;
- (void)playAnimatedEmojiSticker:(long long)stickerFileId animated:(BOOL)isAnimated;
- (void)installPollHandler;
@end

@interface TGChatViewController (Internal)

- (void)applyPictureTo:(UIImageView *)imageView message:(NSDictionary *)m atSize:(CGSize)size;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other;
- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)collection;
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
- (TGRichTextLayout *)quoteLayoutFor:(NSDictionary *)m text:(NSString *)text width:(CGFloat)width;
@end

@interface TGChatViewController (VoiceVideo)

- (void)inputChanged;
- (void)updateComposerButtons;
- (void)recordStart;
- (void)recordCancel;
- (void)recordFinish;
- (void)stopVideoNote;
- (void)stopVideoNoteKeepingBar:(BOOL)keepBar;
- (void)startVideoNoteRing;
- (void)startVideoNoteRingResumingAtCurrentPosition;
- (void)startVideoNoteRingFromFraction:(double)fromFraction duration:(NSTimeInterval)duration;
- (void)pauseVideoNoteRing;
- (void)resumeVideoNoteRing;
- (void)videoNoteTicked;
- (void)playVideoNoteAtPlaylistIndex:(NSInteger)index;
- (void)playVideoNoteAtPath:(NSString *)path row:(NSInteger)row;
- (void)cancelPendingVideoNoteDownload;
- (void)videoNoteReachedEnd:(NSNotification *)note;

@end

@interface TGChatViewController (Composer)

- (void)buildInputBar:(CGRect)b;
- (CGFloat)inputBarHeight;
- (CGFloat)composerTextHeightForContent:(CGFloat)content;
- (void)layoutComposerSubviews;
- (void)remeasureComposerForNewWidth;
- (void)sendTapped;
- (void)refreshComposerCustomEmojiOverlay;
- (void)adjustPendingCustomEmojiForRange:(NSRange)range replacementLength:(NSInteger)length;
- (NSArray *)customEmojiEntitiesForOriginalText:(NSString *)original
									 sentAsText:(NSString *)sent;
- (void)adjustPendingMentionRunsForRange:(NSRange)range replacementLength:(NSInteger)length;
- (NSArray *)mentionNameEntitiesForOriginalText:(NSString *)original
									  sentAsText:(NSString *)sent;
- (void)seedPendingStyleEntitiesFromMessage:(NSDictionary *)m;
- (void)adjustPendingStyleEntitiesForRange:(NSRange)range replacementLength:(NSInteger)length;
- (NSArray *)styleEntitiesForOriginalText:(NSString *)original
								sentAsText:(NSString *)sent;
- (void)applyMicButtonGlyph;

@end

@interface TGChatViewController (ChatActionBar)

- (BOOL)postingBlocked;
- (BOOL)blockSendForSlowMode;
- (void)recomputeComposerState;
- (void)applyPostingRights;
- (void)composerPermissionsChanged:(NSNotification *)note;
- (void)frozenAccountStateChanged:(NSNotification *)note;
- (void)chatMemberChanged:(NSNotification *)note;
- (void)chatMuteStateChanged:(NSNotification *)note;
- (void)secretChatStateNotificationReceived:(NSNotification *)note;
- (void)chatActionBarChanged:(NSNotification *)note;
- (void)removeChannelActionBar;
- (void)buildChannelActionBar;
- (void)updateChannelActionTitle;
- (void)refreshSecretChatBlockedStatusText;
- (void)unblockFromChat:(UIButton *)button;
- (void)openFrozenAccountDetails:(UIButton *)button;
- (void)runActionBarBlockOption:(NSString *)title;
- (void)loadChatActionBar;
- (void)performActionBarReportSpam;
- (void)performActionBarSharePhoneNumber;

@end

@interface TGChatViewController (Wallpaper)

- (void)loadChatWallpaper;
- (void)applyChatWallpaperRow:(NSDictionary *)row generation:(NSUInteger)generation;
- (void)chatBackgroundChanged:(NSNotification *)note;
- (void)offerWallpaperRevertForMessage:(NSDictionary *)m;
- (void)handleWallpaperRevertAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex;

@end

@interface TGChatViewController (Theme)

- (void)loadChatTheme;
- (void)chatThemeChanged:(NSNotification *)note;
- (void)chatThemeCatalogChanged:(NSNotification *)note;

@end

@interface TGChatViewController (SplitLayout)

- (void)outgoingReadStateChanged:(NSNotification *)note;
- (void)isTranslatableChanged:(NSNotification *)note;
- (void)pinnedMessagesChanged:(NSNotification *)note;

@end

@interface TGChatViewController (Header)

- (void)videoChatDidChange:(NSNotification *)note;
- (void)muteFromChat:(UIButton *)button;
- (void)layoutTitleView;
- (void)buildTitleView;
- (void)buildBackButton;
- (void)updateBackButtonUnreadBadge;
- (void)unreadCounterRelevantUpdateReceived:(NSNotification *)note;
- (void)buildAvatarButton;

@end

@interface TGChatViewController (Keyboard)

- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;
- (void)keyboardWillChangeFrame:(NSNotification *)note;
- (void)layoutChatStackAnimated:(BOOL)animated duration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve;
- (void)shiftForKeyboardHeight:(CGFloat)height;

@end

@interface TGChatViewController (Playback) <TGExternalPlayback>

- (void)musicPlayerStateChanged;
- (void)musicPlayerProgressed;
- (void)audioTagsArrived:(NSNotification *)note;
- (int64_t)playingMessageId;
- (CGFloat)playedFraction;

@end

@interface TGChatViewController (Downloads)

- (void)fileStateChanged:(NSNotification *)note;
- (void)storeImage:(UIImage *)image forFile:(NSNumber *)fileId;
- (void)beginDownloadHUDForFile:(long long)fileId;
- (void)endDownloadHUDForFile:(long long)fileId;
- (void)fetchVisiblePictures;
- (CGFloat)pictureDecodeLimit;
- (void)refreshFileStatusForFile:(NSNumber *)fileId;

@end

@interface TGChatViewController (Pinned)

- (void)paintBannerGround:(UIView *)view;
- (void)showAllPinnedMessages;
- (void)unpinEverything;
- (void)loadPinnedMessage;
- (BOOL)isMessagePinnedLocally:(int64_t)messageId;
- (void)purgeDeletedPinnedMessageId:(int64_t)messageId;
- (void)refreshEditedPinnedMessage:(NSDictionary *)message;
- (void)paintBannerGround:(UIView *)banner;
- (void)jumpToMessageId:(int64_t)messageId inCurrentChatNotFound:(void (^)(void))notFound;
- (void)loadDeeperHistoryAndScrollTo:(int64_t)messageId;
- (NSArray *)messagesMerging:(NSArray *)incoming;

@end

@interface TGChatViewController (Taps)

- (void)showRecordingFailure;
- (void)runFailedMessageOption:(NSString *)chosen;
- (void)showAlertTitle:(NSString *)title message:(NSString *)message;
- (void)playAudioMessage:(NSDictionary *)m fromSeconds:(NSTimeInterval)seconds;
- (void)tapFellThroughOnMessage:(NSDictionary *)m;
- (BOOL)revealMediaSpoilerIfActiveForMessage:(NSDictionary *)m row:(NSInteger)row;
- (void)showGalleryForMessage:(NSDictionary *)m;
- (void)showGalleryForLinkPreview:(NSDictionary *)preview;

@end

@interface TGChatViewController (Albums)

- (NSInteger)rowForMessageId:(int64_t)messageId;
- (NSDictionary *)messageAtRow:(NSInteger)row;
- (NSArray *)messagesAtRow:(NSInteger)row;
- (NSInteger)displayRowCount;
- (NSArray *)albumAtRow:(NSInteger)row;
- (CGSize)tileSizeForMessage:(NSDictionary *)m;
- (NSDictionary *)mosaicForRow:(NSInteger)row;
- (CGSize)imageSizeForRow:(NSInteger)row;
- (BOOL)dayHeadersOpenTheCalendar;
- (void)openDayCalendarAroundDate:(NSTimeInterval)date;
- (BOOL)messageCanTile:(NSDictionary *)m;
- (BOOL)scrollToMessageId:(int64_t)messageId;

@end

@interface TGChatViewController (Data)

- (void)loadOlderHistoryIfNeeded;
- (void)applyOlderHistoryPage:(NSArray *)messages olderThan:(long long)anchorId;

- (int64_t)topVisibleMessageIdWithDelta:(CGFloat *)delta;
- (BOOL)placeRow:(NSInteger)row atTopWithDelta:(CGFloat)delta;
- (NSInteger)rowAtOrAfterMessageId:(int64_t)messageId;
- (void)reload;
- (void)reloadForChatIdentityChangedTo:(int64_t)newChatId;
- (void)refreshCommentThreadStateIfStale;
- (void)setFloatingButton:(UIButton *)button shown:(BOOL)shown;
- (void)rememberScrollPosition;
- (NSArray *)chipsFor:(NSDictionary *)m;
- (BOOL)historyWindowHoldsTheNewest;
- (void)updateShortContentInset;
- (void)scrollToBottomAnimated:(BOOL)animated;
- (void)updateScrollDownButton;
- (void)updateScrollDownBadge:(NSInteger)unread;
- (void)setNeedsTableReloadKeepingBottom;
- (void)fetchMissingImages;
- (void)resolveUnknownSenders;
- (void)resolveUnknownForwardOrigins;
- (void)fetchMissingQuotes;
- (void)fetchMissingVoiceFiles;
- (void)layoutFloatingButtons;
- (void)centreEmptyPlate;
- (BOOL)historyIsAtBottom;
- (void)setNeedsTableReloadFollowingBottom:(BOOL)follow;
- (void)setNeedsFetchMissingImages;
- (void)updateEmptyState;
- (CGSize)previewSizeFor:(NSDictionary *)m;
- (CGSize)chipsRowSizeFor:(NSDictionary *)m;
- (BOOL)messageCarriesMapCard:(NSDictionary *)m;
- (UIImage *)mapCardFor:(NSDictionary *)m;
- (void)invalidateMapCacheForMessage:(NSDictionary *)message;
- (void)invalidateLinkPreviewForMessage:(NSDictionary *)message;
- (void)setNeedsTableReload;
- (NSDictionary *)previewFor:(NSDictionary *)m;
- (NSDictionary *)richPreviewDictFor:(NSDictionary *)m;
- (UIImage *)previewImageFor:(NSDictionary *)preview;
- (void)customReactionEmojiResolved;
- (void)savedMessagesTagLabelsChanged;
- (BOOL)historyStopsShortOfTheNewest;
- (void)interactionInfoChanged:(NSNotification *)note;
- (void)loadNewestHistoryAndShowIt;
- (void)resolveOpenAnchor;

@end

@interface TGChatViewController (Table) <UITableViewDataSource, UITableViewDelegate>

- (NSString *)audioLiveClockTextWithDuration:(NSInteger)fallback;
- (NSString *)serviceLineFor:(NSDictionary *)m;
- (NSNumber *)wallpaperRevertTargetFor:(NSDictionary *)m;
- (BOOL)fileCellShowsThumbnailFor:(NSDictionary *)m;
- (CGFloat)fileCellTileSideFor:(NSDictionary *)m;
- (NSString *)contactNameFor:(NSDictionary *)m;
- (NSString *)contactPhoneFor:(NSDictionary *)m;
- (NSDictionary *)fileStateFor:(NSDictionary *)m;
- (TGFileStatusKind)statusKindForFileState:(NSDictionary *)state
								  playable:(BOOL)playable
								   playing:(BOOL)playing;
- (NSString *)fileTitleFor:(NSDictionary *)m;
- (NSString *)fileSubtitleFor:(NSDictionary *)m state:(NSDictionary *)state;
- (TGAudioMetadata *)audioTagsFor:(NSDictionary *)m;
- (NSString *)audioTitleFor:(NSDictionary *)m tags:(TGAudioMetadata *)tags;
- (NSString *)audioArtistFor:(NSDictionary *)m
						tags:(TGAudioMetadata *)tags
					   state:(NSDictionary *)state;
- (NSString *)audioClockTemplateFor:(NSDictionary *)m;
- (NSString *)audioClockTextFor:(NSDictionary *)m current:(BOOL)current;
- (NSString *)clockTextForSeconds:(NSInteger)seconds;
- (NSString *)fileCaptionFor:(NSDictionary *)m;
- (NSString *)bubbleReuseIdentifierAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface TGChatViewController (Attachments)

- (BOOL)cameraAvailable;
- (UIImage *)pasteboardImage;
- (void)captureVideoRound:(BOOL)round;
- (Class)videoCaptureClass;

@end

@interface TGChatViewController (SendOptions)

- (NSInteger)mediaSelfDestruct;
- (void)clearMediaSelfDestruct;
- (void)runEffectPickerIndex:(NSInteger)index;
- (BOOL)allowsMessageEffects;
- (void)showEffectPicker;
- (void)showScheduledMessages;
- (void)beginEditingScheduledMessage:(NSDictionary *)m messageId:(int64_t)messageId;
- (NSDictionary *)sendOptionsDictionary;
- (void)loadScheduledMessages;
- (void)hasScheduledMessagesChanged:(NSNotification *)note;
- (void)playEffectBurstWithEmoji:(NSString *)emoji;
- (void)showSchedulePicker;

@end

@interface TGChatViewController (Drafts)

- (void)showSelfDestructTimerPicker;
- (void)runSendAsPickerIndex:(NSInteger)index;
- (void)runSendOption:(NSString *)title;
- (void)restoreDraft;
- (void)flushDraftOnAppState:(NSNotification *)note;
- (void)saveDraft;
- (void)chatDraftChanged:(NSNotification *)note;
- (void)sendHeld:(UILongPressGestureRecognizer *)hold;
- (void)loadAvailableSenders;
- (void)chatMessageSenderChanged:(NSNotification *)note;
- (BOOL)isRemindersChat;
- (BOOL)allowsViewOnceMedia;

@end

@interface TGChatViewController (Links)

- (void)followTextTarget:(NSDictionary *)target;
- (void)openExternalLink:(NSString *)url;
- (BOOL)openMediaTimestamp:(NSTimeInterval)seconds forRow:(NSInteger)row;
- (void)openLink:(NSString *)url;
- (void)openLinkInMessage:(NSDictionary *)m;
- (TGEmojiLabel *)richBodyLabelForCell:(UITableViewCell *)cell;
- (void)forgetLayoutOfMessage:(NSNumber *)messageId;
- (void)followRichLink:(NSDictionary *)link inRow:(NSInteger)row;
- (BOOL)handleRichTapInRow:(NSInteger)row;
- (void)reloadRow:(NSInteger)row;
- (void)resolveAndOpenLink:(NSString *)url;
- (BOOL)routeInternalLink:(NSDictionary *)link;
- (BOOL)routeSettingsLink:(NSDictionary *)link;
- (void)presentOauthLoginForUrl:(NSString *)url;
- (void)presentOauthMatchCodePickerForUrl:(NSString *)url
									 info:(NSDictionary *)info
									codes:(NSArray *)codes;
- (void)presentOauthConfirmForUrl:(NSString *)url info:(NSDictionary *)info matchCode:(NSString *)matchCode;
- (void)explainUnsupportedLink:(NSString *)url;
- (void)openChatId:(int64_t)targetChatId title:(NSString *)title isGroup:(BOOL)isGroup;
- (void)openChatId:(int64_t)targetChatId
			 title:(NSString *)title
		   isGroup:(BOOL)isGroup
	  focusMessage:(int64_t)messageId;
- (void)openChatId:(int64_t)targetChatId
			 title:(NSString *)title
		   isGroup:(BOOL)isGroup
	  focusMessage:(int64_t)messageId
		completion:(void (^)(TGChatViewController *chat))completion;
- (void)confirmExternalLink:(NSString *)url;
- (void)openInstantView:(NSString *)url;
- (void)openInstantView:(NSString *)url fallbackURL:(NSString *)fallbackURL;
- (void)pushRichMessageReaderWithBlocks:(NSArray *)blocks title:(NSString *)title;
- (void)openRichMessage:(NSDictionary *)m;
- (NSTimeInterval)mediaTimestampInMessage:(NSDictionary *)m;
- (void)touchedMessageBackground;

@end

@interface TGChatViewController (Gestures)

- (void)runPeerMenuOption:(NSString *)chosen;
- (void)attachReplySwipeToRowCell:(UITableViewCell<TGReplySwipeCell> *)cell;
- (void)inputBarSwiped:(UIPanGestureRecognizer *)pan;
- (void)messageBackgroundTapped:(UITapGestureRecognizer *)tap;
- (void)resetReplySwipeOnCell:(UITableViewCell<TGReplySwipeCell> *)cell;
- (void)showPeerMenuForUserId:(int64_t)userId fromView:(UIView *)view;
- (void)attachPeerGesturesToRowCell:(TGMessageRowCell *)cell;
- (void)refreshPeerGesturesInCell:(TGMessageRowCell *)cell;
- (void)insertMentionOfUser:(int64_t)userId name:(NSString *)name;
- (NSString *)publicUsernameIn:(NSDictionary *)user;
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer;
- (BOOL)hasDismissableInput;
- (BOOL)canReplyToRow:(NSInteger)row;
- (BOOL)canBeginReplySwipeOnCell:(UITableViewCell<TGReplySwipeCell> *)cell;
- (void)stopReplySwipeAnimationsInCell:(UITableViewCell<TGReplySwipeCell> *)cell;
- (void)applyReplySwipeOffset:(CGFloat)offset toCell:(UITableViewCell<TGReplySwipeCell> *)cell;
- (CGFloat)replySwipeTriggerForRow:(NSInteger)row;
- (CGFloat)replySwipeArrowInsetForRow:(NSInteger)row;
- (void)placeReplyArrowInCell:(UITableViewCell<TGReplySwipeCell> *)cell forRow:(NSInteger)row;
- (void)updateReplyArrowInCell:(UITableViewCell<TGReplySwipeCell> *)cell progress:(CGFloat)progress;
- (void)popReplyArrowInCell:(UITableViewCell<TGReplySwipeCell> *)cell;
- (void)springReplySwipeBackInCell:(UITableViewCell<TGReplySwipeCell> *)cell from:(CGFloat)offset;
- (void)replySwiped:(TGReplySwipeRecognizer *)pan;
- (void)beginReplyToRow:(NSInteger)row;
- (UIView *)bubbleViewForMessageId:(int64_t)messageId;

@end

@interface TGChatViewController (LinkHitTesting)

- (void)runHeldLinkOption:(NSString *)chosen;
- (void)runBankCardOptionIndex:(NSInteger)index;
- (void)followBankCardNumber:(NSString *)cardNumber;
- (void)showHeldLinkSheetFor:(NSString *)url;
- (NSString *)urlInLabel:(UILabel *)label atPoint:(CGPoint)point;

@end

@interface TGChatViewController (Alerts)

- (void)presentQuoteOutdatedAlertForMessageIds:(NSArray *)messageIds;
- (void)joinChatByInviteLinkRetrying:(NSString *)invite;
- (void)startPendingBotLink:(NSString *)link;
- (void)confirmJoinChatByInviteLink:(NSString *)invite info:(NSDictionary *)info;
- (NSString *)textInAlert:(UIAlertView *)alertView;
- (void)presentAiSuggestion:(NSString *)suggestion original:(NSString *)original title:(NSString *)title;

@end

@interface TGChatViewController (ActionHandlers)

- (void)forwardWithCopy:(BOOL)asCopy removeCaptions:(BOOL)removeCaptions;
- (void)runPinOption:(NSString *)chosen;
- (void)runSuggestPostTimingOption:(NSString *)title;
- (void)reportMessages:(NSArray *)messageIds optionId:(NSString *)optionId;
- (void)reportMessages:(NSArray *)messageIds optionId:(NSString *)optionId text:(NSString *)text;
- (void)runModerationAction:(NSString *)action;
- (void)performModerationAction:(NSString *)action;
- (BOOL)aiPremiumRequiredFor:(NSString *)errorMessage;
- (void)deleteMessage:(NSDictionary *)m forEveryone:(BOOL)forEveryone;
- (void)performDeleteMessage:(NSDictionary *)m forEveryone:(BOOL)forEveryone;
- (void)handleFactCheckAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex;
- (void)performAddOfferWithSendDate:(int64_t)sendDate;
- (void)performApproveSuggestedPost;
- (void)performDeclineSuggestedPostWithComment:(NSString *)comment;
- (void)showForwardOptions;
- (void)showSuggestPostTimingSheet;
- (NSString *)transcriptFor:(NSDictionary *)m;
- (void)performMessageAction:(NSString *)action;
- (void)confirmApproveSuggestedPost:(int64_t)messageId price:(NSString *)price senderName:(NSString *)senderName;
- (void)showDeclineSuggestedPostPrompt:(int64_t)messageId;
- (void)beginSuggestPostForMessageId:(int64_t)messageId currentPrice:(NSString *)priceText;
- (void)showFactCheckPromptForMessage:(int64_t)messageId existing:(NSString *)existing;
- (void)offerModerationForMessage:(NSDictionary *)m;
- (void)showPinOptionsForMessage:(int64_t)messageId;
- (void)pickQuoteFromMessage:(NSDictionary *)m;
- (BOOL)messageCanBeTranscribed:(NSDictionary *)m;
- (void)transcribeMessage:(int64_t)messageId;
- (void)scheduleTranscriptFallbackCheckForMessage:(int64_t)messageId;
- (BOOL)transcriptionUpsellRequiredFor:(NSString *)errorMessage;
- (void)showTranscriptionFailureAlertFor:(NSString *)errorMessage;
- (void)translateMessage:(int64_t)messageId;
- (void)autoTranslateMessagesIfNeeded:(NSArray *)messages;
- (void)revertAutoTranslatedMessages;
- (void)summarizeMessage:(int64_t)messageId;

@end

@interface TGChatViewController (Checklist)

- (void)performDeleteChecklistTask;
- (void)handleChecklistAddAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex;
- (void)handleChecklistEditAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex;
- (void)promptAddChecklistTaskForRow:(NSInteger)row;
- (void)toggleChecklistTaskAtIndex:(NSUInteger)index atRow:(NSInteger)row;
- (void)showChecklistTaskMenuAtIndex:(NSUInteger)index atRow:(NSInteger)row;
- (void)runChecklistTaskMenuOption:(NSString *)chosen;
- (void)promptEditChecklistTaskWithText:(NSString *)text;
- (void)promptDeleteChecklistTask;

@end

@interface TGChatViewController (Polls)

- (void)handlePollAddOptionAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex;
- (void)showPollComposer;
- (void)promptAddPollOptionForRow:(NSInteger)row;
- (void)retractPollVoteForRow:(NSInteger)row;
- (NSString *)pollSubtitleFor:(NSDictionary *)m;

@end

@interface TGChatViewController (Bots)

- (void)runBotMenu:(NSString *)chosen;
- (void)runBotButtonAtIndex:(NSInteger)index;
- (void)openBotFromEntry:(NSDictionary *)entry;
- (void)runInlineQueryForBot:(int64_t)botId query:(NSString *)query offset:(NSString *)offset;
- (void)detectBotChat;
- (void)detectGiftEligibility;
- (void)detectGroupBotCommands;
- (void)showGroupBotCommandsMenu;
- (void)runGroupBotCommandsPick:(NSInteger)index;
- (void)prefetchRecentInlineBots;
- (void)showCallbackAnswer:(NSDictionary *)answer;
- (int64_t)botChatUserId;
- (void)showBotMenu;
- (BOOL)offerBotButtonsForRow:(NSInteger)row message:(NSDictionary *)m;

@end

@interface TGChatViewController (Location)

- (void)runLocationOption:(NSString *)chosen;
- (void)showLocationOptions;

@end

@interface TGChatViewController (TextTools)

- (void)runTextToolAtIndex:(NSInteger)index;
- (void)runAiRewriteStyleAtIndex:(NSInteger)index;
- (NSString *)fragmentOf:(NSString *)text entity:(NSDictionary *)entity;
- (void)showTextTools;
- (NSString *)composerText;

@end

@interface TGChatViewController (Selection) <TGChatLayoutBridgeSelectionDelegate>

- (void)runSelectionMore:(NSString *)chosen;
- (void)deleteSelectedForEveryone:(BOOL)forEveryone;
- (void)endSelection;
- (void)toggleSelectionOfRow:(NSInteger)row;
- (UIImage *)selectionGlyphChecked:(BOOL)checked;
- (void)beginSelectionWithMessage:(int64_t)messageId;
- (void)openInfoForMessageId:(int64_t)messageId;
- (void)openInfoForMessageId:(int64_t)messageId section:(NSString *)section;
- (BOOL)saveMediaMessageToCameraRoll:(NSDictionary *)m;
- (void)autosaveMessageIfNeeded:(NSDictionary *)m;
- (void)fetchMissingSelectionPermissions;

@end

@interface TGChatViewController (AttachmentPickers)

- (void)takePhoto;
- (void)pastePhoto;
- (void)pickMusic;
- (void)pickMedia;
- (void)pickContact;
- (void)sendCurrentLocation;
- (BOOL)startLocationUpdatesRequestingAuthorizationIfNeeded;
- (void)scheduleLocationFetchTimeout;
- (void)cancelLocationFetchTimeout;
- (void)prefetchVenueLocation;
- (void)sendVenueWithCachedLocation:(CLLocation *)fix;
- (void)stopLiveLocationTrackingCleanup;
- (void)stopExpiredLiveLocationTracking;
- (void)refreshLiveLocationTimerState;
- (void)sendPendingPastedImage;
- (void)pickPhotoAlbum;
- (void)sendPickedPhotos:(NSArray *)paths spoiler:(BOOL)spoiler;
- (void)sendAlbumBatch:(NSArray *)paths caption:(NSString *)caption spoiler:(BOOL)spoiler selfDestructSeconds:(NSInteger)selfDestructSeconds replyTo:(int64_t)replyToId options:(NSDictionary *)options;
- (NSString *)stageImageForSending:(UIImage *)image;
- (void)presentSendPreviewForImage:(UIImage *)image
						  videoPath:(NSString *)videoPath
					  videoDuration:(NSTimeInterval)videoDuration
						  videoSize:(CGSize)videoSize;
- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker;
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error;
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status;
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)picker;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
- (void)handleAttachPickOfMovie:(NSString *)moviePath image:(UIImage *)image assetURL:(NSURL *)assetURL;
- (void)finishSendingDocumentAtPath:(NSString *)path;
- (void)sendOriginalAssetAsDocumentAtURL:(NSURL *)assetURL fallbackImage:(UIImage *)fallbackImage;
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations;
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)picker
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person
								 property:(ABPropertyID)property
							   identifier:(ABMultiValueIdentifier)identifier;

@end

@interface TGChatViewController (Stickers)

- (void)showGifPicker;
- (void)showQuickReplies;
- (void)toggleStickerPanel;
- (void)openStickerSetWithId:(int64_t)setId;

@end

@interface TGChatViewController (Geometry)

- (NSString *)quoteKindLabelFor:(NSDictionary *)original;
- (void)openProfileForUserId:(int64_t)userId;
- (void)openForwardOriginUser:(int64_t)userId title:(NSString *)title;
- (void)openForwardOriginChat:(int64_t)chatId
						title:(NSString *)title
					  message:(int64_t)messageId;
- (void)openForwardOriginForRow:(NSInteger)row;
- (void)openCommentsForRow:(NSInteger)row;
- (TGRichTextPalette *)bodyPaletteFor:(NSDictionary *)m;
- (NSArray *)entitiesOf:(NSDictionary *)m;
- (BOOL)rowCarriesForwardAvatar:(NSDictionary *)m;
- (CGFloat)maxBubbleWidthFor:(NSDictionary *)m;
- (BOOL)messageBurnsOnOpening:(NSDictionary *)m;
- (void)applyPictureTo:(UIImageView *)view message:(NSDictionary *)m;
- (NSString *)stampFor:(NSDictionary *)m;
- (BOOL)quoteIsVideoNoteFor:(NSDictionary *)m;
- (BOOL)mediaSpoilerActiveForMessage:(NSDictionary *)m;
- (NSInteger)largeEmojiCountFor:(NSDictionary *)m;
- (NSNumber *)pictureFileIdFor:(NSDictionary *)m;
- (UIFont *)bodyFontFor:(NSDictionary *)m;
- (TGRichTextLayout *)bodyLayoutFor:(NSDictionary *)m;
- (UIImage *)imageFor:(NSDictionary *)m;
- (BOOL)pictureFailedFor:(NSDictionary *)m;
- (UIImage *)retryGlyphOfSide:(CGFloat)side;
- (CGFloat)bubbleWidthBudget;
- (CGSize)declaredPixelSizeFor:(NSDictionary *)m;
- (CGSize)imageSizeFor:(NSDictionary *)m;
- (NSString *)quoteKindLabelFor:(NSDictionary *)m;
- (CGFloat)mediaMaxSide;
- (CGSize)drawnSizeForImageSize:(CGSize)source;
- (TGFileStatusKind)mediaStatusKindFor:(NSDictionary *)m state:(NSDictionary *)state;
- (NSString *)mediaBadgeTextFor:(NSDictionary *)m;
- (CGFloat)decodeLimitFor:(NSDictionary *)m;
- (NSString *)bubbleTextFor:(NSDictionary *)m;
- (NSString *)dayStringForMessage:(NSDictionary *)m;
- (BOOL)forwardOriginIsReachable:(NSDictionary *)m;
- (BOOL)messageIsSticker:(NSDictionary *)m;
- (NSString *)quoteAuthorFor:(NSDictionary *)m;
- (NSString *)quoteDisplayTextFor:(NSDictionary *)m;
- (NSArray *)quoteEntitiesFor:(NSDictionary *)m;
- (NSString *)quoteTextFor:(NSDictionary *)m;
- (UIImage *)quoteThumbnailFor:(NSDictionary *)m;
- (BOOL)rowOpensNewDay:(NSInteger)row;
- (NSInteger)unreadDividerRow;
- (NSString *)viewCountTextFor:(NSDictionary *)m;
- (void)warmMinithumbnailsFor:(NSArray *)messages;

@end

@interface TGChatViewController (SendState)

- (NSString *)sendStateForMessage:(NSDictionary *)m;
- (BOOL)canResendMessage:(NSDictionary *)m;

@end

@interface TGChatViewController (Mentions)

- (void)loadUnreadMentions;
- (void)loadUnreadReactions;
- (void)unreadMentionsUpdateReceived:(NSNotification *)note;
- (void)unreadReactionsUpdateReceived:(NSNotification *)note;

@end

@interface TGChatViewController (TapReactions)

- (NSString *)originalTextOf:(NSDictionary *)m;
- (NSArray *)originalEntitiesOf:(NSDictionary *)m;
- (BOOL)messageHasQuotableText:(NSDictionary *)m;
- (void)showActionsForRow:(NSInteger)row;
- (void)messageDoubleTapped:(UITapGestureRecognizer *)tap;
- (void)setPressedRow:(NSInteger)row;
- (void)showActionsSheetForRow:(NSInteger)row;
- (NSString *)textOf:(NSDictionary *)m;
- (void)showReactionPickerForMessage:(int64_t)messageId fromView:(UIView *)source;
- (NSString *)savableMediaKindFor:(NSDictionary *)m;
- (TGRichTextLayout *)textSelectionLayoutFor:(NSDictionary *)m text:(NSString *)text;
- (void)beginTextSelectionForMessage:(NSDictionary *)m;
- (void)endTextSelection;
- (void)repaintBubbleArtworkOnRow:(NSInteger)row;
- (void)sendQuickReactionToMessage:(int64_t)messageId;

@end

@interface TGChatViewController (Search)

- (void)searchChatForTag:(NSString *)tag;
- (void)toggleChatSearch;
- (UIImage *)avatarForUser:(int64_t)userId name:(NSString *)name;
- (UIImage *)avatarForChat:(int64_t)chatId name:(NSString *)name;

@end

@interface TGChatViewController (MessageActions) <EKEventEditViewDelegate>

- (void)searchEverywhereForTag:(NSString *)tag;
- (void)showPhoneMenuFor:(NSString *)number atPoint:(CGPoint)where;
- (void)showPhoneMenuFor:(NSString *)number atPoint:(CGPoint)where
				firstName:(NSString *)firstName
				 lastName:(NSString *)lastName;

@end

@interface TGChatViewController (ReadState)

- (void)flushChannelViewMetricsExceptForIds:(NSSet *)exceptIds;
- (void)markVisibleMessagesRead;
- (NSInteger)unreadMessagesStillBelow;

@end

@interface TGChatViewController (LayoutBridge) <TGBubbleCellDelegate>

- (NSDictionary *)albumCaptionMessageAtRow:(NSInteger)row;
- (void)jumpToQuoteAtRow:(NSInteger)row;
- (void)tg_refreshLayoutContextIfNeeded;
- (void)tg_rebuildLayoutBridgeItems;
- (void)tg_invalidateLayoutForMessageId:(int64_t)messageId;
- (void)tg_invalidateLayoutForRepliesToMessageId:(int64_t)originId;
- (void)tg_invalidateLayoutForSenderNameArrived:(int64_t)userId;
- (TGChatLayoutContext *)tg_buildLayoutContext;
- (void)tg_captureLayoutContextInputs;

@end

@interface TGChatViewController (MentionAutocomplete)

- (BOOL)mentionAutocompleteEligible;
- (void)updateMentionSuggestions;
- (void)showMentionCandidates:(NSArray *)candidates;
- (void)buildMentionSuggestions;
- (void)clearMentionSuggestions;
- (void)insertMentionCandidate:(NSDictionary *)candidate;

@end

@interface TGChatViewController (InlineBotAutocomplete)

- (BOOL)updateInlineBotQueryTrigger;
- (void)clearInlineBotQuery;
- (void)showInlineQueryResults:(NSArray *)results buttonText:(NSString *)buttonText;
- (void)appendInlineQueryResults:(NSArray *)results;
- (void)loadMoreInlineQueryResults;
- (int64_t)cachedInlineBotIdForUsername:(NSString *)username;
- (void)resolveInlineBotUsername:(NSString *)username;
- (void)scheduleInlineQueryForBot:(int64_t)botId query:(NSString *)query;
- (void)buildInlineQueryStrip;
- (void)sendInlineQueryResult:(NSDictionary *)result;

@end

@interface TGChatViewController (ComposeBanner)

- (void)clearComposeState;
- (void)cancelComposeState;
- (void)setComposeMode:(TGComposeMode)mode messageId:(int64_t)messageId;
- (void)showComposeBanner:(NSString *)text;

@end
