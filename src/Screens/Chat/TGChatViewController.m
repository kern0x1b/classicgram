#import "TGClient+ChatManagement.h"
#import "TGPollUpdateMerge.h"
#import "TGChatViewController.h"
#import "TGLocalization.h"
#import "TGLinkPreviewView.h"
#import "TGFileStatusView.h"
#import "TGReplySwipeRecognizer.h"
#import "TGMessageInfoViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGMosaicTileView.h"
#import "TGChatInputTextView.h"
#import "TGChatMessageLayout.h"
#import "TGChatLayoutBridge.h"
#import "TGChatPresenter.h"
#import "TGChatLayoutContext.h"
#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGMessageItemBuilder.h"
#import "TGMessageItemResolvedInputs.h"
#import "TGChatComposerState.h"
#import "TGLiveLocationMessageIdRemap.h"
#import "TGChatUpgradeMarkerFilter.h"
#import "TGClient+Notifications.h"
#import "TGClient.h"
#import "TGClient+UserStatus.h"
#import "TGClient+SavedMessages.h"
#import "AppDelegate.h"
#import "TGTheme.h"
#import "TGPreferenceFlags.h"
#import "TGIcons.h"
#import "TGForwardPicker.h"
#import "TGVoiceRecorder.h"
#import "TGPollComposerViewController.h"
#import "TGMosaicLayout.h"
#import "TGEmoji.h"
#import "TGRichText.h"
#import "TGCustomEmojiCache.h"
#import "TGLazyFramework.h"
#import "TGDiskCache.h"
#import "TGByteFormat.h"
#import <AddressBookUI/AddressBookUI.h>
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>
#import "TGVoiceDecoder.h"
#import "TGMusicPlayer.h"
#import "TGAudioMetadata.h"
#import "UIImage+WebP.h"
#import "TGLottieView.h"
#import "UIView+SafeTint.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGReactionPickerView.h"
#import "TGMessageActionsSheet.h"
#import "TGTextSelectionOverlay.h"
#import "TGStickerPanelView.h"
#import "TGQuickReplyListViewController.h"
#import "TGStickerSuggestionStrip.h"
#import "TGClient+Messages.h"
#import "TGClient+Reactions.h"
#import "TGQuotePickerViewController.h"
#import "TGScheduledMessagesViewController.h"
#import "TGAssetPicker.h"
#import <ImageIO/ImageIO.h>
#import "TGImageDecode.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGDayCalendarView.h"
#import "TGPlateMetrics.h"

const NSTimeInterval kDeferredActionDelay = 1.0;
const NSTimeInterval kTranscriptFallbackDelay = 30.0;
const CGFloat kInputHeight = 43.0f;
const CGFloat kFloatingButtonSide = 36.0f;
const CGFloat kFloatingButtonGap = 7.0f;
const CGFloat kComposeBannerHeight = 28.0f;
const NSInteger kPinnedBannerHighlightTag = 991;
const NSInteger kPinnedBannerCaptionTag = 992;
const NSInteger kPinnedBannerBodyTag = 993;
static void TGApplyIncomingTranscript(NSMutableDictionary *transcripts,
	NSMutableSet *transcriptsPending, NSNumber *messageId, NSDictionary *message) {
	NSDictionary *transcript = [message[@"transcript"] isKindOfClass:NSDictionary.class]
		? message[@"transcript"]
		: nil;
	NSString *state = [transcript[@"state"] isKindOfClass:NSString.class] ? transcript[@"state"] : nil;
	if ([state isEqualToString:@"text"]) {
		NSString *text = [transcript[@"text"] isKindOfClass:NSString.class] ? transcript[@"text"] : @"";
		transcripts[messageId] = text.length ? text : TGL(@"Message.AudioTranscription.ErrorEmpty", @"No speech was recognised.");
		[transcriptsPending removeObject:messageId];
		return;
	}
	if ([state isEqualToString:@"pending"]) {
		NSString *partial = [transcript[@"text"] isKindOfClass:NSString.class] ? transcript[@"text"] : @"";
		if (partial.length && ![transcripts[messageId] isEqualToString:partial])
			transcripts[messageId] = partial;
		return;
	}
	[transcripts removeObjectForKey:messageId];
}

