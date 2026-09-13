#import "TGClient+ChatManagement.h"
#import "TGStringTruncation.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+SecretChats.h"
#import "TGClient+ChatState.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"
#import "TGLocalization.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGBubbleCellBase.h"
#import "TGFileBubbleCell.h"
#import "TGDiskCache.h"

static const NSInteger kChatSearchPageSize = 50;
static const NSTimeInterval kChatSearchDebounce = 0.35;

@implementation TGChatViewController (Search)

- (void)toggleChatSearch {
	if (self.chatSearchBar) {
		[self endChatSearch];
		return;
	}

	CGRect b = self.view.bounds;
	self.chatSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, 44)];
	self.chatSearchBar.delegate = self;
	self.chatSearchBar.placeholder = TGL(@"Conversation.SearchPlaceholder", @"Search in chat");
	self.chatSearchBar.showsCancelButton = YES;
	self.chatSearchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:self.chatSearchBar];
	[self.chatSearchBar becomeFirstResponder];

	self.chatSearchRestoreAtBottom = ![self displayRowCount] || [self historyIsAtBottom];
	CGFloat delta = 0;
	self.chatSearchRestoreMessageId = [self topVisibleMessageIdWithDelta:&delta];
	self.chatSearchRestoreDelta = delta;

	self.chatSearchTotalCount = 0;
	self.chatSearchCurrentIndex = -1;
	self.chatSearchPendingOlderNav = NO;

	self.messagesBeforeSearch = self.messages;
}

- (void)endChatSearch {
	[self.chatSearchBar resignFirstResponder];
	[self.chatSearchBar removeFromSuperview];
	self.chatSearchBar = nil;
	self.chatSearchNextFromMessageId = 0;
	self.chatSearchNextOffset = nil;
	self.chatSearchLoadingMore = NO;
	self.chatSearchExhausted = NO;
	[self hideChatSearchNavBar];
	self.chatSearchTotalCount = 0;
	self.chatSearchCurrentIndex = -1;
	self.chatSearchPendingOlderNav = NO;

	if (self.messagesBeforeSearch) {
		self.messages = self.messagesBeforeSearch;
		self.messagesBeforeSearch = nil;
		[self.table reloadData];
		if (self.chatSearchRestoreAtBottom || self.chatSearchRestoreMessageId == 0 ||
			![self placeRow:[self rowAtOrAfterMessageId:self.chatSearchRestoreMessageId]
				 atTopWithDelta:self.chatSearchRestoreDelta])
			[self scrollToBottomAnimated:NO];
	}
	self.chatSearchRestoreMessageId = 0;
	self.chatSearchRestoreDelta = 0;
	self.chatSearchRestoreAtBottom = NO;
	[self updateEmptyState];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[self endChatSearch];
}

- (void)searchChatForTag:(NSString *)tag {
	if (!tag.length)
		return;
	if (!self.chatSearchBar)
		[self toggleChatSearch];
	if (!self.chatSearchBar)
		return;
	self.chatSearchBar.text = tag;
	[self searchBar:self.chatSearchBar textDidChange:tag];
}

- (void)applyChatSearchMessages:(NSArray *)found total:(NSInteger)total append:(BOOL)append {
	NSArray *ascending = [[found reverseObjectEnumerator] allObjects];
	self.chatSearchTotalCount = total;
	BOOL pendingOlderNav = self.chatSearchPendingOlderNav;
	self.chatSearchPendingOlderNav = NO;
	[self showChatSearchNavBarIfNeeded];

	if (append && ascending.count) {
		CGFloat keepDelta = 0;
		int64_t keepTop = [self topVisibleMessageIdWithDelta:&keepDelta];
		NSInteger insertedCount = (NSInteger)ascending.count;
		self.messages = [ascending arrayByAddingObjectsFromArray:self.messages];
		if (self.chatSearchCurrentIndex >= 0)
			self.chatSearchCurrentIndex += insertedCount;
		[self.table reloadData];
		if (pendingOlderNav) {
			[self chatSearchMoveToIndex:insertedCount - 1];
		} else if (keepTop == 0 ||
			![self placeRow:[self rowAtOrAfterMessageId:keepTop] atTopWithDelta:keepDelta]) {
			[self scrollToBottomAnimated:NO];
		}
	} else if (!append) {
		self.messages = ascending;
		self.chatSearchCurrentIndex = ascending.count ? (NSInteger)ascending.count - 1 : -1;
		[self.table reloadData];
		if (self.chatSearchCurrentIndex >= 0)
			[self chatSearchMoveToIndex:self.chatSearchCurrentIndex];
	}
	[self updateEmptyState];
	[self updateChatSearchNavDisplay];
}

