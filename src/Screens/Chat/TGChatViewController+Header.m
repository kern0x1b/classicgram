#import "TGClient+ChatManagement.h"
#import "TGStringTruncation.h"
#import "TGChatViewController.h"
#import "TGChatTitleMute.h"
#import "TGChatTitleCredibility.h"
#import "TGChatTitlePremium.h"
#import "TGContactsService.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGClient+Account.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGPreferenceFlags.h"
#import "TGEmoji.h"
#import "TGClient+Network.h"
#import "TGCustomEmojiCache.h"
#import "TGClient+Notifications.h"
#import "TGClient+Files.h"
#import "TGImageDecode.h"
#import "TGProfileViewController.h"
#import "TGEditProfileViewController.h"
#import "TGClient+SecretChats.h"
#import "TGSnackbar.h"

static int64_t TGChatHeaderStatusUserId(TGChatViewController *chat) {
	return [[TGClient shared] isSecretChat:chat.chatId]
		? [[TGClient shared] secretChatUserIdForChat:chat.chatId]
		: chat.chatId;
}

@implementation TGChatViewController (Header)

- (void)buildTitleView {
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 36)];

	TGEmojiLabel *name = [[TGEmojiLabel alloc] initWithFrame:CGRectMake(0, 1, 200, 20)];
	name.text = self.chatTitle ?: TGL(@"ChatList.UnnamedChat", @"Chat");
	name.font = [UIFont boldSystemFontOfSize:16];
	name.textColor = [[TGTheme shared] barTitleColour];
	name.backgroundColor = [UIColor clearColor];
	name.textAlignment = NSTextAlignmentCenter;
	UIColor *headerShadow = [[TGTheme shared] barTitleShadowColour];
	if (headerShadow) {
		name.shadowColor = headerShadow;
		name.shadowOffset = CGSizeMake(0, -1);
	}
	[header addSubview:name];

	UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 21, 200, 14)];
	subtitle.font = [UIFont boldSystemFontOfSize:12];
	subtitle.textColor = [UIColor colorWithRed:0xe0 / 255.0f green:0xee / 255.0f
										  blue:0xfd / 255.0f
										 alpha:1.0f];
	subtitle.backgroundColor = [UIColor clearColor];
	subtitle.textAlignment = NSTextAlignmentCenter;
	subtitle.adjustsFontSizeToFitWidth = YES;
	subtitle.minimumScaleFactor = 0.7f;
	if (headerShadow) {
		subtitle.shadowColor = headerShadow;
		subtitle.shadowOffset = CGSizeMake(0, -1);
	}
	[header addSubview:subtitle];

	UIImageView *muteIcon = [[UIImageView alloc]
		initWithImage:[UIImage imageNamed:@"ConversationMuted.png"]];
	muteIcon.hidden = YES;
	[header addSubview:muteIcon];
	self.titleMuteIcon = muteIcon;

	UILabel *credibility = [[UILabel alloc] initWithFrame:CGRectZero];
	credibility.font = [UIFont boldSystemFontOfSize:11];
	credibility.backgroundColor = [UIColor clearColor];
	credibility.hidden = YES;
	[header addSubview:credibility];
	self.titleCredibilityLabel = credibility;

	UIImageView *premium = [[UIImageView alloc]
		initWithImage:TGChatTitlePremiumImage()];
	premium.hidden = YES;
	[header addSubview:premium];
	self.titlePremiumIcon = premium;

	header.userInteractionEnabled = YES;
	[header addGestureRecognizer:[[UITapGestureRecognizer alloc]
									 initWithTarget:self
											 action:@selector(openProfile)]];
	self.titleHeader = header;
	self.titleNameLabel = name;
	self.titleStatusLabel = subtitle;
	[self refreshHeaderCredibilityMark];
	[self buildAvatarButton];
	self.navigationItem.titleView = header;
	[self layoutTitleView];

	__weak typeof(self) weakSelf = self;
	self.chatHeaderRestingSubtitle = @"";
	self.chatActionObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatActionDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGChatViewController *strongSelf = weakSelf;
					int64_t chatId = [note.userInfo[TGChatActionChatIdKey] longLongValue];
					int64_t topicId = [note.userInfo[TGChatActionTopicIdKey] longLongValue];
					if (!strongSelf || chatId != strongSelf.chatId || topicId != strongSelf.threadId)
						return;
					NSString *action = note.userInfo[TGChatActionTextKey];
					if (action.length) {
						[strongSelf applyHeaderSubtitleText:action];
						return;
					}
					[strongSelf refreshHeaderRestingSubtitle];
				}];

	__weak typeof(self) weakConnection = self;
	self.connectionStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGConnectionStateDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGChatViewController *me = weakConnection;
					if (!me)
						return;
					id rawText = note.userInfo[TGConnectionStateTitleKey];
					NSString *text = [rawText isKindOfClass:NSString.class] ? rawText : nil;
					me.connectionStatusText = text.length ? text : nil;
					[me refreshHeaderRestingSubtitle];
				}];
	self.connectionStatusText = [[TGClient shared] connectionStateTitle];
	[self refreshHeaderRestingSubtitle];

	__weak typeof(self) weakChat = self;
	self.themeChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGThemeChangedNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[TGIcons flush];
					TGChatViewController *me = weakChat;
					me.view.backgroundColor = [[TGTheme shared] chatBackgroundColour];
					me.table.backgroundColor = [UIColor clearColor];
					me.inputBar.backgroundColor = [[TGTheme shared] inputBarColour];
					me.input.textColor = [[TGTheme shared] primaryTextColour];
					[me loadChatWallpaper];
					[[TGTheme shared] styleNavigationBar:me.navigationController.navigationBar];
					[me.table reloadData];
				}];

	self.customEmojiObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGCustomEmojiImagesDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGChatViewController *me = weakChat;
					if (!me)
						return;
					[NSObject
						cancelPreviousPerformRequestsWithTarget:me
													   selector:@selector(reloadForCustomEmojiArrival)
														 object:nil];
					[me performSelector:@selector(reloadForCustomEmojiArrival) withObject:nil
							 afterDelay:0.05];
				}];

	[self loadPinnedMessage];
	self.outgoingReadStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatReadOutboxDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf outgoingReadStateChanged:note];
				}];
	self.isTranslatableObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatIsTranslatableDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf isTranslatableChanged:note];
				}];
	self.pinnedMessagesObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatPinnedMessagesDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf pinnedMessagesChanged:note];
				}];
	self.chatActionBarObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatActionBarDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf chatActionBarChanged:note];
				}];
	self.composerPermissionsObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatPermissionsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf composerPermissionsChanged:note];
				}];
	self.frozenStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGFreezeStateDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf frozenAccountStateChanged:note];
				}];
	self.userBlockedStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUserBlockedStateDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf composerPermissionsChanged:note];
				}];
	self.chatMemberObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatMemberDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf chatMemberChanged:note];
				}];
	self.chatMuteStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatNotificationSettingsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf chatMuteStateChanged:note];
				}];
	self.secretChatStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGSecretChatStateDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf secretChatStateNotificationReceived:note];
				}];
	self.chatMessageSenderObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatMessageSenderDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf chatMessageSenderChanged:note];
				}];
	self.chatBackgroundObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatBackgroundDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf chatBackgroundChanged:note];
				}];
	self.chatThemeObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatThemeDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf chatThemeChanged:note];
				}];
	self.chatThemeCatalogObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatAppearanceCatalogDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf chatThemeCatalogChanged:note];
				}];
	[self loadChatActionBar];
	__weak typeof(self) weakReadSelf = self;
	[[TGClient shared] refreshOutgoingReadStateForChat:self.chatId
											completion:^(long long lastReadId) {
												TGChatViewController *me = weakReadSelf;
												if (!me || lastReadId == 0)
													return;
												[me.table reloadData];
											}];
	[self applyPostingRights];
	[self loadAvailableSenders];

	if (self.chatId == [[TGClient shared] savedMessagesChatId]) {
		subtitle.hidden = YES;
		return;
	}

	self.videoChatObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatVideoChatDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf videoChatDidChange:note];
				}];

	if (!self.group) {
		[[TGClient shared] statusForUser:TGChatHeaderStatusUserId(self) completion:^(NSString *status) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || !status.length)
				return;
			strongSelf.chatHeaderRestingSubtitle = status;
			if (!subtitle.text.length)
				[strongSelf refreshHeaderRestingSubtitle];
		}];
		__weak typeof(self) weakStatus = self;
		self.userStatusObserverToken = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGUserStatusDidChangeNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
						TGChatViewController *strongSelf = weakStatus;
						if (!strongSelf)
							return;
						if ([note.userInfo[@"userId"] longLongValue] != TGChatHeaderStatusUserId(strongSelf))
							return;
						[strongSelf applyUserStatusInfo:note.userInfo[@"status"]];
					}];
		[self refreshHeaderRestingSubtitle];
		return;
	}

	[[TGClient shared] memberCountForChat:self.chatId completion:^(NSInteger count) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || count <= 0)
			return;
		strongSelf.chatHeaderRestingSubtitle = TGLPlural(@"Conversation.StatusMembers", count,
			@"1 member", @"%@ members");
		[strongSelf refreshHeaderRestingSubtitle];
	}];

	[self refreshHeaderRestingSubtitle];
}

