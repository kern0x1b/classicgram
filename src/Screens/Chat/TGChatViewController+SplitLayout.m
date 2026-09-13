#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGChatHistoryCache.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGClient+Translation.h"
#import "TGLocalization.h"
#import "TGClient+Reactions.h"
#import "TGMessageActionsSheet.h"
#import "TGSnackbar.h"
#import "TGPopupMenu.h"
#import "TGDayCalendarView.h"
#import "TGReactionPickerView.h"
#import "TGMusicPlayer.h"
#import "TGClient+UserStatus.h"

@implementation TGChatViewController (SplitLayout)

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
								duration:(NSTimeInterval)duration {
	[super willRotateToInterfaceOrientation:orientation duration:duration];
	if (!TGChatIsPad())
		return;
	[self.masterPopover dismissPopoverAnimated:NO];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation {
	[super didRotateFromInterfaceOrientation:orientation];
	if (!TGChatIsPad())
		return;
	[self relayoutForPaneWidth];
}

- (void)relayoutForPaneWidth {
	[self.chipsRowSizes removeAllObjects];
	[self.mosaics removeAllObjects];
	[self.tileSizes removeAllObjects];
	[self.tileBitmaps removeAllObjects];
	[self.tileBitmapsRequested removeAllObjects];

	NSArray *visible = [self.table indexPathsForVisibleRows];
	NSIndexPath *anchor = visible.count ? visible.lastObject : nil;
	[self.table reloadData];
	if (anchor && anchor.row < [self displayRowCount])
		[self.table scrollToRowAtIndexPath:anchor
						  atScrollPosition:UITableViewScrollPositionBottom
								  animated:NO];

	[self layoutTitleView];
}

- (void)splitViewController:(UISplitViewController *)splitController
	 willHideViewController:(UIViewController *)master
		  withBarButtonItem:(UIBarButtonItem *)barButtonItem
	   forPopoverController:(UIPopoverController *)popover {
	if (!TGChatIsPad())
		return;

	barButtonItem.title = barButtonItem.title.length ? barButtonItem.title : TGL(@"DialogList.Title", @"Chats");
	self.masterRevealItem = barButtonItem;
	self.masterPopover = popover;

	if (!self.leftItemBeforeSplitKnown) {
		self.leftItemBeforeSplitKnown = YES;
		self.leftItemBeforeSplit = self.navigationItem.leftBarButtonItem;
	}
	self.navigationItem.leftBarButtonItem = barButtonItem;
	[self layoutTitleView];
}

- (void)splitViewController:(UISplitViewController *)splitController
	   willShowViewController:(UIViewController *)master
	invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
	if (!TGChatIsPad())
		return;

	if (self.navigationItem.leftBarButtonItem == barButtonItem ||
		self.navigationItem.leftBarButtonItem == self.masterRevealItem)
		self.navigationItem.leftBarButtonItem = self.leftItemBeforeSplit;

	self.masterRevealItem = nil;
	self.masterPopover = nil;
	[self layoutTitleView];
}