- (void)runChatSearchQuery:(NSString *)query append:(BOOL)append {
	__weak typeof(self) weakSelf = self;
	self.chatSearchGeneration += 1;
	NSInteger generation = self.chatSearchGeneration;

	if ([[TGClient shared] isSecretChat:self.chatId]) {
		NSString *offset = append ? (self.chatSearchNextOffset ?: @"") : @"";
		[[TGClient shared] searchInSecretChat:self.chatId
										 query:query
										offset:offset
										 limit:kChatSearchPageSize
									completion:^(NSArray *found, NSString *nextOffset, NSInteger total) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || strongSelf.chatSearchGeneration != generation ||
				![strongSelf.chatSearchBar.text isEqualToString:query])
				return;
			strongSelf.chatSearchNextOffset = nextOffset;
			strongSelf.chatSearchExhausted = !nextOffset.length;
			if (!found.count && !strongSelf.chatSearchExhausted) {
				[strongSelf runChatSearchQuery:query append:YES];
				return;
			}
			strongSelf.chatSearchLoadingMore = NO;
			[strongSelf applyChatSearchMessages:found total:total append:append];
		}];
		return;
	}

	int64_t fromMessageId = append ? self.chatSearchNextFromMessageId : 0;
	[[TGClient shared] searchInChat:self.chatId
							  query:query
						   threadId:self.threadId
			   directMessagesTopic:self.directMessagesTopicId
						 savedTopic:self.savedTopicId
					  fromMessageId:fromMessageId
							  limit:kChatSearchPageSize
						 completion:^(NSArray *found, int64_t next, NSInteger total) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.chatSearchGeneration != generation ||
			![strongSelf.chatSearchBar.text isEqualToString:query])
			return;
		strongSelf.chatSearchNextFromMessageId = next;
		strongSelf.chatSearchExhausted = (next == 0);
		if (!found.count && !strongSelf.chatSearchExhausted) {
			[strongSelf runChatSearchQuery:query append:YES];
			return;
		}
		strongSelf.chatSearchLoadingMore = NO;
		[strongSelf applyChatSearchMessages:found total:total append:append];
	}];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)query {
	self.chatSearchNextFromMessageId = 0;
	self.chatSearchNextOffset = nil;
	self.chatSearchLoadingMore = NO;
	self.chatSearchExhausted = NO;
	self.chatSearchPendingOlderNav = NO;
	self.chatSearchGeneration += 1;
	NSInteger generation = self.chatSearchGeneration;

	if (!query.length) {
		self.chatSearchTotalCount = 0;
		self.chatSearchCurrentIndex = -1;
		[self hideChatSearchNavBar];
		self.messages = self.messagesBeforeSearch ?: @[];
		[self.table reloadData];
		[self updateEmptyState];
		return;
	}

	self.chatSearchLoadingMore = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kChatSearchDebounce * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || strongSelf.chatSearchGeneration != generation)
				return;
			[strongSelf runChatSearchQuery:query append:NO];
		});
}

- (void)chatSearchMoveToIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.messages.count)
		return;
	self.chatSearchCurrentIndex = index;
	NSDictionary *m = self.messages[(NSUInteger)index];
	int64_t messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? [m[@"id"] longLongValue] : 0;
	if (messageId != 0)
		[self scrollToMessageId:messageId];
	[self updateChatSearchNavDisplay];
}

