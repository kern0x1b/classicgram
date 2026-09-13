#import "TGClient+ChatManagement.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGClient+Contacts.h"
#import "TGClient+Privacy.h"
#import "TGClient+SecretChats.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGGroupMembersViewController.h"
#import "TGNewContactViewController.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGSettingsService.h"
#import "TGFrozenAccountViewController.h"

static const CGFloat kChatActionBarHeight = 40.0f;

@implementation TGChatViewController (ChatActionBar)

#pragma mark - chat action bar (stranger strip)

- (void)loadChatActionBar {
	if (!self.chatId || self.chatId == [[TGClient shared] savedMessagesChatId])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] actionBarForChat:self.chatId completion:^(NSDictionary *actionBar) {
		[weakSelf setChatActionBarInfo:actionBar];
	}];
}

- (void)chatActionBarChanged:(NSNotification *)note {
	if (![note.object respondsToSelector:@selector(longLongValue)] ||
		[(NSNumber *)note.object longLongValue] != self.chatId)
		return;
	NSDictionary *actionBar = note.userInfo[@"action_bar"];
	[self setChatActionBarInfo:[actionBar isKindOfClass:[NSDictionary class]] ? actionBar : nil];
}

- (void)setChatActionBarInfo:(NSDictionary *)info {
	if ((self.chatActionBar == info) || [self.chatActionBar isEqual:info])
		return;
	self.chatActionBar = info;
	[self rebuildChatActionBar];
}

- (void)rebuildChatActionBar {
	NSString *type = self.chatActionBar[@"kind"];
	if (![type isKindOfClass:[NSString class]] || !type.length) {
		[self setActionBarShown:NO];
		return;
	}

	NSMutableArray *specs = [NSMutableArray array];
	if ([type isEqualToString:@"chatActionBarReportSpam"]) {
		[specs addObject:@{@"title" : TGL(@"Conversation.ReportSpam", @"Report as Spam"), @"destructive" : @YES, @"action" : @"reportSpam"}];
	} else if ([type isEqualToString:@"chatActionBarInviteMembers"]) {
		[specs addObject:@{@"title" : TGL(@"Conversation.AddMembers", @"Add Members"), @"destructive" : @NO, @"action" : @"addMembers"}];
	} else if ([type isEqualToString:@"chatActionBarReportAddBlock"]) {
		[specs addObject:@{@"title" : TGL(@"Conversation.BlockUser", @"Block User"), @"destructive" : @YES, @"action" : @"block"}];
		[specs addObject:@{@"title" : TGL(@"Conversation.AddContact", @"Add Contact"), @"destructive" : @NO, @"action" : @"addContact"}];
	} else if ([type isEqualToString:@"chatActionBarAddContact"]) {
		[specs addObject:@{@"title" : TGL(@"Conversation.AddContact", @"Add Contact"), @"destructive" : @NO, @"action" : @"addContact"}];
	} else if ([type isEqualToString:@"chatActionBarSharePhoneNumber"]) {
		[specs addObject:@{@"title" : TGL(@"Conversation.ShareMyPhoneNumber", @"Share My Phone Number"), @"destructive" : @NO, @"action" : @"sharePhone"}];
	} else if ([type isEqualToString:@"chatActionBarJoinRequest"]) {
		NSString *pendingTitle = self.chatActionBar[@"title"];
		if (![pendingTitle isKindOfClass:[NSString class]] || !pendingTitle.length)
			pendingTitle = self.chatTitle ?: @"";
		NSString *pendingText = [NSString stringWithFormat:TGL(@"Chat.JoinRequestPendingFormat", @"Your request to join %@ is pending"), pendingTitle];
		[specs addObject:@{@"title" : pendingText, @"destructive" : @NO, @"action" : @""}];
	} else {
		[self setActionBarShown:NO];
		return;
	}

	[self buildActionBarViewWithSpecs:specs];
	[self setActionBarShown:YES];
}

