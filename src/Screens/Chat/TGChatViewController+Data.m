#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGChatHistoryCache.h"
#import "TGChatViewControllerInternal.h"
#import "TGChatHistoryMerge.h"
#import "TGTheme.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGClient+ChatList.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGPreferenceFlags.h"
#import "TGLinkPreviewView.h"
#import "TGReactionPickerView.h"
#import "TGImageDecode.h"
#import "AppDelegate.h"
#import "TGClient+MessageContent.h"
#import "TGClient+Files.h"
#import "TGClient+Reactions.h"
#import "TGClient+SecretChats.h"
#import "TGClient+WebLinks.h"
#import "TGFileDownloadService.h"
#import "TGAccountManager.h"
#import "TGChatPositionKey.h"
#import "TGLiveLocationRehydration.h"
#import "TGLinkPreviewFetchDecision.h"
#import "TGChatUpgradeMarkerFilter.h"

@implementation TGChatViewController (Data)

- (void)showHistorySpinnerAfterGrace {
	if (self.historySpinner)
		return;
	self.historySpinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.historySpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin |
		UIViewAutoresizingFlexibleTopMargin |
		UIViewAutoresizingFlexibleBottomMargin;
	self.historySpinner.hidesWhenStopped = YES;
	[self.view insertSubview:self.historySpinner aboveSubview:self.table];

	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || !strongSelf.historySpinner || strongSelf.messages.count)
				return;
			CGRect history = strongSelf.table.frame;
			strongSelf.historySpinner.center = CGPointMake(
				floorf(CGRectGetMidX(history)),
				floorf(CGRectGetMidY(history) + strongSelf.pinnedBannerInset / 2));
			[strongSelf.historySpinner startAnimating];
		});
}

- (void)hideHistorySpinner {
	[self.historySpinner stopAnimating];
	[self.historySpinner removeFromSuperview];
	self.historySpinner = nil;
}

static NSString *const TGChatPositionsKey = @"TGChatScrollPositions";
static const NSUInteger kChatPositionsLimit = 64;

static NSDictionary *TGStoredChatPosition(int64_t chatId, int64_t threadId) {
	NSDictionary *all = [[NSUserDefaults standardUserDefaults]
		dictionaryForKey:[TGAccountManager defaultsKey:TGChatPositionsKey]];
	id entry = all[TGChatPositionKey(chatId, threadId)];
	return [entry isKindOfClass:NSDictionary.class] ? entry : nil;
}

static void TGRememberChatPosition(int64_t chatId, int64_t threadId, int64_t messageId, CGFloat delta) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *known = [defaults dictionaryForKey:[TGAccountManager defaultsKey:TGChatPositionsKey]];
	NSString *key = TGChatPositionKey(chatId, threadId);
	NSDictionary *entry = [known[key] isKindOfClass:NSDictionary.class] ? known[key] : nil;

	if (messageId == 0) {
		if (!entry)
			return;
	} else if ([entry[@"m"] longLongValue] == messageId &&
		fabsf([entry[@"d"] floatValue] - (float)delta) < 1.0f) {
		return;
	}

	NSMutableDictionary *all = [(known ?: @{}) mutableCopy];
	if (messageId == 0) {
		[all removeObjectForKey:key];
	} else {
		all[key] = @{@"m" : @(messageId),
			@"d" : @((float)delta),
			@"t" : @([NSDate timeIntervalSinceReferenceDate])};
	}

	while (all.count > kChatPositionsLimit) {
		NSString *oldest = nil;
		NSTimeInterval when = 0;
		for (NSString *each in all) {
			NSTimeInterval stamp = [all[each][@"t"] doubleValue];
			if (!oldest || stamp < when) {
				oldest = each;
				when = stamp;
			}
		}
		if (!oldest)
			break;
		[all removeObjectForKey:oldest];
	}

	[defaults setObject:all forKey:[TGAccountManager defaultsKey:TGChatPositionsKey]];
	[defaults synchronize];
}

- (void)resolveOpenAnchor {
	if (self.unreadOnOpenKnown)
		return;
	self.unreadOnOpenKnown = YES;
	self.cachedUnreadRow = NSNotFound;
	self.cachedUnreadKey = nil;

	TGClient *client = [TGClient shared];
	self.unreadOnOpen = [client unreadCountInChat:self.chatId];
	self.lastReadInboxOnOpen = [client lastReadIncomingMessageInChat:self.chatId];

	if (self.unreadOnOpen == 0 && self.directMessagesTopicId == 0 &&
		[client isChatMarkedAsUnread:self.chatId])
		[client setChat:self.chatId markedAsUnread:NO completion:nil];

	if (self.focusMessageId != 0 || self.threadId != 0)
		return;

	if (self.unreadOnOpen > 0 && self.lastReadInboxOnOpen != 0) {
		NSInteger newer = self.unreadOnOpen + kUnreadSlack;
		if (newer > kHistoryPageLimit - kUnreadContextRows)
			newer = kHistoryPageLimit - kUnreadContextRows;
		self.openAnchorFetchId = self.lastReadInboxOnOpen;
		self.openAnchorNewerWanted = newer;
		self.openAnchorIsUnread = YES;
		return;
	}

	NSDictionary *stored = TGStoredChatPosition(self.chatId, self.threadId);
	int64_t remembered = [stored[@"m"] longLongValue];
	if (remembered == 0)
		return;
	self.openAnchorFetchId = remembered;
	self.openAnchorRestoreId = remembered;
	self.openAnchorRestoreDelta = (CGFloat)[stored[@"d"] floatValue];
	self.openAnchorNewerWanted = kRestoreContextRows;
}

- (BOOL)historyStraddlesOpenAnchor:(NSArray *)messages {
	if (self.openAnchorFetchId == 0 || self.initialPlacementDone)
		return YES;
	BOOL atOrUnder = NO, over = NO;
	for (NSDictionary *m in messages) {
		if (![m[@"id"] isKindOfClass:NSNumber.class])
			continue;
		if ([m[@"id"] longLongValue] > self.openAnchorFetchId)
			over = YES;
		else
			atOrUnder = YES;
		if (atOrUnder && over)
			return YES;
	}
	return NO;
}

- (int64_t)topVisibleMessageIdWithDelta:(CGFloat *)delta {
	if (delta)
		*delta = 0;
	if (!self.table || ![self displayRowCount])
		return 0;

	CGFloat top = self.table.contentOffset.y + self.table.contentInset.top;
	NSIndexPath *path = [self.table indexPathForRowAtPoint:CGPointMake(0, top + 1)];
	if (!path)
		path = [[self.table indexPathsForVisibleRows] firstObject];
	if (!path)
		return 0;

	NSDictionary *m = [self messageAtRow:path.row];
	if (![m[@"id"] isKindOfClass:NSNumber.class])
		return 0;
	if (delta)
		*delta = top - [self.table rectForRowAtIndexPath:path].origin.y;
	return [m[@"id"] longLongValue];
}

- (BOOL)placeRow:(NSInteger)row atTopWithDelta:(CGFloat)delta {
	if (row == NSNotFound || row < 0 || row >= [self displayRowCount])
		return NO;

	CGRect rect = [self.table rectForRowAtIndexPath:
			[NSIndexPath indexPathForRow:row inSection:0]];
	CGFloat lowest = self.table.contentSize.height + self.table.contentInset.bottom -
		self.table.bounds.size.height;
	CGFloat highest = -self.table.contentInset.top;
	CGFloat y = rect.origin.y + delta - self.table.contentInset.top;
	if (y > lowest)
		y = lowest;
	if (y < highest)
		y = highest;
	[self.table setContentOffset:CGPointMake(0, y) animated:NO];
	return YES;
}

