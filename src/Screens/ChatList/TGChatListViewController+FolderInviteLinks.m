#import "TGUnreadSummaryKey.h"
#import "TGStringTruncation.h"
#import "TGDateUtils.h"
#import "TGChatDateKind.h"
#import "TGClient+ChatManagement.h"
#import "TGChatListViewControllerInternal.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGActionSheet.h"
#import "TGChatFolderLinkPreviewViewController.h"
#import "TGLocalization.h"
#import "RootViewController.h"
#import "TGChatViewController.h"
#import "TGClient+ChatList.h"
#import "TGClient+Notifications.h"
#import "TGFlattenChatList.h"
#import "TGClient+Stories.h"
#import "TGClient+Files.h"
#import "TGClient+SecretChats.h"
#import "TGFoldersViewController.h"
#import "TGStoryComposer.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGContactsViewController.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGSearchViewController.h"
#import "TGSwipeGestureRecognizer.h"
#import "TGEmoji.h"
#import "TGActionsMenu.h"
#import "TGSavedMessagesViewController.h"
#import "TGPreferenceFlags.h"
#import "UIView+SafeTint.h"
#import "TGDiskCache.h"
#import "TGImageDecode.h"
#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAlertView.h"
#import "TGChatListHelpers.h"
#import "TGChatCell.h"
#import "TGStoriesViewController.h"

@implementation TGChatListViewController (FolderInviteLinks)

#pragma mark - folder invite links

- (void)askFolderInviteLink {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"ChatList.AddFolder", @"Add Folder")
						 message:TGL(@"ChatListFolder.PasteLink", @"Paste a folder invite link")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"ChatListFolder.Check", @"Check"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	UITextField *field = [alert textFieldAtIndex:0];
	field.keyboardType = UIKeyboardTypeURL;
	field.autocapitalizationType = UITextAutocapitalizationTypeNone;
	field.autocorrectionType = UITextAutocorrectionTypeNo;
	alert.tag = 21;
	[alert show];
}

- (void)checkFolderInviteLink:(NSString *)link {
	[TGChatFolderLinkPreviewViewController presentForInviteLink:link
			fromNavigationController:self.navigationController];
}

- (UIView *)folderStripWithWidth:(CGFloat)width top:(CGFloat)top {
	UIView *strip = [[UIView alloc] initWithFrame:CGRectMake(0, top, width, kFolderStripHeight)];
	strip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIImage *background = TGScopeBarBackgroundImage();
	if (background) {
		UIImageView *plate = [[UIImageView alloc] initWithImage:background];
		plate.frame = strip.bounds;
		plate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[strip addSubview:plate];
	} else {
		strip.backgroundColor = [[TGTheme shared] listBackgroundColour];
	}

	UIScrollView *scroller = [[UIScrollView alloc] initWithFrame:strip.bounds];
	scroller.backgroundColor = [UIColor clearColor];
	scroller.showsHorizontalScrollIndicator = NO;
	scroller.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[strip addSubview:scroller];

	UIImage *normalPlate = [[UIImage imageNamed:@"SearchBarScopeButton.png"]
		stretchableImageWithLeftCapWidth:6
							topCapHeight:11];
	UIImage *selectedPlate = [[UIImage imageNamed:@"SearchBarScopeButton_Highlighted.png"]
		stretchableImageWithLeftCapWidth:6
							topCapHeight:11];

	NSArray *entries = [self folderStripEntries];

	UIFont *font = [UIFont boldSystemFontOfSize:12];
	CGFloat x = kFolderChipGap;
	for (NSInteger i = 0; i < entries.count; i++) {
		UIButton *button = [self folderStripButtonForEntry:entries[i] font:font left:x normalPlate:normalPlate selectedPlate:selectedPlate];
		[scroller addSubview:button];
		x += button.frame.size.width + kFolderChipGap;
	}

	scroller.contentSize = CGSizeMake(MAX(x, width), kFolderStripHeight);

	if (!background) {
		UIView *hair = [[UIView alloc] initWithFrame:
				CGRectMake(0, kFolderStripHeight - 0.5f, width, 0.5f)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		[strip addSubview:hair];
	}
	return strip;
}

- (NSArray *)folderStripEntries {
	NSMutableArray *entries = [NSMutableArray array];
	[entries addObject:@{@"title" : TGL(@"ChatList.Tabs.AllChats", @"All Chats"), @"folder" : @0}];
	for (id entry in [self folderList]) {
		NSDictionary *folder = TGReplyDictionary(entry);
		[entries addObject:@{@"title" : (TGReplyString(folder[@"title"]) ?: TGL(@"ChatListFolder.DefaultTitle", @"Folder")),
			@"folder" : ([folder[@"id"] isKindOfClass:[NSNumber class]]
					? folder[@"id"]
					: @0)}];
	}
	return entries;
}

- (NSString *)folderStripCaptions {
	NSMutableString *out = [NSMutableString string];
	for (NSDictionary *entry in [self folderStripEntries]) {
		NSInteger listId = [entry[@"folder"] integerValue];
		[out appendFormat:@"%ld=%@;", (long)listId,
			[self unreadSuffixForList:(TGChatListId)(listId ?: TGChatListMain)]];
	}
	return out;
}

- (UIButton *)folderStripButtonForEntry:(NSDictionary *)entry
								   font:(UIFont *)font
								   left:(CGFloat)left
							normalPlate:(UIImage *)normalPlate
						  selectedPlate:(UIImage *)selectedPlate {
	NSInteger listId = [entry[@"folder"] integerValue];
	NSString *caption = [entry[@"title"] stringByAppendingString:
			[self unreadSuffixForList:(TGChatListId)(listId ?: TGChatListMain)]];
	BOOL selected = (listId == self.folderId);

	CGFloat textWidth = ceilf([caption sizeWithFont:font].width);
	CGFloat buttonWidth = textWidth + kFolderChipPadding * 2;
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.exclusiveTouch = YES;
	button.adjustsImageWhenHighlighted = NO;
	button.frame = CGRectMake(left, (int)((kFolderStripHeight - kFolderChipHeight) / 2),
		buttonWidth, kFolderChipHeight);
	[button setBackgroundImage:(selected ? selectedPlate : normalPlate)
					  forState:UIControlStateNormal];
	[button setBackgroundImage:(selectedPlate ?: normalPlate)
					  forState:UIControlStateHighlighted];

	UILabel *label = [[UILabel alloc] initWithFrame:
			CGRectMake(kFolderChipPadding, 0, textWidth, kFolderChipHeight)];
	label.text = caption;
	label.font = font;
	label.textAlignment = TGLocalizedLeadingTextAlignment();
	label.backgroundColor = [UIColor clearColor];
	label.userInteractionEnabled = NO;
	[self styleFolderStripLabel:label selected:selected];
	[button addSubview:label];
	button.tag = listId;
	[button addTarget:self action:@selector(folderButtonTapped:)
		forControlEvents:UIControlEventTouchUpInside];
	[button addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
									 initWithTarget:self
											 action:@selector(folderButtonHeld:)]];
	return button;
}

