#import "TGClient+ChatManagement.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGEmoji.h"
#import "TGClient+Messages.h"
#import "TGClient+Forums.h"
#import "TGClient+SavedMessages.h"
#import "TGLocalization.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGChatUpgradeMarkerFilter.h"

@implementation TGChatViewController (Pinned)

static NSString *TGPinnedBannerLoadingText(void) {
	return TGL(@"Chat.PinnedListPreview.Loading", @"Loading...");
}

static NSString *TGFirstLineOfText(NSString *text) {
	if (![text isKindOfClass:NSString.class] || !text.length)
		return @"";
	NSArray *lines = [text componentsSeparatedByCharactersInSet:
			[NSCharacterSet newlineCharacterSet]];
	NSCharacterSet *blank = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	for (NSString *line in lines) {
		NSString *trimmed = [line stringByTrimmingCharactersInSet:blank];
		if (trimmed.length)
			return trimmed;
	}
	return @"";
}

static NSString *TGPhraseFromContentType(NSString *ctype) {
	NSString *rest = [ctype hasPrefix:@"message"] ? [ctype substringFromIndex:7] : ctype;
	if (!rest.length)
		return TGL(@"Conversation.InputTextPlaceholder", @"Message");
	NSMutableString *out = [NSMutableString stringWithCapacity:rest.length + 8];
	for (NSInteger i = 0; i < rest.length; i++) {
		unichar c = [rest characterAtIndex:i];
		if (i > 0 && c >= 'A' && c <= 'Z') {
			[out appendString:@" "];
			[out appendFormat:@"%C", (unichar)(c - 'A' + 'a')];
		} else {
			[out appendFormat:@"%C", c];
		}
	}
	return out;
}

- (void)loadPinnedMessage {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] pinnedMessagesForChat:self.chatId thread:self.threadId savedTopic:self.savedTopicId completion:^(NSArray *found) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !found)
			return;
		if (found.count || strongSelf.threadId != 0 || strongSelf.savedTopicId != 0) {
			[strongSelf adoptPinnedMessages:found];
			return;
		}
		[[TGClient shared] pinnedMessageForChat:strongSelf.chatId completion:^(NSDictionary *m) {
			TGChatViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			[innerSelf adoptPinnedMessages:[m isKindOfClass:NSDictionary.class] ? @[ m ] : @[]];
		}];
	}];
}

- (void)adoptPinnedMessages:(NSArray *)messages {
	int64_t previous = self.pinnedMessageId;
	self.pinnedMessages = messages ?: @[];
	if (!self.pinnedMessages.count) {
		self.pinnedMessageId = 0;
		self.pinnedMessage = nil;
		self.pinnedIndex = 0;
		[self hidePinnedBanner];
		[self leavePinnedListIfShowing];
		return;
	}

	NSInteger keep = NSNotFound;
	for (NSInteger i = 0; i < (NSInteger)self.pinnedMessages.count; i++) {
		if ([self.pinnedMessages[i][@"id"] longLongValue] == previous) {
			keep = i;
			break;
		}
	}
	self.pinnedIndex = (keep != NSNotFound)
		? keep
		: (NSInteger)self.pinnedMessages.count - 1;
	[self showPinnedMessageAtIndex:self.pinnedIndex];
	if (self.messagesBeforePinnedList)
		[self showAllPinnedMessages];
}

- (void)showPinnedMessageAtIndex:(NSInteger)index {
	if (!self.pinnedMessages.count)
		return;
	if (index < 0 || index >= (NSInteger)self.pinnedMessages.count)
		index = 0;
	self.pinnedIndex = index;

	NSDictionary *m = self.pinnedMessages[index];
	self.pinnedMessage = m;
	self.pinnedMessageId = [m[@"id"] longLongValue];

	NSString *text = [self pinnedBannerBodyFor:m];
	NSString *caption = [self pinnedBannerCaption];

	UILabel *captionLabel = (UILabel *)[self.pinnedBanner viewWithTag:kPinnedBannerCaptionTag];
	UILabel *bodyLabel = (UILabel *)[self.pinnedBanner viewWithTag:kPinnedBannerBodyTag];
	if (captionLabel && bodyLabel) {
		captionLabel.text = caption;
		bodyLabel.text = text;
	} else {
		[self showPinnedBanner:text caption:caption];
	}

	if (![self pinnedMessageIsResolved:m])
		[self resolvePinnedMessageAtIndex:index];
}