- (void)buildActionBarViewWithSpecs:(NSArray *)specs {
	static const NSInteger kActionBarCloseTag = 8999;
	static const NSInteger kActionBarButtonBase = 9100;
	static const CGFloat kActionBarCloseWidth = 36.0f;

	if (!self.actionBarView) {
		CGRect b = self.view.bounds;
		self.actionBarView = [[UIView alloc] initWithFrame:
				CGRectMake(0, CGRectGetMinY(self.inputBar.frame) - kChatActionBarHeight,
					b.size.width, kChatActionBarHeight)];
		self.actionBarView.backgroundColor = [[TGTheme shared] inputBarColour];
		self.actionBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleTopMargin;
		self.actionBarView.clipsToBounds = YES;

		UIView *hair = [[UIView alloc] initWithFrame:
				CGRectMake(0, 0, b.size.width, kRetinaPixel)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		hair.userInteractionEnabled = NO;
		[self.actionBarView addSubview:hair];

		UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
		close.tag = kActionBarCloseTag;
		close.titleLabel.font = [UIFont systemFontOfSize:20];
		[close setTitle:@"×" forState:UIControlStateNormal];
		[close setTitleColor:[[TGTheme shared] secondaryTextColour]
					forState:UIControlStateNormal];
		[close addTarget:self action:@selector(actionBarCloseTapped)
			forControlEvents:UIControlEventTouchUpInside];
		close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.actionBarView addSubview:close];

		[self.view insertSubview:self.actionBarView belowSubview:self.inputBar];
	}

	CGFloat width = self.actionBarView.bounds.size.width;
	for (UIView *sub in [self.actionBarView.subviews copy])
		if (sub.tag >= kActionBarButtonBase)
			[sub removeFromSuperview];

	UIView *close = [self.actionBarView viewWithTag:kActionBarCloseTag];
	close.frame = CGRectMake(width - kActionBarCloseWidth, 0,
		kActionBarCloseWidth, kChatActionBarHeight);

	NSInteger count = (NSInteger)specs.count;
	if (!count) {
		self.actionBarActions = nil;
		return;
	}

	NSMutableArray *actions = [NSMutableArray array];
	CGFloat available = width - kActionBarCloseWidth;
	CGFloat buttonWidth = floorf(available / count);
	UIColor *destructiveColour = [UIColor colorWithRed:0.85f green:0.16f blue:0.14f alpha:1.0f];
	for (NSInteger i = 0; i < count; i++) {
		NSDictionary *spec = specs[i];
		[actions addObject:spec[@"action"] ?: @""];

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = kActionBarButtonBase + i;
		button.frame = CGRectMake(i * buttonWidth, 0, buttonWidth, kChatActionBarHeight);
		button.titleLabel.font = [UIFont systemFontOfSize:15];
		BOOL destructive = [spec[@"destructive"] boolValue];
		UIColor *colour = destructive ? destructiveColour : [[TGTheme shared] accentColour];
		[button setTitleColor:colour forState:UIControlStateNormal];
		[button setTitleColor:[colour colorWithAlphaComponent:0.4f]
					 forState:UIControlStateHighlighted];
		[button setTitle:spec[@"title"] forState:UIControlStateNormal];
		[button addTarget:self action:@selector(actionBarButtonTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[self.actionBarView addSubview:button];

		if (i > 0) {
			UIView *divider = [[UIView alloc] initWithFrame:
					CGRectMake(i * buttonWidth, 9, kRetinaPixel, kChatActionBarHeight - 18)];
			divider.tag = kActionBarButtonBase + 50 + i;
			divider.backgroundColor = [[TGTheme shared] separatorColour];
			divider.userInteractionEnabled = NO;
			[self.actionBarView addSubview:divider];
		}
	}
	self.actionBarActions = actions;
}

- (void)setActionBarShown:(BOOL)shown {
	if (!self.actionBarView && !shown)
		return;

	BOOL onScreen = self.actionBarView && !self.actionBarView.hidden &&
		self.actionBarView.alpha > 0.01f;
	if (onScreen == shown)
		return;

	UIEdgeInsets insets = self.table.contentInset;
	insets.bottom += shown ? kChatActionBarHeight : -self.actionBarInset;
	self.actionBarInset = shown ? kChatActionBarHeight : 0.0f;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;

	if (shown) {
		self.actionBarView.frame = CGRectMake(0,
			CGRectGetMinY(self.inputBar.frame) - kChatActionBarHeight,
			self.view.bounds.size.width, kChatActionBarHeight);
		self.actionBarView.alpha = 0.0f;
		self.actionBarView.hidden = NO;
	}
	[self layoutFloatingButtons];
	if (self.composeBannerInset > 0.0f)
		[self repositionComposeBanner];

	[UIView animateWithDuration:0.2 delay:0.0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{ self.actionBarView.alpha = shown ? 1.0f : 0.0f; }
		completion:^(BOOL finished) {
			if (finished && self.actionBarView.alpha < 0.01f)
				self.actionBarView.hidden = YES;
		}];
}

- (void)repositionComposeBanner {
	if (!self.composeBanner || self.composeBanner.hidden)
		return;
	self.composeBanner.frame = CGRectMake(0,
		CGRectGetMinY(self.inputBar.frame) - self.actionBarInset - kComposeBannerHeight,
		self.view.bounds.size.width, kComposeBannerHeight);
}

- (void)actionBarButtonTapped:(UIButton *)sender {
	NSInteger index = sender.tag - 9100;
	if (index < 0 || index >= (NSInteger)self.actionBarActions.count)
		return;
	NSString *action = self.actionBarActions[index];
	if ([action isEqualToString:@"reportSpam"]) {
		[self actionBarReportSpam];
	} else if ([action isEqualToString:@"addMembers"]) {
		[self actionBarAddMembers];
	} else if ([action isEqualToString:@"block"]) {
		[self actionBarBlockUser];
	} else if ([action isEqualToString:@"addContact"]) {
		[self actionBarAddContact];
	} else if ([action isEqualToString:@"sharePhone"]) {
		[self actionBarSharePhoneNumber];
	}
}

- (void)actionBarCloseTapped {
	int64_t chatId = self.chatId;
	NSDictionary *dismissed = self.chatActionBar;
	[self setChatActionBarInfo:nil];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeActionBarForChat:chatId completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		[strongSelf setChatActionBarInfo:dismissed];
		[TGSnackbar showInView:strongSelf.view
						  text:TGL(@"Toast.CouldNotOpenLink", @"Could not open this link")
					   seconds:2
					  onCommit:nil];
	}];
}