- (void)styleFolderStripLabel:(UILabel *)label selected:(BOOL)selected {
	if (selected) {
		label.textColor = [UIColor whiteColor];
		label.shadowColor = [UIColor colorWithRed:0x11 / 255.0f
											green:0x2e / 255.0f
											 blue:0x5c / 255.0f
											alpha:0.2f];
		label.shadowOffset = CGSizeMake(0, -1);
	} else {
		label.textColor = [UIColor colorWithRed:0x4a / 255.0f green:0x65 / 255.0f
										   blue:0x87 / 255.0f
										  alpha:1.0f];
		label.shadowColor = nil;
		label.shadowOffset = CGSizeZero;
	}
}

- (void)folderButtonHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	UIView *button = hold.view;
	if (!button)
		return;
	NSInteger listId = button.tag;

	UIView *host = self.navigationController.view ?: self.view;
	CGPoint where = [button.superview convertPoint:
			CGPointMake(CGRectGetMidX(button.frame), CGRectGetMaxY(button.frame))
											toView:host];

	NSArray *items = @[
		@{@"title" : TGL(@"ChatList.Context.MarkAllAsRead", @"Mark All as Read"), @"icon" : @"chat"},
		@{@"title" : TGL(@"ChatList.AddFolderFromLink", @"Add Folder from Link…"), @"icon" : @"folder"},
		@{@"title" : TGL(@"ChatList.EditFolders", @"Edit Folders"), @"icon" : @"folder"},
	];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:host
				  onChoice:^(NSInteger choice, NSString *title) {
					  TGChatListViewController *strongSelf = weakSelf;
					  if (!strongSelf)
						  return;
					  if (choice == 0) {
						  [[TGClient shared] markListAsRead:(TGChatListId)(listId ?: TGChatListMain)];
						  [strongSelf reload];
					  } else if (choice == 1) {
						  [strongSelf askFolderInviteLink];
					  } else if (choice == 2) {
						  [strongSelf openFolderManagement];
					  }
				  }];
}

- (void)folderButtonTapped:(UIButton *)button {
	if (self.folderId == button.tag)
		return;
	self.folderId = button.tag;
	self.folderLimit = 60;
	[self applyTitleView];
	[self rebuildTableHeader];
	[self reload];
}

- (UIView *)storyTrayWithWidth:(CGFloat)width top:(CGFloat)top {
	UIView *band = [[UIView alloc] initWithFrame:CGRectMake(0, top, width, kStoryTrayHeight)];
	UIImage *plateImage = TGScopeBarBackgroundImage();
	if (plateImage) {
		UIImageView *plate = [[UIImageView alloc] initWithImage:plateImage];
		plate.frame = band.bounds;
		[band addSubview:plate];
	} else {
		band.backgroundColor = [UIColor colorWithRed:0xE4 / 255.0f green:0xE9 / 255.0f
												blue:0xF0 / 255.0f
											   alpha:1.0f];
	}

	UIScrollView *tray = [[UIScrollView alloc] initWithFrame:band.bounds];
	tray.backgroundColor = [UIColor clearColor];
	tray.showsHorizontalScrollIndicator = NO;
	[band addSubview:tray];

	CGFloat x = 8;
	for (NSInteger i = 0; i < self.storyPosters.count; i++) {
		UIView *cell = [self storyTrayCellForPoster:self.storyPosters[i] index:i left:x];
		[tray addSubview:cell];
		x += kStoryCellWidth;
	}
	tray.contentSize = CGSizeMake(x + 8, kStoryTrayHeight);

	if (!plateImage) {
		UIView *hair = [[UIView alloc] initWithFrame:
				CGRectMake(0, kStoryTrayHeight - 0.5f, width, 0.5f)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		[band addSubview:hair];
	}
	return band;
}

- (UIView *)storyTrayCellForPoster:(NSDictionary *)poster index:(NSUInteger)index left:(CGFloat)x {
	TGTheme *theme = [TGTheme shared];
	BOOL unread = [poster[@"unread"] boolValue];

	UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(x, 0, kStoryCellWidth, kStoryTrayHeight)];
	cell.backgroundColor = [UIColor clearColor];
	cell.tag = (NSInteger)index;

	UIView *ring = [[UIView alloc] initWithFrame:CGRectMake(4, 4, kStoryAvatar + 4, kStoryAvatar + 4)];
	ring.backgroundColor = [UIColor clearColor];
	ring.layer.cornerRadius = 7;
	ring.layer.borderWidth = 2;
	ring.layer.borderColor = unread
		? [theme accentColour].CGColor
		: [UIColor colorWithRed:0xC3 / 255.0f green:0xCB / 255.0f
						   blue:0xD6 / 255.0f
						  alpha:1.0f]
			  .CGColor;
	[cell addSubview:ring];

	UIImageView *avatar = [[UIImageView alloc] initWithFrame:
			CGRectMake(6, 6, kStoryAvatar, kStoryAvatar)];
	avatar.layer.cornerRadius = 5;
	avatar.clipsToBounds = YES;
	avatar.contentMode = UIViewContentModeScaleAspectFill;
	NSString *posterKey = TGAvatarKeyForChat(poster);
	UIImage *photo = posterKey.length ? self.avatars[posterKey] : nil;
	if (!photo) {
		NSString *title = TGReplyString(poster[@"title"]) ?: @"";
		NSString *initial = title.length ? TGSafeFirstCharacter(title).uppercaseString : @"?";
		photo = [TGIcons avatarWithInitials:initial
									   size:kStoryAvatar
								   colourId:[poster[@"chatId"] longLongValue]];
	}
	avatar.image = photo;
	[cell addSubview:avatar];

	UILabel *name = [[TGEmojiLabel alloc] initWithFrame:CGRectMake(0, 64, kStoryCellWidth, 13)];
	name.backgroundColor = [UIColor clearColor];
	name.font = [UIFont systemFontOfSize:11];
	name.textAlignment = NSTextAlignmentCenter;
	name.lineBreakMode = NSLineBreakByTruncatingTail;
	name.textColor = unread ? [theme primaryTextColour] : [theme secondaryTextColour];
	name.text = TGReplyString(poster[@"title"]) ?: @"";
	[cell addSubview:name];

	[cell addGestureRecognizer:[[UITapGestureRecognizer alloc]
								   initWithTarget:self
										   action:@selector(storyCellTapped:)]];
	return cell;
}