- (NSString *)pinnedBannerBodyFor:(NSDictionary *)m {
	if (![m isKindOfClass:NSDictionary.class])
		return TGPinnedBannerLoadingText();

	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	NSString *text = TGFirstLineOfText([m[@"text"] isKindOfClass:NSString.class]
			? m[@"text"]
			: nil);

	if ([kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"])
		return text.length ? [NSString stringWithFormat:TGL(@"Message.StickerText", @"Sticker %@"), text] : TGL(@"Message.Sticker", @"Sticker");

	if (text.length)
		return text;

	NSString *label = [self quoteKindLabelFor:m];
	if (label.length)
		return label;
	if (kind.length)
		return TGPhraseFromContentType(kind);
	return TGPinnedBannerLoadingText();
}

- (BOOL)pinnedMessageIsResolved:(NSDictionary *)m {
	if (![m isKindOfClass:NSDictionary.class])
		return NO;
	if ([m[@"text"] isKindOfClass:NSString.class] && [m[@"text"] length])
		return YES;
	return [m[@"kind"] isKindOfClass:NSString.class] && [m[@"kind"] length];
}

- (void)resolvePinnedMessageAtIndex:(NSInteger)index {
	int64_t messageId = self.pinnedMessageId;
	if (messageId == 0)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] messageWithId:messageId inChat:self.chatId
						  completion:^(NSDictionary *fetched) {
							  TGChatViewController *strongSelf = weakSelf;
							  if (!strongSelf || ![strongSelf pinnedMessageIsResolved:fetched])
								  return;
							  if (index < 0 || index >= (NSInteger)strongSelf.pinnedMessages.count)
								  return;
							  if ([strongSelf.pinnedMessages[index][@"id"] longLongValue] != messageId)
								  return;

							  NSMutableArray *merged = [strongSelf.pinnedMessages mutableCopy];
							  [merged replaceObjectAtIndex:index withObject:fetched];
							  strongSelf.pinnedMessages = merged;
							  if (strongSelf.pinnedIndex == index)
								  [strongSelf showPinnedMessageAtIndex:index];
						  }];
}

- (NSString *)pinnedBannerCaption {
	NSInteger total = (NSInteger)self.pinnedMessages.count;
	if (total < 2)
		return TGL(@"Conversation.PinnedMessage", @"Pinned message");
	return [NSString stringWithFormat:@"%@ #%ld", TGL(@"Conversation.PinnedMessage", @"Pinned message"),
		(long)(self.pinnedIndex + 1)];
}

- (void)hidePinnedBanner {
	if (!self.pinnedBanner)
		return;
	[self.pinnedBanner removeFromSuperview];
	self.pinnedBanner = nil;
	UIEdgeInsets insets = self.table.contentInset;
	insets.top -= self.pinnedBannerInset;
	self.pinnedBannerInset = 0;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
	[self centreEmptyPlate];
	[self updateShortContentInset];
}

- (void)showPinnedBanner:(NSString *)text {
	[self showPinnedBanner:text caption:TGL(@"Conversation.PinnedMessage", @"Pinned message")];
}

- (void)paintBannerGround:(UIView *)view {
	view.backgroundColor = [[TGTheme shared] inputBarColour];
	UIImage *strip = [UIImage imageNamed:@"ConversationInputPanel_Background"];
	if (strip == nil)
		return;
	UIImageView *ground = [[UIImageView alloc] initWithFrame:view.bounds];
	ground.image = [strip stretchableImageWithLeftCapWidth:0 topCapHeight:0];
	ground.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleHeight;
	ground.userInteractionEnabled = NO;
	[view addSubview:ground];
}

