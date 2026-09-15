#import "TGChatPreviewKind.h"
#import "TGStringTruncation.h"
#import "TGChatSwipeActions.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+ChatState.h"
#import "TGChatTitleCredibility.h"
#import "TGChatListViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGChatViewController.h"
#import "TGPreferenceFlags.h"
#import "TGTopicsViewController.h"
#import "TGDirectMessagesViewController.h"
#import "TGClient+ChatList.h"
#import "TGClient+Notifications.h"
#import "TGClient+Files.h"
#import "TGClient+SecretChats.h"
#import "TGTheme.h"
#import "TGSingleLinePreview.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGSwipeGestureRecognizer.h"
#import "TGEmoji.h"
#import "TGActionsMenu.h"
#import "TGDiskCache.h"
#import "TGImageDecode.h"
#import "AppDelegate.h"
#import "TGChatListHelpers.h"
#import "TGChatCell.h"
#import "TGAccountManager.h"

@implementation TGChatListViewController (Search)

#pragma mark - search

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	self.searchResults = nil;
	[searchBar resignFirstResponder];
	[self.tableView reloadData];
	self.searchBarRevealed = NO;
	[self snapSearchBar:self.tableView];
}

- (NSArray *)visibleChats {
	if (self.searchResults)
		return self.searchResults;

	BOOL hideSaved = [[self headerRows] containsObject:@"saved"];
	int64_t saved = hideSaved ? [[TGClient shared] savedMessagesChatId] : 0;
	if (!hideSaved && !self.chatsPendingDeletion.count)
		return self.chats;

	NSMutableArray *rest = [NSMutableArray array];
	for (NSDictionary *c in self.chats) {
		int64_t chatId = [c[@"id"] longLongValue];

		if (chatId == saved || [self.chatsPendingDeletion containsObject:@(chatId)])
			continue;
		[rest addObject:c];
	}
	return rest;
}

- (NSDictionary *)chatForRow:(NSInteger)row {
	NSArray *rows = [self visibleChats];
	NSInteger index = row - (NSInteger)[self headerRows].count;
	if (index < 0 || index >= (NSInteger)rows.count)
		return nil;
	return rows[index];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	[self updateEmptyState];
	if (self.searchResults)
		return self.searchResults.count;
	return [self visibleChats].count + [self headerRows].count;
}

- (void)resetCell:(TGChatCell *)cell plain:(BOOL)plainPlate {
	TGTheme *theme = [TGTheme shared];
	[cell applyTextSize];
	cell.chatId = 0;
	cell.backgroundColor = [theme listBackgroundColour];
	cell.backgroundView.hidden = !plainPlate;
	cell.titleLabel.textColor = plainPlate ? TGChatListTitleColour() : [theme primaryTextColour];
	cell.previewLabel.textColor = plainPlate ? TGChatListMessageColour()
											 : [theme secondaryTextColour];
	cell.dateLabel.textColor = [theme accentColour];
	cell.authorLabel.hidden = YES;
	cell.onlineDot.hidden = YES;
	cell.tick.hidden = YES;
	cell.muteIcon.hidden = YES;
	cell.pendingIndicator.hidden = YES;
	cell.errorBadge.hidden = YES;
	cell.groupIcon.hidden = YES;
	cell.premiumIcon.hidden = YES;
	cell.credibilityLabel.hidden = YES;
	cell.folderTag.hidden = YES;
	cell.pin.hidden = YES;
	cell.mentionBadge.hidden = YES;
	cell.reactionBadge.hidden = YES;
	cell.draftLabel.hidden = YES;
	cell.badge.hidden = YES;
	cell.badgeBackground.hidden = YES;
	cell.badge.text = @"";
	cell.accessoryType = UITableViewCellAccessoryNone;
	[cell setDateText:@"" suffix:nil bold:NO];
	cell.previewLabel.text = @"";
	cell.titleLabel.text = @"";
	cell.authorLabel.text = @"";
	cell.tick.image = nil;
	cell.tick.highlightedImage = nil;
	cell.onlineDot.layer.borderColor = [theme listBackgroundColour].CGColor;
}

