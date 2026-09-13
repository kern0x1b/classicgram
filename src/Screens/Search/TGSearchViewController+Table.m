#import "TGClient+Contacts.h"
#import "TGStringTruncation.h"
#import "TGClient+ChatState.h"
#import "TGSearchViewController.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGClient+Files.h"
#import "TGSearchViewControllerInternal.h"
#import "TGSearchCalendarViewController.h"
#import "TGSearchResultCell.h"
#import "TGSearchMessageCell.h"
#import "AppDelegate.h"
#import "TGImageDecode.h"
#import "TGChatViewController.h"
#import "TGClient+Search.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+SafeTint.h"

@implementation TGSearchViewController (Table)

- (void)setNeedsResultsReload {
	if (!self.resultsReload)
		self.resultsReload = [[TGTableReloadCoalescer alloc] initWithTableView:self.tableView];
	[self.resultsReload setNeedsReload];
}

#pragma mark - table

- (void)rebuildSections {
	NSMutableArray *built = [NSMutableArray array];
	if (_scopedChatId && ![self hasActiveQuery]) {
		[built addObject:@{@"title" : (_scopedChatTitle ?: TGL(@"ChatList.UnnamedChat", @"Chat")),
			@"rows" : @[ @{@"title" : TGL(@"Chat.JumpToDate", @"Jump to Date"),
				@"subtitle" : TGL(@"SharedMedia.CalendarTooltip", @"Browse this chat day by day"),
				@"action" : @"calendar",
				@"chatId" : @0,
				@"isGroup" : @NO,
				@"fileId" : [NSNull null]} ]}];
		if (self.liveLocations.count)
			[built addObject:@{@"title" : TGL(@"Search.LiveLocations", @"Live Locations"),
				@"rows" : self.liveLocations,
				@"messages" : @YES}];
		self.sections = built;
		[self syncResultsPresenter];
		[self.tableView reloadData];
		[self updateStatusLabel];
		return;
	}
	if (![self hasActiveQuery]) {
		if (self.topPeers.count)
			[built addObject:@{@"title" : TGL(@"DialogList.RecentTitlePeople", @"People"), @"rows" : self.topPeers}];

		NSMutableArray *rows = [NSMutableArray array];
		NSMutableSet *seen = [NSMutableSet set];
		for (NSDictionary *r in self.recents) {
			int64_t chatId = [r[@"chatId"] longLongValue];
			if (!chatId || [seen containsObject:@(chatId)])
				continue;
			[seen addObject:@(chatId)];
			[rows addObject:@{@"title" : (r[@"title"] ?: @""),
				@"subtitle" : @"",
				@"chatId" : (r[@"chatId"] ?: @0),
				@"isGroup" : @([r[@"isGroup"] boolValue]),
				@"fileId" : ([[TGClient shared] photoFileIdForChat:chatId]
						?: [NSNull null])}];
		}
		for (NSDictionary *r in self.remoteRecents) {
			if (![r isKindOfClass:NSDictionary.class])
				continue;
			int64_t chatId = [r[@"id"] longLongValue];
			NSString *title = [r[@"title"] isKindOfClass:NSString.class] ? r[@"title"] : @"";
			if (!chatId || !title.length || [seen containsObject:@(chatId)])
				continue;
			[seen addObject:@(chatId)];
			[rows addObject:@{@"title" : title,
				@"subtitle" : @"",
				@"chatId" : @(chatId),
				@"isGroup" : @NO,
				@"unknownType" : @YES,
				@"fileId" : ([r[@"photoFileId"] isKindOfClass:NSNumber.class]
						? r[@"photoFileId"]
						: ([[TGClient shared] photoFileIdForChat:chatId]
								  ?: [NSNull null]))}];
		}
		if (rows.count)
			[built addObject:@{@"title" : TGL(@"DialogList.SearchSectionRecent", @"Recent"), @"rows" : rows, @"recent" : @YES}];

		if (self.tmeLinks.count)
			[built addObject:@{@"title" : TGL(@"Search.RecentLinks", @"Recent Links"), @"rows" : self.tmeLinks}];

		NSMutableArray *tagRows = [NSMutableArray array];
		for (id entry in self.recentTags) {
			NSString *entryString = [entry isKindOfClass:NSString.class] ? entry : nil;
			if (!entryString.length)
				continue;
			NSString *tag = ([entryString hasPrefix:@"#"] || [entryString hasPrefix:@"$"])
				? entryString
				: [@"#" stringByAppendingString:entryString];
			[tagRows addObject:@{@"title" : tag,
				@"subtitle" : @"",
				@"hashtag" : tag,
				@"chatId" : @0,
				@"isGroup" : @NO,
				@"fileId" : [NSNull null]}];
		}
		if (tagRows.count)
			[built addObject:@{@"title" : TGL(@"Search.RecentHashtags", @"Recent Hashtags"), @"rows" : tagRows, @"tags" : @YES}];
	} else {
		NSMutableArray *localHits = [NSMutableArray array];
		[localHits addObjectsFromArray:self.chatHits];
		[localHits addObjectsFromArray:self.contactHits];
		if (localHits.count)
			[built addObject:@{@"title" : @"", @"rows" : localHits, @"noHeader" : @YES}];
		if (self.recentMatches.count)
			[built addObject:@{@"title" : TGL(@"DialogList.SearchSectionRecent", @"Recent"), @"rows" : self.recentMatches}];
		if (self.globalHits.count)
			[built addObject:@{@"title" : TGL(@"DialogList.SearchSectionGlobal", @"Global Search"), @"rows" : self.globalHits}];
		if (self.hashtagHits.count)
			[built addObject:@{@"title" : TGL(@"Search.Hashtags", @"Hashtags"), @"rows" : self.hashtagHits}];
		if (self.messageHits.count) {
			NSString *title = TGL(@"DialogList.SearchSectionMessages", @"Messages");
			if (_scopedChatId) {
				title = [NSString stringWithFormat:TGL(@"DialogList.SearchSectionMessagesIn", @"Messages in %@"),
						(_scopedChatTitle ?: TGL(@"ChatList.UnnamedChat", @"Chat"))];
				if (_dateAnchored && _anchorLabel.length)
					title = [NSString stringWithFormat:TGL(@"DialogList.SearchSectionFromSuffix", @"%@, from %@"), title, _anchorLabel];
				if (_tagEmoji.length)
					title = [NSString stringWithFormat:@"%@ %@", title, _tagEmoji];
				if (_senderName.length)
					title = [NSString stringWithFormat:TGL(@"DialogList.SearchSectionFromSuffix", @"%@, from %@"), title, _senderName];
			} else if ([[self class] isTagQuery:_query]) {
				title = TGL(@"DialogList.SearchSectionPublicPosts", @"Public Posts");
			} else {
				if (_scope != 0)
					title = [[self class] scopeTitles][_scope];
				if (_chatTypeIndex != 0)
					title = [NSString stringWithFormat:TGL(@"DialogList.SearchSectionInSuffix", @"%@ in %@"), title,
						[[self class] chatTypeTitles][_chatTypeIndex]];
			}
			[built addObject:@{@"title" : title, @"rows" : self.messageHits, @"paged" : @YES, @"messages" : @YES}];
		}
	}
	self.sections = built;
	[self syncResultsPresenter];
	[self.tableView reloadData];
	[self updateStatusLabel];
}