- (NSInteger)rowAtOrAfterMessageId:(int64_t)messageId {
	NSInteger count = [self displayRowCount];
	for (NSInteger i = 0; i < count; i++) {
		NSDictionary *m = [self messageAtRow:i];
		if ([m[@"id"] isKindOfClass:NSNumber.class] &&
			[m[@"id"] longLongValue] >= messageId)
			return i;
	}
	return NSNotFound;
}

- (void)readWhatIsOnScreenSoon {
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf markVisibleMessagesRead];
	});
}

- (void)placeOpenAnchorFinal:(BOOL)final {
	if (self.focusMessageId != 0) {
		[self scrollToBottomAnimated:NO];
		if (final)
			self.initialPlacementDone = YES;
		return;
	}

	BOOL anchored = (self.openAnchorFetchId != 0);
	if (anchored) {
		NSInteger row = self.openAnchorIsUnread
			? [self unreadDividerRow]
			: [self rowAtOrAfterMessageId:self.openAnchorRestoreId];
		CGFloat delta = self.openAnchorIsUnread ? 0 : self.openAnchorRestoreDelta;
		if ([self placeRow:row atTopWithDelta:delta]) {
			self.initialPlacementDone = YES;
			self.openAnchorFetchId = 0;
			self.anchorToBottom = NO;
			self.openedOnAnAnchor = YES;
			[self updateScrollDownButton];
			[self readWhatIsOnScreenSoon];
			return;
		}
		if (!final)
			return;
		self.openAnchorFetchId = 0;
	}

	self.initialPlacementDone = YES;
	self.openedOnAnAnchor = anchored;
	[self scrollToBottomAnimated:NO];
	[self readWhatIsOnScreenSoon];
}

- (void)settleScrollFinal:(BOOL)final
			   keepingTop:(int64_t)keepId
					delta:(CGFloat)keepDelta
				 atBottom:(BOOL)wasAtBottom {
	if (!self.initialPlacementDone) {
		[self placeOpenAnchorFinal:final];
		return;
	}
	if (wasAtBottom || keepId == 0 ||
		![self placeRow:[self rowAtOrAfterMessageId:keepId] atTopWithDelta:keepDelta])
		[self scrollToBottomAnimated:NO];
	[self updateScrollDownButton];
}

- (void)rememberScrollPosition {
	if (self.chatSearchBar || self.messagesBeforeSearch || self.messagesBeforePinnedList)
		return;
	if (![self displayRowCount] || [self historyIsAtBottom]) {
		TGRememberChatPosition(self.chatId, self.threadId, 0, 0);
		return;
	}
	CGFloat delta = 0;
	int64_t top = [self topVisibleMessageIdWithDelta:&delta];
	TGRememberChatPosition(self.chatId, self.threadId, top, delta);
}

- (void)reloadForChatIdentityChangedTo:(int64_t)newChatId {
	self.chatId = newChatId;
	self.messages = @[];
	self.openAnchorFetchId = 0;
	self.openAnchorRestoreId = 0;
	self.openAnchorNewerWanted = 0;
	self.openAnchorIsUnread = NO;
	self.unreadOnOpen = 0;
	self.cachedUnreadKey = nil;
	self.cachedUnreadRow = NSNotFound;
	self.pendingPartialHistory = nil;
	[self reload];
}

- (void)reload {
	int64_t requestedChatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	self.localHistoryShown = NO;
	self.networkHistoryShown = NO;
	self.olderHistoryExhausted = NO;
	self.olderHistoryPending = NO;
	if (self.messages.count != 0) {
		[self reloadFromNetwork];
		return;
	}

	TGChatHistoryCache *historyCache = [TGChatHistoryCache shared];
	NSArray *remembered = [historyCache messagesForChat:self.chatId thread:self.threadId];
	if (remembered.count && self.openAnchorFetchId != 0 &&
		![self history:remembered holdsMessageId:self.openAnchorFetchId])
		remembered = nil;
	if (remembered.count) {
		TGMarkOpenStage([NSString stringWithFormat:@"%lu messages from the last visit",
			(unsigned long)remembered.count]);
		[self applyHistory:remembered final:NO partial:NO];
	}

	[self showHistorySpinnerAfterGrace];

	if (self.savedTopicId != 0 || self.directMessagesTopicId != 0) {
		[self reloadFromNetwork];
		return;
	}

	void (^onLocalHistory)(NSArray *) = ^(NSArray *messages) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.chatId != requestedChatId ||
			!messages.count || strongSelf.networkHistoryShown ||
			![strongSelf historyStraddlesOpenAnchor:messages])
			return;
		strongSelf.localHistoryShown = YES;
		TGMarkOpenStage([NSString stringWithFormat:@"%lu cached messages drawn",
			(unsigned long)messages.count]);
		[strongSelf applyHistory:messages final:NO partial:NO];
	};

	TGClient *client = [TGClient shared];
	void (^onPrefetched)(NSArray *) = ^(NSArray *messages) {
		TGMarkOpenStage(@"prefetched local history attached");
		onLocalHistory(messages);
	};
	BOOL attachedToPrefetch = self.threadId == 0 &&
		[client attachToPrefetchedHistoryForChat:self.chatId
								   aroundMessage:self.openAnchorFetchId
										   newer:self.openAnchorNewerWanted
										   limit:kHistoryPageLimit
									  completion:onPrefetched];
	if (attachedToPrefetch) {
		[self reloadFromNetwork];
		return;
	}

	void (^partial)(NSArray *) = ^(NSArray *messages) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.chatId != requestedChatId ||
			!messages.count || strongSelf.networkHistoryShown ||
			messages.count <= strongSelf.messages.count ||
			![strongSelf historyStraddlesOpenAnchor:messages])
			return;
		[strongSelf schedulePartialHistory:messages];
	};

	[[TGClient shared] historyForChat:self.chatId
							   thread:self.threadId
						aroundMessage:self.openAnchorFetchId
								newer:self.openAnchorNewerWanted
								limit:kHistoryPageLimit
							onlyLocal:YES
							 progress:partial
						   completion:onLocalHistory];
	[self reloadFromNetwork];
}

- (void)schedulePartialHistory:(NSArray *)messages {
	self.pendingPartialHistory = messages;
	if (self.partialHistoryScheduled)
		return;
	self.partialHistoryScheduled = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.partialHistoryScheduled = NO;
		NSArray *latest = strongSelf.pendingPartialHistory;
		strongSelf.pendingPartialHistory = nil;
		if (!latest.count || strongSelf.networkHistoryShown ||
			latest.count <= strongSelf.messages.count)
			return;
		strongSelf.localHistoryShown = YES;
		TGMarkOpenStage([NSString stringWithFormat:@"%lu of the cached messages drawn",
			(unsigned long)latest.count]);
		[strongSelf applyHistory:latest final:NO partial:YES];
	});
}