- (void)configureHeaderCell:(TGChatCell *)cell kind:(NSString *)kind {
	BOOL isArchive = [kind isEqualToString:@"archive"];
	cell.titleLabel.text = isArchive ? TGL(@"ChatList.ArchivedChatsTitle", @"Archived Chats") : TGSavedMessagesTitle();
	NSDictionary *topArchivedChat = isArchive ? TGReplyArray([TGClient shared].archivedChats).firstObject : nil;
	if (topArchivedChat)
		[self configurePreviewInCell:cell chat:topArchivedChat plain:YES];
	else
		cell.previewLabel.text = isArchive ? @"" : TGL(@"ChatList.SavedMessagesSubtitle", @"Your own notes and forwards");
	[cell setDateText:@"" suffix:nil bold:NO];
	cell.badge.hidden = YES;
	cell.badgeBackground.hidden = YES;
	cell.mentionBadge.hidden = YES;
	cell.reactionBadge.hidden = YES;
	cell.avatar.image = isArchive
		? [TGIcons archiveAvatarOfSide:kAvatar]
		: [TGIcons savedMessagesAvatarOfSide:kAvatar];
	cell.avatar.backgroundColor = [UIColor clearColor];
	[self describeCell:cell unread:0 muted:NO];
}

- (void)configurePreviewInCell:(TGChatCell *)cell chat:(NSDictionary *)c plain:(BOOL)plainPlate {
	TGTheme *theme = [TGTheme shared];
	NSDictionary *detail = [c[@"id"] isKindOfClass:[NSNumber class]]
		? TGReplyDictionary(self.rowDetails[c[@"id"]])
		: nil;
	NSString *action = TGReplyString(c[@"action"]);
	NSString *draft = TGReplyString(c[@"draft"]);
	NSString *handshake = [self secretHandshakeTextForChat:c];
	TGChatPreviewKind previewKind = TGChatPreviewKindForRow(action.length > 0,
		handshake.length > 0,
		draft.length > 0,
		[TGReplyString(detail[@"source"]) isEqualToString:@"psa"],
		self.searchResults != nil);
	if (previewKind == TGChatPreviewKindAction) {
		cell.previewLabel.text = TGSingleLinePreviewText(action);
		cell.previewLabel.textColor = plainPlate ? TGChatListActionColour()
												 : [theme typingColour];
	} else if (previewKind == TGChatPreviewKindHandshake) {
		cell.previewLabel.text = TGSingleLinePreviewText(handshake);
		cell.previewLabel.textColor = plainPlate ? TGChatListActionColour()
												 : [theme typingColour];
	} else if (previewKind == TGChatPreviewKindDraft) {
		cell.draftLabel.hidden = NO;
		cell.previewLabel.text = TGSingleLinePreviewText(draft);
	} else if (previewKind == TGChatPreviewKindAnnouncement) {
		NSString *note = TGReplyString(detail[@"sourceText"]);
		cell.authorLabel.text = note.length ? note : TGL(@"ChatList.PublicServiceAnnouncement", @"Public Service Announcement");
		cell.authorLabel.hidden = NO;
		cell.previewLabel.text = TGSingleLinePreviewText(TGReplyString(c[@"text"]) ?: @"");
	} else {
		NSString *preview = TGReplyString(c[@"text"]) ?: @"";
		NSRange split = [c[@"isGroup"] boolValue] && !self.searchResults
			? [preview rangeOfString:@": "]
			: NSMakeRange(NSNotFound, 0);
		if (split.location != NSNotFound && split.location > 0 && split.location <= 40) {
			cell.authorLabel.text = [preview substringToIndex:split.location];
			cell.authorLabel.hidden = NO;
			preview = [preview substringFromIndex:split.location + split.length];
		}
		cell.previewLabel.text = TGSingleLinePreviewText(preview);
	}
}

- (void)configureBadgeInCell:(TGChatCell *)cell chat:(NSDictionary *)c unread:(NSInteger)unread {
	BOOL markedUnread = (unread <= 0) && [self chatIsUnread:c];
	BOOL hasMention = [c[@"unreadMentionCount"] integerValue] > 0;
	BOOL hasReaction = [c[@"unreadReactionCount"] integerValue] > 0;
	cell.badge.hidden = (unread <= 0 && !markedUnread);
	cell.badgeBackground.hidden = cell.badge.hidden;
	cell.mentionBadge.hidden = !hasMention;
	cell.reactionBadge.hidden = !hasReaction;
	cell.pin.hidden = !([c[@"isPinned"] boolValue] && unread <= 0 && !markedUnread
		&& !hasMention && !hasReaction);
	cell.badge.text = unread > 0
		? (unread < 1000 ? [NSString stringWithFormat:@"%ld", (long)unread]
						 : [NSString stringWithFormat:@"%ldK", (long)(unread / 1000)])
		: @"";
}