- (void)syncResultsPresenter {
	[_resultsPresenter updateWithSections:self.sections];
}

- (UIImage *)searchResultsRowBridge:(TGSearchResultsRowBridge *)bridge
					avatarForChatId:(int64_t)chatId
							  title:(NSString *)title
							 fileId:(NSNumber *)fileId
							   size:(CGFloat)size {
	return [self avatarForChat:chatId title:title fileId:fileId size:size];
}

- (void)updateStatusLabel {
	if (self.sections.count) {
		self.statusLabel.hidden = YES;
		return;
	}
	if (![self hasActiveQuery]) {
		self.statusLabel.text = _scopedChatId
			? [TGL(@"Search.SearchInPrefix", @"Search in ") stringByAppendingString:
					  (_scopedChatTitle ?: TGL(@"HashtagSearch.ThisChat", @"this chat"))]
			: TGL(@"DialogList.SearchLabel", @"Search for messages or users");
		self.statusLabel.hidden = NO;
		return;
	}
	self.statusLabel.text = (_pending > 0 || _debouncing)
		? TGL(@"Channel.Stickers.Searching", @"Searching...")
		: TGL(@"Conversation.SearchNoResults", @"No results");
	self.statusLabel.hidden = NO;
}

- (NSDictionary *)rowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = ((NSDictionary *)self.sections[indexPath.section])[@"rows"];
	if (indexPath.row >= (NSInteger)rows.count)
		return nil;
	return rows[indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count)
		return 0;
	NSArray *rows = ((NSDictionary *)self.sections[section])[@"rows"];
	return (NSInteger)rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count)
		return nil;
	NSDictionary *info = self.sections[section];
	if ([info[@"noHeader"] boolValue])
		return nil;
	return info[@"title"];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count)
		return nil;

	NSDictionary *info = self.sections[section];
	if ([info[@"noHeader"] boolValue])
		return nil;
	NSString *title = [info[@"title"] isKindOfClass:NSString.class] ? info[@"title"] : @"";
	BOOL isRecent = [info[@"recent"] boolValue];
	BOOL isTags = [info[@"tags"] boolValue];

	CGFloat width = tableView.bounds.size.width;
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, kSearchSectionHeight)];
	header.clipsToBounds = NO;
	header.backgroundColor = [UIColor clearColor];

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont boldSystemFontOfSize:15];
	label.numberOfLines = 1;
	label.text = title;

	UIColor *actionColour;
	UIImage *background = [UIImage imageNamed:
			section == 0 ? @"CategoryDividerFirst.png" : @"CategoryDivider.png"];
	if (background) {
		UIImageView *backgroundView = [[UIImageView alloc] initWithImage:background];
		backgroundView.frame = CGRectMake(0, -1, width, kSearchSectionHeight + 1);
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[header addSubview:backgroundView];
	} else {
		UIColor *plate = [UIColor colorWithRed:0xa8 / 255.0f green:0xb0 / 255.0f blue:0xb8 / 255.0f alpha:1.0f];
		header.backgroundColor = plate;
	}
	label.textColor = [UIColor whiteColor];
	label.shadowColor = [UIColor colorWithRed:0x88 / 255.0f green:0x92 / 255.0f
										 blue:0x9c / 255.0f
										alpha:1.0f];
	label.shadowOffset = CGSizeMake(0, -1);
	actionColour = [UIColor whiteColor];

	[label sizeToFit];
	label.frame = CGRectOffset(label.frame, 10, 1);
	[header addSubview:label];

	if (isRecent || isTags) {
		UIButton *clear = [UIButton buttonWithType:UIButtonTypeCustom];
		clear.frame = CGRectMake(width - 90, 0, 80, kSearchSectionHeight);
		clear.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		clear.titleLabel.font = [UIFont boldSystemFontOfSize:13];
		clear.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
		[clear setTitle:TGL(@"WebSearch.RecentSectionClear", @"Clear") forState:UIControlStateNormal];
		[clear setTitleColor:actionColour forState:UIControlStateNormal];
		UIColor *shadow = [UIColor colorWithRed:0x88 / 255.0f green:0x92 / 255.0f blue:0x9c / 255.0f alpha:1.0f];
		[clear setTitleShadowColor:shadow forState:UIControlStateNormal];
		clear.titleLabel.shadowOffset = CGSizeMake(0, -1);
		[clear addTarget:self
				  action:(isTags ? @selector(clearRecentTags) : @selector(clearRecents))
			forControlEvents:UIControlEventTouchUpInside];
		[header addSubview:clear];
	}

	return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count)
		return 0;
	if ([((NSDictionary *)self.sections[section])[@"noHeader"] boolValue])
		return 0;
	return kSearchSectionHeight;
}