- (void)reloadFromNetwork {
	int64_t requestedChatId = self.chatId;
	__weak typeof(self) weakSelf = self;

	if (self.savedTopicId != 0) {
		[[TGClient shared] historyForSavedTopic:self.savedTopicId
										  limit:kHistoryPageLimit
									 completion:^(NSArray *messages) {
										 TGChatViewController *strongSelf = weakSelf;
										 if (!strongSelf || strongSelf.chatId != requestedChatId)
											 return;
										 if (!messages) {
											 [strongSelf hideHistorySpinner];
											 return;
										 }
										 strongSelf.networkHistoryShown = YES;
										 [strongSelf applyHistory:messages final:YES partial:NO];
									 }];
		return;
	}

	if (self.directMessagesTopicId != 0) {
		TGClient *client = [TGClient shared];
		[client historyForDirectMessagesTopic:self.directMessagesTopicId
									   inChat:self.chatId
										limit:kHistoryPageLimit
								   completion:^(NSArray *messages) {
									   TGChatViewController *strongSelf = weakSelf;
									   if (!strongSelf || strongSelf.chatId != requestedChatId)
										   return;
									   if (!messages) {
										   [strongSelf hideHistorySpinner];
										   return;
									   }
									   strongSelf.networkHistoryShown = YES;
									   [strongSelf applyHistory:messages final:YES partial:NO];
								   }];
		return;
	}

	[[TGClient shared] historyForChat:self.chatId
							   thread:self.threadId
						aroundMessage:self.openAnchorFetchId
								newer:self.openAnchorNewerWanted
								limit:kHistoryPageLimit
							onlyLocal:NO
							 progress:nil completion:^(NSArray *messages) {
								 TGChatViewController *strongSelf = weakSelf;
								 if (!strongSelf || strongSelf.chatId != requestedChatId)
									 return;
								 if (!messages) {
									 [strongSelf hideHistorySpinner];
									 return;
								 }
								 if (strongSelf.localHistoryShown && messages.count < strongSelf.messages.count)
									 return;
								 strongSelf.networkHistoryShown = YES;
								 TGMarkOpenStage([NSString stringWithFormat:@"%lu messages from TDLib",
									 (unsigned long)messages.count]);
								 [strongSelf applyHistory:messages final:YES partial:NO];
							 }];
}

- (void)refreshCommentThreadStateIfStale {
	if (!self.messages.count)
		return;
	BOOL isChannel = NO;
	for (NSDictionary *m in self.messages) {
		if ([m[@"channelPost"] boolValue]) {
			isChannel = YES;
			break;
		}
	}
	if (!isChannel)
		return;
	[self reloadFromNetwork];
}

- (BOOL)history:(NSArray *)messages holdsMessageId:(int64_t)messageId {
	for (NSDictionary *m in messages)
		if ([m[@"id"] longLongValue] == messageId)
			return YES;
	return NO;
}

- (void)applyHistory:(NSArray *)messages final:(BOOL)final partial:(BOOL)partial {
	messages = TGMessagesWithChatUpgradeMarkersRemoved(messages);
	NSTimeInterval startedAt = TGPerfLogging()
		? [NSDate timeIntervalSinceReferenceDate]
		: 0;
	CGFloat keepDelta = 0;
	BOOL keepBottom = ![self displayRowCount] || [self historyIsAtBottom];
	int64_t keepTop = [self topVisibleMessageIdWithDelta:&keepDelta];
	BOOL changed = messages.count == 0 || ![messages isEqualToArray:self.messages];
	if (messages.count)
		[self hideHistorySpinner];
	self.messages = messages;
	if (changed) {
		[self warmMinithumbnailsFor:messages];
		[self.reactionChipsRequested removeAllObjects];
		[self.reactionChips removeAllObjects];
		[self.chipsRowSizes removeAllObjects];
		[self.commentCounts removeAllObjects];
		[self.viewCounts removeAllObjects];
	}
	for (NSNumber *key in [self.sendStates allKeys]) {
		if ([self.sendStates[key] isEqualToString:@"sent"])
			continue;
		[self.sendStates removeObjectForKey:key];
		[self.sendStatesRequested removeObject:key];
	}
	self.anchorToBottom = (self.openAnchorFetchId == 0 && !self.openAnchorIsUnread &&
		self.openAnchorRestoreId == 0);
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{ weakSelf.anchorToBottom = NO; });
	if (changed) {
		[self.table reloadData];
		[self updateShortContentInset];
		if (!self.liveLocationMessageId) {
			int64_t ownActiveLiveLocationMessageId = TGOwnActiveLiveLocationMessageId(messages,
				[NSDate timeIntervalSinceReferenceDate]);
			if (ownActiveLiveLocationMessageId)
				self.liveLocationMessageId = ownActiveLiveLocationMessageId;
		}
		[self refreshLiveLocationTimerState];
	}
	if (final && messages.count && ![[TGClient shared] isSecretChat:self.chatId])
		[[TGChatHistoryCache shared] setMessages:messages
										 forChat:self.chatId
										  thread:self.threadId];
	if (messages.count) {
		TGMarkOpenFrame([NSString stringWithFormat:@"FIRST FRAME with %lu messages",
			(unsigned long)messages.count]);
		if (!partial)
			TGMarkOpenSettledFrame([NSString stringWithFormat:
					@"SETTLED FRAME with %lu messages", (unsigned long)messages.count]);
	}
	if (changed) {
		[self updateEmptyState];
		[self settleScrollFinal:final keepingTop:keepTop delta:keepDelta
					   atBottom:keepBottom];
		[self fetchMissingImages];
		[self resolveUnknownSenders];
		[self resolveUnknownForwardOrigins];
		[self fetchMissingQuotes];
		[self fetchMissingVoiceFiles];
		if (self.selecting)
			[self fetchMissingSelectionPermissions];
	}
	if (startedAt > 0)
		NSLog(@"PERF applyHistory %@ %lu msgs %@ in %.0f ms",
			final ? @"final" : (partial ? @"partial" : @"local"),
			(unsigned long)messages.count, changed ? @"redrawn" : @"unchanged",
			([NSDate timeIntervalSinceReferenceDate] - startedAt) * 1000.0);

	if (self.focusMessageId && final) {
		int64_t wanted = self.focusMessageId;
		self.focusMessageId = 0;
		self.anchorToBottom = NO;
		if (![self scrollToMessageId:wanted])
			[self loadDeeperHistoryAndScrollTo:wanted];
	}
}

static void TGDrawMapPin(CGContextRef ctx, CGPoint tip, CGFloat side) {
	CGFloat headRadius = side * 0.30f;
	CGPoint head = CGPointMake(tip.x, tip.y - side * 0.66f);

	CGContextSaveGState(ctx);
	CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 0.18f);
	CGContextFillEllipseInRect(ctx, CGRectMake(tip.x - side * 0.26f, tip.y - side * 0.06f, side * 0.52f, side * 0.16f));

	CGContextSetRGBFillColor(ctx, 0.90f, 0.22f, 0.20f, 1.0f);
	CGContextMoveToPoint(ctx, tip.x, tip.y);
	CGContextAddQuadCurveToPoint(ctx, head.x - headRadius * 0.9f, head.y + headRadius * 0.8f,
		head.x - headRadius, head.y);
	CGContextAddArc(ctx, head.x, head.y, headRadius, (CGFloat)M_PI, (CGFloat)(2 * M_PI), 0);
	CGContextAddQuadCurveToPoint(ctx, head.x + headRadius * 0.9f, head.y + headRadius * 0.8f,
		tip.x, tip.y);
	CGContextClosePath(ctx);
	CGContextFillPath(ctx);

	CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
	CGContextFillEllipseInRect(ctx, CGRectMake(head.x - headRadius * 0.38f, head.y - headRadius * 0.38f, headRadius * 0.76f, headRadius * 0.76f));
	CGContextRestoreGState(ctx);
}

static UIImage *TGMapCardWithPin(UIImage *tile, CGSize points) {
	if (!tile || points.width < 1 || points.height < 1)
		return tile;
	UIGraphicsBeginImageContextWithOptions(points, YES, 0);
	[tile drawInRect:CGRectMake(0, 0, points.width, points.height)];
	TGDrawMapPin(UIGraphicsGetCurrentContext(),
		CGPointMake(points.width / 2, points.height / 2 + 8), 26.0f);
	UIImage *card = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return card ?: tile;
}

