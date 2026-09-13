#import "TGTopicsViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+Forums.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGPopupMenu.h"
#import "TGDateUtils.h"
#import "TGDateLabel.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAlertView.h"
#import "TGCustomEmojiCache.h"

#import "TGTopicsViewControllerInternal.h"
#import "TGHexColour.h"

@implementation TGTopicsViewController (Search)

#pragma mark - search

- (NSArray *)displayedTopics {
	return self.searchResults ? self.searchResults : self.topics;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];

	NSString *query = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (query.length == 0) {
		self.searchQuery = nil;
		self.searchResults = nil;
		self.searching = NO;
		[self.spinner stopAnimating];
		[self updateEmptyState];
		[self.tableView reloadData];
		return;
	}

	self.searchQuery = query;
	[self performSelector:@selector(runSearch) withObject:nil afterDelay:0.4];
}

- (void)runSearch {
	NSString *query = self.searchQuery;
	if (query.length == 0)
		return;

	self.searching = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchForumTopicsInChat:self.chatId query:query
									completion:^(NSArray *topics) {
										TGTopicsViewController *strongSelf = weakSelf;
										if (!strongSelf || strongSelf.searchQuery.length == 0 || ![strongSelf.searchQuery isEqualToString:query])
											return;
										strongSelf.searching = NO;
										strongSelf.searchResults = [strongSelf cleanedTopics:topics];
										[strongSelf updateEmptyState];
										[strongSelf.tableView reloadData];
									}];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
	[self runSearch];
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
	searchBar.text = @"";
	self.searchQuery = nil;
	self.searchResults = nil;
	self.searching = NO;
	[searchBar setShowsCancelButton:NO animated:YES];
	[searchBar resignFirstResponder];
	[self updateEmptyState];
	[self.tableView reloadData];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	if (searchBar.text.length == 0)
		[searchBar setShowsCancelButton:NO animated:YES];
}

- (void)reloadTopics {
	if (self.loading)
		return;
	if (self.reordering) {
		self.reloadPendingAfterReorder = YES;
		return;
	}
	self.loading = YES;

	if (!self.loadedOnce) {
		self.emptyContainer.hidden = YES;
		[self.spinner startAnimating];
	}

	self.nextOffset = nil;
	self.reachedEnd = NO;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] forumTopicsForChat:self.chatId
									query:nil
							   offsetDate:0
						  offsetMessageId:0
							offsetTopicId:0
									limit:40
							   completion:^(NSArray *topics, NSDictionary *nextOffset, NSInteger totalCount) {
								   TGTopicsViewController *strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   strongSelf.loading = NO;
								   strongSelf.loadedOnce = YES;
								   [strongSelf.spinner stopAnimating];
								   if ([strongSelf respondsToSelector:@selector(refreshControl)])
									   [strongSelf.refreshControl endRefreshing];

								   strongSelf.totalCount = totalCount;
								   strongSelf.nextOffset = nextOffset;
								   NSArray *clean = [strongSelf cleanedTopics:topics];
								   strongSelf.reachedEnd = (clean.count == 0 || nextOffset == nil);
								   strongSelf.topics = [strongSelf orderedTopics:clean];

								   [strongSelf updateEmptyState];
								   [strongSelf updateSubtitle];
								   [strongSelf.tableView reloadData];
							   }];
}

- (NSArray *)cleanedTopics:(NSArray *)topics {
	NSMutableArray *clean = [NSMutableArray array];
	if ([topics isKindOfClass:NSArray.class]) {
		for (id topic in topics) {
			if ([topic isKindOfClass:NSDictionary.class])
				[clean addObject:topic];
		}
	}
	return clean;
}

- (NSArray *)orderedTopics:(NSArray *)topics {
	NSMutableArray *ordered = [NSMutableArray arrayWithCapacity:topics.count];
	for (NSDictionary *topic in topics) {
		if (TGTopicFlag(topic, @"isPinned"))
			[ordered addObject:topic];
	}
	for (NSDictionary *topic in topics) {
		if (!TGTopicFlag(topic, @"isPinned"))
			[ordered addObject:topic];
	}
	return ordered;
}

- (void)updateEmptyState {
	if (!self.emptyContainer)
		return;

	BOOL empty;
	NSString *title;
	NSString *text;

	if (self.searchResults) {
		empty = (self.searchResults.count == 0);
		title = TGL(@"ChatList.Search.NoResults", @"No Results");
		text = TGL(@"ChatList.Search.NoResultsDescription", @"There were no results.\nTry a new search.");
	} else {
		empty = (self.topics.count == 0 && self.loadedOnce);
		title = TGL(@"ChatList.EmptyTopicsTitle", @"No Topics Yet");
		text = TGL(@"ChatList.EmptyTopicsText", @"Topics keep separate conversations in one group.");
	}

	self.emptyContainer.hidden = !empty;
	if (!empty)
		return;

	self.emptyContainer.titleLabel.text = title;
	self.emptyContainer.bodyLabel.text = text;
	[self layoutEmptyContent];
}