const CGFloat kBubbleTailOverhang = 6.0f;
const CGFloat kBubbleTailCap = 12.0f;
const CGFloat kRetinaPixel = 0.5f;
const CGFloat kBubbleMinW = 40.0f;
const CGFloat kBubbleMinH = 31.0f;
const CGFloat kBubbleMaxW = 244.0f;
const CGFloat kBubbleReferenceWidth = 320.0f;
const CGFloat kBubbleBudgetAtReference = 250.0f;
const CGFloat kBubbleOutgoingTrim = 12.0f;
const CGFloat kBubbleAvatarTrim = 40.0f;
const CGFloat kPadH = 10.0f;
const CGFloat kAvatarSide = 38.0f;
const CGFloat kSenderAvatarRadius = kAvatarSide * 0.12f;
const CGFloat kPadV = 5.0f;
const CGFloat kForwardJumpSide = 24.0f;
const CGFloat kForwardJumpGap = 4.0f;

BOOL TGChatIsPad(void) {
	static BOOL pad = NO;
	static BOOL known = NO;
	if (!known) {
		known = YES;
		pad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
	}
	return pad;
}

CGFloat TGMessageBaseFontSize(void) {
	CGFloat size = [TGTheme shared].messageFontSize;
	return size > 0 ? size : 16.0f;
}

UIColor *TGMessageBodyColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:20 / 255.0f green:22 / 255.0f
								  blue:23 / 255.0f
								 alpha:1.0f];
	return colour;
}

NSString *TGFoldLineBreaks(NSString *text) {
	if ([text rangeOfString:@"\n"].location == NSNotFound)
		return text;
	NSArray *pieces = [text componentsSeparatedByCharactersInSet:
			[NSCharacterSet newlineCharacterSet]];
	NSMutableArray *kept = [NSMutableArray array];
	for (NSString *piece in pieces) {
		NSString *trimmed = [piece stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceCharacterSet]];
		if (trimmed.length)
			[kept addObject:trimmed];
	}
	return [kept componentsJoinedByString:@" "];
}

UIColor *TGMessageLinkColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0x00 / 255.0f green:0x4b / 255.0f
								  blue:0xad / 255.0f
								 alpha:1.0f];
	return colour;
}
const CGFloat kImageMax = 200.0f;
const NSUInteger kPictureMemoryBudget = 5 * 1024 * 1024;
const NSUInteger kMaxLivePictures = 12;
const CGFloat kDayRowHeight = 27.0f;
const CGFloat kUnreadRowHeight = 34.0f;
const NSInteger kHistoryPageLimit = 60;
const CGFloat kOlderHistoryTriggerOffset = 400.0f;
const NSInteger kUnreadContextRows = 12;
const NSInteger kRestoreContextRows = 25;
const NSInteger kUnreadSlack = 4;
const NSInteger kDayJumpContextRows = 12;
const CGFloat kSystemPlateHeight = 21.0f;

UIColor *TGSystemPlateColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:70 / 255.0f green:99 / 255.0f
								  blue:126 / 255.0f
								 alpha:0.4f];
	return colour;
}

UIImage *TGUnreadDividerImage(void) {
	static UIImage *image = nil;
	static BOOL looked = NO;
	if (!looked) {
		looked = YES;
		UIImage *raw = [UIImage imageNamed:@"ConversationNewMessagesDivider"];
		if (raw)
			image = [raw stretchableImageWithLeftCapWidth:1 topCapHeight:0];
	}
	return image;
}

UIImage *TGUnreadArrowImage(void) {
	static UIImage *image = nil;
	if (image)
		return image;
	CGSize size = CGSizeMake(11, 8);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(ctx, 2.0f);
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);
	CGContextSetRGBStrokeColor(ctx, 140 / 255.0f, 162 / 255.0f, 182 / 255.0f, 1.0f);
	CGContextMoveToPoint(ctx, 1.5f, 1.5f);
	CGContextAddLineToPoint(ctx, 5.5f, 6.0f);
	CGContextAddLineToPoint(ctx, 9.5f, 1.5f);
	CGContextStrokePath(ctx);
	image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

const CGFloat kAudioPairHeight = 40.0f;
const CGFloat kAudioClockGap = 10.0f;
const CGFloat kAudioCoverDisc = 32.0f;
const CGFloat kVoiceDiscSide = 36.0f;