- (void)storyCellTapped:(UITapGestureRecognizer *)tap {
	NSInteger index = tap.view.tag;
	if (index < 0 || index >= (NSInteger)self.storyPosters.count)
		return;

	NSDictionary *poster = self.storyPosters[index];
	int64_t chatId = [poster[@"chatId"] longLongValue];
	if (!chatId)
		return;
	[TGStoriesViewController openStoriesForChat:chatId
										   name:TGReplyString(poster[@"title"]) ?: @""
										   from:self];
}

- (void)refreshStoryPosters {
	if (self.showsArchive) {
		if (self.storyPosters.count) {
			self.storyPosters = nil;
			[self rebuildTableHeader];
		}
		return;
	}

	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - self.lastStorySweep < 20.0 &&
		(self.storyPosters || self.storyProbesPending > 0))
		return;
	self.lastStorySweep = now;

	NSArray *candidates = self.chats;
	if (candidates.count > 40)
		candidates = [candidates subarrayWithRange:NSMakeRange(0, 40)];

	NSMutableSet *probed = [NSMutableSet set];
	for (NSDictionary *chat in candidates)
		[probed addObject:@([chat[@"id"] longLongValue])];
	NSMutableDictionary *kept = [NSMutableDictionary dictionary];
	for (NSNumber *known in self.storyPostersById) {
		if (![probed containsObject:known])
			kept[known] = self.storyPostersById[known];
	}

	self.storyPostersById = kept;
	self.storyProbesPending = 0;
	if (!candidates.count) {
		[self commitStoryPosters];
		return;
	}

	[[TGClient shared] loadActiveStoriesArchived:NO];
	[self commitStoryPosters];
}

- (void)commitStoryPosters {
	NSArray *sorted = [self.storyPostersById.allValues sortedArrayUsingComparator:
			^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
				BOOL unreadA = [a[@"unread"] boolValue];
				BOOL unreadB = [b[@"unread"] boolValue];
				if (unreadA != unreadB)
					return unreadA ? NSOrderedAscending : NSOrderedDescending;
				long long orderA = [a[@"order"] longLongValue];
				long long orderB = [b[@"order"] longLongValue];
				if (orderA == orderB)
					return NSOrderedSame;
				return orderA > orderB ? NSOrderedAscending : NSOrderedDescending;
			}];

	BOOL had = self.storyPosters.count > 0;
	self.storyPosters = sorted;
	if (had || sorted.count)
		[self rebuildTableHeader];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
	TGSearchViewController *search = [[TGSearchViewController alloc] init];
	search.archiveOnly = self.showsArchive;
	[self.navigationController pushViewController:search animated:YES];
	return NO;
}

- (void)styleSearchBar {
	TGTheme *theme = [TGTheme shared];
	self.searchBar.barStyle = UIBarStyleDefault;
	if ([self.searchBar respondsToSelector:@selector(setBackgroundImage:)]) {
		[self.searchBar setBackgroundImage:[UIImage imageNamed:@"SearchBarBackground.png"]];
	}
	if ([self.searchBar respondsToSelector:@selector(setBarTintColor:)]) {
		self.searchBar.barTintColor = [theme listBackgroundColour];
		[self.searchBar tg_setTintColor:[theme accentColour]];
	} else {
		[self.searchBar tg_setTintColor:[UIColor colorWithWhite:0.68f alpha:1.0f]];
	}
}

- (BOOL)splitLayoutActive {
	return [RootViewController isSplitLayoutActive];
}

- (void)presentChatController:(UIViewController *)controller {
	if (![self splitLayoutActive]) {
		[self.navigationController pushViewController:controller animated:YES];
		return;
	}
	if (![RootViewController presentInDetail:controller])
		[self.navigationController pushViewController:controller animated:YES];
}

- (void)openSavedMessages {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId)
		return;
	if ([TGPreferenceFlags savedMessagesShowsTopics]) {
		[self.navigationController pushViewController:
				[[TGSavedMessagesViewController alloc] init]
											 animated:YES];
		return;
	}
	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = TGSavedMessagesTitle();
	[self presentChatController:vc];
}

- (void)composeTapped {
	[self closeOpenSwipeCellAnimated:NO];
	self.sheetItems = @[
		@{@"kind" : @"newMessage", @"title" : TGL(@"Compose.NewMessage", @"New Message")},
		@{@"kind" : @"addStory", @"title" : TGL(@"StoryFeed.ContextAddStory", @"Add Story")},
	];
	[self presentSheetForItemsWithTitle:TGL(@"VoiceOver.Navigation.Compose", @"Compose") cancelTitle:TGL(@"Common.Cancel", @"Cancel")];
}

- (void)startNewMessage {
	TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
	contacts.title = TGL(@"Compose.NewMessage", @"New Message");
	contacts.pickerMode = YES;
	[self.navigationController pushViewController:contacts animated:YES];
}

- (void)reload {
	if (self.interactiveMoveInProgress) {
		self.reloadPendingAfterInteractiveMove = YES;
		return;
	}
	self.openSwipeCell = nil;
	[self reportFirstRows];
	[self refreshUnconfirmedSession];
	if (self.showsArchive) {
		self.chats = TGChatRows([TGClient shared].archivedChats);
		[self.tableView reloadData];
		[self pinHeaderIfSearchBarClipped];
		[self applyInitialScrollOffset];
		[self fetchMissingAvatars];
		[self refreshUnreadCounters];
		return;
	}

	if (self.folderId != 0) {
		__weak typeof(self) weakSelf = self;
		NSInteger requested = self.folderId;
		[[TGClient shared] chatsInList:(TGChatListId)self.folderId limit:self.folderLimit
							completion:^(NSArray *reply) {
								TGChatListViewController *strongSelf = weakSelf;
								if (!strongSelf || strongSelf.folderId != requested)
									return;
								strongSelf.loadingMore = NO;
								strongSelf.chats = TGChatRows(reply);
								[strongSelf.tableView reloadData];
								[strongSelf pinHeaderIfSearchBarClipped];
								[strongSelf refreshUnreadCounters];
								[strongSelf rebuildTableHeader];
								[strongSelf fetchMissingAvatars];
								[strongSelf refreshStoryPosters];
								[strongSelf refreshFolderNewChats];
								[strongSelf pumpFolderIfEmpty:requested];
							}];
		return;
	}

	self.chats = TGChatRows([TGClient shared].chats);
	self.loadingMore = NO;
	if (!self.showsArchive) {
		[self loadCachedAvatarsForFirstFrame];
		[self warmAvatarPlaceholders];
	}
	[self.tableView reloadData];
	[self pinHeaderIfSearchBarClipped];
	[self refreshUnreadCounters];
	[self rebuildTableHeader];
	[self fetchMissingAvatars];
	[self refreshStoryPosters];
	[self refreshFolderNewChats];
}

