#import "TGMediaViewControllerInternal.h"
#import "TGClient+Search.h"
#import "TGClient+Files.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGStorageDownloadsViewController.h"

@implementation TGMediaViewController (Loading)

- (void)buildDownloadsBanner {
	self.banner = [[UIControl alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width, kMediaBannerHeight)];
	self.banner.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.banner.backgroundColor = [[TGTheme shared] barColour];
	self.banner.hidden = YES;
	[self.banner addTarget:self action:@selector(bannerTapped)
		forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.banner];

	CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;

	self.bannerTitle = [[UILabel alloc] initWithFrame:
			CGRectMake(12 + retinaPixel, 2, self.view.bounds.size.width - 12 - 46, 18)];
	self.bannerTitle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.bannerTitle.backgroundColor = [UIColor clearColor];
	self.bannerTitle.font = [UIFont boldSystemFontOfSize:14];
	self.bannerTitle.lineBreakMode = NSLineBreakByTruncatingTail;
	self.bannerTitle.textColor = [UIColor colorWithRed:0x36 / 255.0f green:0x3a / 255.0f
											  blue:0x40 / 255.0f
											 alpha:1.0f];
	self.bannerTitle.text = TGL(@"ChatList.Search.FilterDownloads", @"Downloads");
	[self.banner addSubview:self.bannerTitle];

	self.bannerDetail = [[UILabel alloc] initWithFrame:
			CGRectMake(12 + retinaPixel, 21 + retinaPixel,
				self.view.bounds.size.width - 12 - 46, 18)];
	self.bannerDetail.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.bannerDetail.backgroundColor = [UIColor clearColor];
	self.bannerDetail.font = [UIFont systemFontOfSize:14];
	self.bannerDetail.lineBreakMode = NSLineBreakByTruncatingTail;
	self.bannerDetail.textColor = [UIColor blackColor];
	[self.banner addSubview:self.bannerDetail];

	UIView *bannerLine = [[UIView alloc] initWithFrame:
			CGRectMake(0, kMediaBannerHeight - 1, self.view.bounds.size.width, 1)];
	bannerLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	bannerLine.backgroundColor = [[TGTheme shared] separatorColour];
	[self.banner addSubview:bannerLine];
}

- (void)loadNextPage {
	if (self.loading || !self.canLoadMore || self.chatId == 0)
		return;

	self.loading = YES;
	if (!self.loadedOnce)
		[self.spinner startAnimating];

	NSInteger token = self.loadToken;
	NSInteger scope = self.scope;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sharedMediaInChat:self.chatId
								 topicId:self.topicId
								   query:self.query ?: @""
							  filterName:TGMediaFilterForScope(scope)
						   fromMessageId:self.lastMessageId
								   limit:kMediaPageSize
							  completion:^(NSDictionary *result, int64_t nextFromMessageId) {
								  typeof(self) strongSelf = weakSelf;
								  if (!strongSelf || strongSelf.loadToken != token)
									  return;
								  [strongSelf applyPageResult:result
											 nextFromMessageId:nextFromMessageId
														 scope:scope];
							  }];
}

- (void)installMessageObserver {
	if (self.messageObserverToken)
		return;
	__weak typeof(self) weakSelf = self;
	self.messageObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGMessageDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		int64_t chatId = [note.userInfo[TGMessageChatIdKey] longLongValue];
		if (chatId != strongSelf.chatId)
			return;
		int64_t deletedId = [note.userInfo[TGMessageDeletedIdKey] longLongValue];
		NSDictionary *message = note.userInfo[TGMessageDataKey];
		if (![message isKindOfClass:NSDictionary.class])
			message = nil;
		if ([message[@"scheduled"] boolValue])
			return;

		if (!message) {
			if (deletedId)
				[strongSelf removeItemWithMessageId:deletedId];
			return;
		}

		int64_t newId = [message[@"id"] longLongValue];
		int64_t existingId = 0;
		if (deletedId && [strongSelf indexOfItemWithMessageId:deletedId] != NSNotFound)
			existingId = deletedId;
		else if (newId && [strongSelf indexOfItemWithMessageId:newId] != NSNotFound)
			existingId = newId;

		if (existingId) {
			[[TGClient shared] rawMessageWithId:(newId ?: existingId)
										  inChat:chatId
									  completion:^(NSDictionary *raw) {
				typeof(self) strongSelf2 = weakSelf;
				if (!strongSelf2 || strongSelf2.chatId != chatId)
					return;
				if (raw)
					[strongSelf2 replaceItemAtMessageId:existingId withMessage:raw];
				else
					[strongSelf2 removeItemWithMessageId:existingId];
			}];
			return;
		}

		if (newId)
			[strongSelf checkForMatchingNewMessageId:newId];
	}];
}