- (void)configureAvatarInCell:(TGChatCell *)cell chat:(NSDictionary *)c {
	NSString *avatarKey = TGAvatarKeyForChat(c);
	UIImage *photo = avatarKey.length ? self.avatars[avatarKey] : nil;
	if ([c[@"isSaved"] boolValue])
		photo = [TGIcons savedMessagesAvatarOfSide:kAvatar];
	if (!photo)
		photo = [self blurredAvatarPlaceholderForChat:c];
	if (!photo) {
		NSString *title = TGReplyString(c[@"title"]) ?: @"";
		NSString *initials = title.length ? TGSafeFirstCharacter(title) : @"?";
		photo = [TGIcons avatarWithInitials:initials.uppercaseString
									   size:kAvatar
								   colourId:[c[@"id"] longLongValue]];
	}
	cell.avatar.image = photo;
	cell.avatar.backgroundColor = [UIColor clearColor];
}

- (void)configureStatusIconsInCell:(TGChatCell *)cell chat:(NSDictionary *)c {
	cell.onlineDot.hidden = ![c[@"isOnline"] boolValue] || [c[@"isSaved"] boolValue];
	cell.tick.hidden = ![c[@"outgoing"] boolValue] || !cell.draftLabel.hidden;
	if (!cell.tick.hidden) {
		NSString *art = [c[@"outgoingRead"] boolValue] ? @"DialogListRead" : @"DialogListSent";
		cell.tick.image = [UIImage imageNamed:[art stringByAppendingString:@".png"]];
		cell.tick.highlightedImage = [UIImage imageNamed:
				[art stringByAppendingString:@"_Highlighted.png"]];
	}

	BOOL sendFailed = [c[@"sendFailed"] boolValue];
	cell.pendingIndicator.hidden = !([c[@"sendPending"] boolValue] && cell.draftLabel.hidden);
	cell.errorBadge.hidden = !(sendFailed && cell.draftLabel.hidden);
	if (!cell.errorBadge.hidden) {
		cell.badge.hidden = YES;
		cell.badgeBackground.hidden = YES;
		cell.mentionBadge.hidden = YES;
		cell.reactionBadge.hidden = YES;
		cell.pin.hidden = YES;
	}

	cell.muteIcon.hidden = ![c[@"isMuted"] boolValue];
	cell.groupIcon.hidden = ![c[@"isGroup"] boolValue];
	cell.premiumIcon.hidden = ![[TGClient shared] cachedPremiumForChatId:[c[@"id"] longLongValue]];
	NSDictionary *credibility = [[TGClient shared]
		cachedCredibilityForChatId:[c[@"id"] longLongValue]];
	NSString *mark = TGChatTitleCredibilityMark(credibility);
	cell.credibilityLabel.text = mark ?: @"";
	cell.credibilityLabel.hidden = !mark.length;
	cell.credibilityLabel.textColor = TGChatTitleCredibilityMarkIsWarning(credibility)
		? [UIColor colorWithRed:0xC4 / 255.0f green:0x2B / 255.0f blue:0x1E / 255.0f alpha:1.0f]
		: [UIColor colorWithRed:0x33 / 255.0f green:0x7a / 255.0f blue:0xcc / 255.0f alpha:1.0f];

	NSDictionary *tag = [[TGClient shared] primaryFolderTagForChatId:[c[@"id"] longLongValue]];
	if (tag) {
		cell.folderTag.text = [(tag[@"title"] ?: @"") uppercaseString];
		cell.folderTag.backgroundColor = [TGTheme
			folderTagColourForColourId:[tag[@"colorId"] integerValue]];
		cell.folderTag.hidden = !cell.folderTag.text.length;
	} else {
		cell.folderTag.hidden = YES;
	}
}