- (void)videoChatDidChange:(NSNotification *)note {
	if ([note.object longLongValue] != self.chatId)
		return;
	[self refreshHeaderRestingSubtitle];
}

- (void)refreshHeaderRestingSubtitle {
	if (self.connectionStatusText.length) {
		[self applyHeaderSubtitleText:self.connectionStatusText];
		return;
	}
	int32_t groupCallId = [[TGClient shared] activeVideoChatGroupCallIdForChat:self.chatId];
	BOOL hasParticipants = [[TGClient shared] videoChatHasParticipantsForChat:self.chatId];
	NSString *next = (groupCallId > 0 && hasParticipants)
		? [NSString stringWithFormat:@"\U0001F534 %@", TGL(@"VoiceChat.Title", @"Video Chat")]
		: (self.chatHeaderRestingSubtitle ?: @"");
	[self applyHeaderSubtitleText:next];
}

- (void)applyUserStatusInfo:(NSDictionary *)info {
	NSString *text = [info isKindOfClass:NSDictionary.class] ? info[@"text"] : nil;
	if (!text.length)
		return;
	self.chatHeaderRestingSubtitle = text;
	[self refreshHeaderRestingSubtitle];

	[self.userStatusExpiryTimer invalidate];
	self.userStatusExpiryTimer = nil;

	BOOL isOnline = [info[@"isOnline"] boolValue];
	double expires = [info[@"expires"] doubleValue];
	if (!isOnline || expires <= 0)
		return;

	NSTimeInterval delay = expires - [[NSDate date] timeIntervalSince1970];
	self.userStatusExpiryTimer = [NSTimer scheduledTimerWithTimeInterval:MAX(delay, 0.1)
																	target:self
																  selector:@selector(userStatusExpiryTimerFired:)
																  userInfo:nil
																   repeats:NO];
}

