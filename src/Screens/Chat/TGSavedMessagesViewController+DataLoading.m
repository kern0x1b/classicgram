#import "TGClient+ChatManagement.h"
#import "TGStringTruncation.h"
#import "TGDateUtils.h"
#import "TGImageDecode.h"
#import "TGSavedMessagesViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGClient+SavedMessages.h"
#import "TGClient+Messages.h"
#import "TGClient+Search.h"
#import "TGFileDownloadService.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"

@implementation TGSavedMessagesViewController (DataLoading)

- (void)reloadMessages {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId) {
		self.messageHits = @[];
		self.messagesLoadedOnce = YES;
		self.messagesCanLoadMore = NO;
		self.messagesNextId = 0;
		[self.tableView reloadData];
		[self updateEmptyContainer];
		return;
	}

	self.messagesLoading = YES;
	self.messagesCanLoadMore = NO;
	self.messagesNextId = 0;
	if (!self.messagesLoadedOnce)
		[self.spinner startAnimating];
	self.emptyContainer.hidden = YES;

	NSInteger token = ++self.searchToken;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchMessagesInChat:chatId
									  query:self.query
							   senderUserId:0
									 filter:TGSavedFilterForScope(self.scope)
							  fromMessageId:0
									  limit:kSavedMessagePage
								 completion:^(NSArray *messages, int64_t next, NSInteger total) {
									 TGSavedMessagesViewController *strongSelf = weakSelf;
									 if (!strongSelf || token != strongSelf.searchToken)
										 return;
									 strongSelf.messagesLoading = NO;
									 strongSelf.messagesLoadedOnce = YES;
									 [strongSelf.spinner stopAnimating];
									 strongSelf.messageHits = [messages isKindOfClass:NSArray.class] ? messages : @[];
									 strongSelf.messagesNextId = next;
									 strongSelf.messagesCanLoadMore = next != 0;
									 [strongSelf.tableView reloadData];
									 [strongSelf updateEmptyContainer];
								 }];
}

- (void)loadMoreMessages {
	if (self.messagesLoading || !self.messagesCanLoadMore || !self.messagesNextId)
		return;

	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId) {
		self.messagesCanLoadMore = NO;
		return;
	}

	self.messagesLoading = YES;
	NSInteger token = self.searchToken;
	int64_t fromMessageId = self.messagesNextId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchMessagesInChat:chatId
									  query:self.query
							   senderUserId:0
									 filter:TGSavedFilterForScope(self.scope)
							  fromMessageId:fromMessageId
									  limit:kSavedMessagePage
								 completion:^(NSArray *messages, int64_t next, NSInteger total) {
									 TGSavedMessagesViewController *strongSelf = weakSelf;
									 if (!strongSelf || token != strongSelf.searchToken)
										 return;
									 strongSelf.messagesLoading = NO;
									 NSArray *appended = [messages isKindOfClass:NSArray.class] ? messages : @[];
									 if (appended.count)
										 strongSelf.messageHits = [strongSelf.messageHits arrayByAddingObjectsFromArray:appended];
									 strongSelf.messagesNextId = next;
									 strongSelf.messagesCanLoadMore = next != 0;
									 [strongSelf.tableView reloadData];
								 }];
}

- (void)buildReminderBanner {
	TGTheme *theme = [TGTheme shared];

	UIButton *banner = [UIButton buttonWithType:UIButtonTypeCustom];
	banner.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, kSavedBannerHeight);
	banner.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	banner.backgroundColor = [theme listBackgroundColour];
	banner.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	banner.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
	banner.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
	[banner setTitleColor:[theme accentColour] forState:UIControlStateNormal];
	[banner addTarget:self action:@selector(showReminders)
		forControlEvents:UIControlEventTouchUpInside];

	UIView *line = [[UIView alloc] initWithFrame:
			CGRectMake(0, kSavedBannerHeight - 1, banner.bounds.size.width, 1)];
	line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	line.backgroundColor = [theme separatorColour];
	[banner addSubview:line];

	self.reminderBanner = banner;
	self.reminders = @[];
}

- (void)reloadReminders {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] scheduledMessagesInChat:chatId completion:^(NSArray *messages, BOOL failed) {
		TGSavedMessagesViewController *strongSelf = weakSelf;
		if (!strongSelf || failed)
			return;

		NSMutableArray *clean = [NSMutableArray array];
		if ([messages isKindOfClass:NSArray.class]) {
			for (id message in messages) {
				if ([message isKindOfClass:NSDictionary.class])
					[clean addObject:message];
			}
		}
		strongSelf.reminders = clean;
		[strongSelf updateReminderBanner];
	}];
}