- (void)chatSearchShowOlderMatch {
	if (!self.messages.count)
		return;
	if (self.chatSearchCurrentIndex > 0) {
		[self chatSearchMoveToIndex:self.chatSearchCurrentIndex - 1];
		return;
	}
	if (self.chatSearchExhausted || self.chatSearchLoadingMore)
		return;
	self.chatSearchPendingOlderNav = YES;
	self.chatSearchLoadingMore = YES;
	[self runChatSearchQuery:self.chatSearchBar.text append:YES];
}

- (void)chatSearchShowNewerMatch {
	if (!self.messages.count)
		return;
	if (self.chatSearchCurrentIndex < (NSInteger)self.messages.count - 1)
		[self chatSearchMoveToIndex:self.chatSearchCurrentIndex + 1];
}

- (void)chatSearchOlderButtonTapped {
	[self chatSearchShowOlderMatch];
}

- (void)chatSearchNewerButtonTapped {
	[self chatSearchShowNewerMatch];
}

- (void)showChatSearchNavBarIfNeeded {
	if (self.chatSearchNavBar || !self.chatSearchBar)
		return;

	CGRect b = self.view.bounds;
	const CGFloat height = 32;
	const CGFloat top = self.chatSearchBar.frame.size.height;
	const CGFloat buttonWidth = 40;

	UIView *bar = [[UIView alloc] initWithFrame:
			CGRectMake(0, top, b.size.width, height)];
	bar.backgroundColor = [[TGTheme shared] inputBarColour];
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	UIButton *older = [UIButton buttonWithType:UIButtonTypeCustom];
	older.frame = CGRectMake(4, 0, buttonWidth, height);
	[older setTitle:@"▲" forState:UIControlStateNormal];
	[older setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	[older setTitleColor:[UIColor colorWithWhite:0.667f alpha:1.0f] forState:UIControlStateDisabled];
	older.titleLabel.font = [UIFont systemFontOfSize:14];
	[older addTarget:self action:@selector(chatSearchOlderButtonTapped)
		forControlEvents:UIControlEventTouchUpInside];
	[bar addSubview:older];
	self.chatSearchOlderButton = older;

	UIButton *newer = [UIButton buttonWithType:UIButtonTypeCustom];
	newer.frame = CGRectMake(4 + buttonWidth, 0, buttonWidth, height);
	[newer setTitle:@"▼" forState:UIControlStateNormal];
	[newer setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	[newer setTitleColor:[UIColor colorWithWhite:0.667f alpha:1.0f] forState:UIControlStateDisabled];
	newer.titleLabel.font = [UIFont systemFontOfSize:14];
	[newer addTarget:self action:@selector(chatSearchNewerButtonTapped)
		forControlEvents:UIControlEventTouchUpInside];
	[bar addSubview:newer];
	self.chatSearchNewerButton = newer;

	CGFloat labelLeft = 4 + buttonWidth * 2 + 8;
	UILabel *count = [[UILabel alloc] initWithFrame:
			CGRectMake(labelLeft, 0, b.size.width - labelLeft - 12, height)];
	count.textAlignment = NSTextAlignmentRight;
	count.font = [UIFont systemFontOfSize:14];
	count.textColor = [UIColor colorWithWhite:0.333f alpha:1.0f];
	count.backgroundColor = [UIColor clearColor];
	count.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[bar addSubview:count];
	self.chatSearchCountLabel = count;

	UIView *hair = [[UIView alloc] initWithFrame:
			CGRectMake(0, height - 1, b.size.width, 1)];
	hair.backgroundColor = [[TGTheme shared] separatorColour];
	hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[bar addSubview:hair];

	[self.view addSubview:bar];
	self.chatSearchNavBar = bar;

	UIEdgeInsets insets = self.table.contentInset;
	insets.top += height;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
}

- (void)hideChatSearchNavBar {
	if (!self.chatSearchNavBar)
		return;
	CGFloat height = self.chatSearchNavBar.frame.size.height;
	[self.chatSearchNavBar removeFromSuperview];
	self.chatSearchNavBar = nil;
	self.chatSearchCountLabel = nil;
	self.chatSearchOlderButton = nil;
	self.chatSearchNewerButton = nil;

	UIEdgeInsets insets = self.table.contentInset;
	insets.top -= height;
	if (insets.top < 0)
		insets.top = 0;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
}

- (void)updateChatSearchNavDisplay {
	if (!self.chatSearchNavBar)
		return;

	NSInteger loaded = (NSInteger)self.messages.count;
	NSInteger index = self.chatSearchCurrentIndex;

	if (!self.chatSearchBar.text.length || (loaded == 0 && self.chatSearchExhausted)) {
		self.chatSearchCountLabel.text = TGL(@"Conversation.SearchNoResults", @"No results");
		self.chatSearchOlderButton.enabled = NO;
		self.chatSearchNewerButton.enabled = NO;
		return;
	}

	NSInteger displayTotal = MAX(self.chatSearchTotalCount, loaded);
	NSInteger position = index >= 0 ? (loaded - index) : 0;
	self.chatSearchCountLabel.text = [NSString stringWithFormat:@"%ld/%ld",
		(long)position, (long)displayTotal];
	self.chatSearchOlderButton.enabled = (index > 0) || !self.chatSearchExhausted;
	self.chatSearchNewerButton.enabled = index >= 0 && index < loaded - 1;
}

- (void)loadMoreChatSearchResultsIfNeeded {
	if (!self.chatSearchBar.text.length || self.chatSearchLoadingMore || self.chatSearchExhausted)
		return;
	self.chatSearchLoadingMore = YES;
	[self runChatSearchQuery:self.chatSearchBar.text append:YES];
}

- (void)tableView:(UITableView *)tableView
	willDisplayCell:(UITableViewCell *)cell
  forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.chatSearchBar.text.length)
		return;
	if (indexPath.row > 2)
		return;
	[self loadMoreChatSearchResultsIfNeeded];
}