- (void)userStatusExpiryTimerFired:(NSTimer *)timer {
	(void)timer;
	self.userStatusExpiryTimer = nil;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] statusForUser:TGChatHeaderStatusUserId(self) completion:^(NSString *status) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !status.length)
			return;
		strongSelf.chatHeaderRestingSubtitle = status;
		[strongSelf refreshHeaderRestingSubtitle];
	}];
}

- (void)refreshHeaderCredibilityMark {
	if (!self.chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGContactsService badgesForChat:self.chatId completion:^(NSDictionary *badges) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *mark = TGChatTitleCredibilityMark(badges);
		strongSelf.titleCredibilityLabel.text = mark ?: @"";
		strongSelf.titleCredibilityLabel.hidden = !mark.length;
		strongSelf.titleCredibilityLabel.textColor = TGChatTitleCredibilityMarkIsWarning(badges)
			? [UIColor whiteColor]
			: [UIColor colorWithRed:0xe0 / 255.0f green:0xee / 255.0f blue:0xfd / 255.0f
							  alpha:1.0f];
		strongSelf.titlePremiumIcon.hidden =
			!(strongSelf.titlePremiumIcon.image && TGChatTitleShowsPremium(badges));
		[strongSelf layoutTitleView];
	}];
}

- (void)applyHeaderSubtitleText:(NSString *)text {
	UILabel *subtitle = self.titleStatusLabel;
	NSString *next = text ?: @"";
	if ([next isEqualToString:subtitle.text ?: @""])
		return;
	CATransition *fade = [CATransition animation];
	fade.duration = 0.2;
	fade.type = kCATransitionFade;
	[subtitle.layer addAnimation:fade forKey:@"tgStatusFade"];
	subtitle.text = next;
	[self layoutTitleView];
}