- (UIImage *)mapCardForLatitude:(double)lat longitude:(double)lon {
	CGSize size = CGSizeMake(kMapCardW, kMapCardH);
	UIGraphicsBeginImageContextWithOptions(size, YES, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	CGContextSetRGBFillColor(ctx, 0.90f, 0.91f, 0.87f, 1.0f);
	CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));

	CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
	CGContextSetLineWidth(ctx, 6);
	double seed = fabs(lat * 1000 + lon * 1000);
	for (NSInteger i = 0; i < 3; i++) {
		double y = 20 + fmod(seed * (i + 3), 90);
		CGContextMoveToPoint(ctx, 0, y);
		CGContextAddLineToPoint(ctx, size.width, y - 12 + fmod(seed * (i + 1), 24));
		CGContextStrokePath(ctx);

		double x = 20 + fmod(seed * (i + 5), 180);
		CGContextMoveToPoint(ctx, x, 0);
		CGContextAddLineToPoint(ctx, x - 10 + fmod(seed * (i + 2), 20), size.height);
		CGContextStrokePath(ctx);
	}

	CGContextSetRGBFillColor(ctx, 0.78f, 0.86f, 0.74f, 1.0f);
	CGContextFillEllipseInRect(ctx, CGRectMake(fmod(seed, 120), fmod(seed, 60), 70, 44));

	TGDrawMapPin(ctx, CGPointMake(size.width / 2, size.height / 2 + 8), 26.0f);

	NSString *coords = [NSString stringWithFormat:@"%.4f, %.4f", lat, lon];
	CGContextSetRGBFillColor(ctx, 0.25f, 0.27f, 0.24f, 1.0f);
	[coords drawAtPoint:CGPointMake(8, size.height - 18)
			   withFont:[UIFont systemFontOfSize:12]];

	UIImage *card = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return card;
}

- (BOOL)messageCarriesMapCard:(NSDictionary *)m {
	return [m[@"lat"] isKindOfClass:NSNumber.class] &&
		[m[@"lon"] isKindOfClass:NSNumber.class];
}

- (UIImage *)mapCardFor:(NSDictionary *)m {
	if (![self messageCarriesMapCard:m])
		return nil;
	NSNumber *key = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	UIImage *card = key ? self.maps[key] : nil;
	if (card)
		return card;
	card = [self mapCardForLatitude:[m[@"lat"] doubleValue]
						  longitude:[m[@"lon"] doubleValue]];
	if (key && card)
		self.maps[key] = card;
	if (key)
		[self fetchMapTileFor:m key:key];
	return card;
}

- (void)invalidateMapCacheForMessage:(NSDictionary *)message {
	if (![message[@"kind"] isEqualToString:@"messageLiveLocation"])
		return;
	NSNumber *key = [message[@"id"] isKindOfClass:NSNumber.class] ? message[@"id"] : nil;
	if (!key)
		return;
	[self.maps removeObjectForKey:key];
	[self.mapTilesRequested removeObject:key];
}

- (void)invalidateLinkPreviewForMessage:(NSDictionary *)message {
	NSNumber *key = [message[@"id"] isKindOfClass:NSNumber.class] ? message[@"id"] : nil;
	if (!key)
		return;
	[self.linkPreviews removeObjectForKey:key];
	[self.linkPreviewsRequested removeObject:key];
}

- (void)fetchMapTileFor:(NSDictionary *)m key:(NSNumber *)key {
	if (!self.mapTilesRequested)
		self.mapTilesRequested = [NSMutableSet set];
	if ([self.mapTilesRequested containsObject:key])
		return;
	[self.mapTilesRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client mapThumbnailForLatitude:[m[@"lat"] doubleValue]
						  longitude:[m[@"lon"] doubleValue]
							   zoom:16
							  width:(NSInteger)kMapCardW
							 height:(NSInteger)kMapCardH
							  scale:1
							 inChat:self.chatId
						 completion:^(long long fileId) {
							 TGChatViewController *strongSelf = weakSelf;
							 if (!strongSelf || fileId <= 0)
								 return;
							 [client downloadFile:fileId completion:^(NSString *path) {
								 if (!path.length)
									 return;
								 CGFloat cardPixels = MAX(kMapCardW, kMapCardH) * [UIScreen mainScreen].scale;
								 dispatch_async(TGImageDecodeQueue(), ^{
									 UIImage *tile = TGDecodeThumbnail(path, cardPixels);
									 if (!tile)
										 return;
									 UIImage *pinned = TGImageDrawnAtPointSize(tile, CGSizeMake(kMapCardW, kMapCardH));
									 UIImage *card = TGMapCardWithPin(pinned, CGSizeMake(kMapCardW, kMapCardH));
									 dispatch_async(dispatch_get_main_queue(), ^{
										 TGChatViewController *innerSelf = weakSelf;
										 if (!innerSelf)
											 return;
										 innerSelf.maps[key] = card;
										 [innerSelf setNeedsTableReload];
									 });
								 });
							 }];
						 }];
}

- (void)setNeedsTableReload {
	if (self.tableReloadPending)
		return;
	self.tableReloadPending = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.tableReloadPending = NO;
		BOOL anchor = strongSelf.pendingReloadAnchors;
		strongSelf.pendingReloadAnchors = NO;
		BOOL follow = strongSelf.pendingReloadFollows;
		BOOL button = strongSelf.pendingScrollButtonUpdate;
		strongSelf.pendingReloadFollows = NO;
		strongSelf.pendingScrollButtonUpdate = NO;
		[strongSelf.table reloadData];
		if (follow)
			[strongSelf scrollToBottomAnimated:YES];
		else if (anchor && strongSelf.anchorToBottom)
			[strongSelf scrollToBottomAnimated:NO];
		if (button && !follow)
			[strongSelf updateScrollDownButton];
	});
}

- (void)setNeedsTableReloadKeepingBottom {
	self.pendingReloadAnchors = YES;
	[self setNeedsTableReload];
}

- (void)setNeedsTableReloadFollowingBottom:(BOOL)follow {
	if (follow)
		self.pendingReloadFollows = YES;
	else
		self.pendingScrollButtonUpdate = YES;
	[self setNeedsTableReload];
}

- (void)setNeedsFetchMissingImages {
	if (self.fetchImagesPending)
		return;
	self.fetchImagesPending = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.fetchImagesPending = NO;
		[strongSelf fetchMissingImages];
	});
}

- (void)resolveUnknownSenders {
	__weak typeof(self) weakSelf = self;
	NSMutableSet *wanted = [NSMutableSet set];
	for (NSDictionary *m in self.messages) {
		int64_t sender = [m[@"senderId"] longLongValue];
		if (sender != 0 && ![[TGClient shared] nameForUserId:sender])
			[wanted addObject:@(sender)];

		int64_t viaBotId = [m[@"viaBotId"] longLongValue];
		if (viaBotId != 0 && ![[TGClient shared] usernameForUserId:viaBotId])
			[wanted addObject:@(viaBotId)];
	}

	for (NSNumber *uid in wanted) {
		[[TGClient shared] ensureUserName:uid.longLongValue completion:^{
			[weakSelf tg_invalidateLayoutForSenderNameArrived:uid.longLongValue];
			[weakSelf setNeedsTableReload];
		}];
	}
}

- (void)resolveUnknownForwardOrigins {
	__weak typeof(self) weakSelf = self;
	NSMutableSet *wanted = [NSMutableSet set];
	for (NSDictionary *m in self.messages) {
		int64_t forwardChatId = [m[@"forwardChatId"] longLongValue];
		if (forwardChatId != 0 && ![[TGClient shared] cachedTitleForChatId:forwardChatId].length)
			[wanted addObject:@(forwardChatId)];
	}

	for (NSNumber *originChatId in wanted) {
		[[TGClient shared] titleForChatId:originChatId.longLongValue completion:^(NSString *title) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || !title.length)
				return;
			for (NSDictionary *m in strongSelf.messages) {
				if ([m[@"forwardChatId"] longLongValue] != originChatId.longLongValue)
					continue;
				NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
				if (messageId)
					[strongSelf tg_invalidateLayoutForMessageId:messageId.longLongValue];
			}
			[strongSelf setNeedsTableReload];
		}];
	}
}