- (void)refreshAvatarForUser:(NSNumber *)key {
	UIImage *avatar = self.senderAvatars[key];
	if (!avatar)
		return;
	int64_t userId = key.longLongValue;
	for (NSIndexPath *path in [self.table indexPathsForVisibleRows]) {
		NSDictionary *m = [self messageAtRow:path.row];
		if (!m)
			continue;
		UITableViewCell *raw = [self.table cellForRowAtIndexPath:path];

		int64_t rowUserId = [m[@"forwardUserId"] longLongValue] ?: [m[@"senderId"] longLongValue];
		if (rowUserId == userId && [raw isKindOfClass:[TGBubbleCellBase class]]) {
			UIImageView *senderAvatar = ((TGBubbleCellBase *)raw).senderAvatar;
			if (senderAvatar && !senderAvatar.hidden) {
				CATransition *fade = [CATransition animation];
				fade.duration = 0.2;
				fade.type = kCATransitionFade;
				[senderAvatar.layer addAnimation:fade forKey:@"tgAvatarFade"];
				senderAvatar.image = avatar;
			}
		}

		int64_t contactUserId = [m[@"contactUserId"] longLongValue];
		if (contactUserId == userId && [raw isKindOfClass:[TGFileBubbleCell class]]) {
			TGFileBubbleCell *fileCell = (TGFileBubbleCell *)raw;
			if (!fileCell.picture.hidden) {
				fileCell.picture.image = avatar;
				fileCell.picture.backgroundColor = [UIColor clearColor];
			}
		}
	}
}

static UIImage *TGImageWithRoundedCorners(UIImage *source, CGFloat radius) {
	if (!source || radius < 0.5f)
		return source;
	CGSize size = source.size;
	if (size.width < 1 || size.height < 1)
		return source;
	UIGraphicsBeginImageContextWithOptions(size, NO, source.scale);
	CGRect box = CGRectMake(0, 0, size.width, size.height);
	[[UIBezierPath bezierPathWithRoundedRect:box cornerRadius:radius] addClip];
	[source drawInRect:box];
	UIImage *rounded = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return rounded ?: source;
}