- (void)layoutEmptyContent {
	CGFloat width = 250;
	CGFloat height = [self.emptyContainer layoutContentWidth:width];

	UIView *background = self.tableView.backgroundView;
	CGRect bounds = background ? background.bounds : self.tableView.bounds;
	self.emptyContainer.frame = CGRectMake((int)((bounds.size.width - width) / 2),
		(int)((bounds.size.height - height) / 2), width, height);
}

- (void)loadMoreTopics {
	if (self.loading || self.loadingMore || self.reordering || self.reachedEnd)
		return;
	NSDictionary *offset = self.nextOffset;
	if (![offset isKindOfClass:NSDictionary.class]) {
		self.reachedEnd = YES;
		return;
	}

	self.loadingMore = YES;
	NSInteger offsetDate = TGTopicInteger(offset, @"date");
	int64_t offsetMessageId = TGTopicLongLong(offset, @"messageId");
	int32_t offsetTopicId = (int32_t)TGTopicInteger(offset, @"topicId");

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] forumTopicsForChat:self.chatId
									query:nil
							   offsetDate:offsetDate
						  offsetMessageId:offsetMessageId
							offsetTopicId:offsetTopicId
									limit:40
							   completion:^(NSArray *topics, NSDictionary *nextOffset, NSInteger totalCount) {
								   TGTopicsViewController *strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   strongSelf.loadingMore = NO;

								   NSArray *page = [strongSelf cleanedTopics:topics];
								   if (page.count == 0 || nextOffset == nil)
									   strongSelf.reachedEnd = YES;
								   if (page.count == 0)
									   return;

								   if (totalCount > 0)
									   strongSelf.totalCount = totalCount;
								   strongSelf.nextOffset = nextOffset;

								   NSMutableSet *known = [NSMutableSet set];
								   for (NSDictionary *topic in strongSelf.topics)
									   [known addObject:@([strongSelf topicIdOf:topic])];

								   NSMutableArray *combined = [strongSelf.topics mutableCopy];
								   for (NSDictionary *topic in page) {
									   NSNumber *identifier = @([strongSelf topicIdOf:topic]);
									   if ([known containsObject:identifier])
										   continue;
									   [known addObject:identifier];
									   [combined addObject:topic];
								   }
								   strongSelf.topics = [strongSelf orderedTopics:combined];

								   [strongSelf updateEmptyState];
								   [strongSelf updateSubtitle];
								   [strongSelf.tableView reloadData];
							   }];
}

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.searchResults)
		return;
	if (indexPath.row >= (NSInteger)self.topics.count - 3)
		[self loadMoreTopics];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self displayedTopics].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGTopicCell";
	TGTopicCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGTopicCell alloc] initWithStyle:UITableViewCellStyleDefault
								  reuseIdentifier:reuse];

	TGTheme *theme = [TGTheme shared];
	[self resetTopicCell:cell theme:theme plainPlate:YES];

	NSArray *rows = [self displayedTopics];
	if (indexPath.row >= (NSInteger)rows.count)
		return cell;

	NSDictionary *t = rows[indexPath.row];
	NSInteger unread = TGTopicInteger(t, @"unread");

	NSString *name = TGTopicString(t, @"name");
	NSString *preview = TGTopicString(t, @"text");
	NSString *title = name.length ? name : TGL(@"Topics.DefaultName", @"Topic");
	BOOL closed = TGTopicFlag(t, @"isClosed");
	BOOL hidden = TGTopicFlag(t, @"isHidden");
	BOOL isGeneral = TGTopicFlag(t, @"isGeneral");

	cell.titleLabel.text = title;
	if (isGeneral && hidden) {
		cell.previewLabel.text = preview.length
			? [NSString stringWithFormat:TGL(@"PeerInfo.HiddenCommunityStatus", @"Hidden · %@"), preview]
			: TGL(@"Topics.Hidden", @"Hidden");
	} else if (closed) {
		cell.previewLabel.text = preview.length
			? [NSString stringWithFormat:TGL(@"Notification.ForumTopicClosedStatus", @"Closed · %@"), preview]
			: TGL(@"Notification.ForumTopicClosed", @"Topic closed");
		cell.previewLabel.textColor = TGColourFromHex(0x536c8c);
	} else if (hidden) {
		cell.previewLabel.text = preview.length
			? [NSString stringWithFormat:TGL(@"PeerInfo.HiddenCommunityStatus", @"Hidden · %@"), preview]
			: TGL(@"Topics.Hidden", @"Hidden");
	} else {
		cell.previewLabel.text = preview;
	}
	cell.dateLabel.text = TGTopicDate(TGTopicDouble(t, @"date"));

	NSInteger mentions = TGTopicInteger(t, @"unreadMentions");
	NSInteger reactions = TGTopicInteger(t, @"unreadReactions");
	cell.pinIcon.hidden = !(TGTopicFlag(t, @"isPinned") && unread <= 0 && mentions <= 0 && reactions <= 0);

	[self applyPlateToCell:cell unread:unread closed:closed];

	NSString *initials = TGTopicInitial(title);
	NSInteger rgb = TGTopicInteger(t, @"iconColor");
	UIImage *avatarImage;
	if (isGeneral) {
		avatarImage = [TGIcons generalTopicAvatarOfSide:kTopicAvatar];
	} else if (rgb > 0) {
		avatarImage = TGTopicAvatarImage(initials, kTopicAvatar, rgb);
	} else {
		avatarImage = [TGIcons avatarWithInitials:initials size:kTopicAvatar
										  colourId:[self topicIdOf:t]];
	}

	long long iconEmojiId = isGeneral ? 0 : TGTopicLongLong(t, @"iconEmojiId");
	if (iconEmojiId) {
		UIImage *customEmojiImage = TGCustomEmojiCachedImage(iconEmojiId);
		if (customEmojiImage)
			avatarImage = customEmojiImage;
		else
			TGCustomEmojiRequestImage(iconEmojiId);
	}
	cell.avatar.image = avatarImage;

	cell.muteIcon.hidden = ![self topicIsMuted:t];

	[self applyBadgeToCell:cell unread:unread mentions:mentions reactions:reactions];

	[cell setNeedsLayout];
	return cell;
}