- (UIImage *)avatarForChat:(int64_t)chatId
					 title:(NSString *)title
					fileId:(NSNumber *)fileId
					  size:(CGFloat)size {
	NSString *cacheKey = [fileId isKindOfClass:NSNumber.class]
		? [NSString stringWithFormat:@"%@_%d", fileId, (int)size]
		: nil;
	UIImage *cached = cacheKey ? self.avatars[cacheKey] : nil;
	if (cached)
		return cached;

	if (cacheKey && ![self.avatarsRequested containsObject:cacheKey]) {
		[self.avatarsRequested addObject:cacheKey];
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] downloadFile:fileId.longLongValue completion:^(NSString *path) {
			if (!path.length)
				return;
			dispatch_async(TGImageDecodeQueue(), ^{
				UIImage *photo = nil;
				@autoreleasepool {
					photo = TGDecodeSquareThumbnail(path, size);
				}
				if (!photo)
					return;
				dispatch_async(dispatch_get_main_queue(), ^{
					TGSearchViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					strongSelf.avatars[cacheKey] = photo;
					[strongSelf setNeedsResultsReload];
				});
			});
		}];
	}

	return [TGIcons avatarWithInitials:
			(title.length ? TGSafeFirstCharacter(title).uppercaseString : @"?")
								  size:size
							  colourId:chatId];
}