static NSString *TGSenderAvatarDiskKey(NSString *photoKey) {
	if (!photoKey.length)
		return nil;
	return [NSString stringWithFormat:@"senderavatar_%@_%d", photoKey,
		(int)kAvatarSide];
}

static CGFloat TGSenderAvatarScale(void) {
	CGFloat scale = [UIScreen mainScreen].scale;
	return scale < 1.0f ? 1.0f : scale;
}

static NSString *TGChatAvatarDiskKey(int64_t chatId) {
	NSString *photoKey = [[TGClient shared] chatInfoForId:chatId][@"photoKey"];
	if (![photoKey isKindOfClass:[NSString class]] || !photoKey.length)
		return nil;
	return TGSenderAvatarDiskKey(photoKey);
}

- (UIImage *)avatarForUser:(int64_t)userId name:(NSString *)name {
	NSNumber *key = @(userId);
	UIImage *cached = self.senderAvatars[key];
	if (cached)
		return cached;

	NSString *initials = name.length ? TGSafeFirstCharacter(name) : @"?";
	UIImage *placeholder = TGImageWithRoundedCorners(
		[TGIcons avatarWithInitials:initials.uppercaseString
							   size:kAvatarSide
						   colourId:userId],
		kSenderAvatarRadius);
	self.senderAvatars[key] = placeholder;

	if ([self.senderAvatarsRequested containsObject:key])
		return placeholder;
	[self.senderAvatarsRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	void (^fetch)(NSNumber *) = ^(NSNumber *fileId) {
		if (!fileId)
			return;
		CGFloat sidePixels = kAvatarSide * [UIScreen mainScreen].scale;
		[TGFileDownloadService downloadFile:fileId.longLongValue completion:^(NSString *path) {
			if (!path.length)
				return;
			dispatch_async(TGImageDecodeQueue(), ^{
				UIImage *photo = TGDecodeThumbnail(path, sidePixels);
				if (!photo)
					return;
				UIImage *square = TGImageDrawnAtPointSize(photo,
					CGSizeMake(kAvatarSide, kAvatarSide));
				NSString *writeKey = TGSenderAvatarDiskKey(
					[[TGClient shared] photoKeyForUserId:userId]);
				if (square && writeKey)
					[TGDiskCache storeImage:square forKey:writeKey];
				UIImage *sized = TGImageWithRoundedCorners(square,
					kSenderAvatarRadius);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGChatViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					strongSelf.senderAvatars[key] = sized;
					[strongSelf refreshAvatarForUser:key];
				});
			});
		}];
	};

	void (^resolveFromNetwork)(void) = ^{
		NSNumber *cachedFile = [[TGClient shared] photoFileIdForUserId:userId];
		if (cachedFile) {
			fetch(cachedFile);
			return;
		}
		[[TGClient shared] userInfo:userId completion:^(NSDictionary *user) {
			if (user)
				[[TGClient shared] cacheProfilePhoto:user];
			id photo = user[@"profile_photo"];
			id small = [photo isKindOfClass:[NSDictionary class]] ? photo[@"small"] : nil;
			id photoId = [small isKindOfClass:[NSDictionary class]] ? small[@"id"] : nil;
			fetch(photoId);
		}];
	};

	NSString *diskKey = TGSenderAvatarDiskKey(
		[[TGClient shared] photoKeyForUserId:userId]);
	if (!diskKey) {
		resolveFromNetwork();
		return placeholder;
	}

	CGFloat scale = TGSenderAvatarScale();
	dispatch_async(TGImageDecodeQueue(), ^{
		UIImage *stored = [TGDiskCache imageForKey:diskKey scale:scale];
		UIImage *rounded = stored ? TGImageWithRoundedCorners(stored, kSenderAvatarRadius) : nil;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (rounded) {
				strongSelf.senderAvatars[key] = rounded;
				[strongSelf refreshAvatarForUser:key];
				return;
			}
			resolveFromNetwork();
		});
	});
	return placeholder;
}