- (void)buildBackButton {
	if (TGChatIsPad())
		return;
	if (!self.navigationController)
		return;

	NSArray *stack = self.navigationController.viewControllers;
	NSInteger index = [stack indexOfObject:self];
	if (index == NSNotFound || index == 0)
		return;

	UIViewController *previous = stack[index - 1];
	NSString *title = previous.title.length ? previous.title : @"Back";

	self.navigationItem.hidesBackButton = YES;
	UIBarButtonItem *item =
		[TGIcons backBarButtonItemWithTitle:title
									 target:self
									 action:@selector(backButtonTapped)];
	self.navigationItem.leftBarButtonItem = item;
	self.backButtonView = (UIButton *)item.customView;
	[self updateBackButtonUnreadBadge];
}

- (void)backButtonTapped {
	[self.navigationController popViewControllerAnimated:YES];
}

- (NSInteger)unreadCountExcludingCurrentChatInList:(NSArray *)chats {
	BOOL countChats = [TGPreferenceFlags badgeCountsUnreadChats];
	BOOL includeMuted = [TGPreferenceFlags badgeIncludesMuted];
	NSInteger total = 0;
	for (id entry in chats) {
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		NSDictionary *c = (NSDictionary *)entry;
		if ([c[@"id"] longLongValue] == self.chatId)
			continue;
		if ([c[@"isMuted"] boolValue] && !includeMuted)
			continue;
		NSInteger unread = [c[@"unread"] integerValue];
		if (countChats) {
			if (unread > 0 || [c[@"markedUnread"] boolValue])
				total += 1;
		} else {
			total += unread;
		}
	}
	return total;
}

- (void)updateBackButtonUnreadBadge {
	if (!self.backButtonView)
		return;

	TGClient *client = [TGClient shared];
	NSInteger total = [self unreadCountExcludingCurrentChatInList:client.chats] +
		[self unreadCountExcludingCurrentChatInList:client.archivedChats];
	if (total < 0)
		total = 0;
	[TGIcons setUnreadCount:total onBackButton:self.backButtonView];
}

- (void)unreadCounterRelevantUpdateReceived:(NSNotification *)note {
	if (self.backButtonUnreadUpdateScheduled)
		return;
	self.backButtonUnreadUpdateScheduled = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		TGChatViewController *strongSelf = weakSelf;
		strongSelf.backButtonUnreadUpdateScheduled = NO;
		[strongSelf updateBackButtonUnreadBadge];
	});
}