- (void)fetchMissingQuotes {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *m in self.messages) {
		NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
		if (replyId && !([m[@"replyText"] length] || self.quotes[replyId] ||
				[self.quotesRequested containsObject:replyId])) {
			[self.quotesRequested addObject:replyId];

			int64_t replyChatId = [m[@"replyChatId"] longLongValue];
			if (!replyChatId)
				replyChatId = self.chatId;

			[[TGClient shared] messageWithId:replyId.longLongValue
									  inChat:replyChatId
								  completion:^(NSDictionary *original) {
									  TGChatViewController *strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  if (!original) {
										  [strongSelf.quotesMissing addObject:replyId];
										  [strongSelf tg_invalidateLayoutForRepliesToMessageId:replyId.longLongValue];
										  [strongSelf.table reloadData];
										  return;
									  }
									  strongSelf.quotes[replyId] = original;
									  [strongSelf tg_invalidateLayoutForRepliesToMessageId:replyId.longLongValue];
									  [strongSelf setNeedsTableReload];
									  [strongSelf setNeedsFetchMissingImages];
								  }];
		}

		NSNumber *pinnedId = [m[@"pinnedId"] isKindOfClass:NSNumber.class] ? m[@"pinnedId"] : nil;
		if (!pinnedId || ![pinnedId longLongValue] || self.quotes[pinnedId] ||
				[self.quotesRequested containsObject:pinnedId])
			continue;
		[self.quotesRequested addObject:pinnedId];

		[[TGClient shared] messageWithId:pinnedId.longLongValue
								  inChat:self.chatId
							  completion:^(NSDictionary *original) {
								  TGChatViewController *strongSelf = weakSelf;
								  if (!strongSelf)
									  return;
								  if (!original) {
									  [strongSelf.quotesMissing addObject:pinnedId];
									  [strongSelf tg_invalidateLayoutForRepliesToMessageId:pinnedId.longLongValue];
									  [strongSelf.table reloadData];
									  return;
								  }
								  strongSelf.quotes[pinnedId] = original;
								  [strongSelf tg_invalidateLayoutForRepliesToMessageId:pinnedId.longLongValue];
								  [strongSelf setNeedsTableReload];
							  }];
	}
}

- (void)fetchMissingVoiceFiles {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *m in self.messages) {
		if (![m[@"kind"] isEqualToString:@"messageVoiceNote"])
			continue;
		NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
		if (!docId)
			continue;
		NSDictionary *state = [self fileStateFor:m];
		if ([state[@"local"] boolValue] || [state[@"active"] boolValue])
			continue;
		if ([self.voiceFilesRequested containsObject:docId])
			continue;
		[self.voiceFilesRequested addObject:docId];

		[TGFileDownloadService downloadFile:docId.longLongValue completion:^(NSString *path) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf.voiceFilesRequested removeObject:docId];
			NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
			if (path.length && messageId)
				[strongSelf tg_invalidateLayoutForMessageId:messageId.longLongValue];
			[strongSelf setNeedsTableReload];
		}];
	}
}

- (void)interactionInfoChanged:(NSNotification *)note {
	NSDictionary *payload = note.object;
	if (![payload isKindOfClass:NSDictionary.class])
		return;
	if ([payload[@"chatId"] longLongValue] != self.chatId)
		return;
	NSNumber *messageId = payload[@"messageId"];
	if (![messageId isKindOfClass:NSNumber.class] || !messageId.longLongValue)
		return;

	NSArray *chips = [payload[@"chips"] isKindOfClass:NSArray.class]
		? payload[@"chips"]
		: @[];
	self.reactionChips[messageId] = chips;
	[self.reactionChipsRequested removeObject:messageId];
	[self.chipsRowSizes removeObjectForKey:messageId];

	if ([payload[@"commentCount"] isKindOfClass:NSNumber.class])
		self.commentCounts[messageId] = payload[@"commentCount"];
	if ([payload[@"views"] isKindOfClass:NSNumber.class])
		self.viewCounts[messageId] = payload[@"views"];

	[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	[self setNeedsTableReload];
}

- (void)customReactionEmojiResolved {
	[self.reactionChipsRequested removeAllObjects];
	[self.chipsRowSizes removeAllObjects];
	for (NSDictionary *m in self.messages) {
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (!messageId)
			continue;
		BOOL hasChips = self.reactionChips[messageId] ||
			([m[@"reactionChips"] isKindOfClass:NSArray.class] &&
				[m[@"reactionChips"] count]);
		if (hasChips)
			[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	}
	[self setNeedsTableReload];
}

- (void)fetchMissingReactionChips {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *m in self.messages) {
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (!messageId || ![m[@"reactions"] length])
			continue;
		if ([m[@"reactionChips"] isKindOfClass:NSArray.class] &&
			[m[@"reactionChips"] count])
			continue;
		if (self.reactionChips[messageId] ||
			[self.reactionChipsRequested containsObject:messageId])
			continue;
		[self.reactionChipsRequested addObject:messageId];

		[[TGClient shared] reactionChipsForMessage:messageId.longLongValue
											inChat:self.chatId
										completion:^(NSArray *chips) {
											TGChatViewController *strongSelf = weakSelf;
											if (!strongSelf || !chips.count)
												return;
											strongSelf.reactionChips[messageId] = chips;
											[strongSelf.chipsRowSizes removeObjectForKey:messageId];
											[strongSelf tg_invalidateLayoutForMessageId:messageId.longLongValue];
											[strongSelf setNeedsTableReload];
										}];
	}
}

- (void)savedMessagesTagLabelsChanged {
	NSMutableArray *affected = [NSMutableArray array];
	for (NSDictionary *m in self.messages) {
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (messageId && self.reactionChips[messageId])
			[affected addObject:messageId];
	}
	[self.reactionChips removeObjectsForKeys:affected];
	[self.chipsRowSizes removeObjectsForKeys:affected];
	[self.reactionChipsRequested removeAllObjects];
	for (NSNumber *messageId in affected)
		[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	[self fetchMissingReactionChips];
	[self setNeedsTableReload];
}

- (void)fetchMissingLinkPreviews {
	if (![TGPreferenceFlags secretChatLinkPreviewsEnabled] &&
		[[TGClient shared] isSecretChat:self.chatId])
		return;
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *m in self.messages) {
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (!messageId || [m[@"service"] boolValue])
			continue;
		if (![m[@"kind"] isEqualToString:@"messageText"])
			continue;
		NSString *text = m[@"text"];
		if (!TGLinkPreviewFetchCandidateText(text))
			continue;
		NSDictionary *linkPreviewOptions = [m[@"linkPreviewOptions"] isKindOfClass:NSDictionary.class]
			? m[@"linkPreviewOptions"]
			: nil;
		if (TGLinkPreviewOptionsAreDisabled(linkPreviewOptions))
			continue;
		if (self.linkPreviews[messageId] ||
			[self.linkPreviewsRequested containsObject:messageId])
			continue;
		[self.linkPreviewsRequested addObject:messageId];

		NSDictionary *optionValues = TGLinkPreviewOptionValuesFromMessage(linkPreviewOptions);
		NSDictionary *previewOptions = [TGClient linkPreviewOptionsDisabled:NO
																		 url:optionValues[TGLinkPreviewOptionURL]
															 forceSmallMedia:[optionValues[TGLinkPreviewOptionForceSmallMedia] boolValue]
															 forceLargeMedia:[optionValues[TGLinkPreviewOptionForceLargeMedia] boolValue]
															   showAboveText:[optionValues[TGLinkPreviewOptionShowAboveText] boolValue]];

		TGClient *client = [TGClient shared];
		[client linkPreviewForText:text withOptions:previewOptions completion:^(NSDictionary *preview) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || ![preview[@"url"] length])
				return;
			strongSelf.linkPreviews[messageId] = preview;
			NSNumber *photo = preview[@"photoFileId"];
			if ([photo isKindOfClass:NSNumber.class] && photo.integerValue != 0 &&
				!strongSelf.images[photo] && ![strongSelf.imagesRequested containsObject:photo]) {
				[strongSelf.imagesRequested addObject:photo];
				CGFloat limit = [strongSelf pictureDecodeLimit];
				[client downloadFile:photo.integerValue completion:^(NSString *path) {
					TGChatViewController *innerSelf = weakSelf;
					if (!path.length) {
						[innerSelf.imagesRequested removeObject:photo];
						return;
					}
					dispatch_async(TGImageDecodeQueue(), ^{
						UIImage *image = TGDecodeThumbnail(path, limit);
						dispatch_async(dispatch_get_main_queue(), ^{
							TGChatViewController *inner = weakSelf;
							if (!inner)
								return;
							if (!image) {
								[inner.imagesRequested removeObject:photo];
								return;
							}
							[inner storeImage:image forFile:photo];
							[inner tg_invalidateLayoutForMessageId:messageId.longLongValue];
							[inner setNeedsTableReload];
						});
					});
				}];
			}
			[strongSelf tg_invalidateLayoutForMessageId:messageId.longLongValue];
			[strongSelf setNeedsTableReload];
		}];
	}
}