- (void)actionBarReportSpam {
	NSString *reportMessage = self.group
		? TGL(@"Conversation.ReportSpamGroupConfirmation",
				@"Are you sure you want to report spam from this group?")
		: TGL(@"Conversation.ReportSpamConfirmation", @"Are you sure you want to report spam from this user?");
	UIAlertView *confirmAlloc = [UIAlertView alloc];
	UIAlertView *confirm = [confirmAlloc initWithTitle:TGL(@"Conversation.ReportSpam", @"Report as Spam")
											   message:reportMessage
											  delegate:self
									 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
									 otherButtonTitles:TGL(@"ReportPeer.Report", @"Report"), nil];
	confirm.tag = kActionBarReportAlertTag;
	[confirm show];
}

- (void)performActionBarReportSpam {
	[self setChatActionBarInfo:nil];
	[self reportMessages:@[] optionId:nil text:@""];
}

- (void)actionBarAddMembers {
	if (self.navigationController) {
		TGGroupMembersViewController *members =
			[[TGGroupMembersViewController alloc] init];
		members.chatId = self.chatId;
		members.initialMode = 0;
		__weak typeof(self) weakSelf = self;
		members.onChatUpgraded = ^(int64_t newChatId) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (strongSelf.selecting)
				[strongSelf endSelection];
			[strongSelf reloadForChatIdentityChangedTo:newChatId];
		};
		[self.navigationController pushViewController:members animated:YES];
	}
}

- (void)actionBarBlockUser {
	UIActionSheet *sheetAlloc = [UIActionSheet alloc];
	UIActionSheet *sheet = [sheetAlloc initWithTitle:
			[NSString stringWithFormat:TGL(@"UserInfo.BlockConfirmation", @"Block %@?"), self.chatTitle ?: TGL(@"GroupMembers.FallbackName", @"this user")]
											delegate:self
								   cancelButtonTitle:nil
							  destructiveButtonTitle:nil
								   otherButtonTitles:TGL(@"Conversation.Moderate.Report", @"Report Spam"), TGL(@"BlockedUsers.BlockTitle", @"Block"), nil];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kActionBarBlockSheetTag;
	[sheet tg_showFromRect:self.actionBarView.bounds inView:self.actionBarView];
}

- (int64_t)resolvedActionBarUserId {
	return [[TGClient shared] isSecretChat:self.chatId]
		? [[TGClient shared] secretChatUserIdForChat:self.chatId]
		: self.chatId;
}

- (void)runActionBarBlockOption:(NSString *)title {
	if (![title length])
		return;
	BOOL block = [title isEqualToString:TGL(@"BlockedUsers.BlockTitle", @"Block")];
	BOOL report = [title isEqualToString:TGL(@"Conversation.Moderate.Report", @"Report Spam")];
	int64_t userId = [self resolvedActionBarUserId];
	__weak typeof(self) weakSelf = self;
	[self setChatActionBarInfo:nil];
	if (block && userId) {
		[[TGClient shared] setUser:userId blocked:YES completion:^(BOOL ok) {
			if (ok)
				return;
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotBlockUser", @"Could not block this user")
							seconds:3
						   onCommit:nil];
		}];
	}
	[self recomputeComposerState];
	if (report)
		[self reportMessages:@[] optionId:nil text:@""];
}