- (void)pumpFolderIfEmpty:(NSInteger)folderId {
	if (folderId == 0 || self.chats.count > 0)
		return;
	if ([self.foldersPumped containsObject:@(folderId)])
		return;
	[self.foldersPumped addObject:@(folderId)];
	[[TGClient shared] loadMoreChatsInList:(TGChatListId)folderId limit:self.folderLimit];
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kChatListDeferredActionDelay * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatListViewController *strongSelf = weakSelf;
			if (strongSelf && strongSelf.folderId == folderId)
				[strongSelf reload];
		});
}

- (void)refreshUnreadCounters {
	TGClient *client = [TGClient shared];
	BOOL includeMuted = [TGPreferenceFlags badgeIncludesMuted];
	BOOL countChats = [TGPreferenceFlags badgeCountsUnreadChats];
	NSString *messagesKey = TGUnreadSummaryKeyForBadge(countChats, includeMuted);
	if (![self.listUnreadIsNative containsObject:@(TGChatListMain)]) {
		NSDictionary *main = TGReplyDictionary([client unreadSummaryForList:TGChatListMain]);
		if ([main[messagesKey] isKindOfClass:[NSNumber class]])
			self.listUnread[@(TGChatListMain)] = main[messagesKey];
	}
	if (![self.listUnreadIsNative containsObject:@(TGChatListArchive)]) {
		NSDictionary *archive = TGReplyDictionary([client unreadSummaryForList:TGChatListArchive]);
		if ([archive[messagesKey] isKindOfClass:[NSNumber class]])
			self.listUnread[@(TGChatListArchive)] = archive[messagesKey];
	}

	static NSTimeInterval lastFolderSweep = 0;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - lastFolderSweep < 5.0)
		return;
	lastFolderSweep = now;

	__weak typeof(self) weakSelf = self;
	for (id entry in (TGReplyArray(client.folders) ?: @[])) {
		NSDictionary *folder = TGReplyDictionary(entry);
		NSInteger listId = [folder[@"id"] integerValue];
		if (listId == 0)
			continue;
		if ([self.listUnreadIsNative containsObject:@(listId)])
			continue;
		[client chatsInList:(TGChatListId)listId limit:100 completion:^(NSArray *reply) {
			TGChatListViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if ([strongSelf.listUnreadIsNative containsObject:@(listId)])
				return;
			NSInteger total = 0;
			for (id item in (TGReplyArray(reply) ?: @[])) {
				NSDictionary *chat = TGReplyDictionary(item);
				if ([chat[@"isMuted"] boolValue] && !includeMuted)
					continue;
				NSInteger contribution = TGUnreadContributionForChatRow(chat);
				total += countChats ? (contribution > 0 ? 1 : 0) : contribution;
			}
			if ([strongSelf.listUnread[@(listId)] integerValue] == total)
				return;
			strongSelf.listUnread[@(listId)] = @(total);
			[strongSelf rebuildTableHeader];
		}];
	}
}

- (void)handleUnreadMessageCountUpdate:(NSDictionary *)info {
	NSNumber *listIdNumber = info[@"listId"];
	if (![listIdNumber isKindOfClass:[NSNumber class]])
		return;
	if ([TGPreferenceFlags badgeCountsUnreadChats])
		return;
	BOOL includeMuted = [TGPreferenceFlags badgeIncludesMuted];
	NSNumber *count = includeMuted ? info[@"unreadCount"] : info[@"unmutedUnreadCount"];
	if (![count isKindOfClass:[NSNumber class]])
		return;
	[self.listUnreadIsNative addObject:listIdNumber];
	if ([self.listUnread[listIdNumber] isEqual:count])
		return;
	self.listUnread[listIdNumber] = count;
	[self rebuildTableHeader];
}

- (void)handleUnreadChatCountUpdate:(NSDictionary *)info {
	NSNumber *listIdNumber = info[@"listId"];
	if (![listIdNumber isKindOfClass:[NSNumber class]])
		return;
	if (![TGPreferenceFlags badgeCountsUnreadChats])
		return;
	BOOL includeMuted = [TGPreferenceFlags badgeIncludesMuted];
	NSNumber *count = includeMuted ? info[@"unreadChats"] : info[@"unmutedUnreadChats"];
	if (![count isKindOfClass:[NSNumber class]])
		return;
	[self.listUnreadIsNative addObject:listIdNumber];
	if ([self.listUnread[listIdNumber] isEqual:count])
		return;
	self.listUnread[listIdNumber] = count;
	[self rebuildTableHeader];
}

- (NSString *)unreadSuffixForList:(TGChatListId)list {
	NSInteger count = [self.listUnread[@(list)] integerValue];
	if (count <= 0)
		return @"";
	return [NSString stringWithFormat:@"  (%ld)", (long)count];
}

- (void)loadMoreIfNeeded {
	if (self.searchResults || self.loadingMore)
		return;
	UITableView *table = self.tableView;
	CGFloat bottom = table.contentOffset.y + table.bounds.size.height;
	if (table.contentSize.height <= 0 || bottom < table.contentSize.height - kRowHeight * 2)
		return;

	self.loadingMore = YES;
	if (self.folderId != 0) {
		if ((NSInteger)self.chats.count < self.folderLimit) {
			self.loadingMore = NO;
			return;
		}
		self.folderLimit += 60;
		[[TGClient shared] loadMoreChatsInList:(TGChatListId)self.folderId limit:60];
		[self reload];
		return;
	}
	[[TGClient shared] loadMoreChatsInList:[self currentListId] limit:60];
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			weakSelf.loadingMore = NO;
		});
}

- (NSArray *)headerRows {
	return @[];
}

- (void)openArchive {
	TGChatListViewController *archive = [[TGChatListViewController alloc] init];
	archive.showsArchive = YES;
	[self.navigationController pushViewController:archive animated:YES];
}

- (TGChatListId)currentListId {
	if (self.showsArchive)
		return TGChatListArchive;
	if (self.folderId != 0)
		return (TGChatListId)self.folderId;
	return TGChatListMain;
}

- (void)presentSheet:(UIActionSheet *)sheet {
	UITabBar *tabBar = [self.tabBarController isKindOfClass:UITabBarController.class]
		? self.tabBarController.tabBar
		: nil;
	if (tabBar)
		[sheet showFromTabBar:tabBar];
	else {
		UIView *view = self.view;
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds), 1, 1) inView:view];
	}
}

- (void)presentSheetForItemsWithTitle:(NSString *)title cancelTitle:(NSString *)cancelTitle {
	NSMutableArray *otherTitles = [NSMutableArray array];
	for (NSDictionary *item in self.sheetItems)
		[otherTitles addObject:item[@"title"]];
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:title
					  delegate:self
				   otherTitles:otherTitles
			  destructiveIndex:-1
				   cancelTitle:cancelTitle
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = 1;
	[self presentSheet:sheet];
}