- (void)showPinnedBanner:(NSString *)text caption:(NSString *)captionText {
	[self hidePinnedBanner];
	CGRect b = self.view.bounds;
	const CGFloat height = 39;
	UIControl *banner = [[UIControl alloc] initWithFrame:
			CGRectMake(0, 0, b.size.width, height)];
	[self paintBannerGround:banner];
	banner.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[banner addTarget:self action:@selector(pinnedBannerTapped)
		forControlEvents:UIControlEventTouchUpInside];
	[banner addTarget:self action:@selector(pinnedBannerPressed:)
		forControlEvents:UIControlEventTouchDown];
	[banner addTarget:self action:@selector(pinnedBannerReleased:)
		forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
		UIControlEventTouchCancel];
	[banner addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
									 initWithTarget:self
											 action:@selector(pinnedBannerHeld:)]];

	const CGFloat textLeft = 12;
	const CGFloat closeWidth = 32;
	const CGFloat textRight = closeWidth + 4;
	UILabel *caption = [[TGEmojiLabel alloc] initWithFrame:
			CGRectMake(textLeft, 3, b.size.width - textLeft - textRight, 16)];
	caption.text = captionText.length ? captionText : TGL(@"Conversation.PinnedMessage", @"Pinned message");
	caption.font = [UIFont boldSystemFontOfSize:13];
	caption.textColor = [UIColor colorWithRed:0.302f green:0.408f blue:0.549f alpha:1.0f];
	caption.backgroundColor = [UIColor clearColor];
	caption.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	caption.tag = kPinnedBannerCaptionTag;
	[banner addSubview:caption];

	UILabel *body = [[TGEmojiLabel alloc] initWithFrame:
			CGRectMake(textLeft, 19, b.size.width - textLeft - textRight, 17)];
	body.text = text;
	body.font = [UIFont systemFontOfSize:13];
	body.textColor = [UIColor colorWithWhite:0.533f alpha:1.0f];
	body.backgroundColor = [UIColor clearColor];
	body.numberOfLines = 1;
	body.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	body.tag = kPinnedBannerBodyTag;
	[banner addSubview:body];

	UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
	close.frame = CGRectMake(b.size.width - closeWidth, 0, closeWidth, height - 1);
	close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[close setTitle:TGL(@"Chat.ComposeBannerClose", @"×") forState:UIControlStateNormal];
	[close setTitleColor:[UIColor colorWithWhite:0.533f alpha:1.0f]
				 forState:UIControlStateNormal];
	[close setTitleColor:[[TGTheme shared] accentColour]
				 forState:UIControlStateHighlighted];
	close.titleLabel.font = [UIFont systemFontOfSize:20];
	[close addTarget:self action:@selector(pinnedBannerCloseTapped)
		forControlEvents:UIControlEventTouchUpInside];
	[banner addSubview:close];

	UIView *hair = [[UIView alloc] initWithFrame:
			CGRectMake(0, height - 1, b.size.width, 1)];
	hair.backgroundColor = [UIColor colorWithRed:0.835f green:0.871f blue:0.898f alpha:1.0f];
	hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[banner addSubview:hair];

	UIView *litPlate = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, b.size.width, height - 1)];
	litPlate.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.08f];
	litPlate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	litPlate.userInteractionEnabled = NO;
	litPlate.alpha = 0.0f;
	litPlate.tag = kPinnedBannerHighlightTag;
	[banner addSubview:litPlate];

	[self.view addSubview:banner];
	self.pinnedBanner = banner;
	self.pinnedBannerInset = height;

	UIEdgeInsets insets = self.table.contentInset;
	insets.top += height;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
	[self centreEmptyPlate];
	[self updateShortContentInset];
}

- (void)pinnedBannerPressed:(UIControl *)banner {
	[banner viewWithTag:kPinnedBannerHighlightTag].alpha = 1.0f;
}

- (void)pinnedBannerReleased:(UIControl *)banner {
	UIView *lit = [banner viewWithTag:kPinnedBannerHighlightTag];
	[UIView animateWithDuration:0.2 delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{ lit.alpha = 0.0f; }
					 completion:nil];
}

- (void)pinnedBannerTapped {
	if (self.messagesBeforePinnedList)
		return;
	if (self.pinnedMessageId == 0)
		return;

	NSDictionary *target = self.pinnedMessage;
	int64_t targetId = self.pinnedMessageId;
	[self advancePinnedBanner];
	[self jumpToPinnedMessage:target withId:targetId];
}