- (void)actionBarAddContact {
	int64_t userId = [self resolvedActionBarUserId];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] userInfo:userId completion:^(NSDictionary *user) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *firstName = [user[@"first_name"] isKindOfClass:[NSString class]] ? user[@"first_name"] : @"";
		NSString *lastName = [user[@"last_name"] isKindOfClass:[NSString class]] ? user[@"last_name"] : @"";
		TGNewContactViewController *form = [[TGNewContactViewController alloc] init];
		form.peerUserId = userId;
		form.prefillFirstName = firstName.length ? firstName : (strongSelf.chatTitle ?: @"");
		form.prefillLastName = lastName;
		form.offersShareException = YES;
		__weak typeof(strongSelf) weakInnerSelf = strongSelf;
		form.onDone = ^(BOOL saved, int64_t resolvedUserId) {
			(void)resolvedUserId;
			TGChatViewController *innerSelf = weakInnerSelf;
			if (!innerSelf)
				return;
			if (saved) {
				[innerSelf setChatActionBarInfo:nil];
				return;
			}
			[TGSnackbar showInView:innerSelf.view
							   text:TGL(@"Toast.CouldNotSaveContact", @"Could not save the contact")
							seconds:2
						   onCommit:nil];
		};
		[strongSelf.navigationController pushViewController:form animated:YES];
	}];
}

- (void)actionBarSharePhoneNumber {
	NSString *shareMessage = [NSString stringWithFormat:
			TGL(@"Conversation.ShareMyPhoneNumberConfirmation", @"Are you sure you want to share your phone number with %@?"),
		self.chatTitle ?: @"this user"];
	UIAlertView *confirmAlloc = [UIAlertView alloc];
	UIAlertView *confirm = [confirmAlloc initWithTitle:TGL(@"Conversation.ShareMyPhoneNumber", @"Share My Phone Number")
											   message:shareMessage
											  delegate:self
									 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
									 otherButtonTitles:TGL(@"Share.Title", @"Share"), nil];
	confirm.tag = kActionBarSharePhoneAlertTag;
	[confirm show];
}

- (void)performActionBarSharePhoneNumber {
	int64_t userId = [self resolvedActionBarUserId];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sharePhoneNumberWithUser:userId completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
							seconds:3
						   onCommit:nil];
			return;
		}
		[strongSelf setChatActionBarInfo:nil];
	}];
}

#pragma mark - channel action bar (posting blocked)

- (BOOL)postingBlocked {
	return self.composerState != nil && !self.composerState.canPost;
}

- (BOOL)blockSendForSlowMode {
	if (!self.composerState.slowModeBlocked)
		return NO;
	NSInteger seconds = MAX(self.composerState.slowModeSecondsRemaining, (NSInteger)1);
	[TGSnackbar showInView:self.view
					   text:[NSString stringWithFormat:
									TGL(@"Toast.SlowModeWaitFormat", @"Slow mode is active. Try again in %@"),
								TGLPlural(@"MessageTimer.Seconds", seconds, @"%ld second", @"%ld seconds")]
					seconds:3
				   onCommit:nil];
	return YES;
}

- (void)recomputeComposerState {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] canSendInChat:self.chatId
							   topic:self.threadId
						  completion:^(BOOL canSend, BOOL isChannel, NSDictionary *permissions) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;

		BOOL wasBlocked = strongSelf.postingBlocked;
		BOOL accountFrozen = [TGSettingsService isFrozen];
		strongSelf.composerState = [TGChatComposerState stateWithCanSend:(canSend && !accountFrozen)
																 isChannel:isChannel
															   permissions:permissions];

		strongSelf.sendButton.enabled = !strongSelf.composerState.slowModeBlocked;

		if (strongSelf.composerState.slowModeBlocked && !strongSelf.slowModeRefreshScheduled) {
			strongSelf.slowModeRefreshScheduled = YES;
			NSInteger waitSeconds = strongSelf.composerState.slowModeSecondsRemaining;
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitSeconds * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
					TGChatViewController *delayedSelf = weakSelf;
					if (!delayedSelf)
						return;
					delayedSelf.slowModeRefreshScheduled = NO;
					[delayedSelf recomputeComposerState];
				});
		}

		if (strongSelf.postingBlocked == wasBlocked)
			return;

		if (strongSelf.postingBlocked) {
			strongSelf.inputBar.hidden = YES;
			[strongSelf.input resignFirstResponder];
			[strongSelf buildChannelActionBar];
		} else {
			strongSelf.inputBar.hidden = NO;
			strongSelf.secretChatBlockedStatusText = nil;
			[strongSelf removeChannelActionBar];
		}
	}];
}