const CGFloat kAlbumGap = 2.0f;
const CGFloat kMosaicMinTileSide = 68.0f;

const CGFloat kPollRow = 30.0f;
const CGFloat kChecklistRow = 26.0f;
const NSInteger kRichMessageCardTag = 0x9012;
const CGFloat kFileCellPairHeight = 38.0f;
const CGFloat kSignatureHeight = 14.0f;
const CGFloat kSignatureTopGap = 2.0f;
const CGFloat kChipsBubbleTopPad = 4.0f;
const CGFloat kChipsBubbleBottomPad = 6.0f;
const CGFloat kChipsBareTopPad = 6.0f;
const CGFloat kChipsBareBottomPad = 2.0f;
const NSUInteger kLargeEmojiTextLimit = 64;

const CGFloat kMapCardW = 220.0f;
const CGFloat kMapCardH = 130.0f;

UIImage *TGImageDrawnAtPointSize(UIImage *source, CGSize points) {
	if (!source || points.width < 1 || points.height < 1)
		return source;
	CGFloat screen = [UIScreen mainScreen].scale;
	if (source.size.width * source.scale <= points.width * screen &&
		source.size.height * source.scale <= points.height * screen)
		return source;
	UIGraphicsBeginImageContextWithOptions(points, NO, 0.0f);
	[source drawInRect:CGRectMake(0, 0, points.width, points.height)];
	UIImage *smaller = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return smaller ?: source;
}

BOOL TGTextIsRightToLeft(NSString *text) {
	NSInteger length = text.length;
	for (NSInteger i = 0; i < length; i++) {
		unichar c = [text characterAtIndex:i];
		if (c >= 0xD800 && c <= 0xDBFF) {
			i++;
			continue;
		}
		if ((c >= 0x0590 && c <= 0x08FF) ||
			(c >= 0xFB1D && c <= 0xFDFF) ||
			(c >= 0xFE70 && c <= 0xFEFF))
			return YES;
		if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
			(c >= 0x00C0 && c <= 0x058F) ||
			(c >= 0x0900 && c <= 0x1FFF) ||
			(c >= 0x2C00 && c <= 0xD7FF) ||
			(c >= 0xF900 && c <= 0xFB17))
			return NO;
	}
	return NO;
}

#pragma mark - bubble cell

NSString *TGFormatByteCount(long long bytes) {
	if (bytes <= 0)
		return @"";
	return TGMediaFormatBytes(bytes);
}

#pragma mark - controller

@implementation TGChatViewController

@dynamic composeMode;
@dynamic pressedRow;

