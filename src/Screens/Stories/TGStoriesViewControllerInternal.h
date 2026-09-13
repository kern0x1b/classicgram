#import <UIKit/UIKit.h>
#import "TGStoriesViewController.h"
#import "TGReactionPickerView.h"

@class TGStoryPage;

@interface TGStoriesViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate,
	UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
	int64_t _chatId;
	NSArray *_storyIds;
	NSInteger _index;
	NSMutableDictionary *_stories;
	NSMutableSet *_seen;
	NSInteger _openStoryId;

	NSMutableArray *_posterList;
	NSInteger _posterIndex;
	BOOL _postersRequested;
	BOOL _dismissing;

	UIView *_stripView;
	UIScrollView *_pagingView;
	NSMutableArray *_visiblePages;
	NSMutableArray *_pageQueue;
	UIView *_footerView;
	UIButton *_replyButton;
	UIButton *_middleButton;
	UIButton *_shareButton;
	UIImageView *_topPanel;
	UIImageView *_bottomPanel;
	UILabel *_counterLabel;
	UILabel *_authorLabel;
	UILabel *_dateLabel;
	UIButton *_closeButton;
	UIButton *_actionButton;
	UIButton *_deleteButton;
	BOOL _navigationBarWasHidden;
	NSInteger _reportStoryId;
	int64_t _reportChatId;
	BOOL _repostingStory;

	__weak TGReactionPickerView *_reactionPicker;
	NSTimer *_timer;
	NSTimeInterval _elapsed;
	BOOL _holdPaused;
	BOOL _modalPaused;
	BOOL _onScreen;
}
@end

@interface TGStoriesViewController (Private)

- (void)tearDownPaging;

- (NSString *)resolvedPosterName;
- (BOOL)isOwnStory;
- (NSDictionary *)currentStory;
- (NSInteger)currentStoryId;

- (void)viewDidLoad;

- (UILabel *)panelLabelWithFont:(UIFont *)font frame:(CGRect)frame;

- (UIButton *)platedButtonWithTitle:(NSString *)title
						   minWidth:(CGFloat)minWidth
							 action:(SEL)action;

- (UIButton *)panelButtonWithImageNamed:(NSString *)name
							   fallback:(NSString *)fallback
								 action:(SEL)action;

- (void)buildTopPanel;

- (void)buildBottomPanel;

- (void)closeTapped;

- (void)deleteTapped;

- (UIButton *)footerButtonWithTitle:(NSString *)title action:(SEL)action;

- (void)buildFooter;

- (void)viewWillLayoutSubviews;

- (void)layoutFooter;

- (void)layoutStrip;

- (void)updateStrip;

- (BOOL)timelineShouldRun;

- (void)updateTimeline;

- (void)resetTimeline;

- (NSTimeInterval)currentStoryDuration;

- (void)updateVideoPlaybackForPauseState;

- (void)setHoldPaused:(BOOL)paused;

- (void)setModalPaused:(BOOL)paused;

- (void)timelineTick;

- (void)viewWillAppear:(BOOL)animated;

- (void)viewDidAppear:(BOOL)animated;

- (void)viewWillDisappear:(BOOL)animated;

- (void)dealloc;

- (void)didReceiveMemoryWarning;

- (void)closeCurrent;

- (CGRect)frameForPageIndex:(NSInteger)index;

- (TGStoryPage *)dequeuePage;

- (void)recycleSparePage:(TGStoryPage *)page;

- (TGStoryPage *)pageForIndex:(NSInteger)index;

- (void)resetPagingGeometry;

- (void)layoutPages;

- (void)setCurrentIndex:(NSInteger)index;

- (void)loadPage:(TGStoryPage *)page;

- (NSNumber *)currentStoryKey;

- (UIImage *)currentImage;

- (void)cancelPhotoForPage:(TGStoryPage *)page;

- (void)cancelAllPhotoLoads;

- (void)loadPhotoForPage:(TGStoryPage *)page story:(NSDictionary *)story;

- (void)retryFailedPages;

- (void)showIndex:(NSInteger)index animated:(BOOL)animated;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView;

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

- (NSDictionary *)posterEntryForCurrentChat;

- (void)discoverPosters;

- (void)appendDiscoveredPosters:(NSMutableArray *)found;

- (void)movePosterBy:(NSInteger)delta;

- (void)dismissViewer;

- (void)viewDragged:(UIPanGestureRecognizer *)recognizer;

- (void)viewHeld:(UILongPressGestureRecognizer *)recognizer;

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer;

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch;

- (BOOL)pointIsOnChrome:(CGPoint)point;

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
	shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other;

- (void)updateChrome;

- (void)viewTapped:(UITapGestureRecognizer *)recognizer;

- (BOOL)handleAreaTapOnPage:(TGStoryPage *)page atPoint:(CGPoint)point;

- (void)openAreaMapAtLatitude:(double)latitude longitude:(double)longitude title:(NSString *)title;

- (void)presentVenueAreaOptionsWithLatitude:(double)latitude longitude:(double)longitude
									  title:(NSString *)title
								   provider:(NSString *)provider
									venueId:(NSString *)venueId;

- (void)openAreaMessageInChat:(int64_t)chatId messageId:(int64_t)messageId;

- (void)openLink:(NSString *)link;

- (NSString *)hashtagInCaption;

- (void)sendReaction:(NSString *)emoji;

- (void)replyPressed;

- (void)middlePressed;

- (void)middleHeld:(UILongPressGestureRecognizer *)recognizer;

- (void)sharePressed;

- (NSMutableArray *)moreActions;

- (void)appendOtherPosterActionsTo:(NSMutableArray *)actions;

- (void)appendStoryStateActionsTo:(NSMutableArray *)actions story:(NSDictionary *)story;

- (void)morePressed;

- (void)askStoryPrivacy;

- (void)presentStoryPrivacySheetForStoryId:(NSInteger)storyId
							  exceptUserIds:(NSArray *)exceptUserIds
							selectedUserIds:(NSArray *)selectedUserIds;

- (void)performMoreAction:(NSString *)action;

- (void)activateStealthMode;

- (void)askCoverFrameChoice;

- (void)openStoryStatistics;

- (void)saveCurrentImageToPhotos;

- (void)hideStoriesFromCurrentPoster;

- (void)toggleOnProfileForStoryId:(NSInteger)storyId;

- (void)confirmDeleteStoryId:(NSInteger)storyId;

- (void)openHashtagSearch;

- (void)openVenueSearchWithProvider:(NSString *)provider venueId:(NSString *)venueId title:(NSString *)title;

- (void)openMyStories;

- (NSArray *)unreadStoryIds;

- (void)markRemainingRead;

- (void)replacePhoto;

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;

- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info;

- (void)applyReplacementPhotoAtPath:(NSString *)path forStoryId:(NSInteger)storyId;

- (void)reportWithOptionId:(NSString *)optionId text:(NSString *)text;

- (void)handleReportResult:(NSDictionary *)result;

- (void)presentReportOptions:(NSDictionary *)result;

- (void)askReportCommentWithOptionId:(NSString *)optionId optional:(BOOL)optional;

@end