- (void)foldersTapped {
	NSArray *folders = [self folderList];

	NSMutableArray *items = [NSMutableArray array];
	[items addObject:@{@"kind" : @"list",
		@"title" : [NSString stringWithFormat:@"%@%@%@",
			(self.folderId == 0 ? @"✓ " : @""),
			TGL(@"ChatList.Tabs.AllChats", @"All Chats"),
			[self unreadSuffixForList:TGChatListMain]],
		@"folder" : @0}];
	for (id entry in folders) {
		NSDictionary *f = TGReplyDictionary(entry);
		NSInteger listId = [f[@"id"] integerValue];
		if (!listId)
			continue;
		NSString *name = TGReplyString(f[@"title"]) ?: TGL(@"ChatListFolder.DefaultTitle", @"Folder");
		[items addObject:@{@"kind" : @"list",
			@"title" : [NSString stringWithFormat:@"%@%@%@",
				(self.folderId == listId ? @"✓ " : @""), name,
				[self unreadSuffixForList:(TGChatListId)listId]],
			@"folder" : @(listId)}];
	}
	[items addObject:@{@"kind" : @"folderLink", @"title" : TGL(@"ChatList.AddFolderFromLink", @"Add Folder from Link…")}];
	[items addObject:@{@"kind" : @"editFolders", @"title" : TGL(@"ChatList.EditFolders", @"Edit Folders")}];
	self.sheetItems = items;

	NSString *sheetTitle = TGL(@"ChatList.ThisAccountHasNoChatFolders", @"This account has no chat folders yet");
	if (folders.count)
		sheetTitle = TGL(@"ChatListFolder.SelectorTitle", @"Chat Folders");
	[self presentSheetForItemsWithTitle:sheetTitle cancelTitle:TGL(@"Common.Cancel", @"Cancel")];
}

- (void)listOptionsTapped {
	self.sheetItems = @[
		@{@"kind" : @"markAllRead", @"title" : TGL(@"ChatList.Context.MarkAllAsRead", @"Mark All as Read")},
	];

	[self presentSheetForItemsWithTitle:[self defaultTitle] cancelTitle:TGL(@"Common.Cancel", @"Cancel")];
}

- (void)actionsTapped {
	[self closeOpenSwipeCellAnimated:NO];
	if (self.showsArchive) {
		[self archiveOptionsTapped];
		return;
	}
	[self listOptionsTapped];
}

- (void)addStory {
	__weak typeof(self) weakSelf = self;
	[TGStoryComposer presentFrom:self completion:^(BOOL posted) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf || !posted)
			return;
		strongSelf.lastStorySweep = 0;
		[[TGClient shared] loadActiveStoriesArchived:NO];
		[strongSelf refreshStoryPosters];
	}];
}

- (void)openFolderManagement {
	TGFoldersViewController *folders = [[TGFoldersViewController alloc] init];
	folders.page = TGFoldersPageList;
	[self.navigationController pushViewController:folders animated:YES];
}

- (void)markCurrentListAsRead {
	[[TGClient shared] markListAsRead:[self currentListId]];
	[self reload];
}

- (void)archiveOptionsTapped {
	self.sheetItems = @[
		@{@"kind" : @"markAllRead", @"title" : TGL(@"ChatList.Context.MarkAllAsRead", @"Mark All as Read")},
		@{@"kind" : @"archiveSettings", @"title" : TGL(@"ChatList.Archive.ContextSettings", @"Archive Settings")},
	];
	[self presentSheetForItemsWithTitle:TGL(@"ChatList.ArchivedChatsTitle", @"Archived Chats") cancelTitle:TGL(@"Common.Cancel", @"Cancel")];
}

- (void)showArchiveSettings {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] archiveSettingsWithCompletion:^(NSDictionary *reply) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.archiveSettings = TGReplyDictionary(reply) ?: @{};

		NSArray *keys = @[ @"archiveUnknownSenders", @"keepUnmutedArchived", @"keepFoldersArchived" ];
		NSArray *names = @[ TGL(@"ChatList.Archive.ToggleArchiveUnknown", @"Archive new chats from unknown senders"),
			TGL(@"ChatList.Archive.ToggleKeepUnmutedArchived", @"Keep unmuted chats archived"),
			TGL(@"ChatList.Archive.ToggleKeepFoldersArchived", @"Keep chats from folders archived") ];
		NSMutableArray *items = [NSMutableArray array];
		for (NSInteger i = 0; i < keys.count; i++) {
			BOOL on = [strongSelf.archiveSettings[keys[i]] boolValue];
			[items addObject:@{@"kind" : @"toggleArchive",
				@"key" : keys[i],
				@"title" : [NSString stringWithFormat:@"%@%@",
					(on ? @"✓ " : @""), names[i]]}];
		}
		strongSelf.sheetItems = items;

		[strongSelf presentSheetForItemsWithTitle:TGL(@"ChatList.Archive.ContextSettings", @"Archive Settings") cancelTitle:TGL(@"Common.Done", @"Done")];
	}];
}

- (void)actionSheet:(UIActionSheet *)sheet didDismissWithButtonIndex:(NSInteger)index {
	if (sheet.tag == 2) {
		if (index == sheet.cancelButtonIndex) {
			self.chatPendingDeleteChoice = nil;
			return;
		}
		[self runChatDeleteChoiceAtIndex:index];
		return;
	}

	if (index == sheet.cancelButtonIndex)
		return;
	if (index < 0 || index >= (NSInteger)self.sheetItems.count)
		return;

	NSDictionary *item = self.sheetItems[index];
	NSString *kind = item[@"kind"];

	if ([kind isEqualToString:@"list"]) {
		[self showFolderFromSheetItem:item];
	} else if ([kind isEqualToString:@"markAllRead"]) {
		[self markCurrentListAsRead];
	} else if ([kind isEqualToString:@"editFolders"]) {
		[self openFolderManagement];
	} else if ([kind isEqualToString:@"newMessage"]) {
		[self startNewMessage];
	} else if ([kind isEqualToString:@"addStory"]) {
		[self addStory];
	} else if ([kind isEqualToString:@"folderLink"]) {
		[self askFolderInviteLink];
	} else if ([kind isEqualToString:@"archiveSettings"]) {
		[self showArchiveSettings];
	} else if ([kind isEqualToString:@"toggleArchive"]) {
		[self toggleArchiveSettingWithKey:item[@"key"]];
	}
}

- (void)showFolderFromSheetItem:(NSDictionary *)item {
	self.folderId = [item[@"folder"] integerValue];
	self.folderLimit = 60;
	[self applyTitleView];
	[self rebuildTableHeader];
	[self reload];
}

- (void)toggleArchiveSettingWithKey:(NSString *)key {
	static NSDictionary *serverKeys = nil;
	if (!serverKeys)
		serverKeys = @{@"archiveUnknownSenders" : @"archiveAndMuteNewChatsFromUnknownUsers",
			@"keepUnmutedArchived" : @"keepUnmutedChatsArchived",
			@"keepFoldersArchived" : @"keepChatsFromFoldersArchived"};

	BOOL on = ![self.archiveSettings[key] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] updateArchiveChatListSettings:@{serverKeys[key] : @(on)}
										   completion:^(BOOL success) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf showArchiveSettings];
	}];
}