- (void)pinnedBannerCloseTapped {
	if (self.pinnedMessageId == 0)
		return;

	int64_t chatId = self.chatId;
	int64_t messageId = self.pinnedMessageId;

	[self purgeDeletedPinnedMessageId:messageId];

	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.view
					   text:TGL(@"Chat.MessageUnpinned", @"Message unpinned")
					seconds:5
					   kind:TGSnackbarKindDestructiveUndo
				   onCommit:^{
					   [[TGClient shared] unpinMessage:messageId inChat:chatId
											 completion:^(BOOL ok) {
												 TGChatViewController *strongSelf = weakSelf;
												 if (!strongSelf || ok)
													 return;
												 [TGSnackbar showInView:strongSelf.view
																   text:TGL(@"Toast.CouldNotUnpinMessage", @"Could not unpin the message")
																seconds:2
															   onCommit:nil];
											 }];
				   }];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{ [weakSelf loadPinnedMessage]; });
}

- (void)jumpToPinnedMessage:(NSDictionary *)message withId:(int64_t)messageId {
	(void)message;
	__weak typeof(self) weakSelf = self;
	[self jumpToMessageId:messageId inCurrentChatNotFound:^{
		[weakSelf purgeDeletedPinnedMessageId:messageId];
	}];
}

- (void)jumpToMessageId:(int64_t)messageId inCurrentChatNotFound:(void (^)(void))notFound {
	if (messageId == 0 || [self scrollToMessageId:messageId])
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] fetchMessageId:messageId inChat:self.chatId
						   completion:^(NSDictionary *fetched, BOOL confirmedNotFound) {
							   TGChatViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   if (!fetched) {
								   if (confirmedNotFound) {
									   if (notFound)
										   notFound();
								   } else {
									   [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotJumpToMessage", @"Could not jump to that message. Try again.")];
								   }
								   return;
							   }
							   if ([strongSelf scrollToMessageId:messageId])
								   return;
							   if ([strongSelf insertMessagePlaceholder:fetched]) {
								   [strongSelf.table reloadData];
								   if ([strongSelf scrollToMessageId:messageId])
									   return;
							   }
							   [strongSelf loadDeeperHistoryAndScrollTo:messageId];
						   }];
}

- (void)advancePinnedBanner {
	if (self.pinnedMessages.count < 2)
		return;
	NSInteger next = self.pinnedIndex - 1;
	if (next < 0)
		next = (NSInteger)self.pinnedMessages.count - 1;
	[self showPinnedMessageAtIndex:next];
}

- (void)showAllPinnedMessages {
	if (!self.pinnedMessages.count)
		return;
	if (!self.messagesBeforePinnedList) {
		self.messagesBeforePinnedList = self.messages ?: @[];
		self.rightItemBeforePinnedList = self.navigationItem.rightBarButtonItem;
		self.titleViewBeforePinnedList = self.navigationItem.titleView;
		self.navigationItem.titleView = nil;
		self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Done", @"Done") bold:YES
									   target:self
									   action:@selector(leavePinnedList)];
	}
	[self hidePinnedBanner];
	self.messages = self.pinnedMessages;
	self.anchorToBottom = NO;
	[self.table reloadData];
	[self updateEmptyState];
	[self setPinnedListTitle];
}

- (void)setPinnedListTitle {
	NSInteger total = (NSInteger)self.pinnedMessages.count;
	self.navigationItem.title = TGLPlural(@"Conversation.PinnedMessagesCount", total, @"Pinned Message", @"%@ Pinned Messages");
}

- (void)leavePinnedList {
	if (!self.messagesBeforePinnedList)
		return;
	self.messages = self.messagesBeforePinnedList;
	self.messagesBeforePinnedList = nil;
	self.navigationItem.rightBarButtonItem = self.rightItemBeforePinnedList;
	self.rightItemBeforePinnedList = nil;
	self.navigationItem.title = nil;
	if (self.titleViewBeforePinnedList) {
		self.navigationItem.titleView = self.titleViewBeforePinnedList;
		self.titleViewBeforePinnedList = nil;
	}
	[self.table reloadData];
	[self updateEmptyState];
	[self scrollToBottomAnimated:NO];
	if (self.pinnedMessages.count)
		[self showPinnedMessageAtIndex:self.pinnedIndex];
}