#pragma mark - layout

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	[self resolveOpenAnchor];

	if (self.chatId != 0 && self.savedTopicId == 0 &&
		self.chatId == [[TGClient shared] savedMessagesChatId])
		self.chatTitle = TGSavedMessagesTitle();

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self buildBackButton];
	[self buildTitleView];
	self.mosaics = [NSMutableDictionary dictionary];
	self.pendingCustomEmojiRuns = [NSMutableArray array];
	self.pendingMentionRuns = [NSMutableArray array];
	self.pendingStyleEntities = [NSMutableArray array];
	self.mentionTriggerRange = NSMakeRange(NSNotFound, 0);
	self.composerCustomEmojiOverlayViews = [NSMutableArray array];
	self.tileSizes = [NSMutableDictionary dictionary];
	self.tileBitmaps = [NSMutableDictionary dictionary];
	self.tileBitmapsRequested = [NSMutableSet set];
	self.messages = @[];
	self.senderAvatars = [NSMutableDictionary dictionary];
	self.senderAvatarsRequested = [NSMutableSet set];
	self.senderChatAvatars = [NSMutableDictionary dictionary];
	self.senderChatAvatarsRequested = [NSMutableSet set];
	self.images = [NSMutableDictionary dictionary];
	self.imageOrder = [NSMutableArray array];
	self.imagesRequested = [NSMutableSet set];
	self.photoFilesInFlight = [NSMutableSet set];
	self.photoFilesCancelled = [NSMutableSet set];
	self.photoFilesFailed = [NSMutableSet set];
	self.filesBeingFetched = [NSMutableSet set];
	self.minithumbnails = [NSMutableDictionary dictionary];
	self.photoWindow = NSMakeRange(NSNotFound, 0);
	self.lottiePaths = [NSMutableDictionary dictionary];
	self.stickerOutlineImages = [NSMutableDictionary dictionary];
	self.stickerOutlinesRequested = [NSMutableSet set];
	self.maps = [NSMutableDictionary dictionary];
	self.mapsRequested = [NSMutableSet set];
	self.quotes = [NSMutableDictionary dictionary];
	self.quotesRequested = [NSMutableSet set];
	self.quotesMissing = [NSMutableSet set];
	self.voiceFilesRequested = [NSMutableSet set];
	self.reactionChips = [NSMutableDictionary dictionary];
	self.reactionChipsRequested = [NSMutableSet set];
	self.quickReactionRequestsInFlight = [NSMutableSet set];
	self.chipsRowSizes = [NSMutableDictionary dictionary];
	self.commentCounts = [NSMutableDictionary dictionary];
	self.viewCounts = [NSMutableDictionary dictionary];
	self.linkPreviews = [NSMutableDictionary dictionary];
	self.linkPreviewsRequested = [NSMutableSet set];
	self.selectedIds = [NSMutableArray array];
	self.nonForwardableMessageIds = [NSMutableSet set];
	self.nonSaveableMessageIds = [NSMutableSet set];
	self.nonCopyableMessageIds = [NSMutableSet set];
	self.nonDeletableForEveryoneMessageIds = [NSMutableSet set];
	self.selectionPermissionsRequested = [NSMutableSet set];
	self.forwardPermissionKnownMessageIds = [NSMutableSet set];
	self.translations = [NSMutableDictionary dictionary];
	self.translationEntities = [NSMutableDictionary dictionary];
	self.translationsPending = [NSMutableDictionary dictionary];
	self.autoTranslatedMessageIds = [NSMutableSet set];
	self.aiSummaries = [NSMutableDictionary dictionary];
	self.transcripts = [NSMutableDictionary dictionary];
	self.transcriptsPending = [NSMutableSet set];
	self.bodyLayouts = [NSMutableDictionary dictionary];
	self.bodyLayoutOrder = [NSMutableArray array];
	self.revealedSpoilers = [NSMutableSet set];
	self.revealedMediaSpoilers = [NSMutableSet set];
	self.expandedQuotes = [NSMutableDictionary dictionary];
	self.sendStates = [NSMutableDictionary dictionary];
	self.sendStatesRequested = [NSMutableSet set];
	self.pollPendingSelections = [NSMutableDictionary dictionary];
	self.pollVotesInFlight = [NSMutableSet set];
	self.readMessageIds = [NSMutableSet set];
	self.channelViewMetricsStart = [NSMutableDictionary dictionary];
	self.mentionIds = [NSMutableArray array];
	self.view.backgroundColor = [[TGTheme shared] chatBackgroundColour];

	CGRect b = self.view.bounds;

	self.table = [[UITableView alloc] initWithFrame:
			CGRectMake(0, 0, b.size.width, b.size.height - kInputHeight)];
	self.table.dataSource = self;
	self.table.delegate = self;
	self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.table.backgroundColor = [UIColor clearColor];
	self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	self.wallpaperView = [[UIImageView alloc] initWithFrame:self.view.bounds];
	self.wallpaperView.contentMode = UIViewContentModeScaleAspectFill;
	self.wallpaperView.clipsToBounds = YES;
	self.wallpaperView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:self.wallpaperView];
	[self loadChatWallpaper];
	[self loadChatTheme];

	self.messageHold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(messageHeld:)];
	self.messageHold.minimumPressDuration = 0.3;
	self.messageHold.allowableMovement = 10.0f;
	self.messageHold.cancelsTouchesInView = YES;
	self.messageHold.delegate = self;
	[self.table addGestureRecognizer:self.messageHold];

	UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(messageDoubleTapped:)];
	doubleTap.numberOfTapsRequired = 2;
	[self.table addGestureRecognizer:doubleTap];

	self.backgroundTap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(messageBackgroundTapped:)];
	self.backgroundTap.cancelsTouchesInView = NO;
	self.backgroundTap.delaysTouchesBegan = NO;
	self.backgroundTap.delaysTouchesEnded = NO;
	self.backgroundTap.delegate = self;
	[self.table addGestureRecognizer:self.backgroundTap];

	self.swipingRow = -1;
	self.pressedRow = -1;

	[self.view addSubview:self.table];

	[self buildInputBar:b];

	self.inputBarDismissSwipe = [[UIPanGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(inputBarSwiped:)];
	self.inputBarDismissSwipe.cancelsTouchesInView = NO;
	self.inputBarDismissSwipe.delaysTouchesBegan = NO;
	self.inputBarDismissSwipe.delaysTouchesEnded = NO;
	self.inputBarDismissSwipe.delegate = self;
	[self.inputBar addGestureRecognizer:self.inputBarDismissSwipe];

	UILongPressGestureRecognizer *sendHold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(sendHeld:)];
	[self.sendButton addGestureRecognizer:sendHold];

	[self restoreDraft];
	[self loadUnreadMentions];
	[self loadUnreadReactions];
	[self detectBotChat];
	[self detectGiftEligibility];
	[self detectGroupBotCommands];
	[self prefetchRecentInlineBots];
	[self loadScheduledMessages];

	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	__weak typeof(self) weakSelf = self;

	self.hasScheduledMessagesObserverToken = [centre
		addObserverForName:TGChatHasScheduledMessagesDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf hasScheduledMessagesChanged:note];
				}];

	self.keyboardWillShowObserverToken = [centre
		addObserverForName:UIKeyboardWillShowNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardWillShow:note];
				}];
	self.keyboardWillHideObserverToken = [centre
		addObserverForName:UIKeyboardWillHideNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardWillHide:note];
				}];
	self.keyboardWillChangeFrameObserverToken = [centre
		addObserverForName:UIKeyboardWillChangeFrameNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardWillChangeFrame:note];
				}];

	self.backgroundFlushDraftObserverToken = [centre
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf flushDraftOnAppState:note];
				}];
	self.terminateFlushDraftObserverToken = [centre
		addObserverForName:UIApplicationWillTerminateNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf flushDraftOnAppState:note];
				}];
	self.chatDraftObserverToken = [centre
		addObserverForName:TGChatDraftDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf chatDraftChanged:note];
				}];

	self.musicPlayerStateObserverToken = [centre
		addObserverForName:TGMusicPlayerStateChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf musicPlayerStateChanged];
				}];
	self.musicPlayerProgressObserverToken = [centre
		addObserverForName:TGMusicPlayerProgressNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf musicPlayerProgressed];
				}];
	self.audioMetadataObserverToken = [centre
		addObserverForName:TGAudioMetadataChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf audioTagsArrived:note];
				}];

	self.interactionInfoObserverToken = [centre
		addObserverForName:TGMessageInteractionInfoDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf interactionInfoChanged:note];
				}];
	self.customReactionEmojiObserverToken = [centre
		addObserverForName:TGReactionCustomEmojiResolvedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf customReactionEmojiResolved];
				}];
	self.mentionsUpdateObserverToken = [centre
		addObserverForName:TGChatUnreadMentionsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf unreadMentionsUpdateReceived:note];
				}];
	self.reactionsUpdateObserverToken = [centre
		addObserverForName:TGChatUnreadReactionsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf unreadReactionsUpdateReceived:note];
				}];
	self.fileStateObserverToken = [centre
		addObserverForName:TGFileStateDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf fileStateChanged:note];
				}];
	self.savedMessagesTagsObserverToken = [centre
		addObserverForName:TGSavedMessagesTagsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (strongSelf.chatId != [[TGClient shared] savedMessagesChatId])
						return;
					int64_t changedTopicId = [note.userInfo[TGSavedMessagesTagsTopicIdKey] longLongValue];
					if (changedTopicId != 0 && strongSelf.savedTopicId != 0 &&
						changedTopicId != strongSelf.savedTopicId)
						return;
					[strongSelf savedMessagesTagLabelsChanged];
				}];
	if (self.backButtonView)
		self.unreadCounterObserverToken = [centre
			addObserverForName:TGNotificationUpdateNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf unreadCounterRelevantUpdateReceived:note];
					}];

	TGBeginOpenTiming();
	[self reload];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGRect frame = self.table.frame;
	if (fabsf(frame.size.width - self.view.bounds.size.width) > 0.5f) {
		frame.size.width = self.view.bounds.size.width;
		self.table.frame = frame;
	}
	[self centreEmptyPlate];
	[self layoutFloatingButtons];
	CGFloat width = self.table.bounds.size.width;
	if (width < 1 || fabsf(width - self.laidOutWidth) < 0.5f) {
		[self updateShortContentInset];
		return;
	}
	self.laidOutWidth = width;
	[self remeasureComposerForNewWidth];
	[self.table reloadData];
	[self updateShortContentInset];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self installMessageHandler];
	[self installPollHandler];
	[TGAssetPicker warmAvailability];
	[[TGMusicPlayer shared] chatOpened:self.chatId];
	[[TGClient shared] openChat:self.chatId];
	[self updateBackButtonUnreadBadge];
	if (TGChatIsPad() && self.masterRevealItem &&
		self.navigationItem.leftBarButtonItem != self.masterRevealItem)
		self.navigationItem.leftBarButtonItem = self.masterRevealItem;
	if (self.liveLocationMessageId && [self.locationMode isEqualToString:@"tracking"])
		[self.locationManager startUpdatingLocation];
	[self refreshLiveLocationTimerState];
	if (self.hasCompletedInitialAppear)
		[self refreshCommentThreadStateIfStale];
	self.hasCompletedInitialAppear = YES;
}