static UIImage *TGRoundedAvatarImageOfSide(UIImage *source, CGFloat side, CGFloat scale) {
	if (!source || side < 1)
		return source;
	CGSize size = source.size;
	if (size.width < 1 || size.height < 1)
		return source;
	CGRect box = CGRectMake(0, 0, side, side);
	UIGraphicsBeginImageContextWithOptions(box.size, NO, scale);
	[[UIBezierPath bezierPathWithRoundedRect:box
								cornerRadius:kAvatarRadius * side / kAvatar] addClip];
	CGFloat factor = MAX(side / size.width, side / size.height);
	CGSize drawn = CGSizeMake(size.width * factor, size.height * factor);
	[source drawInRect:CGRectMake((side - drawn.width) / 2,
						   (side - drawn.height) / 2,
						   drawn.width, drawn.height)];
	UIImage *rounded = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return rounded ?: source;
}

static UIImage *TGRoundedAvatarImage(UIImage *source) {
	return TGRoundedAvatarImageOfSide(source, kAvatar, 0.0f);
}

static UIImage *TGRoundedMiniAvatarImage(UIImage *source) {
	if (!source)
		return source;
	CGSize size = source.size;
	CGFloat side = MIN(size.width, size.height);
	if (side < 1 || side >= kAvatar)
		return TGRoundedAvatarImage(source);
	return TGRoundedAvatarImageOfSide(source, side, source.scale);
}

- (void)dropAvatarForKey:(NSString *)avatarKey {
	if (!avatarKey.length)
		return;
	[self.avatars removeObjectForKey:avatarKey];
	[self.avatarsRequested removeObject:avatarKey];
	[self.avatarsFailedOnce removeObject:avatarKey];
	if ([self.avatarsInFlight containsObject:avatarKey]) {
		[self.avatarsInFlight removeObject:avatarKey];
		NSNumber *fileId = [self avatarFileIdForKey:avatarKey];
		if ([fileId isKindOfClass:[NSNumber class]])
			[[TGClient shared] cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:NO];
	}
}

- (void)evictAvatarsOutsideRows:(NSInteger)margin {
	if ((!self.avatars.count && !self.avatarMinis.count) || self.searchResults)
		return;
	if (![self.tableView indexPathsForVisibleRows].count)
		return;
	NSSet *keep = [self avatarKeysWithinRows:margin];
	for (NSString *avatarKey in [self.avatars.allKeys copy]) {
		if ([keep containsObject:avatarKey])
			continue;
		[self dropAvatarForKey:avatarKey];
	}

	NSSet *keepMinis = [self minithumbnailKeysWithinRows:margin];
	for (NSString *encoded in [self.avatarMinis.allKeys copy]) {
		if ([keepMinis containsObject:encoded])
			continue;
		[self.avatarMinis removeObjectForKey:encoded];
	}
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[self pruneRowDetails];
	[self evictAvatarsOutsideRows:0];
}

- (NSSet *)avatarKeysWithinRows:(NSInteger)margin {
	NSMutableSet *wanted = [NSMutableSet set];
	NSArray *rows = [self visibleChats];
	NSInteger headerCount = (NSInteger)[self headerRows].count;

	NSInteger first = NSIntegerMax;
	NSInteger last = -1;
	for (NSIndexPath *path in ([self.tableView indexPathsForVisibleRows] ?: @[])) {
		first = MIN(first, path.row);
		last = MAX(last, path.row);
	}
	if (last < 0) {
		first = headerCount;
		last = headerCount + margin;
	} else {
		first -= margin;
		last += margin;
	}

	for (NSInteger row = first; row <= last; row++) {
		NSInteger index = row - headerCount;
		if (index < 0 || index >= (NSInteger)rows.count)
			continue;
		NSString *avatarKey = TGAvatarKeyForChat(rows[index]);
		if (avatarKey.length)
			[wanted addObject:avatarKey];
	}
	for (NSDictionary *poster in (self.storyPosters ?: @[])) {
		NSString *avatarKey = TGAvatarKeyForChat(poster);
		if (avatarKey.length)
			[wanted addObject:avatarKey];
	}
	return wanted;
}

- (NSSet *)minithumbnailKeysWithinRows:(NSInteger)margin {
	NSMutableSet *wanted = [NSMutableSet set];
	NSArray *rows = [self visibleChats];
	NSInteger headerCount = (NSInteger)[self headerRows].count;

	NSInteger first = NSIntegerMax;
	NSInteger last = -1;
	for (NSIndexPath *path in ([self.tableView indexPathsForVisibleRows] ?: @[])) {
		first = MIN(first, path.row);
		last = MAX(last, path.row);
	}
	if (last < 0) {
		first = headerCount;
		last = headerCount + margin;
	} else {
		first -= margin;
		last += margin;
	}

	for (NSInteger row = first; row <= last; row++) {
		NSInteger index = row - headerCount;
		if (index < 0 || index >= (NSInteger)rows.count)
			continue;
		NSString *encoded = rows[index][@"photoMini"];
		if ([encoded isKindOfClass:[NSString class]] && encoded.length)
			[wanted addObject:encoded];
	}
	for (NSDictionary *poster in (self.storyPosters ?: @[])) {
		NSString *encoded = poster[@"photoMini"];
		if ([encoded isKindOfClass:[NSString class]] && encoded.length)
			[wanted addObject:encoded];
	}
	return wanted;
}

- (NSSet *)avatarKeysWanted {
	return [self avatarKeysWithinRows:kAvatarPrefetchRows];
}

- (BOOL)storyPostersUseAvatarKey:(NSString *)avatarKey {
	for (NSDictionary *poster in (self.storyPosters ?: @[]))
		if ([avatarKey isEqualToString:(TGAvatarKeyForChat(poster) ?: @"")])
			return YES;
	return NO;
}

- (NSDictionary *)chatShownByCell:(TGChatCell *)cell {
	long long chatId = cell.chatId;
	if (!chatId)
		return nil;
	for (NSDictionary *c in [self visibleChats]) {
		if ([c[@"id"] longLongValue] == chatId)
			return c;
	}
	return nil;
}

- (TGChatCell *)cellShowingChatId:(long long)chatId {
	if (!chatId)
		return nil;
	for (UITableViewCell *raw in ([self.tableView visibleCells] ?: @[])) {
		if (![raw isKindOfClass:[TGChatCell class]])
			continue;
		if (((TGChatCell *)raw).chatId == chatId)
			return (TGChatCell *)raw;
	}
	return nil;
}