- (void)purgeDeletedPinnedMessageId:(int64_t)messageId {
	if (messageId == 0 || !self.pinnedMessages.count)
		return;

	BOOL affected = self.pinnedMessageId == messageId;
	NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:self.pinnedMessages.count];
	for (NSDictionary *m in self.pinnedMessages) {
		if ([m[@"id"] longLongValue] == messageId)
			affected = YES;
		else
			[filtered addObject:m];
	}
	if (!affected)
		return;
	[self adoptPinnedMessages:filtered];
}

- (void)refreshEditedPinnedMessage:(NSDictionary *)message {
	if (![message isKindOfClass:NSDictionary.class] || !self.pinnedMessages.count)
		return;

	int64_t messageId = [message[@"id"] longLongValue];
	if (messageId == 0)
		return;

	NSInteger index = NSNotFound;
	for (NSInteger i = 0; i < (NSInteger)self.pinnedMessages.count; i++) {
		if ([self.pinnedMessages[i][@"id"] longLongValue] == messageId) {
			index = i;
			break;
		}
	}
	if (index == NSNotFound)
		return;

	NSMutableArray *updated = [self.pinnedMessages mutableCopy];
	[updated replaceObjectAtIndex:index withObject:message];
	self.pinnedMessages = updated;
	if (self.pinnedIndex == index)
		[self showPinnedMessageAtIndex:index];
}

- (BOOL)isMessagePinnedLocally:(int64_t)messageId {
	if (messageId == 0)
		return NO;
	for (NSDictionary *m in self.pinnedMessages)
		if ([m[@"id"] longLongValue] == messageId)
			return YES;
	return self.pinnedMessageId == messageId;
}

- (void)leavePinnedListIfShowing {
	if (self.messagesBeforePinnedList)
		[self leavePinnedList];
}

- (BOOL)insertMessagePlaceholder:(NSDictionary *)message {
	if (![message isKindOfClass:NSDictionary.class] ||
		![message[@"id"] isKindOfClass:NSNumber.class])
		return NO;
	int64_t messageId = [message[@"id"] longLongValue];
	if (messageId == 0 || [self rowForMessageId:messageId] != NSNotFound)
		return NO;

	NSMutableArray *merged = [self.messages mutableCopy] ?: [NSMutableArray array];
	NSInteger index = 0;
	while (index < (NSInteger)merged.count &&
		[merged[index][@"id"] longLongValue] < messageId)
		index++;
	[merged insertObject:message atIndex:index];
	self.messages = merged;
	self.anchorToBottom = NO;
	return YES;
}

- (void)loadDeeperHistoryAndScrollTo:(int64_t)messageId {
	if (self.deeperHistoryPending)
		return;
	self.deeperHistoryPending = YES;

	__weak typeof(self) weakSelf = self;
	void (^applyDeeper)(NSArray *) = ^(NSArray *messages) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.deeperHistoryPending = NO;
		if (messages.count > strongSelf.messages.count) {
			strongSelf.messages = [strongSelf messagesMerging:messages];
			strongSelf.anchorToBottom = NO;
			[strongSelf.table reloadData];
			[strongSelf fetchMissingImages];
			[strongSelf resolveUnknownSenders];
			[strongSelf resolveUnknownForwardOrigins];
			[strongSelf fetchMissingQuotes];
		}
		[strongSelf scrollToMessageId:messageId];
	};

	TGClient *client = [TGClient shared];
	if (self.savedTopicId != 0) {
		[client historyForSavedTopic:self.savedTopicId
							   limit:400
						  completion:applyDeeper];
		return;
	}

	if (self.directMessagesTopicId != 0) {
		[client historyForDirectMessagesTopic:self.directMessagesTopicId
									   inChat:self.chatId
										limit:400
								   completion:applyDeeper];
		return;
	}

	[client historyForChat:self.chatId
					thread:self.threadId
					 limit:400
				completion:applyDeeper];
}