- (void)attachSwipeHandlersToCell:(TGChatCell *)cell chat:(NSDictionary *)c {
	cell.swipeActions = [self swipeActionsForChat:c];
	__weak typeof(self) weakSelf = self;
	__weak TGChatCell *weakCell = cell;
	cell.onSwipeOpen = ^{
		[weakSelf closeOpenSwipeCellAnimated:YES];
		weakSelf.openSwipeCell = weakCell;
	};
	cell.onSwipeAction = ^(NSString *kind) {
		[weakSelf runSwipeAction:kind forCell:weakCell];
	};
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *header = [self headerRows];
	NSArray *rows = [self visibleChats];

	static NSString *reuse = @"TGChatCell";
	TGChatCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGChatCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
	if (cell == self.openSwipeCell)
		self.openSwipeCell = nil;

	TGTheme *theme = [TGTheme shared];
	[self resetCell:cell plain:YES];

	if (indexPath.row >= (NSInteger)(header.count + rows.count))
		return cell;
	if (indexPath.row < (NSInteger)header.count) {
		[self configureHeaderCell:cell kind:header[indexPath.row]];
		[cell setNeedsLayout];
		return cell;
	}

	NSDictionary *c = rows[indexPath.row - header.count];
	cell.chatId = [c[@"id"] longLongValue];
	cell.titleLabel.text = TGReplyString(c[@"title"]) ?: @"";
	if (!self.searchResults && [c[@"id"] longLongValue] &&
		[[TGClient shared] secretChatIdForChat:[c[@"id"] longLongValue]] != 0)
		cell.titleLabel.textColor = TGSecretChatColour();
	cell.dateLabel.textColor = [theme accentColour];
	NSString *marker = nil;
	BOOL bold = NO;
	NSString *stamp = TGChatDateParts([c[@"date"] doubleValue], &marker, &bold);
	[cell setDateText:stamp suffix:marker bold:bold];

	[self configurePreviewInCell:cell chat:c plain:YES];

	[self configureStatusIconsInCell:cell chat:c];

	NSInteger unread = [c[@"unread"] integerValue];
	[self configureBadgeInCell:cell chat:c unread:unread];
	[self configureAvatarInCell:cell chat:c];
	[self attachSwipeHandlersToCell:cell chat:c];

	if (self.multiSelecting)
		cell.accessoryType = [self.selectedChatIds containsObject:c[@"id"]]
			? UITableViewCellAccessoryCheckmark
			: UITableViewCellAccessoryNone;

	[self describeCell:cell unread:unread muted:[c[@"isMuted"] boolValue]];
	[cell setNeedsLayout];
	return cell;
}

- (void)fetchRowDetailForChat:(NSDictionary *)chat {
	if (self.searchResults)
		return;
	NSNumber *key = chat[@"id"];
	if (![key isKindOfClass:[NSNumber class]] || ![key longLongValue])
		return;
	if (self.rowDetails[key] || [self.rowDetailsRequested containsObject:key])
		return;
	if (self.rowDetails.count >= kRowDetailCacheLimit)
		[self pruneRowDetails];
	[self.rowDetailsRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] rowDetailForChat:[key longLongValue] completion:^(NSDictionary *reply) {
		TGChatListViewController *strongSelf = weakSelf;
		NSDictionary *detail = TGReplyDictionary(reply);
		if (!strongSelf)
			return;
		if (!detail) {
			[strongSelf.rowDetailsRequested removeObject:key];
			return;
		}
		strongSelf.rowDetails[key] = detail;

		TGChatCell *cell = [strongSelf cellShowingChatId:[key longLongValue]];
		NSIndexPath *path = cell ? [strongSelf.tableView indexPathForCell:cell] : nil;
		if (path && [[strongSelf chatForRow:path.row][@"id"] isEqual:key])
			[strongSelf.tableView reloadRowsAtIndexPaths:@[ path ]
								withRowAnimation:UITableViewRowAnimationNone];
	}];
}

- (void)pruneRowDetails {
	NSMutableSet *keep = [NSMutableSet set];
	for (UITableViewCell *raw in ([self.tableView visibleCells] ?: @[])) {
		if (![raw isKindOfClass:[TGChatCell class]])
			continue;
		long long chatId = ((TGChatCell *)raw).chatId;
		if (chatId)
			[keep addObject:@(chatId)];
	}
	for (id key in [self.rowDetails.allKeys copy]) {
		if ([keep containsObject:key])
			continue;
		[self.rowDetails removeObjectForKey:key];
		[self.rowDetailsRequested removeObject:key];
	}
}