- (void)applyArrivedAvatar:(UIImage *)image forKey:(NSString *)avatarKey {
	NSMutableSet *owners = [NSMutableSet set];
	for (NSDictionary *c in [self visibleChats]) {
		if ([avatarKey isEqualToString:(TGAvatarKeyForChat(c) ?: @"")] &&
			![c[@"isSaved"] boolValue])
			[owners addObject:@([c[@"id"] longLongValue])];
	}
	if (!owners.count) {
		if ([self storyPostersUseAvatarKey:avatarKey])
			[self rebuildTableHeader];
		return;
	}

	for (UITableViewCell *raw in ([self.tableView visibleCells] ?: @[])) {
		if (![raw isKindOfClass:[TGChatCell class]])
			continue;
		TGChatCell *cell = (TGChatCell *)raw;
		if (!cell.chatId || ![owners containsObject:@(cell.chatId)])
			continue;
		if (cell.avatar.image == image)
			continue;
		UIImageView *target = cell.avatar;
		[UIView transitionWithView:target
						  duration:0.2
						   options:UIViewAnimationOptionTransitionCrossDissolve
						animations:^{ target.image = image; }
						completion:nil];
	}
	if ([self storyPostersUseAvatarKey:avatarKey])
		[self rebuildTableHeader];
}

- (void)reportFirstRows {
	static NSUInteger lastCount = 0;
	static NSTimeInterval firstSeen = 0;
	if (self.showsArchive)
		return;
	NSInteger count = [TGClient shared].chats.count;
	if (!count || count == lastCount)
		return;
	if (firstSeen <= 0)
		firstSeen = [NSDate timeIntervalSinceReferenceDate];
	if ([NSDate timeIntervalSinceReferenceDate] - firstSeen > 20.0)
		return;
	lastCount = count;
	TGMarkLaunchStage([NSString stringWithFormat:@"chat list has %lu rows",
		(unsigned long)count]);
}

static NSString *TGAvatarDiskKey(NSString *avatarKey) {
	if (!avatarKey.length || [avatarKey hasPrefix:@"session"])
		return nil;
	return [NSString stringWithFormat:@"chatavatar_%@_%d", avatarKey, (int)kAvatar];
}

const NSTimeInterval kChatListDeferredActionDelay = 1.0;

NSString *TGAvatarKeyForChat(NSDictionary *chat) {
	NSString *stable = chat[@"photoKey"];
	if ([stable isKindOfClass:[NSString class]] && stable.length)
		return stable;
	NSNumber *fileId = chat[@"photoFileId"];
	if ([fileId isKindOfClass:[NSNumber class]])
		return [NSString stringWithFormat:@"session%@", fileId];
	return nil;
}

static CGFloat TGAvatarScale(void) {
	CGFloat scale = [UIScreen mainScreen].scale;
	return scale < 1.0f ? 1.0f : scale;
}

- (UIImage *)blurredAvatarPlaceholderForChat:(NSDictionary *)chat {
	NSString *encoded = chat[@"photoMini"];
	if (![encoded isKindOfClass:[NSString class]] || !encoded.length)
		return nil;
	id cached = self.avatarMinis[encoded];
	if (cached)
		return [cached isKindOfClass:[UIImage class]] ? cached : nil;
	[self warmAvatarPlaceholders];
	return nil;
}

- (void)warmAvatarPlaceholders {
	NSMutableArray *pending = [NSMutableArray array];
	for (NSDictionary *c in [self visibleChats]) {
		NSString *encoded = c[@"photoMini"];
		if (![encoded isKindOfClass:[NSString class]] || !encoded.length)
			continue;
		if (self.avatarMinis[encoded])
			continue;
		self.avatarMinis[encoded] = [NSNull null];
		[pending addObject:encoded];
	}
	if (!pending.count)
		return;

	__weak typeof(self) weakSelf = self;
	dispatch_async(TGImageDecodeQueue(), ^{
		NSMutableDictionary *decoded = [NSMutableDictionary dictionary];
		@autoreleasepool {
			for (NSString *encoded in pending) {
				NSData *bytes = [[TGClient shared] minithumbnailData:@{@"data" : encoded}];
				UIImage *image = bytes.length
					? TGRoundedMiniAvatarImage([UIImage imageWithData:bytes])
					: nil;
				if (image)
					decoded[encoded] = image;
			}
		}
		if (!decoded.count)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatListViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf.avatarMinis addEntriesFromDictionary:decoded];
			[strongSelf.tableView reloadData];
		});
	});
}

- (NSNumber *)avatarFileIdForKey:(NSString *)avatarKey {
	for (NSDictionary *c in [self visibleChats]) {
		if ([avatarKey isEqualToString:(TGAvatarKeyForChat(c) ?: @"")])
			return c[@"photoFileId"];
	}
	for (NSDictionary *poster in (self.storyPosters ?: @[])) {
		if ([avatarKey isEqualToString:(TGAvatarKeyForChat(poster) ?: @"")])
			return poster[@"photoFileId"];
	}
	return nil;
}

- (void)startAvatarLoadForKey:(NSString *)avatarKey {
	[self.avatarsRequested addObject:avatarKey];
	[self.avatarsInFlight addObject:avatarKey];

	NSString *key = TGAvatarDiskKey(avatarKey);
	__weak typeof(self) weakSelf = self;
	dispatch_async(TGImageDecodeQueue(), ^{
		UIImage *cached = TGRoundedAvatarImage(
			[TGDiskCache imageForKey:key scale:TGAvatarScale()]);
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatListViewController *strongSelf = weakSelf;
			if (!strongSelf || ![strongSelf.avatarsRequested containsObject:avatarKey])
				return;
			if (!cached) {
				[strongSelf downloadAvatarForKey:avatarKey];
				return;
			}
			[strongSelf.avatarsInFlight removeObject:avatarKey];
			[strongSelf.avatarsFailedOnce removeObject:avatarKey];
			strongSelf.avatars[avatarKey] = cached;
			[strongSelf applyArrivedAvatar:cached forKey:avatarKey];
		});
	});
}

- (void)loadCachedAvatarsForFirstFrame {
	if (self.warmedFirstFrameAvatars)
		return;
	self.warmedFirstFrameAvatars = YES;
	NSArray *rows = [self visibleChats];
	NSInteger limit = MIN(rows.count, (NSUInteger)(kAvatarPrefetchRows + 4));
	NSInteger found = 0;
	for (NSInteger i = 0; i < limit; i++) {
		NSString *avatarKey = TGAvatarKeyForChat(rows[i]);
		if (!avatarKey.length || self.avatars[avatarKey])
			continue;
		UIImage *cached = [TGDiskCache imageForKey:TGAvatarDiskKey(avatarKey)
											 scale:TGAvatarScale()];
		if (!cached)
			continue;
		self.avatars[avatarKey] = TGRoundedAvatarImage(cached);
		[self.avatarsRequested addObject:avatarKey];
		found++;
	}
	TGMarkLaunchStage([NSString stringWithFormat:@"%lu avatars off disk", (unsigned long)found]);
}