- (void)layoutTitleView {
	if (!self.titleHeader)
		return;

	CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
	CGFloat barWidth = self.navigationController.navigationBar.bounds.size.width;
	if (barWidth > 1)
		screenWidth = barWidth;
	UIView *leftView = self.navigationItem.leftBarButtonItem.customView;
	UIView *rightView = self.navigationItem.rightBarButtonItem.customView;
	CGFloat leftWidth = (leftView ? leftView.frame.size.width : 54.0f) + 13.0f;
	CGFloat rightWidth = (rightView ? rightView.frame.size.width : 37.0f) + 13.0f;
	CGFloat maxWidth = screenWidth - 2 * MAX(leftWidth, rightWidth);
	if (maxWidth < 80.0f)
		maxWidth = 80.0f;

	NSString *nameText = self.titleNameLabel.text.length ? self.titleNameLabel.text : @" ";
	NSString *statusText = self.titleStatusLabel.hidden || !self.titleStatusLabel.text.length
		? @""
		: self.titleStatusLabel.text;

	CGFloat nameWidth = TGEmojiTextSize(nameText, self.titleNameLabel.font,
		CGSizeMake(10000, 40), NSLineBreakByWordWrapping, 1)
							.width;
	CGFloat statusWidth = statusText.length
		? [statusText sizeWithFont:self.titleStatusLabel.font].width
		: 0.0f;
	CGFloat width = ceilf(MAX(nameWidth, statusWidth));
	if (width > maxWidth)
		width = maxWidth;
	if (((int)width) % 2 != 0)
		width += 1;

	CGFloat height = statusText.length ? 36.0f : 22.0f;
	const CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;

	NSString *markText = self.titleCredibilityLabel.hidden
		? @""
		: (self.titleCredibilityLabel.text ?: @"");
	CGSize markSize = markText.length
		? [markText sizeWithFont:self.titleCredibilityLabel.font]
		: CGSizeZero;
	markSize.width = ceilf(markSize.width);
	markSize.height = ceilf(markSize.height);
	CGFloat markRoom = TGChatTitleCredibilityRoom(markSize.width);

	BOOL hasPremium = !self.titlePremiumIcon.hidden && self.titlePremiumIcon.image;
	CGSize premiumSize = hasPremium ? self.titlePremiumIcon.image.size : CGSizeZero;
	CGFloat premiumRoom = hasPremium ? TGChatTitlePremiumRoom(premiumSize.width) : 0.0f;

	BOOL muted = self.chatId != 0 && [[TGClient shared] isChatMuted:self.chatId];
	CGSize muteSize = self.titleMuteIcon.image ? self.titleMuteIcon.image.size : CGSizeZero;
	CGFloat muteRoom = muted ? muteSize.width + kTGChatTitleMuteIconGap : 0.0f;
	if (muted || markRoom > 0.0f || premiumRoom > 0.0f)
		width = TGChatTitleWidthWithMuteIcon(width, muteSize.width * (muted ? 1.0f : 0.0f) +
			markRoom + premiumRoom, maxWidth);

	self.titleHeader.frame = CGRectMake(0, 0, width + muteRoom + markRoom + premiumRoom, height);
	CGFloat nameY = statusText.length ? 0 : 1;
	self.titleNameLabel.frame = CGRectMake(0, nameY, width, 21);
	self.titleStatusLabel.frame = CGRectMake(0, height - 15 - 3 + retinaPixel, width, 15);

	if (markText.length)
		self.titleCredibilityLabel.frame = TGChatTitleCredibilityFrame(width, ceilf(nameWidth),
			markSize, nameY);

	if (hasPremium)
		self.titlePremiumIcon.frame = TGChatTitlePremiumFrame(width,
			ceilf(nameWidth) + markRoom, premiumSize, nameY);

	self.titleMuteIcon.hidden = !muted;
	if (muted)
		self.titleMuteIcon.frame = TGChatTitleMuteIconFrame(width,
			ceilf(nameWidth) + markRoom + premiumRoom, muteSize, nameY);

	[self.titleHeader.superview setNeedsLayout];
	[self.navigationController.navigationBar setNeedsLayout];
}