- (NSString *)swipeActionTitleForKind:(NSString *)kind chat:(NSDictionary *)chat {
	if ([kind isEqualToString:@"unmute"])
		return TGL(@"ChatList.Context.Unmute", @"Unmute");
	if ([kind isEqualToString:@"mute"])
		return TGL(@"ChatList.Context.Mute", @"Mute");
	if ([kind isEqualToString:@"unarchive"])
		return TGL(@"ChatList.Context.Unarchive", @"Unarchive");
	if ([kind isEqualToString:@"archive"])
		return TGL(@"ChatList.Context.Archive", @"Archive");
	return [chat[@"isGroup"] boolValue]
		? TGL(@"PeerInfo.AlertLeaveAction", @"Leave")
		: TGL(@"Common.Delete", @"Delete");
}

- (NSArray *)swipeActionsForChat:(NSDictionary *)chat {
	NSArray *kinds = TGChatSwipeActionKinds(chat, self.searchResults != nil,
		self.multiSelecting, self.showsArchive);
	if (!kinds.count)
		return nil;

	NSMutableArray *actions = [NSMutableArray arrayWithCapacity:kinds.count];
	for (NSString *kind in kinds) {
		NSMutableDictionary *action = [NSMutableDictionary dictionaryWithDictionary:@{
			@"kind" : kind,
			@"title" : [self swipeActionTitleForKind:kind chat:chat],
		}];
		if ([kind isEqualToString:@"delete"])
			action[@"destructive"] = @YES;
		[actions addObject:action];
	}
	return actions;
}

- (void)closeOpenSwipeCellAnimated:(BOOL)animated {
	TGChatCell *open = self.openSwipeCell;
	self.openSwipeCell = nil;
	[open setSwipeActionsVisible:NO animated:animated];
}

- (void)runSwipeAction:(NSString *)kind forCell:(TGChatCell *)cell {
	if (!cell)
		return;
	NSIndexPath *path = [self.tableView indexPathForCell:cell];
	if (!path)
		return;
	NSDictionary *chat = [self chatShownByCell:cell];
	if (!chat)
		return;

	int64_t chatId = [chat[@"id"] longLongValue];
	if (!chatId)
		return;

	[cell setSwipeActionsVisible:NO animated:YES];
	if (self.openSwipeCell == cell)
		self.openSwipeCell = nil;

	if ([kind isEqualToString:@"unmute"]) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] setChat:chatId
					muteForSeconds:0
						completion:^(BOOL ok) {
			TGChatListViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[strongSelf showNotificationsAlertWithMessage:TGL(@"ChatList.SettingCouldNotBeChangedMessage", @"Telegram would not change that setting.")];
				return;
			}
			[strongSelf.muteRemaining removeObjectForKey:@(chatId)];
			[strongSelf reload];
		}];
	} else if ([kind isEqualToString:@"mute"]) {
		self.actionChat = chat;
		CGRect rect = [self.tableView rectForRowAtIndexPath:path];
		self.menuPoint = [self.tableView convertPoint:
				CGPointMake(120, CGRectGetMaxY(rect) - 10)
											   toView:self.navigationController.view];
		[self showMuteDurationsForChat:chatId];
	} else if ([kind isEqualToString:@"archive"]) {
		[self setChat:chatId archived:YES];
	} else if ([kind isEqualToString:@"unarchive"]) {
		[self setChat:chatId archived:NO];
	} else if ([kind isEqualToString:@"delete"]) {
		[self confirmDeleteChat:chat];
	}
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *c = [self chatForRow:indexPath.row];
	if (!c)
		return;
	[self fetchRowDetailForChat:c];
	NSString *avatarKey = TGAvatarKeyForChat(c);
	if (avatarKey.length && !self.avatars[avatarKey] &&
		![self.avatarsRequested containsObject:avatarKey])
		[self startAvatarLoadForKey:avatarKey];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell
	   forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.avatarsInFlight.count)
		return;
	NSSet *wanted = [self avatarKeysWanted];
	for (NSString *avatarKey in [self.avatarsInFlight allObjects]) {
		if ([wanted containsObject:avatarKey])
			continue;
		[self.avatarsInFlight removeObject:avatarKey];
		[self.avatarsRequested removeObject:avatarKey];
		NSNumber *fileId = [self avatarFileIdForKey:avatarKey];
		if ([fileId isKindOfClass:[NSNumber class]])
			[[TGClient shared] cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:NO];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.searchResults)
		return NO;
	NSArray *header = [self headerRows];
	return indexPath.row >= (NSInteger)header.count;
}