- (void)downloadAvatarForKey:(NSString *)avatarKey {
	NSNumber *fileId = [self avatarFileIdForKey:avatarKey];
	if (![fileId isKindOfClass:[NSNumber class]]) {
		[self.avatarsInFlight removeObject:avatarKey];
		[self.avatarsRequested removeObject:avatarKey];
		return;
	}

	NSString *key = TGAvatarDiskKey(avatarKey);
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:[fileId longLongValue] completion:^(NSString *reply) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.avatarsInFlight removeObject:avatarKey];

		NSString *path = TGReplyString(reply);
		if (!path.length) {
			[strongSelf avatarFailed:avatarKey];
			return;
		}

		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *img = nil;
			@autoreleasepool {
				img = TGDecodeSquareThumbnail(path, kAvatar);
			}
			if (img && key.length)
				[TGDiskCache storeImage:img forKey:key];
			img = TGRoundedAvatarImage(img);
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatListViewController *innerSelf = weakSelf;
				if (!innerSelf)
					return;
				if (!img) {
					[innerSelf avatarFailed:avatarKey];
					return;
				}
				[innerSelf.avatarsFailedOnce removeObject:avatarKey];
				innerSelf.avatars[avatarKey] = img;
				[innerSelf applyArrivedAvatar:img forKey:avatarKey];
			});
		});
	}];
}

- (void)avatarFailed:(NSString *)avatarKey {
	if (![self.avatarsRequested containsObject:avatarKey])
		return;
	if ([self.avatarsFailedOnce containsObject:avatarKey])
		return;
	[self.avatarsFailedOnce addObject:avatarKey];
	[self.avatarsRequested removeObject:avatarKey];
}

- (void)fetchMissingAvatars {
	self.lastAvatarSweep = [NSDate timeIntervalSinceReferenceDate];
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

	for (NSString *avatarKey in wanted) {
		if (self.avatars[avatarKey] || [self.avatarsRequested containsObject:avatarKey])
			continue;
		[self startAvatarLoadForKey:avatarKey];
	}

	[self evictAvatarsOutsideRows:kAvatarRetainRows];
}

- (void)fetchMissingAvatarsThrottled {
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - self.lastAvatarSweep < 0.15)
		return;
	[self fetchMissingAvatars];
}

- (void)describeCell:(TGChatCell *)cell unread:(NSInteger)unread muted:(BOOL)muted {
	NSMutableArray *parts = [NSMutableArray array];
	if (cell.titleLabel.text.length)
		[parts addObject:cell.titleLabel.text];
	if (!cell.draftLabel.hidden)
		[parts addObject:TGL(@"DialogList.Draft", @"Draft:")];
	if (cell.previewLabel.text.length)
		[parts addObject:cell.previewLabel.text];
	if (cell.dateLabel.text.length)
		[parts addObject:cell.dateLabel.text];
	if (unread > 0)
		[parts addObject:TGLPlural(@"VoiceOver.Chat.UnreadMessages", unread, @"%ld unread message", @"%ld unread messages")];
	if (muted)
		[parts addObject:TGL(@"Notifications.ExceptionsMuted", @"Muted")];

	cell.isAccessibilityElement = YES;
	cell.accessibilityLabel = [parts componentsJoinedByString:@", "];
	cell.accessibilityTraits = UIAccessibilityTraitButton;
}

UIColor *TGSecretChatColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0x22 / 255.0f green:0x9a / 255.0f
								  blue:0x0a / 255.0f
								 alpha:1.0f];
	return colour;
}

- (NSString *)secretHandshakeTextForChat:(NSDictionary *)chat {
	if (self.searchResults)
		return nil;
	int64_t chatId = [chat[@"id"] longLongValue];
	if (!chatId || [[TGClient shared] secretChatIdForChat:chatId] == 0)
		return nil;

	NSNumber *key = @(chatId);
	NSString *cached = self.secretStatuses[key];
	if (cached)
		return cached.length ? cached : nil;
	if ([self.secretStatusesRequested containsObject:key])
		return nil;
	[self.secretStatusesRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] secretChatStatusForChat:chatId completion:^(NSString *status) {
		TGChatListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *line = TGReplyString(status) ?: @"";
		strongSelf.secretStatuses[key] = line;
		if (line.length)
			[strongSelf.tableView reloadData];
	}];
	return nil;
}

- (void)secretChatStateNotificationReceived:(NSNotification *)note {
	if (![note.object respondsToSelector:@selector(intValue)])
		return;
	int secretId = [(NSNumber *)note.object intValue];

	NSMutableSet *keys = [NSMutableSet setWithSet:self.secretStatusesRequested];
	[keys addObjectsFromArray:self.secretStatuses.allKeys];

	NSNumber *affectedKey = nil;
	for (NSNumber *key in keys) {
		if ([[TGClient shared] secretChatIdForChat:key.longLongValue] == secretId) {
			affectedKey = key;
			break;
		}
	}
	if (!affectedKey)
		return;

	[self.secretStatusesRequested removeObject:affectedKey];
	[self.secretStatuses removeObjectForKey:affectedKey];
	[self.tableView reloadData];
}

static BOOL TGChatDateUses12Hour(void) {
	static BOOL twelve = NO;
	static BOOL asked = NO;
	if (!asked) {
		asked = YES;
		NSString *shape = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
		twelve = ([shape rangeOfString:@"a"].location != NSNotFound);
	}
	return twelve;
}

NSString *TGChatDateParts(NSTimeInterval unix, NSString **suffix, BOOL *bold) {
	if (suffix)
		*suffix = nil;
	if (bold)
		*bold = NO;
	if (unix <= 0)
		return @"";

	time_t then = (time_t)unix;
	time_t now = (time_t)[[NSDate date] timeIntervalSince1970];
	struct tm thenParts, nowParts;
	localtime_r(&then, &thenParts);
	localtime_r(&now, &nowParts);

	TGChatDateKind kind = TGChatDateKindForAge(thenParts.tm_year == nowParts.tm_year,
		nowParts.tm_yday - thenParts.tm_yday);
	if (kind == TGChatDateKindTime) {
		if (!TGChatDateUses12Hour())
			return [TGDateUtils stringForShortTime:(int)unix];
		if (bold)
			*bold = YES;
		if (suffix)
			*suffix = [@" " stringByAppendingString:
					[TGDateUtils stringForClockMarker:(int)unix]];
		return [TGDateUtils stringForShortTimeWithoutMarker:(int)unix];
	}
	if (kind == TGChatDateKindWeekday)
		return [TGDateUtils shortWeekdayNameForTmWday:thenParts.tm_wday];
	return [TGDateUtils stringForShortDate:(int)unix];
}

@end