- (void)updateReminderBanner {
	if (self.reminders.count) {
		NSString *title = TGLPlural(@"ScheduledMessages.RemindersCount", (NSInteger)self.reminders.count,
			@"%ld Reminder", @"%ld Reminders");
		[self.reminderBanner setTitle:title forState:UIControlStateNormal];
		self.reminderBanner.backgroundColor = [[TGTheme shared] listBackgroundColour];
		[self.reminderBanner setTitleColor:[[TGTheme shared] accentColour]
								  forState:UIControlStateNormal];
	}
	[self updateTableHeader];
}

- (NSString *)titleForReminder:(NSDictionary *)reminder {
	NSString *text = TGSavedShortText(reminder, 24);

	NSTimeInterval when = [reminder[@"sendDate"] doubleValue];
	if (when <= 0)
		return text;

	return [NSString stringWithFormat:@"%@  %@",
		[TGDateUtils stringForDateAndTime:(int)when], text];
}

- (void)showReminders {
	if (self.reminders.count == 0)
		return;

	UIActionSheet *sheet = [UIActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"ScheduledMessages.RemindersTitle", @"Reminders")
						delegate:self
			   cancelButtonTitle:nil
		  destructiveButtonTitle:nil
			   otherButtonTitles:nil];
	NSInteger shown = MIN((NSInteger)self.reminders.count, 6);
	for (NSInteger i = 0; i < shown; i++)
		[sheet addButtonWithTitle:[self titleForReminder:self.reminders[i]]];

	[sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.cancelButtonIndex = shown;
	sheet.tag = kSavedReminderSheetTag;
	[sheet tg_showFromRect:self.reminderBanner.bounds inView:self.reminderBanner];
}

- (void)reloadTopics {
	if (self.loading)
		return;
	self.loading = YES;

	if (!self.loadedOnce)
		[self.spinner startAnimating];

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client loadSavedMessagesTopicsWithLimit:kSavedTopicPage
								  completion:^(NSArray *topics) {
									  TGSavedMessagesViewController *strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  strongSelf.loading = NO;
									  strongSelf.loadedOnce = YES;
									  [strongSelf.spinner stopAnimating];
									  [strongSelf applyTopics:topics];
								  }];
}

- (void)applyCachedTopics {
	[self applyTopics:[[TGClient shared] cachedSavedMessagesTopics]];
}

- (void)applyTopics:(NSArray *)topics {
	if (self.reordering)
		return;

	NSMutableArray *clean = [NSMutableArray array];
	if ([topics isKindOfClass:NSArray.class]) {
		for (id topic in topics) {
			if ([topic isKindOfClass:NSDictionary.class])
				[clean addObject:topic];
		}
	}

	NSMutableArray *ordered = [NSMutableArray arrayWithCapacity:clean.count];
	for (NSDictionary *topic in clean) {
		if ([topic[@"isPinned"] boolValue])
			[ordered addObject:topic];
	}
	for (NSDictionary *topic in clean) {
		if (![topic[@"isPinned"] boolValue])
			[ordered addObject:topic];
	}

	self.topics = ordered;
	if (self.query.length)
		self.topicHits = [self topicsMatchingQuery:self.query];
	[self fetchMissingAvatars];
	[self.tableView reloadData];
	[self updateEmptyContainer];
	[self hideSearchBarOnFirstLayout];
}

- (void)downloadTopicAvatarFileId:(NSNumber *)fileId {
	if (!fileId || [fileId longLongValue] <= 0 ||
		self.avatars[fileId] || [self.avatarsRequested containsObject:fileId])
		return;
	[self.avatarsRequested addObject:fileId];

	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:[fileId longLongValue] completion:^(NSString *path) {
		if (!path.length)
			return;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *image = nil;
			@autoreleasepool {
				image = TGDecodeSquareThumbnail(path, kSavedAvatar);
			}
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGSavedMessagesViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				strongSelf.avatars[fileId] = image;
				if (!strongSelf.avatarReload)
					strongSelf.avatarReload = [[TGTableReloadCoalescer alloc]
						initWithTableView:strongSelf.tableView];
				[strongSelf.avatarReload setNeedsReload];
			});
		});
	}];
}