- (void)splitViewController:(UISplitViewController *)splitController
			popoverController:(UIPopoverController *)popover
	willPresentViewController:(UIViewController *)master {
	[self.input resignFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[TGClient shared] closeChat:self.chatId];
	[self rememberScrollPosition];
	[[TGChatHistoryCache shared] persist];
	[self saveDraft];
	[self stopVideoNote];
	[self flushChannelViewMetricsExceptForIds:nil];

	[TGSnackbar commitNow];
	[TGPopupMenu dismiss];
	[TGDayCalendarView dismiss];
	[TGReactionPickerView dismiss];
	[[TGClient shared] unwatchAllReactions];
	[self.actionsSheet dismiss];
	self.actionsSheet = nil;
	BOOL reallyLeaving = !self.navigationController || self.isMovingFromParentViewController;
	if (self.locationManager && (reallyLeaving || !self.liveLocationMessageId))
		[self.locationManager stopUpdatingLocation];
	if (self.liveLocationMessageId && reallyLeaving) {
		self.liveLocationMessageId = 0;
		self.locationMode = nil;
		[self stopLiveLocationTrackingCleanup];
	}
	[self.liveLocationRefreshTimer invalidate];
	self.liveLocationRefreshTimer = nil;
	if (reallyLeaving)
		[[TGMusicPlayer shared] chatClosed:self.chatId];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];

	NSMutableSet *keep = [NSMutableSet set];
	NSMutableSet *keepFiles = [NSMutableSet set];
	NSMutableSet *keepReplies = [NSMutableSet set];
	NSMutableSet *keepSenders = [NSMutableSet set];
	for (NSIndexPath *path in [self.table indexPathsForVisibleRows]) {
		for (NSDictionary *m in [self messagesAtRow:path.row]) {
			if ([m[@"id"] isKindOfClass:NSNumber.class])
				[keep addObject:m[@"id"]];
			if ([m[@"replyId"] isKindOfClass:NSNumber.class])
				[keepReplies addObject:m[@"replyId"]];
			if ([m[@"senderId"] isKindOfClass:NSNumber.class])
				[keepSenders addObject:m[@"senderId"]];
			NSNumber *fileId = [self pictureFileIdFor:m];
			if (fileId)
				[keepFiles addObject:fileId];
		}
	}
	[self.tileBitmaps removeAllObjects];
	[self.tileBitmapsRequested removeAllObjects];
	for (NSNumber *key in [self.maps allKeys])
		if (![keep containsObject:key])
			[self.maps removeObjectForKey:key];
	for (NSNumber *key in [self.minithumbnails allKeys])
		if (![keep containsObject:key])
			[self.minithumbnails removeObjectForKey:key];

	for (NSNumber *fileId in [self.images allKeys]) {
		if ([keepFiles containsObject:fileId])
			continue;
		[self.images removeObjectForKey:fileId];
		[self.imagesRequested removeObject:fileId];
		[self.imageOrder removeObject:fileId];
	}

	for (NSNumber *key in [self.senderAvatars allKeys])
		if (![keepSenders containsObject:key]) {
			[self.senderAvatars removeObjectForKey:key];
			[self.senderAvatarsRequested removeObject:key];
		}
	for (NSNumber *key in [self.quotes allKeys])
		if (![keepReplies containsObject:key]) {
			[self.quotes removeObjectForKey:key];
			[self.quotesRequested removeObject:key];
		}
	for (NSNumber *key in [self.reactionChips allKeys])
		if (![keep containsObject:key]) {
			[self.reactionChips removeObjectForKey:key];
			[self.reactionChipsRequested removeObject:key];
		}
	for (NSNumber *key in [self.chipsRowSizes allKeys])
		if (![keep containsObject:key])
			[self.chipsRowSizes removeObjectForKey:key];
	for (NSNumber *key in [self.linkPreviews allKeys])
		if (![keep containsObject:key]) {
			[self.linkPreviews removeObjectForKey:key];
			[self.linkPreviewsRequested removeObject:key];
		}
	self.photoWindow = NSMakeRange(NSNotFound, 0);
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.connectionStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.connectionStateObserverToken];
	if (self.themeChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.themeChangedObserverToken];
	if (self.customEmojiObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.customEmojiObserverToken];
	if (self.chatActionObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatActionObserverToken];
	if (self.messageObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.messageObserverToken];
	if (self.pollObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.pollObserverToken];
	if (self.protectedContentObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.protectedContentObserver];
	if (self.fileProgressObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.fileProgressObserverToken];
	if (self.keyboardWillShowObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillShowObserverToken];
	if (self.keyboardWillHideObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillHideObserverToken];
	if (self.keyboardWillChangeFrameObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillChangeFrameObserverToken];
	if (self.backgroundFlushDraftObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.backgroundFlushDraftObserverToken];
	if (self.terminateFlushDraftObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.terminateFlushDraftObserverToken];
	if (self.chatDraftObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatDraftObserverToken];
	if (self.musicPlayerStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.musicPlayerStateObserverToken];
	if (self.musicPlayerProgressObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.musicPlayerProgressObserverToken];
	if (self.audioMetadataObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.audioMetadataObserverToken];
	if (self.interactionInfoObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.interactionInfoObserverToken];
	if (self.customReactionEmojiObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.customReactionEmojiObserverToken];
	if (self.fileStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.fileStateObserverToken];
	if (self.savedMessagesTagsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.savedMessagesTagsObserverToken];
	if (self.unreadCounterObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.unreadCounterObserverToken];
	if (self.outgoingReadStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.outgoingReadStateObserverToken];
	if (self.isTranslatableObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.isTranslatableObserverToken];
	if (self.pinnedMessagesObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.pinnedMessagesObserverToken];
	if (self.chatActionBarObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatActionBarObserverToken];
	if (self.composerPermissionsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.composerPermissionsObserverToken];
	if (self.frozenStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.frozenStateObserverToken];
	if (self.chatBackgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatBackgroundObserverToken];
	if (self.chatThemeObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatThemeObserverToken];
	if (self.chatThemeCatalogObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatThemeCatalogObserverToken];
	if (self.hasScheduledMessagesObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.hasScheduledMessagesObserverToken];
	if (self.userBlockedStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.userBlockedStateObserverToken];
	if (self.chatMemberObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatMemberObserverToken];
	if (self.chatMuteStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatMuteStateObserverToken];
	if (self.secretChatStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.secretChatStateObserverToken];
	if (self.chatMessageSenderObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatMessageSenderObserverToken];
	if (self.videoChatObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.videoChatObserverToken];
	if (self.videoNoteReachedEndObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.videoNoteReachedEndObserverToken];
	if (self.videoNoteInterruptionObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.videoNoteInterruptionObserverToken];
	if (self.userStatusObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.userStatusObserverToken];
	if (self.mentionsUpdateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.mentionsUpdateObserverToken];
	if (self.reactionsUpdateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.reactionsUpdateObserverToken];
	[self.recordTimer invalidate];
	self.recordTimer = nil;
	[self.videoNoteTicker invalidate];
	self.videoNoteTicker = nil;
	[self.userStatusExpiryTimer invalidate];
	self.userStatusExpiryTimer = nil;
	[self.liveLocationRefreshTimer invalidate];
	self.liveLocationRefreshTimer = nil;
}