- (void)installPollHandler {
	if (self.pollObserverToken)
		return;
	__weak typeof(self) weakSelf = self;
	self.pollObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGPollDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSIndexSet *changed = nil;
		NSArray *merged = TGMessagesWithUpdatedPoll(strongSelf.messages,
				note.userInfo[TGPollDataKey], &changed);
		if (!changed.count)
			return;
		strongSelf.messages = [merged mutableCopy];
		[changed enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
			(void)stop;
			NSDictionary *message = strongSelf.messages[index];
			[strongSelf tg_invalidateLayoutForMessageId:[message[@"id"] longLongValue]];
		}];
		[strongSelf.table reloadData];
	}];
}

- (void)installMessageHandler {
	if (self.messageObserverToken)
		return;
	__weak typeof(self) weakSelf = self;
	self.messageObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGMessageDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
		TGChatViewController *strongSelf = weakSelf;
		int64_t chatId = [note.userInfo[TGMessageChatIdKey] longLongValue];
		if (!strongSelf || chatId != strongSelf.chatId)
			return;
		NSDictionary *message = note.userInfo[TGMessageDataKey];
		int64_t deletedId = [note.userInfo[TGMessageDeletedIdKey] longLongValue];

		if ([message[@"scheduled"] boolValue])
			return;

		if (TGMessageIsChatUpgradeMarker(message))
			return;

		if (strongSelf.chatSearchBar) {
			NSMutableArray *behind = [(strongSelf.messagesBeforeSearch ?: @[]) mutableCopy];
			if (deletedId != 0) {
				NSUInteger staleIndex = [behind indexOfObjectPassingTest:
						^BOOL(NSDictionary *candidate, NSUInteger idx, BOOL *stop) {
					return [candidate[@"id"] longLongValue] == deletedId;
				}];
				if (staleIndex != NSNotFound)
					[behind removeObjectAtIndex:staleIndex];
			}
			if (message) {
				NSNumber *newId = [message[@"id"] isKindOfClass:NSNumber.class] ? message[@"id"] : nil;
				NSUInteger existingIndex = newId ? [behind indexOfObjectPassingTest:
						^BOOL(NSDictionary *candidate, NSUInteger idx, BOOL *stop) {
					return [candidate[@"id"] isEqual:newId];
				}] : NSNotFound;
				if (existingIndex != NSNotFound)
					[behind replaceObjectAtIndex:existingIndex withObject:message];
				else
					[behind addObject:message];
			}
			strongSelf.messagesBeforeSearch = behind;
			return;
		}

		if (message) {
			NSNumber *newId = [message[@"id"] isKindOfClass:NSNumber.class] ? message[@"id"] : nil;
			if (deletedId && newId) {
				strongSelf.liveLocationMessageId = TGRemappedLiveLocationMessageId(
						strongSelf.liveLocationMessageId, deletedId, newId.longLongValue);
				[strongSelf.sendStates removeObjectForKey:@(deletedId)];
				[strongSelf.sendStatesRequested removeObject:@(deletedId)];
				[strongSelf.sendStates removeObjectForKey:newId];
				[strongSelf.sendStatesRequested removeObject:newId];
				NSMutableArray *swapped = [strongSelf.messages mutableCopy];
				BOOL found = NO;
				for (NSInteger i = 0; i < swapped.count; i++) {
					if ([swapped[i][@"id"] longLongValue] != deletedId)
						continue;
					[swapped replaceObjectAtIndex:i withObject:message];
					found = YES;
					break;
				}
				if (found) {
					strongSelf.messages = swapped;
					[strongSelf.translations removeObjectForKey:newId];
					[strongSelf.translationEntities removeObjectForKey:newId];
					[strongSelf.translationsPending removeObjectForKey:newId];
					[strongSelf.aiSummaries removeObjectForKey:newId];
					TGApplyIncomingTranscript(strongSelf.transcripts, strongSelf.transcriptsPending, newId, message);
					[strongSelf.pollVotesInFlight removeObject:newId];
					[strongSelf.pollPendingSelections removeObjectForKey:newId];
					[strongSelf invalidateMapCacheForMessage:message];
					[strongSelf invalidateLinkPreviewForMessage:message];
					[strongSelf fetchMissingImages];
					NSArray *swappedChips = [TGClient reactionChipsFromMessage:message chatId:strongSelf.chatId];
					if (swappedChips.count) {
						strongSelf.reactionChips[newId] = swappedChips;
						[strongSelf.chipsRowSizes removeObjectForKey:newId];
						[strongSelf.reactionChipsRequested addObject:newId];
					} else if (![message[@"reactions"] length]) {
						[strongSelf.reactionChips removeObjectForKey:newId];
						[strongSelf.chipsRowSizes removeObjectForKey:newId];
						[strongSelf.reactionChipsRequested removeObject:newId];
					}
					[strongSelf tg_invalidateLayoutForMessageId:newId.longLongValue];
					[strongSelf refreshLiveLocationTimerState];
					[strongSelf.table reloadData];
					return;
				}

				if ([newId longLongValue] == deletedId)
					return;
			}
			NSArray *liveChips = [TGClient reactionChipsFromMessage:message chatId:strongSelf.chatId];
			if (newId && liveChips.count) {
				strongSelf.reactionChips[newId] = liveChips;
				[strongSelf.chipsRowSizes removeObjectForKey:newId];
				[strongSelf.reactionChipsRequested addObject:newId];
			}

			if (newId) {
				NSMutableArray *replaced = [strongSelf.messages mutableCopy];
				NSInteger existingIndex = NSNotFound;
				for (NSInteger i = 0; i < replaced.count; i++) {
					if ([replaced[i][@"id"] isEqual:newId]) {
						existingIndex = i;
						break;
					}
				}
				if (existingIndex != NSNotFound) {
					[replaced replaceObjectAtIndex:existingIndex withObject:message];
					strongSelf.messages = replaced;
					[strongSelf.translations removeObjectForKey:newId];
					[strongSelf.translationEntities removeObjectForKey:newId];
					[strongSelf.translationsPending removeObjectForKey:newId];
					[strongSelf.aiSummaries removeObjectForKey:newId];
					TGApplyIncomingTranscript(strongSelf.transcripts, strongSelf.transcriptsPending, newId, message);
					[strongSelf.pollVotesInFlight removeObject:newId];
					[strongSelf.pollPendingSelections removeObjectForKey:newId];
					[strongSelf invalidateMapCacheForMessage:message];
					[strongSelf invalidateLinkPreviewForMessage:message];
					[strongSelf fetchMissingImages];
					[strongSelf refreshEditedPinnedMessage:message];
					[strongSelf tg_invalidateLayoutForMessageId:newId.longLongValue];
					[strongSelf refreshLiveLocationTimerState];
					[strongSelf.table reloadData];
					return;
				}
			}
			if (strongSelf.savedTopicId != 0)
				return;
			if ([strongSelf historyStopsShortOfTheNewest]) {
				if ([message[@"outgoing"] boolValue])
					[strongSelf loadNewestHistoryAndShowIt];
				else
					[strongSelf updateScrollDownButton];
				return;
			}
			BOOL follow = [message[@"outgoing"] boolValue] || [strongSelf historyIsAtBottom];
			NSMutableArray *next = [strongSelf.messages mutableCopy];
			[next addObject:message];
			strongSelf.messages = next;
			[strongSelf warmMinithumbnailsFor:@[ message ]];
			[strongSelf refreshLiveLocationTimerState];
			[strongSelf setNeedsTableReloadFollowingBottom:follow];
			[strongSelf updateEmptyState];
			[strongSelf setNeedsFetchMissingImages];
			[strongSelf fetchMissingQuotes];
			if (newId && follow)
				[[TGClient shared] markRead:@[ newId ] inChat:chatId];
			if (follow && ![message[@"outgoing"] boolValue]) {
				int64_t effectId = [message[@"effectId"] longLongValue];
				if (effectId) {
					__weak typeof(strongSelf) weakMe = strongSelf;
					[[TGClient shared] messageEffect:effectId completion:^(NSDictionary *effect) {
						TGChatViewController *inner = weakMe;
						NSString *emoji = effect[@"emoji"];
						if (inner && emoji.length)
							[inner playEffectBurstWithEmoji:emoji];
					}];
				}
			}
			return;
		}
		if (deletedId) {
			[strongSelf purgeDeletedPinnedMessageId:deletedId];
			NSMutableArray *left = [NSMutableArray arrayWithCapacity:strongSelf.messages.count];
			for (NSDictionary *existing in strongSelf.messages)
				if ([existing[@"id"] longLongValue] != deletedId)
					[left addObject:existing];
			if (left.count == strongSelf.messages.count)
				return;
			strongSelf.messages = left;
			[strongSelf.table reloadData];
			[strongSelf updateEmptyState];
			[strongSelf fetchMissingImages];
			return;
		}
		[strongSelf reload];
	}];
}