- (NSInteger)pinnedRowCount {
	if (self.searchResults)
		return 0;
	NSArray *rows = [self visibleChats];
	NSInteger count = 0;
	for (NSDictionary *chat in rows) {
		if (![chat[@"isPinned"] boolValue])
			break;
		count++;
	}
	return count;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.searchResults || [self visibleChats].count != self.chats.count)
		return NO;
	NSInteger pinned = [self pinnedRowCount];
	if (pinned < 2)
		return NO;
	NSInteger index = indexPath.row - (NSInteger)[self headerRows].count;
	return index >= 0 && index < pinned;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
	targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
						 toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
	self.interactiveMoveInProgress = YES;
	NSInteger header = (NSInteger)[self headerRows].count;
	NSInteger pinned = [self pinnedRowCount];
	NSInteger row = proposedDestinationIndexPath.row;
	if (row < header)
		row = header;
	if (row > header + pinned - 1)
		row = header + pinned - 1;
	return [NSIndexPath indexPathForRow:row inSection:0];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
		   toIndexPath:(NSIndexPath *)destinationIndexPath {
	self.interactiveMoveInProgress = NO;
	BOOL reloadWasPending = self.reloadPendingAfterInteractiveMove;
	self.reloadPendingAfterInteractiveMove = NO;

	NSInteger header = (NSInteger)[self headerRows].count;
	NSInteger pinned = [self pinnedRowCount];
	NSInteger from = sourceIndexPath.row - header;
	NSInteger to = destinationIndexPath.row - header;
	if (from < 0 || to < 0 || from >= pinned || to >= pinned || from == to) {
		if (reloadWasPending)
			[self reload];
		return;
	}

	NSMutableArray *reordered = [self.chats mutableCopy];
	if (from >= (NSInteger)reordered.count || to >= (NSInteger)reordered.count) {
		if (reloadWasPending)
			[self reload];
		return;
	}
	NSArray *previousChats = self.chats;
	id moved = reordered[from];
	[reordered removeObjectAtIndex:from];
	[reordered insertObject:moved atIndex:to];
	self.chats = reordered;
	[self reloadRowsFrom:MIN(from, to) to:MAX(from, to)];

	NSMutableArray *ids = [NSMutableArray array];
	for (NSInteger i = 0; i < pinned; i++) {
		NSNumber *key = reordered[i][@"id"];
		if ([key isKindOfClass:[NSNumber class]])
			[ids addObject:key];
	}
	if (!ids.count) {
		if (reloadWasPending)
			[self reload];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPinnedChats:ids inList:[self currentListId] completion:^(BOOL success) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!success) {
			strongSelf.chats = previousChats;
			[strongSelf reload];
			[TGSnackbar showInView:strongSelf.navigationController.view
							   text:TGL(@"ChatList.Context.PinFailed", @"Telegram could not update the chat.")
							seconds:2
						   onCommit:nil];
		}
	}];

	if (reloadWasPending)
		[self reload];
}