- (void)reloadForCustomEmojiArrival {
	[self.table reloadData];
	[self refreshComposerCustomEmojiOverlay];
}

- (void)outgoingReadStateChanged:(NSNotification *)note {
	if ([note.object longLongValue] != self.chatId)
		return;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self reloadTicksInVisibleRows];
	});
}

- (void)isTranslatableChanged:(NSNotification *)note {
	if ([note.object longLongValue] != self.chatId)
		return;
	dispatch_async(dispatch_get_main_queue(), ^{
		if ([[TGClient shared] isChatTranslatable:self.chatId])
			[self autoTranslateMessagesIfNeeded:self.messages];
		else
			[self revertAutoTranslatedMessages];
	});
}

- (void)pinnedMessagesChanged:(NSNotification *)note {
	if ([note.object longLongValue] != self.chatId)
		return;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self loadPinnedMessage];
	});
}

- (void)reloadTicksInVisibleRows {
	NSArray *visible = [self.table indexPathsForVisibleRows];
	if (!visible.count)
		return;
	long long readTo = [[TGClient shared] lastReadOutgoingMessageInChat:self.chatId];
	NSMutableArray *changedPaths = [NSMutableArray array];
	for (NSIndexPath *path in visible) {
		NSDictionary *m = [self messageAtRow:path.row];
		if (!m || ![m[@"outgoing"] boolValue])
			continue;
		long long thisId = [m[@"id"] longLongValue];
		if (thisId == 0 || thisId > readTo)
			continue;
		[self tg_invalidateLayoutForMessageId:thisId];
		[changedPaths addObject:path];
	}
	if (!changedPaths.count)
		return;
	[self.table reloadRowsAtIndexPaths:changedPaths
					  withRowAnimation:UITableViewRowAnimationNone];
}

@end