- (NSDictionary *)richPreviewDictFor:(NSDictionary *)m {
	NSNumber *coverFileId = [m[@"richCoverFileId"] isKindOfClass:NSNumber.class]
		? m[@"richCoverFileId"]
		: nil;
	NSString *subtitle = [m[@"richSubtitle"] isKindOfClass:NSString.class] ? m[@"richSubtitle"] : @"";
	NSString *snippet = [m[@"richSnippet"] isKindOfClass:NSString.class] ? m[@"richSnippet"] : @"";
	int64_t messageId = [m[@"id"] longLongValue];
	return @{
		@"url" : [NSString stringWithFormat:@"tg-rich-message:%lld", messageId],
		@"siteName" : m[@"richKicker"] ?: @"",
		@"title" : [m[@"richTitle"] length] ? m[@"richTitle"]
											: TGL(@"Attachment.Article", @"Article"),
		@"description" : subtitle.length
			? [NSString stringWithFormat:@"%@\n%@", subtitle, snippet]
			: snippet,
		@"photoFileId" : coverFileId ?: (id)[NSNull null],
		@"hasInstantView" : @YES,
		@"hasLargeMedia" : @(coverFileId != nil),
		@"showLargeMedia" : @YES,
		@"showMediaAboveDescription" : @YES,
	};
}

- (NSDictionary *)previewFor:(NSDictionary *)m {
	if ([m[@"kind"] isEqualToString:@"messageRichMessage"])
		return [self richPreviewDictFor:m];
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	return messageId ? self.linkPreviews[messageId] : nil;
}

- (void)fetchMissingRichMessageCovers {
	for (NSDictionary *m in self.messages) {
		if (![m[@"kind"] isEqualToString:@"messageRichMessage"])
			continue;
		NSNumber *photo = m[@"richCoverFileId"];
		if (![photo isKindOfClass:NSNumber.class] || photo.integerValue == 0)
			continue;
		if (self.images[photo] || [self.imagesRequested containsObject:photo])
			continue;
		[self.imagesRequested addObject:photo];

		int64_t messageId = [m[@"id"] longLongValue];
		__weak typeof(self) weakSelf = self;
		CGFloat limit = [self pictureDecodeLimit];
		[[TGClient shared] downloadFile:photo.integerValue completion:^(NSString *path) {
			TGChatViewController *strongSelf = weakSelf;
			if (!path.length) {
				[strongSelf.imagesRequested removeObject:photo];
				return;
			}
			dispatch_async(TGImageDecodeQueue(), ^{
				UIImage *image = TGDecodeThumbnail(path, limit);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGChatViewController *innerSelf = weakSelf;
					if (!innerSelf)
						return;
					if (!image) {
						[innerSelf.imagesRequested removeObject:photo];
						return;
					}
					[innerSelf storeImage:image forFile:photo];
					[innerSelf tg_invalidateLayoutForMessageId:messageId];
					[innerSelf setNeedsTableReload];
				});
			});
		}];
	}
}

- (UIImage *)previewImageFor:(NSDictionary *)preview {
	NSNumber *photo = preview[@"photoFileId"];
	return [photo isKindOfClass:NSNumber.class] ? self.images[photo] : nil;
}

- (CGSize)previewSizeFor:(NSDictionary *)m {
	NSDictionary *preview = [self previewFor:m];
	if (!preview)
		return CGSizeZero;

	return [TGLinkPreviewView sizeForPreview:preview
									   image:[self previewImageFor:preview]
									maxWidth:[self maxBubbleWidthFor:m] - 2 * kPadH];
}

- (NSArray *)chipsFor:(NSDictionary *)m {
	if ([m[@"service"] boolValue])
		return nil;
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	NSArray *fresher = messageId ? self.reactionChips[messageId] : nil;
	if (fresher)
		return [TGClient resolvedChips:fresher];
	id own = m[@"reactionChips"];
	return [own isKindOfClass:NSArray.class] ? [TGClient resolvedChips:own] : nil;
}

- (CGSize)chipsRowSizeFor:(NSDictionary *)m {
	NSArray *chips = [self chipsFor:m];
	if (!chips.count)
		return CGSizeZero;

	CGFloat maxW = [self maxBubbleWidthFor:m] - 2 * kPadH;
	CGFloat floorW = [TGReactionChipsView rowHeight] * 2;
	if (maxW < floorW)
		maxW = floorW;

	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	NSArray *cached = messageId ? self.chipsRowSizes[messageId] : nil;
	if (cached.count == 2 && fabsf([cached[0] floatValue] - maxW) < 0.5f)
		return [cached[1] CGSizeValue];

	CGSize size = [TGReactionChipsView sizeForChips:chips width:maxW];
	if (size.width < 1 || size.height < 1)
		return CGSizeZero;
	if (messageId)
		self.chipsRowSizes[messageId] = @[ @(maxW), [NSValue valueWithCGSize:size] ];
	return size;
}

- (void)fetchMissingImages {
	__weak typeof(self) weakSelf = self;
	[self fetchMissingReactionChips];
	[self fetchMissingLinkPreviews];
	[self fetchMissingRichMessageCovers];

	for (NSDictionary *m in self.messages) {
		if (![m[@"docName"] isEqualToString:@"tgs"])
			continue;
		NSNumber *docId = m[@"docId"];
		if (![docId isKindOfClass:NSNumber.class] || self.lottiePaths[docId])
			continue;
		if ([self.imagesRequested containsObject:docId])
			continue;
		[self.imagesRequested addObject:docId];

		[[TGClient shared] downloadFile:[docId longLongValue] completion:^(NSString *path) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || !path)
				return;
			strongSelf.lottiePaths[docId] = path;
			int64_t messageId = [m[@"id"] longLongValue];
			if (messageId)
				[strongSelf tg_invalidateLayoutForMessageId:messageId];
			[strongSelf setNeedsTableReloadKeepingBottom];
		}];
	}

	self.photoWindow = NSMakeRange(NSNotFound, 0);
	[self fetchVisiblePictures];
}

