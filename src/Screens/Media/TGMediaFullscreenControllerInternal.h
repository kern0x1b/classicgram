#import "TGMediaFullscreenController.h"
#import "TGMediaProgressRing.h"

#import <MediaPlayer/MediaPlayer.h>

@class TGMediaPageView;

@interface TGMediaFullscreenController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, UIActionSheetDelegate> {
	NSMutableArray *_items;
	NSInteger _startIndex;
	NSInteger _currentIndex;
	NSInteger _busyPageIndex;

	UIScrollView *_pagingView;
	UIPanGestureRecognizer *_dismissPan;
	CGSize _validSize;
	NSMutableDictionary *_visiblePages;
	NSMutableArray *_pagePool;
	NSMutableDictionary *_imageCache;

	UIImageView *_topBar;
	UIImageView *_topCorners;
	UILabel *_counterLabel;
	UILabel *_burnCountdownLabel;
	NSTimer *_burnCountdownTimer;
	NSInteger _burnSecondsRemaining;
	UILabel *_dateLabel;
	UIImageView *_bottomBar;
	UIView *_controlsContainer;
	UIView *_progressContainer;
	UILabel *_progressLabel;
	UIActivityIndicatorView *_progressSpinner;
	UILabel *_authorLabel;
	UIButton *_playButton;
	UIButton *_actionButton;
	UIButton *_deleteButton;
	UIActivityIndicatorView *_spinner;
	NSMutableSet *_failedPages;
	NSMutableSet *_prefetchedFiles;
	NSArray *_sheetActions;
	NSArray *_stickerSetChoices;
	NSNumber *_pendingForwardMessageId;

	UILabel *_captionLabel;
	UIView *_captionPanel;
	TGMediaProgressRing *_progressRing;
	NSNumber *_ringFileId;
	id _fileProgressObserverToken;
	id _backgroundObserverToken;

	BOOL _chromeHidden;
	BOOL _dismissing;
	BOOL _statusBarWasHidden;

	MPMoviePlayerController *_inlinePlayer;
	NSInteger _inlinePlayerIndex;
	BOOL _inlinePlaying;
	id _inlinePlaybackDidFinishObserverToken;
}

@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, assign) NSInteger startIndex;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) NSInteger busyPageIndex;

@property (nonatomic, strong) UIScrollView *pagingView;
@property (nonatomic, strong) UIPanGestureRecognizer *dismissPan;
@property (nonatomic, assign) CGSize validSize;
@property (nonatomic, strong) NSMutableDictionary *visiblePages;
@property (nonatomic, strong) NSMutableArray *pagePool;
@property (nonatomic, strong) NSMutableDictionary *imageCache;

@property (nonatomic, strong) UIImageView *topBar;
@property (nonatomic, strong) UIImageView *topCorners;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UILabel *burnCountdownLabel;
@property (nonatomic, strong) NSTimer *burnCountdownTimer;
@property (nonatomic, assign) NSInteger burnSecondsRemaining;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *bottomBar;
@property (nonatomic, strong) UIView *controlsContainer;
@property (nonatomic, strong) UIView *progressContainer;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UIActivityIndicatorView *progressSpinner;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSMutableSet *failedPages;
@property (nonatomic, strong) NSMutableSet *prefetchedFiles;
@property (nonatomic, strong) NSArray *sheetActions;
@property (nonatomic, strong) NSArray *stickerSetChoices;
@property (nonatomic, strong) NSNumber *pendingForwardMessageId;

@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UIView *captionPanel;
@property (nonatomic, strong) TGMediaProgressRing *progressRing;
@property (nonatomic, strong) NSNumber *ringFileId;

@property (nonatomic, assign) BOOL chromeHidden;
@property (nonatomic, assign) BOOL dismissing;
@property (nonatomic, assign) BOOL statusBarWasHidden;

@property (nonatomic, strong) MPMoviePlayerController *inlinePlayer;
@property (nonatomic, assign) NSInteger inlinePlayerIndex;
@property (nonatomic, assign) BOOL inlinePlaying;

- (NSDictionary *)currentItem;
@end

@interface TGMediaFullscreenController (Chrome)

- (void)buildPagingView;
- (void)buildTopBar;
- (void)buildBottomBar;
- (void)buildCaptionPanel;
- (void)buildOverlayAndGestures;
- (void)layoutCaptionPanel;
- (void)layoutTopBar;
- (void)updateChromeForCurrentItem;
- (void)setChromeHidden:(BOOL)hidden animated:(BOOL)animated;
- (void)installProgressHook;
- (void)removeProgressHook;
- (void)stopBurnCountdown;

@end

@interface TGMediaFullscreenController (Paging)

- (void)layoutPagesPreservingIndex:(NSInteger)index;
- (void)recyclePage:(TGMediaPageView *)page forKey:(NSNumber *)key;
- (void)updateLoadingChrome;
- (void)retryTapped;

@end

@interface TGMediaFullscreenController (Actions)

- (void)installBackgroundObserver;
- (void)removeBackgroundObserver;
- (void)showMessage:(NSString *)message;
- (void)closeTapped;
- (void)showCurrentItemInChat;
- (void)saveCurrentItem;
- (void)forwardCurrentItem;
- (void)pushForwardPickerForMessageId:(int64_t)messageId asCopy:(BOOL)asCopy removeCaptions:(BOOL)removeCaptions;
- (void)presentActionsSheetWithItem:(NSDictionary *)item canForward:(BOOL)canForward canSave:(BOOL)canSave hasFile:(BOOL)hasFile;
- (void)presentDeleteSheetForItem:(NSDictionary *)item canDeleteForEveryone:(BOOL)canDeleteForEveryone;
- (void)deleteCurrentItemForEveryone:(BOOL)forEveryone;
- (void)lookupStickerForCurrentItem;

@end

@interface TGMediaFullscreenController (Playback)

- (void)stopInlinePlayer;

@end