- (void)applyPostingRights {
	[self recomputeComposerState];
}

- (void)composerPermissionsChanged:(NSNotification *)note {
	if (note.object && ![note.object isEqual:@(self.chatId)])
		return;
	[self recomputeComposerState];
}

- (void)frozenAccountStateChanged:(NSNotification *)note {
	(void)note;
	[self recomputeComposerState];
}

- (void)chatMemberChanged:(NSNotification *)note {
	if (![note.object isEqual:@(self.chatId)])
		return;
	int64_t affectedUserId = [note.userInfo[TGChatMemberUserIdKey] longLongValue];
	int64_t myId = [[[TGClient shared] me][@"id"] longLongValue];
	if (!affectedUserId || !myId || affectedUserId != myId)
		return;
	[self recomputeComposerState];
}

- (void)secretChatStateNotificationReceived:(NSNotification *)note {
	if (![note.object respondsToSelector:@selector(intValue)] ||
		![[TGClient shared] isSecretChat:self.chatId] ||
		[(NSNumber *)note.object intValue] != [[TGClient shared] secretChatIdForChat:self.chatId])
		return;
	[self recomputeComposerState];
}

- (void)removeChannelActionBar {
	[self.channelActionBarView removeFromSuperview];
	self.channelActionBarView = nil;
	self.channelActionButton = nil;
}

- (void)buildChannelActionBar {
	if (self.channelActionBarView)
		return;
	CGRect b = self.view.bounds;
	UIView *bar = [[UIView alloc] initWithFrame:
			CGRectMake(0, b.size.height - kInputHeight, b.size.width, kInputHeight)];
	bar.backgroundColor = [[TGTheme shared] inputBarColour];
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleTopMargin;
	bar.clipsToBounds = NO;

	UIImage *strip = [UIImage imageNamed:@"ConversationInputPanel_Background"];
	if (strip) {
		UIImageView *stripView = [[UIImageView alloc] initWithFrame:
				CGRectMake(0, 0, b.size.width, kInputHeight)];
		stripView.image = [strip stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		stripView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
		stripView.userInteractionEnabled = NO;
		[bar addSubview:stripView];
	}

	UIImage *shadow = [UIImage imageNamed:@"ChatInputContainer_Shadow"];
	if (shadow) {
		UIImageView *shadowView = [[UIImageView alloc] initWithFrame:
				CGRectMake(0, -shadow.size.height, b.size.width, shadow.size.height)];
		shadowView.image = [shadow stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleBottomMargin;
		shadowView.userInteractionEnabled = NO;
		[bar addSubview:shadowView];
	} else {
		UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0, b.size.width, 1)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		hair.userInteractionEnabled = NO;
		[bar addSubview:hair];
	}

	UIButton *action = [UIButton buttonWithType:UIButtonTypeCustom];
	action.frame = CGRectMake(0, 0, b.size.width, kInputHeight);
	action.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleHeight;
	action.backgroundColor = [UIColor clearColor];
	action.titleLabel.font = [UIFont systemFontOfSize:17];
	BOOL frozenAccount = [TGSettingsService isFrozen];
	BOOL topicClosed = self.composerState.topicClosed;
	BOOL secretChatBlocked = [[TGClient shared] isSecretChat:self.chatId];
	BOOL blockedPrivateChat = !self.group && !secretChatBlocked;
	BOOL notMember = !self.composerState.isMember;
	if (!frozenAccount && (topicClosed || secretChatBlocked)) {
		[action setTitleColor:[[TGTheme shared] secondaryTextColour]
					 forState:UIControlStateNormal];
		action.userInteractionEnabled = NO;
	} else {
		UIColor *accent = frozenAccount ? [UIColor redColor] : [[TGTheme shared] accentColour];
		[action setTitleColor:accent forState:UIControlStateNormal];
		[action setTitleColor:[accent colorWithAlphaComponent:0.4f]
					 forState:UIControlStateHighlighted];
		SEL actionSelector = frozenAccount
			? @selector(openFrozenAccountDetails:)
			: (notMember
				? @selector(joinFromChat:)
				: (blockedPrivateChat ? @selector(unblockFromChat:) : @selector(muteFromChat:)));
		[action addTarget:self
					action:actionSelector
			forControlEvents:UIControlEventTouchUpInside];
	}
	[bar addSubview:action];

	self.channelActionButton = action;
	self.channelActionBarView = bar;
	if (frozenAccount) {
		[self.channelActionButton setTitle:TGL(@"Chat.PanelFrozenAccount.Title", @"Your account is frozen — tap to view details")
								  forState:UIControlStateNormal];
	} else if (topicClosed) {
		[self.channelActionButton setTitle:TGL(@"Chat.ThisTopicIsClosed", @"This topic is closed")
								  forState:UIControlStateNormal];
	} else if (secretChatBlocked) {
		NSString *cachedStatus = self.secretChatBlockedStatusText;
		[self.channelActionButton
			setTitle:(cachedStatus.length ? cachedStatus : TGL(@"SecretChat.CannotSendYet", @"You cannot send messages yet"))
			forState:UIControlStateNormal];
		if (!cachedStatus.length)
			[self refreshSecretChatBlockedStatusText];
	} else if (notMember) {
		[self.channelActionButton setTitle:TGL(@"Channel.JoinChannel", @"Join")
								  forState:UIControlStateNormal];
	} else if (blockedPrivateChat) {
		[self.channelActionButton setTitle:TGL(@"Conversation.UnblockUser", @"Unblock User")
								  forState:UIControlStateNormal];
	} else {
		self.channelMuted = [[TGClient shared] isChatMuted:self.chatId];
		[self updateChannelActionTitle];
	}

	[self.view addSubview:bar];
}

- (void)openFrozenAccountDetails:(UIButton *)button {
	(void)button;
	TGFrozenAccountViewController *screen = [[TGFrozenAccountViewController alloc] init];
	UINavigationController *nav = [[UINavigationController alloc]
		initWithRootViewController:screen];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)joinFromChat:(UIButton *)button {
	if (!button.userInteractionEnabled)
		return;
	button.userInteractionEnabled = NO;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setChat:self.chatId joined:YES completion:^(BOOL ok) {
		if (ok)
			return;
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		button.userInteractionEnabled = YES;
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
						seconds:3
					   onCommit:nil];
	}];
	[self recomputeComposerState];
}