- (BOOL)sectionIsMessages:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return NO;
	return [((NSDictionary *)self.sections[section])[@"messages"] boolValue];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self sectionIsMessages:indexPath.section]
		? kSearchMessageRowHeight
		: kSearchRowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([_resultsRowBridge ownsRowAtIndexPath:indexPath])
		return [_resultsRowBridge cellForIndexPath:indexPath inTable:tableView];

	NSDictionary *messageRow = [self rowAtIndexPath:indexPath];
	if ([self sectionIsMessages:indexPath.section]) {
		static NSString *messageReuse = @"TGSearchMessageCell";
		TGSearchMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:messageReuse];
		if (!cell)
			cell = [[TGSearchMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
											  reuseIdentifier:messageReuse];

		NSString *messageTitle = [messageRow[@"title"] isKindOfClass:NSString.class]
			? messageRow[@"title"]
			: @"";
		cell.titleLabel.text = messageTitle;
		cell.authorLabel.text = [messageRow[@"author"] isKindOfClass:NSString.class]
			? messageRow[@"author"]
			: @"";
		cell.textLabel_.text = [messageRow[@"subtitle"] isKindOfClass:NSString.class]
			? messageRow[@"subtitle"]
			: @"";
		cell.dateLabel.text = [messageRow[@"date"] isKindOfClass:NSString.class]
			? messageRow[@"date"]
			: @"";
		NSNumber *messageFileId = [messageRow[@"fileId"] isKindOfClass:NSNumber.class] ? messageRow[@"fileId"] : nil;
		int64_t messageChatId = [messageRow[@"chatId"] longLongValue];
		cell.avatarView.image = [self avatarForChat:messageChatId title:messageTitle fileId:messageFileId size:kSearchMessageAvatar];
		[cell setNeedsLayout];
		return cell;
	}

	static NSString *reuse = @"TGSearchCell";
	TGSearchResultCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGSearchResultCell alloc] initWithStyle:UITableViewCellStyleDefault
										 reuseIdentifier:reuse];

	NSDictionary *row = [self rowAtIndexPath:indexPath];
	NSString *title = [row[@"title"] isKindOfClass:NSString.class] ? row[@"title"] : @"";
	NSString *subtitle = [row[@"subtitle"] isKindOfClass:NSString.class] ? row[@"subtitle"] : @"";
	int64_t colourId = [row[@"chatId"] longLongValue];
	if (!colourId)
		colourId = [row[@"userId"] longLongValue];

	NSString *nameFirst = [row[@"firstName"] isKindOfClass:NSString.class] ? row[@"firstName"] : @"";
	NSString *nameLast = [row[@"lastName"] isKindOfClass:NSString.class] ? row[@"lastName"] : @"";
	if (nameFirst.length || nameLast.length)
		[cell setTitleFirst:(nameFirst.length ? nameFirst : nameLast)
					 second:(nameFirst.length ? nameLast : nil)];
	else
		[cell setTitleFirst:title second:nil];
	cell.subtitleLabel.text = subtitle;
	cell.dateLabel.text = [row[@"date"] isKindOfClass:NSString.class] ? row[@"date"] : @"";

	NSString *hashtagRow = [row[@"hashtag"] isKindOfClass:NSString.class] ? row[@"hashtag"] : nil;
	if (hashtagRow.length) {
		NSString *initial = TGSafeFirstCharacter(hashtagRow);
		cell.avatarView.image = [TGIcons avatarWithInitials:initial size:kSearchAvatar colourId:(int64_t)hashtagRow.hash];
		[cell setNeedsLayout];
		return cell;
	}

	NSNumber *rowFileId = [row[@"fileId"] isKindOfClass:NSNumber.class] ? row[@"fileId"] : nil;
	cell.avatarView.image = [self avatarForChat:colourId title:title fileId:rowFileId size:kSearchAvatar];

	[cell setNeedsLayout];
	return cell;
}

- (void)openChat:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup focusMessageId:(int64_t)focusMessageId {
	if (!chatId)
		return;
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = title;
	chat.group = isGroup;
	chat.focusMessageId = focusMessageId;
	[self.navigationController pushViewController:chat animated:YES];
}