- (NSArray *)messagesMerging:(NSArray *)incoming {
	NSMutableDictionary *byId = [NSMutableDictionary dictionary];
	NSMutableArray *unkeyed = [NSMutableArray array];
	for (NSArray *source in @[ self.messages ?: @[], TGMessagesWithChatUpgradeMarkersRemoved(incoming) ?: @[] ]) {
		for (NSDictionary *m in source) {
			if ([m[@"id"] isKindOfClass:NSNumber.class] && [m[@"id"] longLongValue] != 0)
				byId[m[@"id"]] = m;
			else
				[unkeyed addObject:m];
		}
	}
	NSArray *keys = [[byId allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
		int64_t left = a.longLongValue, right = b.longLongValue;
		if (left == right)
			return NSOrderedSame;
		return left < right ? NSOrderedAscending : NSOrderedDescending;
	}];
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:byId.count + unkeyed.count];
	for (NSNumber *key in keys)
		[out addObject:byId[key]];
	[out addObjectsFromArray:unkeyed];
	return out;
}

- (void)pinnedBannerHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	[self showPinnedBannerMenu];
}

- (void)showPinnedBannerMenu {
	if (self.pinnedMessageId == 0)
		return;

	int64_t chatId = self.chatId;
	int64_t messageId = self.pinnedMessageId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] propertiesOfMessage:messageId inChat:chatId
								 completion:^(NSDictionary *properties) {
									 TGChatViewController *strongSelf = weakSelf;
									 if (!strongSelf || !strongSelf.pinnedBanner)
										 return;
									 [strongSelf presentPinnedBannerMenuCanUnpinAll:[properties[@"canPin"] boolValue]];
								 }];
}

- (void)presentPinnedBannerMenuCanUnpinAll:(BOOL)canUnpinAll {
	UIActionSheet *sheetAlloc = [UIActionSheet alloc];
	UIActionSheet *sheet = canUnpinAll
		? [sheetAlloc initWithTitle:TGL(@"Channel.AdminLogFilter.EventsPinned", @"Pinned messages")
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			  destructiveButtonTitle:TGL(@"Chat.PanelUnpinAllMessages", @"Unpin All Messages")
				   otherButtonTitles:TGL(@"Chat.PinnedListPreview.ShowAllMessages", @"Show All Messages"), nil]
		: [sheetAlloc initWithTitle:TGL(@"Channel.AdminLogFilter.EventsPinned", @"Pinned messages")
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			  destructiveButtonTitle:nil
				   otherButtonTitles:TGL(@"Chat.PinnedListPreview.ShowAllMessages", @"Show All Messages"), nil];
	sheet.tag = kPinnedSheetTag;
	[sheet tg_showFromRect:self.pinnedBanner.bounds inView:self.pinnedBanner];
}

- (void)unpinEverything {
	int64_t chatId = self.chatId;
	int64_t threadId = self.threadId;
	int64_t savedTopicId = self.savedTopicId;

	self.pinnedMessageId = 0;
	self.pinnedMessages = @[];
	self.pinnedIndex = 0;
	[self leavePinnedListIfShowing];
	[self hidePinnedBanner];

	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.view
					   text:TGL(@"Topics.PinnedMessagesRemoved", @"Pinned messages removed.")
					seconds:5
					   kind:TGSnackbarKindDestructiveUndo
				   onCommit:^{
					   void (^afterUnpin)(BOOL) = ^(BOOL ok) {
						   TGChatViewController *strongSelf = weakSelf;
						   if (!strongSelf || ok)
							   return;
						   [TGSnackbar showInView:strongSelf.view
											 text:TGL(@"Chat.CouldNotUnpinAllMessages", @"Could not unpin the messages.")
										  seconds:2
										 onCommit:nil];
					   };
					   if (threadId != 0) {
						   [[TGClient shared] unpinAllMessagesInForumTopicInChat:chatId
																		   topic:(int32_t)threadId
																	  completion:afterUnpin];
						   return;
					   }
					   if (savedTopicId != 0) {
						   [[TGClient shared] unpinAllMessagesInSavedTopic:savedTopicId
																 completion:afterUnpin];
						   return;
					   }
					   [[TGClient shared] unpinAllMessagesInChat:chatId completion:afterUnpin];
				   }];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{ [weakSelf loadPinnedMessage]; });
}

@end