- (void)fetchMissingAvatars {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *topic in self.topics) {
		NSString *kind = TGSavedTopicKind(topic);
		if ([kind isEqualToString:@"myNotes"] || [kind isEqualToString:@"authorHidden"])
			continue;
		int64_t chatId = [topic[@"chatId"] longLongValue];
		if (!chatId)
			continue;

		NSNumber *chatKey = @(chatId);
		NSNumber *fileId = self.chatFileIds[chatKey] ?: [[TGClient shared] photoFileIdForChat:chatId];
		if (fileId && fileId.longLongValue > 0) {
			self.chatFileIds[chatKey] = fileId;
			[self downloadTopicAvatarFileId:fileId];
			continue;
		}

		if ([self.avatarChatIdsRequested containsObject:chatKey])
			continue;
		[self.avatarChatIdsRequested addObject:chatKey];

		[[TGClient shared] photoFileIdForChat:chatId completion:^(NSNumber *fetchedFileId) {
			TGSavedMessagesViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (fetchedFileId && fetchedFileId.integerValue > 0)
				strongSelf.chatFileIds[chatKey] = fetchedFileId;
			[strongSelf downloadTopicAvatarFileId:fetchedFileId];
		}];
	}
}

- (UIImage *)avatarForTopic:(NSDictionary *)topic {
	NSString *kind = TGSavedTopicKind(topic);
	if ([kind isEqualToString:@"myNotes"])
		return [TGIcons myNotesAvatarOfSide:kSavedAvatar];
	if ([kind isEqualToString:@"authorHidden"])
		return [TGIcons hiddenAuthorAvatarOfSide:kSavedAvatar];

	int64_t chatId = [topic[@"chatId"] longLongValue];
	if (chatId) {
		NSNumber *fileId = self.chatFileIds[@(chatId)] ?: [[TGClient shared] photoFileIdForChat:chatId];
		UIImage *photo = fileId ? self.avatars[fileId] : nil;
		if (photo)
			return photo;
	}

	NSString *title = TGSavedTopicTitle(topic);
	NSString *initials = title.length ? TGSafeFirstCharacter(title).uppercaseString : @"?";
	return [TGIcons avatarWithInitials:initials size:kSavedAvatar colourId:chatId];
}

- (void)buildEmptyContainerInside:(UIView *)background {
	TGTheme *theme = [TGTheme shared];

	TGPlaceholderView *container = [[TGPlaceholderView alloc] initWithFrame:CGRectMake(0, 0, 250, 0)];
	container.hidden = YES;

	container.iconView.image = [TGIcons savedMessagesAvatarOfSide:66];

	container.titleLabel.textColor = [theme secondaryTextColour];
	container.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	container.titleLabel.text = TGSavedEmptyTitleForScope(self.scope);

	container.bodyLabel.textColor = [theme secondaryTextColour];
	container.bodyLabel.font = [UIFont systemFontOfSize:14];
	container.bodyLabel.text = TGSavedEmptyTextForScope(self.scope);

	CGFloat height = [container layoutContentWidth:250];
	container.frame = CGRectMake(floorf((background.bounds.size.width - 250) / 2.0f),
		floorf((background.bounds.size.height - height) / 2.0f), 250, height);
	container.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

	self.emptyContainer = container;
	[background addSubview:container];
}

- (void)updateEmptyContainer {
	BOOL searching = self.query.length > 0;
	BOOL empty;
	if (searching)
		empty = (self.topicHits.count == 0) && (self.messageHits.count == 0) && self.messagesLoadedOnce;
	else if (self.scope == kSavedScopeChats)
		empty = (self.topics.count == 0) && self.loadedOnce;
	else
		empty = (self.messageHits.count == 0) && self.messagesLoadedOnce;

	if (empty)
		[self restyleEmptyContainerSearching:searching];
	self.emptyContainer.hidden = !empty;
}

- (void)restyleEmptyContainerSearching:(BOOL)searching {
	NSString *title = searching ? TGL(@"SharedMedia.SearchNoResults", @"No Results")
								: TGSavedEmptyTitleForScope(self.scope);
	NSString *text = searching
		? [NSString stringWithFormat:TGL(@"SharedMedia.SearchNoResultsDescription", @"There were no results for \"%@\".\nTry a new search."), self.query]
		: TGSavedEmptyTextForScope(self.scope);

	if ([self.emptyContainer.titleLabel.text isEqualToString:title] &&
		[self.emptyContainer.bodyLabel.text isEqualToString:text])
		return;

	self.emptyContainer.titleLabel.text = title;
	self.emptyContainer.bodyLabel.text = text;
	[self layoutEmptyContainer];
}

- (void)layoutEmptyContainer {
	TGPlaceholderView *container = self.emptyContainer;
	if (!container)
		return;

	CGFloat width = container.bounds.size.width;
	CGRect frame = container.frame;
	CGFloat height = [container layoutContentWidth:width];
	frame.origin.y += floorf((frame.size.height - height) / 2.0f);
	frame.size.height = height;
	container.frame = frame;
}

@end