- (void)updateShortContentInset {
	if (!self.table)
		return;
	UIEdgeInsets insets = self.table.contentInset;
	CGFloat fixed = insets.top - self.shortContentInset;
	CGFloat room = self.table.bounds.size.height - fixed - insets.bottom;
	NSInteger rows = [self displayRowCount];
	if (self.shortContentInset <= 0 && rows * kSystemPlateHeight > room)
		return;
	CGFloat pad = rows ? room - self.table.contentSize.height : 0;
	if (pad < 0)
		pad = 0;
	if (fabsf(pad - self.shortContentInset) < 0.5f)
		return;
	insets.top = fixed + pad;
	self.shortContentInset = pad;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
}

- (void)scrollToBottomAnimated:(BOOL)animated {
	if (![self displayRowCount])
		return;
	NSIndexPath *last = [NSIndexPath indexPathForRow:[self displayRowCount] - 1
										   inSection:0];
	[self.table scrollToRowAtIndexPath:last
					  atScrollPosition:UITableViewScrollPositionBottom
							  animated:animated];
	[self updateScrollDownButton];
}

static const CGFloat kEmptyPlateWidth = 122.0f;
static const CGFloat kEmptyPlateHeight = 116.0f;

- (void)centreEmptyPlate {
	if (!self.emptyPlate)
		return;
	CGRect history = self.table.frame;
	if (history.size.height < 1)
		return;
	self.emptyPlate.frame = CGRectMake(
		floorf((history.size.width - kEmptyPlateWidth) / 2),
		CGRectGetMinY(history) + self.pinnedBannerInset +
			floorf((history.size.height - self.pinnedBannerInset -
					   kEmptyPlateHeight) /
				2),
		kEmptyPlateWidth, kEmptyPlateHeight);
}

- (void)updateEmptyState {
	BOOL wanted = (self.messages.count == 0);
	if (!wanted && !self.emptyPlate)
		return;

	if (!self.emptyPlate) {
		self.emptyPlate = [[UIView alloc]
			initWithFrame:
				CGRectMake(0, 0, kEmptyPlateWidth, kEmptyPlateHeight)];
		self.emptyPlate.backgroundColor = TGSystemPlateColour();
		self.emptyPlate.layer.cornerRadius = 10;
		self.emptyPlate.userInteractionEnabled = NO;
		self.emptyPlate.alpha = 0.0f;
		self.emptyPlate.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin |
			UIViewAutoresizingFlexibleTopMargin |
			UIViewAutoresizingFlexibleBottomMargin;
		[self.view insertSubview:self.emptyPlate aboveSubview:self.wallpaperView];

		UIImage *glyph = [UIImage imageNamed:@"ConversationIconPlain.png"];
		if (!glyph)
			glyph = [self plainConversationGlyph];
		self.emptyGlyph = [[UIImageView alloc] initWithImage:glyph];
		self.emptyGlyph.frame = CGRectMake(
			floorf((kEmptyPlateWidth - glyph.size.width) / 2), 23,
			glyph.size.width, glyph.size.height);
		[self.emptyPlate addSubview:self.emptyGlyph];

		self.emptyLabel = [[UILabel alloc] init];
		self.emptyLabel.numberOfLines = 0;
		self.emptyLabel.lineBreakMode = NSLineBreakByWordWrapping;
		self.emptyLabel.textAlignment = NSTextAlignmentCenter;
		self.emptyLabel.font = [UIFont boldSystemFontOfSize:13];
		self.emptyLabel.textColor = [UIColor whiteColor];
		self.emptyLabel.backgroundColor = [UIColor clearColor];
		self.emptyLabel.userInteractionEnabled = NO;
		[self.emptyPlate addSubview:self.emptyLabel];
	}

	self.emptyLabel.text = self.chatSearchBar
		? TGL(@"Conversation.SearchNoResults", @"No results")
		: TGL(@"Conversation.EmptyPlaceholder", @"No messages here yet");
	CGSize fits = [self.emptyLabel sizeThatFits:CGSizeMake(110, 1000)];
	self.emptyLabel.frame = CGRectMake(floorf((kEmptyPlateWidth - fits.width) / 2),
		kEmptyPlateHeight - fits.height - 8,
		fits.width, fits.height);
	[self centreEmptyPlate];

	BOOL shown = (!self.emptyPlate.hidden && self.emptyPlate.alpha > 0.01f);
	if (wanted == shown)
		return;
	if (wanted) {
		self.emptyPlate.hidden = NO;
		[UIView animateWithDuration:0.3 delay:0.0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{ self.emptyPlate.alpha = 1.0f; }
						 completion:nil];
		return;
	}
	[UIView animateWithDuration:0.3 delay:0.0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{ self.emptyPlate.alpha = 0.0f; }
		completion:^(BOOL finished) {
			if (finished && self.emptyPlate.alpha < 0.01f)
				self.emptyPlate.hidden = YES;
		}];
}