- (void)openRecentLinkRow:(NSDictionary *)row {
	NSString *title = [row[@"title"] isKindOfClass:NSString.class] ? row[@"title"] : @"";
	BOOL isGroup = [row[@"isGroup"] boolValue];
	int64_t chatId = [row[@"chatId"] longLongValue];
	int64_t userId = [row[@"userId"] longLongValue];
	__weak typeof(self) weakSelf = self;

	if (chatId) {
		[self rememberRecent:@{@"chatId" : @(chatId),
			@"title" : title,
			@"isGroup" : @(isGroup)}];
		[self openChat:chatId title:title isGroup:isGroup focusMessageId:0];
		return;
	}

	if (userId) {
		[[TGClient shared] privateChatWithUser:userId completion:^(int64_t createdChatId) {
			TGSearchViewController *strongSelf = weakSelf;
			if (!strongSelf || !createdChatId)
				return;
			[strongSelf rememberRecent:@{@"chatId" : @(createdChatId),
				@"title" : title,
				@"isGroup" : @NO}];
			[strongSelf openChat:createdChatId title:title isGroup:NO focusMessageId:0];
		}];
		return;
	}

	NSString *username = [row[@"username"] isKindOfClass:NSString.class] ? row[@"username"] : @"";
	if (!username.length)
		return;
	[[TGClient shared] chatWithUsername:username
							 completion:^(int64_t chatId, NSString *resolvedTitle) {
								 TGSearchViewController *strongSelf = weakSelf;
								 if (!strongSelf || !chatId)
									 return;
								 NSString *name = resolvedTitle.length ? resolvedTitle : title;
								 [strongSelf rememberRecent:@{@"chatId" : @(chatId),
									 @"title" : name,
									 @"isGroup" : @(isGroup)}];
								 [strongSelf openChat:chatId title:name isGroup:isGroup focusMessageId:0];
							 }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self.bar resignFirstResponder];

	NSDictionary *row = [self rowAtIndexPath:indexPath];
	if (!row)
		return;

	NSString *action = [row[@"action"] isKindOfClass:NSString.class] ? row[@"action"] : nil;
	if ([action isEqualToString:@"calendar"]) {
		[self openCalendarForChat:_scopedChatId
							title:(_scopedChatTitle ?: @"")
			isGroup:_scopedIsGroup];
		return;
	}

	NSString *tmeUrl = [row[@"tmeUrl"] isKindOfClass:NSString.class] ? row[@"tmeUrl"] : nil;
	if (tmeUrl.length) {
		[self openRecentLinkRow:row];
		return;
	}

	NSString *hashtag = [row[@"hashtag"] isKindOfClass:NSString.class] ? row[@"hashtag"] : nil;
	if (hashtag.length) {
		self.bar.text = hashtag;
		[self searchBar:self.bar textDidChange:hashtag];
		[self.bar becomeFirstResponder];
		return;
	}

	NSString *title = [row[@"title"] isKindOfClass:NSString.class] ? row[@"title"] : @"";
	BOOL isGroup = [row[@"isGroup"] boolValue];
	int64_t chatId = [row[@"chatId"] longLongValue];
	int64_t focusMessageId = [row[@"messageId"] longLongValue];
	if (chatId) {
		if ([row[@"unknownType"] boolValue]) {
			__weak typeof(self) weakSelf = self;
			TGClient *client = [TGClient shared];
			[client chatSummaryForChatId:chatId completion:^(NSDictionary *chat) {
				TGSearchViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				BOOL group = [chat[@"isGroup"] boolValue] || [chat[@"isChannel"] boolValue];
				NSString *name = [chat[@"title"] isKindOfClass:NSString.class] && [chat[@"title"] length] ? chat[@"title"] : title;
				[strongSelf rememberRecent:@{@"chatId" : @(chatId),
					@"title" : name,
					@"isGroup" : @(group)}];
				[strongSelf openChat:chatId title:name isGroup:group focusMessageId:focusMessageId];
			}];
			return;
		}
		[self rememberRecent:row];
		[self openChat:chatId title:title isGroup:isGroup focusMessageId:focusMessageId];
		return;
	}

	int64_t userId = [row[@"userId"] longLongValue];
	if (!userId)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t createdChatId) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf || !createdChatId)
			return;
		[strongSelf rememberRecent:@{@"chatId" : @(createdChatId),
			@"title" : title,
			@"isGroup" : @NO}];
		[strongSelf openChat:createdChatId title:title isGroup:NO focusMessageId:0];
	}];
}