- (void)unblockFromChat:(UIButton *)button {
	if (!button.userInteractionEnabled)
		return;
	button.userInteractionEnabled = NO;
	int64_t userId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setUser:userId blocked:NO completion:^(BOOL ok) {
		if (ok)
			return;
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		button.userInteractionEnabled = YES;
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotUnblockUser", @"Could not unblock this user")
						seconds:3
					   onCommit:nil];
	}];
	[self recomputeComposerState];
}

- (void)refreshSecretChatBlockedStatusText {
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] secretChatStatusForChat:chatId completion:^(NSString *status) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.chatId != chatId || !status.length)
			return;
		strongSelf.secretChatBlockedStatusText = status;
		if (strongSelf.postingBlocked && [[TGClient shared] isSecretChat:chatId])
			[strongSelf.channelActionButton setTitle:status forState:UIControlStateNormal];
	}];
}

- (void)updateChannelActionTitle {
	[self.channelActionButton setTitle:(self.channelMuted ? TGL(@"Conversation.Unmute", @"Unmute") : TGL(@"Call.Mute", @"Mute"))
							  forState:UIControlStateNormal];
}

- (void)chatMuteStateChanged:(NSNotification *)note {
	if (![note.object isEqual:@(self.chatId)])
		return;
	[self layoutTitleView];
	if (!self.channelActionButton || !self.postingBlocked)
		return;

	BOOL frozenAccount = [TGSettingsService isFrozen];
	BOOL topicClosed = self.composerState.topicClosed;
	BOOL secretChatBlocked = [[TGClient shared] isSecretChat:self.chatId];
	BOOL blockedPrivateChat = !self.group && !secretChatBlocked;
	BOOL notMember = !self.composerState.isMember;
	if (frozenAccount || topicClosed || secretChatBlocked || notMember || blockedPrivateChat)
		return;

	self.channelMuted = [[TGClient shared] isChatMuted:self.chatId];
	[self updateChannelActionTitle];
}

@end
