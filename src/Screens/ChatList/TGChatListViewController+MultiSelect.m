#import "TGClient+ChatManagement.h"
#import "TGIcons.h"
#import "TGChatListViewControllerInternal.h"
#import "TGClient+Notifications.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGLocalization.h"

@implementation TGChatListViewController (MultiSelect)

#pragma mark - multi-select

- (void)beginMultiSelectWithChat:(int64_t)chatId {
	if (!self.multiSelecting) {
		self.multiSelecting = YES;
		self.selectedChatIds = [NSMutableSet set];
		self.rightItemBeforeMultiSelect = self.navigationItem.rightBarButtonItem;
		self.leftItemBeforeMultiSelect = self.navigationItem.leftBarButtonItem;
		self.navigationItem.rightBarButtonItem = nil;
		self.navigationItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
									   target:self
									   action:@selector(endMultiSelect)];
		[self buildBatchPanel];
	}
	if (chatId != 0)
		[self.selectedChatIds addObject:@(chatId)];
	[self updateMultiSelectChrome];
	[self.tableView reloadData];
}

- (void)endMultiSelect {
	self.multiSelecting = NO;
	self.selectedChatIds = nil;
	self.navigationItem.rightBarButtonItem = self.rightItemBeforeMultiSelect;
	self.navigationItem.leftBarButtonItem = self.leftItemBeforeMultiSelect;
	self.rightItemBeforeMultiSelect = nil;
	self.leftItemBeforeMultiSelect = nil;
	self.navigationItem.title = nil;
	UIView *panel = self.batchPanel;
	self.batchPanel = nil;
	self.tableView.contentInset = UIEdgeInsetsZero;
	self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
	[UIView animateWithDuration:0.2 delay:0.0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{ panel.alpha = 0.0f; }
		completion:^(BOOL finished) { [panel removeFromSuperview]; }];
	[self.tableView reloadData];
}

- (void)toggleMultiSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *header = [self headerRows];
	if (indexPath.row < (NSInteger)header.count)
		return;
	NSArray *rows = [self visibleChats];
	NSInteger index = indexPath.row - (NSInteger)header.count;
	if (index < 0 || index >= (NSInteger)rows.count)
		return;

	NSDictionary *c = rows[index];
	NSNumber *chatId = [c[@"id"] isKindOfClass:NSNumber.class] ? c[@"id"] : nil;
	if (!chatId || !chatId.longLongValue)
		return;

	if ([self.selectedChatIds containsObject:chatId])
		[self.selectedChatIds removeObject:chatId];
	else
		[self.selectedChatIds addObject:chatId];

	if (!self.selectedChatIds.count) {
		[self endMultiSelect];
		return;
	}
	[self updateMultiSelectChrome];
	[self.tableView reloadRowsAtIndexPaths:@[ indexPath ]
						  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)updateMultiSelectChrome {
	self.navigationItem.title = TGLPlural(@"ChatList.SelectedChats", self.selectedChatIds.count,
		@"%@ Chat Selected", @"%@ Chats Selected");
}

- (void)buildBatchPanel {
	CGRect b = self.view.bounds;
	const CGFloat height = 44;
	UIView *panel = [[UIView alloc] initWithFrame:
			CGRectMake(0, b.size.height - height, b.size.width, height)];
	panel.backgroundColor = [[TGTheme shared] inputBarColour];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UIImage *bar = [UIImage imageNamed:@"ConversationActionBar"];
	if (bar) {
		UIImageView *plate = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, b.size.width, height)];
		plate.image = [bar stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		plate.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[panel addSubview:plate];
	}

	NSArray *titles = @[
		(self.showsArchive ? TGL(@"ChatList.Context.Unarchive", @"Unarchive")
						   : TGL(@"ChatList.Context.Archive", @"Archive")),
		TGL(@"ChatList.Context.Mute", @"Mute"),
		TGL(@"ChatList.Read", @"Read"),
		TGL(@"Common.Delete", @"Delete"),
	];
	CGFloat slice = b.size.width / titles.count;
	for (NSInteger i = 0; i < titles.count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(floorf(slice * i), 0,
			floorf(slice * (i + 1)) - floorf(slice * i), height);
		button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		button.tag = (NSInteger)i;
		[button setTitle:titles[i] forState:UIControlStateNormal];
		BOOL destructive = [titles[i] isEqualToString:TGL(@"Common.Delete", @"Delete")];
		UIColor *ink = destructive
			? [UIColor colorWithRed:0.78f green:0.16f blue:0.13f alpha:1.0f]
			: [[TGTheme shared] accentColour];
		[button setTitleColor:ink forState:UIControlStateNormal];
		[button setTitleColor:[ink colorWithAlphaComponent:0.4f] forState:UIControlStateHighlighted];
		[button setTitleColor:[ink colorWithAlphaComponent:0.3f] forState:UIControlStateDisabled];
		[button addTarget:self action:@selector(batchButtonTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[panel addSubview:button];

		if (i > 0) {
			CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.5f) ? 0.5f : 1.0f;
			UIView *rule = [[UIView alloc] initWithFrame:
					CGRectMake(floorf(slice * i), 7, retinaPixel, height - 14)];
			rule.backgroundColor = [[TGTheme shared] separatorColour];
			[panel addSubview:rule];
		}
	}

	panel.alpha = 0.0f;
	[self.view addSubview:panel];
	self.batchPanel = panel;
	self.tableView.contentInset = UIEdgeInsetsMake(0, 0, height, 0);
	self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
	[UIView animateWithDuration:0.2 delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{ panel.alpha = 1.0f; }
					 completion:nil];
}