#pragma mark - per-row actions

- (void)handleLongPress:(UILongPressGestureRecognizer *)press {
	if (press.state != UIGestureRecognizerStateBegan)
		return;
	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:
			[press locationInView:self.tableView]];
	if (!indexPath)
		return;
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	int64_t chatId = [row[@"chatId"] longLongValue];
	if (!chatId)
		return;
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO];

	_sheetKind = kSheetRowActions;
	_sheetChatId = chatId;
	_sheetChatTitle = [row[@"title"] isKindOfClass:NSString.class] ? row[@"title"] : @"";
	_sheetIsGroup = [row[@"isGroup"] boolValue];
	_sheetIsTopPeer = [row[@"isTopPeer"] boolValue];

	NSMutableArray *otherTitles = [NSMutableArray arrayWithArray:@[
		TGL(@"SavedMessages.OpenChat", @"Open Chat"),
		TGL(@"Conversation.SearchPlaceholder", @"Search in chat"),
		TGL(@"Chat.JumpToDate", @"Jump to Date") ]];
	if (_sheetIsTopPeer)
		[otherTitles addObject:TGL(@"ChatList.Context.RemoveFromRecents", @"Clear from Recents")];

	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:_sheetChatTitle
					  delegate:self
				   otherTitles:otherTitles
			  destructiveIndex:(_sheetIsTopPeer ? (NSInteger)otherTitles.count - 1 : -1)
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	[self.bar resignFirstResponder];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	[sheet tg_showFromRect:cell.frame inView:self.tableView];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSInteger kind = _sheetKind;
	_sheetKind = kSheetRowActions;

	if (kind == kSheetSender) {
		if (buttonIndex == 0) {
			if (_senderUserId)
				[self applySender:0 name:nil];
		} else if (buttonIndex > 0 &&
			buttonIndex <= (NSInteger)self.senderCandidates.count) {
			NSDictionary *person = self.senderCandidates[buttonIndex - 1];
			int64_t userId = [person[@"userId"] longLongValue];
			if (userId != _senderUserId)
				[self applySender:userId name:person[@"name"]];
		}
		[self.bar becomeFirstResponder];
		return;
	}

	int64_t chatId = _sheetChatId;
	NSString *title = _sheetChatTitle;
	BOOL isGroup = _sheetIsGroup;
	BOOL isTopPeer = _sheetIsTopPeer;
	_sheetChatId = 0;
	_sheetIsTopPeer = NO;
	if (!chatId)
		return;
	if (buttonIndex == 0) {
		[self rememberRecent:@{@"chatId" : @(chatId), @"title" : (title ?: @""), @"isGroup" : @(isGroup)}];
		[self openChat:chatId title:title isGroup:isGroup focusMessageId:0];
		return;
	}
	if (buttonIndex == 1) {
		[self enterChatScope:chatId title:title isGroup:isGroup];
		return;
	}
	if (buttonIndex == 2) {
		[self openCalendarForChat:chatId title:title isGroup:isGroup];
		return;
	}
	if (buttonIndex == 3 && isTopPeer)
		[self forgetTopPeer:chatId];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section >= (NSInteger)self.sections.count)
		return NO;
	NSDictionary *info = self.sections[indexPath.section];
	return [info[@"tags"] boolValue] || [info[@"recent"] boolValue];
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"Appearance.RemoveTheme", @"Remove");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	NSString *tag = [row[@"hashtag"] isKindOfClass:NSString.class] ? row[@"hashtag"] : nil;
	if (!tag.length) {
		[self forgetRecentChat:[row[@"chatId"] longLongValue]];
		return;
	}
	[[TGClient shared] removeSearchedForTag:tag];
	NSMutableArray *kept = [NSMutableArray array];
	for (id entry in self.recentTags) {
		NSString *entryString = [entry isKindOfClass:NSString.class] ? entry : nil;
		if (!entryString.length)
			continue;
		NSString *candidate = ([entryString hasPrefix:@"#"] || [entryString hasPrefix:@"$"])
			? entryString
			: [@"#" stringByAppendingString:entryString];
		if ([candidate isEqualToString:tag])
			continue;
		[kept addObject:entry];
	}
	self.recentTags = kept;
	[self rebuildSections];
}

@end