- (void)applyAvatarFileId:(NSNumber *)fileId toButton:(UIButton *)button pixels:(CGFloat)avatarPixels {
	[[TGClient shared] downloadFile:fileId.longLongValue completion:^(NSString *path) {
		if (!path.length)
			return;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *photo = TGDecodeThumbnail(path, avatarPixels);
			if (!photo)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				[button setImage:photo forState:UIControlStateNormal];
			});
		});
	}];
}

- (void)buildAvatarButton {
	CGFloat side = 35;
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = CGRectMake(0, 0, side, side);
	button.layer.cornerRadius = 4.0f;
	button.clipsToBounds = YES;
	[button addTarget:self action:@selector(openProfile)
		forControlEvents:UIControlEventTouchUpInside];

	NSString *title = self.chatTitle ?: @"";
	BOOL isSaved = (self.chatId == [[TGClient shared] savedMessagesChatId]);
	BOOL showsSavedIcon = isSaved && self.savedTopicOriginChatId == 0;
	int64_t avatarChatId = (isSaved && self.savedTopicOriginChatId != 0)
		? self.savedTopicOriginChatId
		: self.chatId;

	NSString *initial = title.length ? TGSafeFirstCharacter(title).uppercaseString : @"?";
	UIImage *avatar = showsSavedIcon
		? [TGIcons savedMessagesAvatarOfSide:side]
		: [TGIcons avatarWithInitials:initial size:side colourId:avatarChatId];
	[button setImage:avatar forState:UIControlStateNormal];

	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:button];

	if (showsSavedIcon)
		return;

	CGFloat avatarPixels = side * [UIScreen mainScreen].scale;
	NSNumber *fileId = [[TGClient shared] photoFileIdForChat:avatarChatId];
	if (fileId && fileId.longLongValue > 0) {
		[self applyAvatarFileId:fileId toButton:button pixels:avatarPixels];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] photoFileIdForChat:avatarChatId completion:^(NSNumber *fetchedFileId) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !fetchedFileId)
			return;
		[strongSelf applyAvatarFileId:fetchedFileId toButton:button pixels:avatarPixels];
	}];
}

- (void)openProfile {
	if (self.chatId == [[TGClient shared] savedMessagesChatId]) {
		[self.navigationController pushViewController:[[TGEditProfileViewController alloc] init]
											 animated:YES];
		return;
	}

	int64_t userId = self.group ? 0 : self.chatId;
	if (!self.group) {
		int64_t secretUserId = [[TGClient shared] secretChatUserIdForChat:self.chatId];
		if (secretUserId != 0)
			userId = secretUserId;
	}
	TGProfileViewController *profile = [[TGProfileViewController alloc]
		initWithChatId:self.chatId
				userId:userId
				 title:self.chatTitle];
	profile.threadId = self.threadId;
	__weak typeof(self) weakSelf = self;
	profile.onSearchTapped = ^{
		[weakSelf.navigationController popViewControllerAnimated:YES];
		[weakSelf toggleChatSearch];
	};
	profile.onChatUpgraded = ^(int64_t newChatId) {
		[weakSelf reloadForChatIdentityChangedTo:newChatId];
	};
	[self.navigationController pushViewController:profile animated:YES];
}

- (void)muteFromChat:(UIButton *)button {
	(void)button;
	BOOL muted = !self.channelMuted;
	self.channelMuted = muted;
	[self updateChannelActionTitle];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setChat:self.chatId
				muteForSeconds:(muted ? kNotificationMuteForever : 0)
					completion:^(BOOL ok) {
		if (ok)
			return;
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.channelMuted = !muted;
		[strongSelf updateChannelActionTitle];
		[TGSnackbar showInView:strongSelf.view
						   text:(muted
									? TGL(@"Toast.CouldNotMuteChat", @"Could not mute this chat")
									: TGL(@"Toast.CouldNotUnmuteChat", @"Could not unmute this chat"))
						seconds:3
					   onCommit:nil];
	}];
}

@end