#pragma mark - photo albums

- (void)setMessages:(NSArray *)messages {
	_messages = messages;
	[self.mosaics removeAllObjects];
	[self.tileSizes removeAllObjects];

	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:messages.count];
	NSMutableDictionary *albums = [NSMutableDictionary dictionary];
	NSMutableDictionary *rowById = [NSMutableDictionary dictionary];

	NSInteger index = 0;
	while (index < messages.count) {
		NSDictionary *head = messages[index];
		NSInteger run = 1;
		if ([self messageCanTile:head]) {
			NSString *album = head[@"albumId"];
			while (index + run < messages.count && run < kMosaicMaxItems) {
				NSDictionary *next = messages[index + run];
				if (![self messageCanTile:next] ||
					![next[@"albumId"] isEqualToString:album] ||
					[next[@"outgoing"] boolValue] != [head[@"outgoing"] boolValue])
					break;
				run++;
			}
		}

		NSNumber *row = @(rows.count);
		[rows addObject:@(index)];
		if (run > 1) {
			NSArray *members = [messages subarrayWithRange:NSMakeRange(index, run)];
			albums[row] = members;
			for (NSDictionary *member in members)
				if ([member[@"id"] isKindOfClass:NSNumber.class])
					rowById[member[@"id"]] = row;
		} else if ([head[@"id"] isKindOfClass:NSNumber.class]) {
			rowById[head[@"id"]] = row;
		}
		index += run;
	}

	self.displayRows = rows;
	self.albumsByRow = albums;
	self.rowByMessageId = rowById;

	if (_stableMessageEntries) {
		for (NSNumber *staleId in [_stableMessageEntries.allKeys copy])
			if (!rowById[staleId])
				[_stableMessageEntries removeObjectForKey:staleId];
	}

	[self tg_rebuildLayoutBridgeItems];
	[self autoTranslateMessagesIfNeeded:messages];
}

#pragma mark - migration bridge

- (TGChatLayoutBridge *)layoutBridge {
	if (!_layoutBridge) {
		_layoutBridge = [[TGChatLayoutBridge alloc] initWithContext:[self tg_buildLayoutContext]];
		_layoutBridge.delegate = self;
		_layoutBridge.selectionDelegate = self;
		[self tg_captureLayoutContextInputs];
	}
	return _layoutBridge;
}

- (TGChatPresenter *)presenter {
	if (!_presenter)
		_presenter = [[TGChatPresenter alloc] init];
	return _presenter;
}

- (NSMutableDictionary *)stableMessageEntries {
	if (!_stableMessageEntries)
		_stableMessageEntries = [NSMutableDictionary dictionary];
	return _stableMessageEntries;
}

@end