- (void)checkForMatchingNewMessageId:(int64_t)messageId {
	if (messageId == 0)
		return;
	for (NSDictionary *item in self.items) {
		if ([item[@"messageId"] longLongValue] == messageId)
			return;
	}

	NSInteger scope = self.scope;
	NSInteger token = self.loadToken;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sharedMediaInChat:self.chatId
								 topicId:self.topicId
								   query:self.query ?: @""
							  filterName:TGMediaFilterForScope(scope)
						   fromMessageId:0
								   limit:1
							  completion:^(NSDictionary *result, int64_t nextFromMessageId) {
								  (void)nextFromMessageId;
								  typeof(self) strongSelf = weakSelf;
								  if (!strongSelf || strongSelf.loadToken != token)
									  return;
								  NSArray *messages = result[@"messages"];
								  NSDictionary *top = [messages isKindOfClass:NSArray.class]
									  ? messages.firstObject
									  : nil;
								  if ([top[@"id"] longLongValue] != messageId)
									  return;
								  [strongSelf prependMatchedMessage:top scope:scope];
							  }];
}

- (void)prependMatchedMessage:(NSDictionary *)message scope:(NSInteger)scope {
	int64_t messageId = [message[@"id"] longLongValue];
	for (NSDictionary *item in self.items) {
		if ([item[@"messageId"] longLongValue] == messageId)
			return;
	}

	NSDictionary *item = TGMediaScopeIsGrid(scope)
		? TGMediaItemFromMessage(message)
		: TGMediaListItemFromMessage(message, scope);
	if (!item)
		return;

	[self.items insertObject:item atIndex:0];
	[self setEmptyVisible:NO animated:YES];
	[self.tableView reloadData];
}

- (NSInteger)indexOfItemWithMessageId:(int64_t)messageId {
	for (NSInteger i = 0; i < (NSInteger)self.items.count; i++) {
		if ([self.items[i][@"messageId"] longLongValue] == messageId)
			return i;
	}
	return NSNotFound;
}

- (BOOL)replaceItemAtMessageId:(int64_t)messageId withMessage:(NSDictionary *)message {
	NSInteger index = [self indexOfItemWithMessageId:messageId];
	if (index == NSNotFound)
		return NO;

	NSDictionary *item = TGMediaScopeIsGrid(self.scope)
		? TGMediaItemFromMessage(message)
		: TGMediaListItemFromMessage(message, self.scope);
	if (item)
		[self.items replaceObjectAtIndex:(NSUInteger)index withObject:item];
	else
		[self.items removeObjectAtIndex:(NSUInteger)index];

	[self.tableView reloadData];
	[self setEmptyVisible:(self.items.count == 0 && !self.canLoadMore) animated:YES];
	return YES;
}

- (void)applyPageResult:(NSDictionary *)result
	   nextFromMessageId:(int64_t)nextFromMessageId
				   scope:(NSInteger)scope {
	self.loading = NO;
	[self.spinner stopAnimating];

	if (!result)
		return;

	self.loadedOnce = YES;

	NSArray *messages = result[@"messages"];
	if (![messages isKindOfClass:NSArray.class])
		messages = @[];

	NSInteger added = 0;
	for (NSDictionary *message in messages) {
		if (![message isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *item = TGMediaScopeIsGrid(scope)
			? TGMediaItemFromMessage(message)
			: TGMediaListItemFromMessage(message, scope);
		if (item) {
			[self.items addObject:item];
			added++;
		}
	}

	self.lastMessageId = nextFromMessageId;
	self.canLoadMore = (nextFromMessageId != 0);

	[self setEmptyVisible:(self.items.count == 0 && !self.canLoadMore) animated:YES];
	[self.tableView reloadData];

	if (added == 0 && self.canLoadMore)
		[self loadNextPage];
}

- (void)refreshDownloadsBanner {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchDownloadsWithQuery:@""
									 onlyActive:NO
								  onlyCompleted:NO
										 offset:nil
										  limit:1
									 completion:^(NSDictionary *page) {
										 typeof(self) strongSelf = weakSelf;
										 if (!strongSelf || !strongSelf.isViewLoaded)
											 return;

										 NSInteger active = [page[@"activeCount"] integerValue];
										 NSInteger paused = [page[@"pausedCount"] integerValue];
										 NSInteger completed = [page[@"completedCount"] integerValue];
										 NSInteger total = active + paused + completed;

										 if (total == 0) {
											 strongSelf.bannerVisible = NO;
											 strongSelf.banner.hidden = YES;
											 [strongSelf.view setNeedsLayout];
											 return;
										 }

										 NSMutableArray *parts = [NSMutableArray array];
										 if (active > 0)
											 [parts addObject:TGLPlural(@"Media.DownloadsActiveCount", active,
												 @"1 downloading", @"%ld downloading")];
										 if (paused > 0)
											 [parts addObject:TGLPlural(@"Media.DownloadsPausedCount", paused,
												 @"1 paused", @"%ld paused")];
										 if (completed > 0)
											 [parts addObject:TGLPlural(@"Media.DownloadsReadyCount", completed,
												 @"1 ready", @"%ld ready")];

										 strongSelf.bannerDetail.text = [parts componentsJoinedByString:@", "];
										 strongSelf.bannerVisible = YES;
										 strongSelf.banner.hidden = NO;
										 [strongSelf.view setNeedsLayout];
									 }];
}

- (void)bannerTapped {
	TGStorageDownloadsViewController *downloads = [[TGStorageDownloadsViewController alloc] init];
	if (self.navigationController)
		[self.navigationController pushViewController:downloads animated:YES];
}

@end