- (void)reloadRowsFrom:(NSInteger)first to:(NSInteger)last {
	NSInteger header = (NSInteger)[self headerRows].count;
	NSInteger rows = (NSInteger)[self visibleChats].count;
	NSMutableArray *paths = [NSMutableArray array];
	for (NSInteger i = MAX(first, 0); i <= last && i < rows; i++)
		[paths addObject:[NSIndexPath indexPathForRow:i + header inSection:0]];
	if (!paths.count)
		return;

	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		TGChatListViewController *strongSelf = weakSelf;
		if ((NSInteger)[strongSelf visibleChats].count != rows)
			return;
		[strongSelf.tableView reloadRowsAtIndexPaths:paths
							withRowAnimation:UITableViewRowAnimationNone];
	});
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![self tableView:tableView canEditRowAtIndexPath:indexPath])
		return UITableViewCellEditingStyleNone;
	return tableView.editing ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([[self chatForRow:indexPath.row][@"isGroup"] boolValue])
		return TGL(@"PeerInfo.AlertLeaveAction", @"Leave");
	return TGL(@"Common.Delete", @"Delete");
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (style != UITableViewCellEditingStyleDelete)
		return;
	NSDictionary *chat = [self chatForRow:indexPath.row];
	if (!chat)
		return;
	[self confirmDeleteChat:chat];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	TGBeginOpenTimingFromTap();
	if (![self splitLayoutActive])
		[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (self.multiSelecting) {
		[self toggleMultiSelectRowAtIndexPath:indexPath];
		return;
	}

	BOOL split = [self splitLayoutActive];

	if (self.openSwipeCell) {
		if (split)
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
		[self closeOpenSwipeCellAnimated:YES];
		return;
	}

	NSArray *header = [self headerRows];
	NSArray *rows = [self visibleChats];
	if (indexPath.row >= (NSInteger)(header.count + rows.count)) {
		if (split)
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
		return;
	}
	if (indexPath.row < (NSInteger)header.count) {
		if ([header[indexPath.row] isEqualToString:@"archive"]) {
			if (split)
				[tableView deselectRowAtIndexPath:indexPath animated:YES];
			[self openArchive];
		} else {
			[self openSavedMessages];
		}
		return;
	}

	NSDictionary *c = rows[indexPath.row - header.count];
	int64_t chatId = [c[@"id"] longLongValue];
	if (!chatId) {
		if (split)
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
		return;
	}
	if (chatId == [[TGClient shared] savedMessagesChatId] && [TGPreferenceFlags savedMessagesShowsTopics]) {
		if (split)
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
		[self openSavedMessages];
		return;
	}
	if ([c[@"isForum"] boolValue]) {
		if (split)
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
		TGTopicsViewController *topics = [[TGTopicsViewController alloc] init];
		topics.chatId = chatId;
		topics.chatTitle = TGReplyString(c[@"title"]);
		[self presentChatController:topics];
		return;
	}

	if ([c[@"isAdministeredDirectMessagesGroup"] boolValue]) {
		if (split)
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
		TGDirectMessagesViewController *topics =
			[[TGDirectMessagesViewController alloc] init];
		topics.chatId = chatId;
		topics.chatTitle = TGReplyString(c[@"title"]);
		[self presentChatController:topics];
		return;
	}

	[self prefetchOpenHistoryForChat:chatId];

	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = TGReplyString(c[@"title"]);
	vc.group = [c[@"isGroup"] boolValue];
	[self presentChatController:vc];
}

static const NSInteger kTGOpenHistoryPageLimit = 60;
static const NSInteger kTGOpenUnreadContextRows = 12;
static const NSInteger kTGOpenRestoreContextRows = 25;
static const NSInteger kTGOpenUnreadSlack = 4;
static NSString *const kTGChatScrollPositionsKey = @"TGChatScrollPositions";

- (void)prefetchOpenHistoryForChat:(int64_t)chatId {
	if (!chatId)
		return;

	TGClient *client = [TGClient shared];
	NSInteger unreadOnOpen = [client unreadCountInChat:chatId];
	long long lastReadInbox = [client lastReadIncomingMessageInChat:chatId];

	int64_t anchorMessageId = 0;
	NSInteger newerWanted = 0;

	if (unreadOnOpen > 0 && lastReadInbox != 0) {
		NSInteger newer = unreadOnOpen + kTGOpenUnreadSlack;
		if (newer > kTGOpenHistoryPageLimit - kTGOpenUnreadContextRows)
			newer = kTGOpenHistoryPageLimit - kTGOpenUnreadContextRows;
		anchorMessageId = lastReadInbox;
		newerWanted = newer;
	} else {
		NSDictionary *known = [[NSUserDefaults standardUserDefaults]
			dictionaryForKey:[TGAccountManager defaultsKey:kTGChatScrollPositionsKey]];
		NSDictionary *stored = known[[NSString stringWithFormat:@"%lld", chatId]];
		int64_t remembered = [stored[@"m"] longLongValue];
		if (remembered != 0) {
			anchorMessageId = remembered;
			newerWanted = kTGOpenRestoreContextRows;
		}
	}

	[client prefetchLocalHistoryForChat:chatId aroundMessage:anchorMessageId
								  newer:newerWanted
								  limit:kTGOpenHistoryPageLimit];
}

@end