- (UIImage *)plainConversationGlyph {
	CGSize size = CGSizeMake(47, 39);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
	CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
	CGContextSetLineWidth(ctx, 1.5f);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);

	CGRect body = CGRectMake(1, 1, 45, 30);
	CGFloat radius = 6;
	CGContextBeginPath(ctx);
	CGContextMoveToPoint(ctx, CGRectGetMinX(body) + radius, CGRectGetMinY(body));
	CGContextAddArcToPoint(ctx, CGRectGetMaxX(body), CGRectGetMinY(body),
		CGRectGetMaxX(body), CGRectGetMaxY(body), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMaxX(body), CGRectGetMaxY(body),
		CGRectGetMinX(body), CGRectGetMaxY(body), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMinX(body), CGRectGetMaxY(body),
		CGRectGetMinX(body), CGRectGetMinY(body), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMinX(body), CGRectGetMinY(body),
		CGRectGetMaxX(body), CGRectGetMinY(body), radius);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);

	CGContextBeginPath(ctx);
	CGContextMoveToPoint(ctx, 11, 30.5f);
	CGContextAddLineToPoint(ctx, 23, 30.5f);
	CGContextAddLineToPoint(ctx, 12, 38.5f);
	CGContextClosePath(ctx);
	CGContextFillPath(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (void)setFloatingButton:(UIButton *)button shown:(BOOL)shown {
	if (!button)
		return;
	BOOL onScreen = (!button.hidden && button.alpha > 0.01f);
	if (onScreen == shown)
		return;
	if (shown) {
		button.alpha = 0.0f;
		button.hidden = NO;
		[UIView animateWithDuration:0.3 delay:0.0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{ button.alpha = 1.0f; }
						 completion:nil];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:0.2 delay:0.0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{ button.alpha = 0.0f; }
		completion:^(BOOL finished) {
			if (!finished || button.alpha > 0.01f)
				return;
			button.hidden = YES;
			[weakSelf layoutFloatingButtons];
		}];
}

- (void)layoutFloatingButtons {
	CGFloat right = self.view.bounds.size.width - kFloatingButtonSide - kFloatingButtonGap;
	CGFloat bottom = CGRectGetMinY(self.inputBar.frame) - self.composeBannerInset -
		self.actionBarInset - kFloatingButtonGap;
	NSArray *column = @[ self.scrollDownButton ?: (id)[NSNull null],
		self.mentionButton ?: (id)[NSNull null],
		self.reactionButton ?: (id)[NSNull null] ];
	for (id entry in column) {
		if (![entry isKindOfClass:UIButton.class])
			continue;
		UIButton *button = entry;
		if (button.hidden && button.alpha < 0.01f)
			continue;
		bottom -= kFloatingButtonSide;
		button.frame = CGRectMake(right, bottom,
			kFloatingButtonSide, kFloatingButtonSide);
		bottom -= kFloatingButtonGap;
		[self.view bringSubviewToFront:button];
	}
}

- (void)updateScrollDownButton {
	BOOL wanted = (self.messages.count > 0) &&
		(![self historyIsAtBottom] || [self historyStopsShortOfTheNewest]);

	if (!wanted && !self.scrollDownButton)
		return;

	if (!self.scrollDownButton) {
		self.scrollDownButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.scrollDownButton.frame = CGRectMake(0, 0, kFloatingButtonSide,
			kFloatingButtonSide);

		[self.scrollDownButton setBackgroundImage:
				[TGIcons floatingPlateOfSide:kFloatingButtonSide chevron:YES pressed:NO]
										 forState:UIControlStateNormal];
		[self.scrollDownButton setBackgroundImage:
				[TGIcons floatingPlateOfSide:kFloatingButtonSide chevron:YES pressed:YES]
										 forState:UIControlStateHighlighted];
		self.scrollDownButton.showsTouchWhenHighlighted = NO;
		self.scrollDownButton.adjustsImageWhenHighlighted = NO;
		self.scrollDownButton.layer.shadowColor = [UIColor blackColor].CGColor;
		self.scrollDownButton.layer.shadowOffset = CGSizeMake(0, 1);
		self.scrollDownButton.layer.shadowRadius = 1.0f;
		self.scrollDownButton.layer.shadowOpacity = 0.25f;
		self.scrollDownButton.layer.shadowPath =
			[UIBezierPath bezierPathWithOvalInRect:
					CGRectMake(0, 0, kFloatingButtonSide, kFloatingButtonSide)]
				.CGPath;
		self.scrollDownButton.hidden = YES;
		self.scrollDownButton.alpha = 0.0f;
		self.scrollDownButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleTopMargin;
		[self.scrollDownButton addTarget:self action:@selector(scrollDownTapped)
						forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:self.scrollDownButton];
	}
	[self setFloatingButton:self.scrollDownButton shown:wanted];
	[self updateScrollDownBadge:(wanted ? [self unreadMessagesStillBelow] : 0)];
	[self layoutFloatingButtons];
}

- (void)updateScrollDownBadge:(NSInteger)unread {
	if (unread <= 0) {
		self.scrollDownBadge.hidden = YES;
		return;
	}

	if (!self.scrollDownBadge) {
		self.scrollDownBadge = [[UILabel alloc] init];
		self.scrollDownBadge.font = [UIFont boldSystemFontOfSize:12];
		self.scrollDownBadge.textColor = [UIColor whiteColor];
		self.scrollDownBadge.textAlignment = NSTextAlignmentCenter;
		self.scrollDownBadge.backgroundColor = [[TGTheme shared] accentColour];
		self.scrollDownBadge.layer.cornerRadius = 9.0f;
		self.scrollDownBadge.clipsToBounds = YES;
		self.scrollDownBadge.userInteractionEnabled = NO;
		[self.scrollDownButton addSubview:self.scrollDownBadge];
	}

	self.scrollDownBadge.text = unread > 99 ? @"99+"
											: [NSString stringWithFormat:@"%ld", (long)unread];
	CGFloat width = MAX(18.0f, ceilf([self.scrollDownBadge.text sizeWithFont:self.scrollDownBadge.font].width) + 10.0f);
	self.scrollDownBadge.frame = CGRectMake(
		(kFloatingButtonSide - width) / 2, -6, width, 18);
	self.scrollDownBadge.hidden = NO;
	[self.scrollDownButton bringSubviewToFront:self.scrollDownBadge];
}

- (BOOL)historyIsAtBottom {
	CGFloat fromBottom = self.table.contentSize.height -
		(self.table.contentOffset.y + self.table.bounds.size.height);
	return (fromBottom <= 220);
}

- (BOOL)historyWindowHoldsTheNewest {
	long long newest = [[TGClient shared] lastMessageIdInChat:self.chatId];
	if (newest == 0 || self.threadId != 0 || self.savedTopicId != 0 ||
		self.directMessagesTopicId != 0)
		return YES;
	NSDictionary *last = [self messageAtRow:[self displayRowCount] - 1];
	if (![last[@"id"] isKindOfClass:NSNumber.class])
		return YES;
	return [last[@"id"] longLongValue] >= newest;
}

- (BOOL)historyStopsShortOfTheNewest {
	return self.openedOnAnAnchor && ![self historyWindowHoldsTheNewest];
}

- (void)scrollDownTapped {
	if ([self historyWindowHoldsTheNewest]) {
		[self scrollToBottomAnimated:YES];
		return;
	}
	[self loadNewestHistoryAndShowIt];
}

- (void)loadNewestHistoryAndShowIt {
	if (self.deeperHistoryPending)
		return;
	self.deeperHistoryPending = YES;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] historyForChat:self.chatId
							   thread:self.threadId
								limit:kHistoryPageLimit
							onlyLocal:NO
						   completion:^(NSArray *messages) {
							   TGChatViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   strongSelf.deeperHistoryPending = NO;
							   if (!messages.count) {
								   [strongSelf scrollToBottomAnimated:YES];
								   return;
							   }
							   strongSelf.openAnchorFetchId = 0;
							   strongSelf.openAnchorRestoreId = 0;
							   strongSelf.openAnchorIsUnread = NO;
							   strongSelf.openedOnAnAnchor = NO;
							   strongSelf.unreadOnOpen = 0;
							   strongSelf.cachedUnreadKey = nil;
							   strongSelf.cachedUnreadRow = NSNotFound;
							   strongSelf.messages = TGMessagesWithChatUpgradeMarkersRemoved(messages);
							   [strongSelf.table reloadData];
							   [strongSelf updateShortContentInset];
							   [strongSelf scrollToBottomAnimated:NO];
							   [strongSelf updateScrollDownButton];
							   [strongSelf fetchMissingImages];
							   [strongSelf resolveUnknownSenders];
							   [strongSelf fetchMissingQuotes];
							   [strongSelf readWhatIsOnScreenSoon];
						   }];
}

- (void)loadOlderHistoryIfNeeded {
	if (self.olderHistoryPending || self.olderHistoryExhausted)
		return;
	if (self.chatSearchBar || !self.messages.count)
		return;
	NSNumber *anchor = [[self.messages firstObject][@"id"] isKindOfClass:NSNumber.class]
		? [self.messages firstObject][@"id"]
		: nil;
	if (!anchor)
		return;

	self.olderHistoryPending = YES;
	long long anchorId = anchor.longLongValue;
	int64_t requestedChatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] historyForChat:self.chatId
							   thread:self.threadId
						aroundMessage:anchorId
								newer:0
								limit:kHistoryPageLimit
							onlyLocal:NO
							 progress:nil
						   completion:^(NSArray *messages) {
							   TGChatViewController *strongSelf = weakSelf;
							   if (!strongSelf || strongSelf.chatId != requestedChatId)
								   return;
							   strongSelf.olderHistoryPending = NO;
							   [strongSelf applyOlderHistoryPage:messages olderThan:anchorId];
						   }];
}

- (void)applyOlderHistoryPage:(NSArray *)messages olderThan:(long long)anchorId {
	NSArray *merged = TGHistoryWithOlderPagePrepended(self.messages, messages, anchorId);
	if (!merged) {
		self.olderHistoryExhausted = YES;
		return;
	}
	BOOL wasAnchoredToBottom = self.anchorToBottom;
	[self applyHistory:merged final:NO partial:NO];
	self.anchorToBottom = wasAnchoredToBottom;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != self.table)
		return;
	[self updateScrollDownButton];
	[self markVisibleMessagesRead];
	[self fetchVisiblePictures];
	if (scrollView.contentOffset.y < kOlderHistoryTriggerOffset)
		[self loadOlderHistoryIfNeeded];
}

@end