- (void)batchButtonTapped:(UIButton *)button {
	NSArray *ids = [self.selectedChatIds allObjects];
	if (!ids.count)
		return;
	switch (button.tag) {
		case 0:
			[self archiveSelectedChats:ids];
			break;
		case 1:
			[self showBatchMuteDurations];
			break;
		case 2:
			[self markSelectedChatsRead:ids];
			break;
		case 3:
			[self confirmDeleteSelectedChats:ids];
			break;
		default:
			break;
	}
}

- (void)archiveSelectedChats:(NSArray *)ids {
	BOOL archiving = !self.showsArchive;
	for (NSNumber *chatId in ids)
		[self setChat:[chatId longLongValue] archived:archiving];
	[self endMultiSelect];
}

- (void)markSelectedChatsRead:(NSArray *)ids {
	for (NSNumber *chatId in ids)
		[self setChat:[chatId longLongValue] read:YES];
	[self endMultiSelect];
}

- (void)showBatchMuteDurations {
	NSArray *items = @[
		@{@"title" : TGL(@"Notification.Mute1h", @"Mute for 1 hour"), @"icon" : @"mute"},
		@{@"title" : TGLPlural(@"MuteFor.Hours", 8, @"Mute for %@ hour", @"Mute for %@ hours"), @"icon" : @"mute"},
		@{@"title" : TGL(@"MuteFor.Days_2", @"Mute for 2 days"), @"icon" : @"mute"},
		@{@"title" : TGLPlural(@"MuteFor.Days", 7, @"Mute for %@ day", @"Mute for %@ days"), @"icon" : @"mute"},
		@{@"title" : TGL(@"MuteFor.Forever", @"Mute forever"), @"icon" : @"mute"},
	];
	NSArray *seconds = @[ @(3600), @(8 * 3600), @(2 * 24 * 3600), @(7 * 24 * 3600),
		@(kNotificationMuteForever) ];

	NSArray *ids = [self.selectedChatIds allObjects];
	CGPoint where = CGPointMake(CGRectGetMidX(self.view.bounds),
		CGRectGetMinY(self.batchPanel.frame));
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.view
				  onChoice:^(NSInteger choice, NSString *title) {
					  TGChatListViewController *strongSelf = weakSelf;
					  if (!strongSelf || choice < 0 || choice >= (NSInteger)seconds.count)
						  return;
					  NSInteger value = [seconds[choice] integerValue];
					  [strongSelf endMultiSelect];
					  __block NSInteger remaining = (NSInteger)ids.count;
					  __block BOOL anyFailed = NO;
					  for (NSNumber *chatId in ids) {
						  [[TGClient shared] setChat:[chatId longLongValue]
									  muteForSeconds:value
										  completion:^(BOOL ok) {
							  TGChatListViewController *innerSelf = weakSelf;
							  if (ok && innerSelf)
								  innerSelf.muteRemaining[chatId] = @(value);
							  else
								  anyFailed = YES;
							  remaining--;
							  if (remaining > 0 || !innerSelf)
								  return;
							  [innerSelf reload];
							  if (anyFailed) {
								  [TGSnackbar showInView:innerSelf.navigationController.view
													 text:TGL(@"Toast.CouldNotMuteAllChats", @"Could not mute all of these chats")
												  seconds:2
												 onCommit:nil];
							  }
						  }];
					  }
				  }];
}

- (void)confirmDeleteSelectedChats:(NSArray *)ids {
	NSString *text = TGLPlural(@"ChatList.DeletedChats", ids.count,
		@"Deleted %@ chat", @"Deleted %@ chats");
	[self endMultiSelect];
	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.navigationController.view text:text seconds:5 kind:TGSnackbarKindDestructiveUndo onCommit:^{
		__block NSInteger remaining = (NSInteger)ids.count;
		__block BOOL anyFailed = NO;
		for (NSNumber *chatId in ids) {
			[[TGClient shared] deleteChat:[chatId longLongValue] revoke:NO completion:^(BOOL ok) {
				TGChatListViewController *strongSelf = weakSelf;
				if (!ok)
					anyFailed = YES;
				remaining--;
				if (remaining > 0 || !strongSelf)
					return;
				[strongSelf reload];
				if (anyFailed) {
					[TGSnackbar showInView:strongSelf.navigationController.view
									   text:TGL(@"Toast.CouldNotLeaveChats", @"Could not leave all of these chats")
									seconds:2
								   onCommit:nil];
				}
			}];
		}
	}];
}

@end