- (void)refreshAvatarForChat:(NSNumber *)key {
	UIImage *avatar = self.senderChatAvatars[key];
	if (!avatar)
		return;
	for (NSIndexPath *path in [self.table indexPathsForVisibleRows]) {
		NSDictionary *m = [self messageAtRow:path.row];
		if (!m || [m[@"forwardChatId"] longLongValue] != [key longLongValue])
			continue;
		UITableViewCell *raw = [self.table cellForRowAtIndexPath:path];
		UIImageView *senderAvatar = nil;
		if ([raw isKindOfClass:[TGBubbleCellBase class]])
			senderAvatar = ((TGBubbleCellBase *)raw).senderAvatar;
		if (!senderAvatar || senderAvatar.hidden)
			continue;
		CATransition *fade = [CATransition animation];
		fade.duration = 0.2;
		fade.type = kCATransitionFade;
		[senderAvatar.layer addAnimation:fade forKey:@"tgAvatarFade"];
		senderAvatar.image = avatar;
	}
}

- (UIImage *)avatarForChat:(int64_t)chatId name:(NSString *)name {
	NSNumber *key = @(chatId);
	UIImage *cached = self.senderChatAvatars[key];
	if (cached)
		return cached;

	NSString *initials = name.length ? TGSafeFirstCharacter(name) : @"?";
	UIImage *placeholder = TGImageWithRoundedCorners(
		[TGIcons avatarWithInitials:initials.uppercaseString
							   size:kAvatarSide
						   colourId:chatId],
		kSenderAvatarRadius);
	self.senderChatAvatars[key] = placeholder;

	if ([self.senderChatAvatarsRequested containsObject:key])
		return placeholder;
	[self.senderChatAvatarsRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	void (^fetch)(NSNumber *) = ^(NSNumber *fileId) {
		if (!fileId || [fileId longLongValue] <= 0)
			return;
		CGFloat sidePixels = kAvatarSide * [UIScreen mainScreen].scale;
		[TGFileDownloadService downloadFile:fileId.longLongValue completion:^(NSString *path) {
			if (!path.length)
				return;
			dispatch_async(TGImageDecodeQueue(), ^{
				UIImage *photo = TGDecodeThumbnail(path, sidePixels);
				if (!photo)
					return;
				UIImage *square = TGImageDrawnAtPointSize(photo,
					CGSizeMake(kAvatarSide, kAvatarSide));
				NSString *writeKey = TGChatAvatarDiskKey(chatId);
				if (square && writeKey)
					[TGDiskCache storeImage:square forKey:writeKey];
				UIImage *sized = TGImageWithRoundedCorners(square,
					kSenderAvatarRadius);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGChatViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					strongSelf.senderChatAvatars[key] = sized;
					[strongSelf refreshAvatarForChat:key];
				});
			});
		}];
	};

	void (^resolveFromNetwork)(void) = ^{
		NSNumber *cachedFile = [[TGClient shared] photoFileIdForChat:chatId];
		if (cachedFile && cachedFile.integerValue > 0) {
			fetch(cachedFile);
			return;
		}
		[[TGClient shared] photoFileIdForChat:chatId completion:^(NSNumber *fetchedFileId) {
			fetch(fetchedFileId);
		}];
	};

	NSString *diskKey = TGChatAvatarDiskKey(chatId);
	if (!diskKey) {
		resolveFromNetwork();
		return placeholder;
	}

	CGFloat scale = TGSenderAvatarScale();
	dispatch_async(TGImageDecodeQueue(), ^{
		UIImage *stored = [TGDiskCache imageForKey:diskKey scale:scale];
		UIImage *rounded = stored ? TGImageWithRoundedCorners(stored, kSenderAvatarRadius) : nil;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (rounded) {
				strongSelf.senderChatAvatars[key] = rounded;
				[strongSelf refreshAvatarForChat:key];
				return;
			}
			resolveFromNetwork();
		});
	});
	return placeholder;
}

@end