- (void)resetTopicCell:(TGTopicCell *)cell theme:(TGTheme *)theme plainPlate:(BOOL)plainPlate {
	cell.backgroundColor = [theme listBackgroundColour];
	cell.backgroundView.hidden = !plainPlate;
	cell.titleLabel.textColor = [theme primaryTextColour];
	cell.previewLabel.textColor = [theme secondaryTextColour];
	cell.dateLabel.textColor = [theme accentColour];
	cell.dateLabel.text = @"";
	cell.previewLabel.text = @"";
	cell.badge.text = @"";
	cell.badge.hidden = YES;
	cell.badgeBackground.hidden = YES;
	cell.pinIcon.hidden = YES;
	cell.muteIcon.hidden = YES;
	[cell applyBadgeShadowForHighlight:(cell.highlighted || cell.selected)];
}

- (void)applyPlateToCell:(TGTopicCell *)cell unread:(NSInteger)unread closed:(BOOL)closed {
	UIImageView *plate = (UIImageView *)cell.backgroundView;
	plate.image = TGTopicPlateImage();
	plate.backgroundColor = [UIColor clearColor];
}

- (void)applyBadgeToCell:(TGTopicCell *)cell unread:(NSInteger)unread mentions:(NSInteger)mentions reactions:(NSInteger)reactions {
	if (unread > 0) {
		cell.badge.text = unread < 1000
			? [NSString stringWithFormat:@"%ld", (long)unread]
			: [NSString stringWithFormat:@"%ldK", (long)(unread / 1000)];
		cell.badge.hidden = NO;
		cell.badgeBackground.hidden = NO;
	} else if (mentions > 0) {
		cell.badge.text = @"@";
		cell.badge.hidden = NO;
		cell.badgeBackground.hidden = NO;
	} else if (reactions > 0) {
		cell.badge.text = @"♥";
		cell.badge.hidden = NO;
		cell.badgeBackground.hidden = NO;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (self.reordering)
		return;

	[self.searchBar resignFirstResponder];

	NSArray *rows = [self displayedTopics];
	if (indexPath.row >= (NSInteger)rows.count)
		return;

	NSDictionary *t = rows[indexPath.row];
	long long threadId = TGTopicLongLong(t, @"threadId");
	if (threadId == 0)
		return;

	NSString *name = TGTopicString(t, @"name");
	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = self.chatId;
	vc.threadId = threadId;
	vc.chatTitle = name.length ? name : TGL(@"Topics.DefaultName", @"Topic");
	vc.group = YES;
	[self.navigationController pushViewController:vc animated:YES];

	int32_t topicId = [self topicIdOf:t];
	if (topicId != 0 && TGTopicInteger(t, @"unread") > 0)
		[[TGClient shared] markForumTopicReadInChat:self.chatId topic:topicId completion:nil];
}

@end
