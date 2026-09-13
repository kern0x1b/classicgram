#import "TGListBackground.h"
#import "TGProfileViewController.h"
#import "TGProfileViewControllerInternal.h"
#import "TGClient.h"
#import "TGProfileButtonsCell.h"
#import "TGProfileRedButtonCell.h"
#import "TGProfilePermissionsController.h"
#import "TGProfileStatisticsController.h"
#import "TGProfileBoostsController.h"
#import "TGProfileCommonGroupsController.h"
#import "TGProfileLinkJoinsController.h"
#import "TGLocalization.h"
#import "TGProfileService.h"
#import "TGContactsService.h"
#import "TGFileDownloadService.h"
#import "TGSettingsService.h"
#import "TGTheme.h"
#import "TGLottieView.h"
#import "TGIcons.h"
#import "TGCallViewController.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGChatViewController.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGHexColour.h"

@implementation TGProfileViewController (Header)

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [self profileTitle];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];

	if (self.chatId) {
		self.muted = [TGProfileService isChatMuted:self.chatId];
		self.translatable = [TGProfileService isChatTranslatable:self.chatId];
	}

	[self buildHeader];
	[self loadDetails];
	[self loadMedia];
	[self loadProfileExtras];
	[self loadStoryPosting];
}

- (NSString *)profileTitle {
	if (self.chatId && [TGContactsService isSecretChat:self.chatId])
		return [NSString stringWithFormat:@"   %@", TGL(@"SecretChat.Title", @"Secret Chat")];
	if (!self.userId && self.chatId)
		return TGL(@"GroupInfo.Title", @"Group Info");
	return TGL(@"UserInfo.Title", @"Info");
}

- (BOOL)isGroupProfile {
	return self.userId == 0 && self.chatId != 0;
}

- (void)loadStoryPosting {
	__weak typeof(self) weakSelf = self;
	[TGProfileService chatsToPostStoriesWithCompletion:^(NSArray *chats) {
		if (![chats isKindOfClass:[NSArray class]])
			return;
		int64_t match = 0;
		for (id chat in chats) {
			if (![chat isKindOfClass:[NSDictionary class]])
				continue;
			int64_t identifier = TGProfileInt64(chat[@"id"]);
			if (!identifier)
				continue;
			if (identifier == weakSelf.chatId || (weakSelf.userId && identifier == weakSelf.userId)) {
				match = identifier;
				break;
			}
		}
		if (!match)
			return;
		weakSelf.storyChatId = match;
		weakSelf.canPostStory = YES;
		[weakSelf rebuildSections];
		[weakSelf.tableView reloadData];
	}];
}

- (void)postStoryTapped {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:@[ TGL(@"Common.TakePhoto", @"Take Photo"),
					   TGL(@"Common.ChoosePhoto", @"Choose Photo") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 77;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)pickStoryPhotoFromCamera:(BOOL)camera {
	UIImagePickerControllerSourceType source = camera
		? UIImagePickerControllerSourceTypeCamera
		: UIImagePickerControllerSourceTypePhotoLibrary;
	if (![UIImagePickerController isSourceTypeAvailable:source]) {
		[self showToast:(camera ? TGL(@"Toast.NoCamera", @"No camera")
							   : TGL(@"Toast.NoPhotoLibrary", @"No photo library"))];
		return;
	}
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = source;
	picker.allowsEditing = NO;
	picker.delegate = self;
	self.pickerMode = kPickerModeStory;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)askStoryPrivacy {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Story.Context.Privacy", @"Who Can See")
					  delegate:self
				   otherTitles:@[ TGL(@"Group.Setup.WhoCanSendMessages.Everyone", @"Everyone"),
					   TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts"),
					   TGL(@"PrivacySettings.LastSeenCloseFriends", @"Close Friends") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 78;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)askStoryCaption {
	UIAlertView *caption = [[TGAlertView alloc]
			initWithTitle:nil
				  message:TGL(@"Conversation.InputTextCaptionPlaceholder", @"Caption")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Stars.Transaction.Reaction.Post", @"Post"), nil];
	caption.tag = 79;
	if ([caption respondsToSelector:@selector(setAlertViewStyle:)])
		caption.alertViewStyle = UIAlertViewStylePlainTextInput;
	[caption show];
}

- (void)postStoryWithCaption:(NSString *)caption {
	NSString *path = self.storyPath;
	if (!path.length || !self.storyChatId)
		return;
	self.storyPath = nil;
	[self showToast:TGL(@"Story.Editor.Uploading", @"Uploading...")];
	__weak typeof(self) weakSelf = self;
	[TGProfileService
		postPhotoStoryAtPath:path
					  asChat:self.storyChatId
					 caption:(caption ?: @"")
		privacy:(self.storyPrivacy ?: @"everyone")
		userIds:nil
				   toProfile:NO
				  completion:^(NSDictionary *story) {
					  BOOL posted = [story isKindOfClass:[NSDictionary class]];
					  [weakSelf showToast:(posted
							  ? TGL(@"Story.PostedToast", @"Story posted")
							  : TGL(@"Story.PostFailedToast", @"Could not post story"))];
				  }];
}

- (void)layoutNameBadge {
	NSString *text = self.nameLabel.text ?: @"";
	CGFloat available = self.nameLabel.frame.size.width;
	CGFloat textWidth = available;
	if (text.length) {
		CGSize measured = [self.nameLabel sizeThatFits:CGSizeMake(available, 1000)];
		textWidth = MIN(measured.width, available);
	}
	CGFloat x = self.nameLabel.frame.origin.x + textWidth + 5;
	CGFloat limit = self.view.bounds.size.width - 30;
	if (x > limit)
		x = limit;
	CGRect labelFrame = self.badgeLabel.frame;
	labelFrame.origin.x = x;
	self.badgeLabel.frame = labelFrame;
	CGRect viewFrame = self.badgeView.frame;
	viewFrame.origin.x = x;
	self.badgeView.frame = viewFrame;
	self.badgeLottieView.frame = viewFrame;
}

- (NSString *)statusRowValueFor:(NSDictionary *)badge emoji:(NSString *)emoji {
	NSString *gift = TGProfileText(badge[@"giftTitle"]);
	NSTimeInterval expires = [badge[@"expires"] isKindOfClass:[NSNumber class]]
		? [badge[@"expires"] doubleValue]
		: 0;
	NSString *text = gift;
	if (expires > [[NSDate date] timeIntervalSince1970]) {
		NSString *until = [NSString stringWithFormat:
				  TGL(@"Channel.AdminLog.MessageRestrictedUntil", @"until %@"),
			[TGDateUtils stringForUntil:(int)expires]];
		text = text.length ? [NSString stringWithFormat:@"%@, %@", text, until] : until;
	}
	if (!text.length)
		return emoji ?: @"";
	return [NSString stringWithFormat:@"%@  %@", text, (emoji ?: @"")];
}

- (void)applyEmojiStatus:(NSDictionary *)badge {
	if (![badge isKindOfClass:[NSDictionary class]]) {
		self.emojiStatusShown = NO;
		self.badgeLabel.hidden = YES;
		self.badgeView.hidden = YES;
		[self.badgeLottieView stop];
		self.badgeLottieView.hidden = YES;
		return;
	}
	self.emojiStatusShown = YES;
	NSString *emoji = TGProfileText(badge[@"emoji"]);
	NSString *glyph = emoji ?: @"⭐";
	self.badgeLabel.text = glyph;
	self.badgeLabel.hidden = !TGProfileCanRenderText(glyph) && !TGEmojiTextNeedsSubstitution(glyph);
	self.badgeView.hidden = YES;
	[self layoutNameBadge];
	NSString *statusValue = [self statusRowValueFor:badge emoji:self.badgeLabel.text];
	self.emojiStatusDetail = statusValue.length ? statusValue : nil;
	[self setDetail:statusValue forLabel:@"status"];

	BOOL isTgs = [badge[@"isTgs"] boolValue];
	NSNumber *thumb = isTgs
		? ([badge[@"stickerFileId"] isKindOfClass:[NSNumber class]]
				  ? badge[@"stickerFileId"]
				  : nil)
		: nil;
	if (!thumb)
		thumb = [badge[@"thumbFileId"] isKindOfClass:[NSNumber class]]
			? badge[@"thumbFileId"]
			: nil;
	if (!thumb)
		thumb = [badge[@"stickerFileId"] isKindOfClass:[NSNumber class]]
			? badge[@"stickerFileId"]
			: nil;
	long long badgeId = [thumb longLongValue];
	if (badgeId <= 0) {
		self.badgeFileId = 0;
		[self.badgeLottieView stop];
		self.badgeLottieView.hidden = YES;
		return;
	}
	if (self.badgeFileId == badgeId) {
		if (isTgs && self.badgeLottieView.loaded) {
			self.badgeLottieView.hidden = NO;
			self.badgeLabel.hidden = YES;
			[self.badgeLottieView play];
			[self layoutNameBadge];
		} else if (!isTgs && self.badgeView.image) {
			self.badgeView.hidden = NO;
			self.badgeLabel.hidden = YES;
			[self layoutNameBadge];
		}
		return;
	}
	self.badgeFileId = badgeId;
	[self.badgeLottieView stop];
	self.badgeLottieView.hidden = YES;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:badgeId completion:^(NSString *path) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!path.length || !strongSelf || strongSelf.badgeFileId != badgeId)
			return;
		if (isTgs) {
			if ([strongSelf.badgeLottieView loadTGSFile:path]) {
				strongSelf.badgeView.hidden = YES;
				strongSelf.badgeLottieView.hidden = NO;
				strongSelf.badgeLabel.hidden = YES;
				[strongSelf.badgeLottieView play];
				[strongSelf layoutNameBadge];
			}
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *image = TGDecodeSquareThumbnail(path, 18.0f);
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				if (weakSelf.badgeFileId != badgeId)
					return;
				weakSelf.badgeView.image = image;
				weakSelf.badgeView.hidden = NO;
				weakSelf.badgeLabel.hidden = YES;
				[weakSelf layoutNameBadge];
			});
		});
	}];
}

- (void)applyBotVerification:(NSDictionary *)badge {
	if (![badge isKindOfClass:[NSDictionary class]] || self.emojiStatusShown)
		return;

	NSString *emoji = TGProfileText(badge[@"emoji"]);
	NSString *glyph = emoji ?: @"✔";
	self.badgeLabel.text = glyph;
	self.badgeLabel.hidden = !TGProfileCanRenderText(glyph) && !TGEmojiTextNeedsSubstitution(glyph);
	self.badgeView.hidden = YES;
	[self layoutNameBadge];

	NSString *botName = TGProfileText(badge[@"botName"]);
	NSString *description = TGProfileText(badge[@"verificationDescription"]);
	NSString *value = botName.length
		? [NSString stringWithFormat:TGL(@"Profile.VerifiedByBot", @"Verified by %@"), botName]
		: TGL(@"Profile.VerifiedByABot", @"Verified by a bot");
	if (description.length)
		value = [NSString stringWithFormat:@"%@ - %@", value, description];
	self.botVerificationDetail = value;
	[self setDetail:value forLabel:@"verified by"];

	NSNumber *thumb = [badge[@"thumbFileId"] isKindOfClass:[NSNumber class]]
		? badge[@"thumbFileId"]
		: nil;
	if (!thumb)
		thumb = [badge[@"stickerFileId"] isKindOfClass:[NSNumber class]]
			? badge[@"stickerFileId"]
			: nil;
	long long badgeId = [thumb longLongValue];
	if (badgeId <= 0) {
		self.badgeFileId = 0;
		return;
	}
	if (self.badgeFileId == badgeId) {
		if (self.badgeView.image) {
			self.badgeView.hidden = NO;
			self.badgeLabel.hidden = YES;
			[self layoutNameBadge];
		}
		return;
	}
	self.badgeFileId = badgeId;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:badgeId completion:^(NSString *path) {
		if (!path.length || weakSelf.badgeFileId != badgeId)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *image = TGDecodeSquareThumbnail(path, 18.0f);
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				if (weakSelf.badgeFileId != badgeId)
					return;
				weakSelf.badgeView.image = image;
				weakSelf.badgeView.hidden = NO;
				weakSelf.badgeLabel.hidden = YES;
				[weakSelf layoutNameBadge];
			});
		});
	}];
}

- (void)toggleSongPlayback {
	NSDictionary *audio = self.profileAudioInfo;
	long long fileId = [audio[@"fileId"] longLongValue];
	if (!fileId)
		return;

	if (self.songPlayerFileId == fileId && self.songPlayer) {
		if (self.songPlayer.playing)
			[self.songPlayer pause];
		else
			[self.songPlayer play];
		[self refreshProfileDetailPresenter];
		[self.tableView reloadData];
		return;
	}

	if (self.songDownloading)
		return;
	self.songDownloading = YES;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.songDownloading = NO;
		if (!path.length)
			return;
		NSError *error = nil;
		AVAudioPlayer *player = [[TGAVClass(AVAudioPlayer) alloc]
			initWithContentsOfURL:[NSURL fileURLWithPath:path]
							error:&error];
		if (!player || error) {
			[strongSelf showToast:TGL(@"Toast.ProfileSongUnplayable", @"This profile song could not be played")];
			return;
		}
		player.delegate = strongSelf;
		strongSelf.songPlayer = player;
		strongSelf.songPlayerFileId = fileId;
		[player play];
		[strongSelf refreshProfileDetailPresenter];
		[strongSelf.tableView reloadData];
	}];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
	if (player != self.songPlayer)
		return;
	[self refreshProfileDetailPresenter];
	[self.tableView reloadData];
}

- (void)loadProfileExtras {
	if (self.userId) {
		[self loadUserProfileExtras];
		return;
	}
	if (!self.chatId)
		return;
	[self loadChatProfileExtras];
}

- (void)reloadEmojiStatus {
	__weak typeof(self) weakSelf = self;
	[TGContactsService emojiStatusForUser:self.userId completion:^(NSDictionary *badge) {
		[weakSelf applyEmojiStatus:badge];
		if (!badge) {
			[TGContactsService botVerificationForUser:weakSelf.userId completion:^(NSDictionary *verification) {
				[weakSelf applyBotVerification:verification];
			}];
		}
	}];
}

- (void)loadUserProfileExtras {
	[self reloadEmojiStatus];
	[self refreshAccountBadges];
	__weak typeof(self) weakSelf = self;

	self.userProfileObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUserProfileDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGProfileViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if ([note.userInfo[@"userId"] longLongValue] != strongSelf.userId)
						return;
					[strongSelf reloadEmojiStatus];
					[strongSelf loadContactFlags];
					[strongSelf refreshAccountBadges];
					[strongSelf loadFullUserProfile];
					[strongSelf refreshGiftEligibility];
				}];

	self.userBlockedStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUserBlockedStateDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGProfileViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (![note.object isEqual:@(strongSelf.userId)])
						return;
					[TGContactsService isUserBlocked:strongSelf.userId completion:^(BOOL blocked) {
						weakSelf.blocked = blocked;
						[weakSelf.tableView reloadData];
					}];
				}];

	[TGProfileService profileAudiosForUser:self.userId offset:0 limit:1
								completion:^(NSArray *audios, BOOL failed) {
									TGProfileViewController *strongSelf = weakSelf;
									if (!strongSelf)
										return;
									NSDictionary *first = audios.count ? audios[0] : nil;
									strongSelf.profileAudioInfo = first;
									if (!first)
										return;
									NSString *title = TGProfileText(first[@"title"]);
									NSString *performer = TGProfileText(first[@"performer"]);
									NSString *value = (title.length && performer.length)
										? [NSString stringWithFormat:@"%@ - %@", performer, title]
										: (title.length ? title : (performer.length ? performer
												: TGL(@"MediaPlayer.UnknownTrack", @"Unknown Track")));
									[strongSelf setDetail:value forLabel:@"song"];
								}];

	[TGContactsService birthdateForUser:self.userId
							 completion:^(NSDictionary *birthdate) {
								 if (![birthdate isKindOfClass:[NSDictionary class]])
									 return;
								 NSString *text = TGProfileText(birthdate[@"text"]);
								 if (!text)
									 return;
								 weakSelf.birthdayDetail = text;
								 [weakSelf setDetail:text forLabel:@"birthday"];
							 }];
	[TGContactsService personalChatForUser:self.userId
								completion:^(int64_t chatId) {
									if (!chatId)
										return;
									weakSelf.personalChatId = chatId;
									weakSelf.personalChatTitle = TGL(@"Settings.PersonalChannelItem", @"Channel");
									[weakSelf rebuildSections];
									[weakSelf.tableView reloadData];
									[TGSettingsService titleForChatId:chatId completion:^(NSString *title) {
										weakSelf.personalChatTitle = TGProfileText(title) ?: TGL(@"Settings.PersonalChannelItem", @"Channel");
										[weakSelf.tableView reloadData];
									}];
								}];
	[self refreshGiftEligibility];
}

- (void)refreshGiftEligibility {
	__weak typeof(self) weakSelf = self;
	[TGContactsService giftEligibilityForUser:self.userId
									completion:^(BOOL acceptsGifts, BOOL acceptsPremiumGift) {
										weakSelf.recipientAcceptsGifts = acceptsGifts;
										weakSelf.recipientAcceptsPremiumGift = acceptsPremiumGift;
									}];
}

- (void)reloadChatEmojiStatus {
	__weak typeof(self) weakSelf = self;
	[TGContactsService emojiStatusForChat:self.chatId completion:^(NSDictionary *badge) {
		[weakSelf applyEmojiStatus:badge];
		if (!badge) {
			[TGContactsService botVerificationForChat:weakSelf.chatId completion:^(NSDictionary *verification) {
				[weakSelf applyBotVerification:verification];
			}];
		}
	}];
}

- (void)loadChatProfileExtras {
	[self reloadChatEmojiStatus];
	[self refreshAccountBadges];

	__weak typeof(self) weakSelf = self;
	self.chatEmojiStatusObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatEmojiStatusDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGProfileViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (![note.object isEqual:@(strongSelf.chatId)])
						return;
					[strongSelf reloadChatEmojiStatus];
				}];

	self.chatVerificationObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatPermissionsDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGProfileViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (note.object && ![note.object isEqual:@(strongSelf.chatId)])
						return;
					[strongSelf refreshAccountBadges];
				}];

	self.chatOnlineMemberCountObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatOnlineMemberCountDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGProfileViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (![note.object isEqual:@(strongSelf.chatId)])
						return;
					NSInteger online = [note.userInfo[TGChatOnlineMemberCountKey] integerValue];
					[strongSelf applyLiveOnlineMemberCount:online];
				}];

	self.chatSlowModeDelayObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatSlowModeDelayDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGProfileViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (![note.object isEqual:@(strongSelf.chatId)])
						return;
					[strongSelf applyLiveSlowModeDelay:[note.userInfo[TGChatSlowModeDelayKey] integerValue]];
				}];

	self.chatPendingJoinRequestsObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatPendingJoinRequestsDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGProfileViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (![note.object isEqual:@(strongSelf.chatId)])
						return;
					[strongSelf applyLivePendingJoinRequestsCount:[note.userInfo[TGChatPendingJoinRequestsCountKey] integerValue]];
				}];
}

- (void)applyLiveOnlineMemberCount:(NSInteger)online {
	if (self.memberCount <= 0)
		return;
	NSString *membersText = TGLPlural(@"Conversation.StatusMembers", self.memberCount, @"1 member", @"%@ members");
	NSString *onlineText = TGLPlural(@"Conversation.StatusOnline", online, @"1 online", @"%d online");
	self.statusLabel.text = online > 0
		? [NSString stringWithFormat:@"%@, %@", membersText, onlineText]
		: membersText;
}

- (void)applyLiveSlowModeDelay:(NSInteger)delay {
	if (self.userId || !self.managementLoaded)
		return;
	self.slowModeDelay = delay;
	[self rebuildManageRows];
}

- (void)applyLivePendingJoinRequestsCount:(NSInteger)count {
	if (self.userId || !self.managementLoaded)
		return;
	self.pendingJoinRequests = count;
	[self rebuildManageRows];
}

- (void)refreshAccountBadges {
	__weak typeof(self) weakSelf = self;
	if (self.userId) {
		[TGContactsService badgesForUser:self.userId completion:^(NSDictionary *badges) {
			[weakSelf applyAccountBadges:badges];
		}];
		return;
	}
	if (!self.chatId)
		return;
	[TGContactsService badgesForChat:self.chatId completion:^(NSDictionary *badges) {
		[weakSelf applyAccountBadges:badges];
	}];
}

- (void)applyAccountBadges:(NSDictionary *)badges {
	if (![badges isKindOfClass:[NSDictionary class]] || self.emojiStatusShown)
		return;
	NSString *mark = nil;
	UIColor *colour = nil;
	if (TGProfileBool(badges[@"isScam"])) {
		mark = TGL(@"Message.ScamAccount", @"Scam").uppercaseString;
		colour = TGColourFromHex(0xc23c2e);
	} else if (TGProfileBool(badges[@"isFake"])) {
		mark = TGL(@"Message.FakeAccount", @"Fake").uppercaseString;
		colour = TGColourFromHex(0xc23c2e);
	} else if (TGProfileBool(badges[@"isVerified"])) {
		mark = @"✓";
		colour = [[TGTheme shared] groupedActionColour];
	}
	if (!mark)
		return;
	self.badgeLabel.text = mark;
	self.badgeLabel.textColor = colour;
	self.badgeLabel.hidden = NO;
	self.badgeView.hidden = YES;
	CGSize measured = [mark sizeWithFont:self.badgeLabel.font];
	CGRect frame = self.badgeLabel.frame;
	frame.size.width = MAX(20.0f, ceilf(measured.width) + 4.0f);
	self.badgeLabel.frame = frame;
	[self layoutNameBadge];
}

- (void)setDetail:(NSString *)value forLabel:(NSString *)label {
	NSMutableArray *rows = [self.details mutableCopy] ?: [NSMutableArray array];
	BOOL replaced = NO;
	for (NSInteger i = 0; i < rows.count; i++) {
		NSArray *pair = rows[i];
		if (pair.count > 0 && [pair[0] isEqualToString:label]) {
			rows[i] = @[ label, value ];
			replaced = YES;
			break;
		}
	}
	if (!replaced)
		[rows addObject:@[ label, value ]];
	self.details = rows;
	[self refreshProfileDetailPresenter];
	[self.tableView reloadData];
}

- (UIImage *)placeholderAvatarPlate {
	return TGProfilePlaceholderPlate(self.userId, [self isGroupProfile]);
}

- (void)showPlaceholderAvatarPlate {
	self.avatarView.image = [self placeholderAvatarPlate];
	self.avatarOverlayView.hidden = YES;
}

- (void)buildHeader {
	CGFloat width = self.view.bounds.size.width;
	CGFloat side = kProfileAvatarSide;
	CGFloat height = [self isGroupProfile] ? kGroupTitleContainerHeight
										   : kTitleContainerHeight;

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
	header.backgroundColor = [UIColor clearColor];

	self.avatarView = [[UIImageView alloc]
		initWithFrame:
			CGRectMake(kGroupedInset, 14, side, side)];
	self.avatarView.userInteractionEnabled = YES;
	self.avatarView.exclusiveTouch = YES;
	UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(avatarTapped)];
	[self.avatarView addGestureRecognizer:avatarTap];
	[header addSubview:self.avatarView];

	UIImage *overlayArt = TGProfileStretchedInCentre(@"ProfileAvatarOverlay.png");
	if (overlayArt) {
		UIImageView *overlay = [[UIImageView alloc] initWithImage:overlayArt];
		overlay.frame = self.avatarView.frame;
		overlay.userInteractionEnabled = NO;
		[header addSubview:overlay];
		self.avatarOverlayView = overlay;
	}

	if (self.avatarImage) {
		self.avatarView.image = TGProfileAvatarPlate(self.avatarImage);
		self.avatarOverlayView.hidden = NO;
	} else {
		[self showPlaceholderAvatarPlate];
	}

	[self buildHeaderLabelsInto:header width:width];

	[self refreshStatus];
	[self layoutNameBadge];

	self.tableView.tableHeaderView = header;
	self.tableView.tableFooterView =
		[[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 7)];
	self.tableView.backgroundColor = TGGroupedListBackground();

	if (self.avatarImage)
		return;
	NSNumber *fileId = self.userId
		? [TGSettingsService photoFileIdForUserId:self.userId]
		: [TGProfileService photoFileIdForChat:self.chatId];
	if (![fileId isKindOfClass:[NSNumber class]])
		return;
	[self loadAvatarFile:fileId.longLongValue];
}

- (CGFloat)headerNameGap {
	return [self isGroupProfile] ? kGroupNameGap : kProfileNameGap;
}

- (CGRect)headerStatusFrameForLeft:(CGFloat)labelLeft width:(CGFloat)available {
	if ([self isGroupProfile])
		return CGRectMake(labelLeft + 1, 49 + TGProfileRetinaPixel(), available, 24);
	return CGRectMake(labelLeft, 52, available, 24);
}

- (void)buildHeaderLabelsInto:(UIView *)header width:(CGFloat)width {
	CGFloat labelLeft = kGroupedInset + kProfileAvatarSide + [self headerNameGap];

	UILabel *nameLabel = [[TGEmojiLabel alloc]
		initWithFrame:
			CGRectMake(labelLeft, 24, width - labelLeft - kGroupedInset, 24)];
	nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	nameLabel.text = TGProfileText(self.name) ?: @"";
	nameLabel.font = [UIFont boldSystemFontOfSize:19];
	nameLabel.backgroundColor = [UIColor clearColor];
	nameLabel.textColor = TGColourFromHex(0x222932);
	nameLabel.shadowColor = [TGColourFromHex(0xedf0f5) colorWithAlphaComponent:0.28f];
	nameLabel.shadowOffset = CGSizeMake(0, 1);
	[header addSubview:nameLabel];
	self.nameLabel = nameLabel;

	self.badgeLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectMake(labelLeft, 24, 20, 24)];
	self.badgeLabel.font = [UIFont systemFontOfSize:17];
	self.badgeLabel.backgroundColor = [UIColor clearColor];
	self.badgeLabel.hidden = YES;
	[header addSubview:self.badgeLabel];

	self.badgeView = [[UIImageView alloc] initWithFrame:CGRectMake(labelLeft, 27, 18, 18)];
	self.badgeView.contentMode = UIViewContentModeScaleAspectFit;
	self.badgeView.hidden = YES;
	[header addSubview:self.badgeView];

	self.badgeLottieView = [[TGLottieView alloc] initWithFrame:self.badgeView.frame];
	self.badgeLottieView.hidden = YES;
	[header addSubview:self.badgeLottieView];

	CGFloat statusWidth = width - labelLeft - kGroupedInset;
	CGRect statusFrame = [self headerStatusFrameForLeft:labelLeft width:statusWidth];
	if ([self isGroupProfile]) {
		self.statusLabel = [[UILabel alloc] initWithFrame:statusFrame];
	} else {
		TGDateLabel *dated = [[TGDateLabel alloc] initWithFrame:statusFrame];
		dated.dateFont = [UIFont systemFontOfSize:14];
		dated.dateTextFont = dated.dateFont;
		dated.dateLabelFont = [UIFont systemFontOfSize:12];
		dated.amWidth = 20;
		dated.pmWidth = 20;
		dated.dstOffset = 2 + TGProfileRetinaPixel();
		self.statusLabel = dated;
	}
	self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.statusLabel.font = [UIFont systemFontOfSize:14];
	self.statusLabel.textColor = TGColourFromHex(0x6d7d90);
	self.statusLabel.shadowColor =
		[TGColourFromHex(0xedf0f5) colorWithAlphaComponent:0.28f];
	self.statusLabel.shadowOffset = CGSizeMake(0, 1);
	self.statusLabel.backgroundColor = [UIColor clearColor];
	self.statusLabel.userInteractionEnabled = YES;
	UITapGestureRecognizer *statusTap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(statusTapped)];
	[self.statusLabel addGestureRecognizer:statusTap];
	[header addSubview:self.statusLabel];
}

- (void)setAvatarViewImage:(UIImage *)image crossfade:(BOOL)crossfade {
	if (!image)
		return;
	if (crossfade && self.avatarView.image) {
		CATransition *fade = [CATransition animation];
		fade.duration = 0.2;
		fade.type = kCATransitionFade;
		[self.avatarView.layer addAnimation:fade forKey:@"avatarFade"];
	}
	self.avatarView.image = TGProfileAvatarPlate(image);
	self.avatarOverlayView.hidden = NO;
}

- (void)showPlaceholderAvatarFromData:(NSData *)data {
	if (!data.length || self.avatarImage)
		return;
	UIImage *tiny = [UIImage imageWithData:data];
	if (!tiny)
		return;
	self.avatarIsPlaceholder = YES;
	[self setAvatarViewImage:tiny crossfade:NO];
}

- (void)cancelAvatarDownload {
	self.avatarFileId = 0;
}

- (void)loadAvatarFile:(long long)fileId {
	if (fileId <= 0)
		return;
	if (self.avatarFileId == fileId)
		return;
	[self cancelAvatarDownload];
	self.avatarFileId = fileId;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		if (!path.length || weakSelf.avatarFileId != fileId)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *image = TGDecodeSquareThumbnail(path, kProfileAvatarSide);
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				if (weakSelf.avatarFileId != fileId)
					return;
				weakSelf.avatarImage = image;
				weakSelf.avatarIsPlaceholder = NO;
				[weakSelf setAvatarViewImage:image crossfade:YES];
			});
		});
	}];
}

- (void)refreshStatus {
	__weak typeof(self) weakSelf = self;
	if (self.userId) {
		[TGContactsService statusInfoForUser:self.userId completion:^(NSDictionary *info) {
			NSString *text = [info isKindOfClass:[NSDictionary class]]
				? TGProfileText(info[@"text"])
				: nil;
			if ([info isKindOfClass:[NSDictionary class]])
				weakSelf.statusInfo = info;
			long long wasOnline = [info[@"wasOnline"] isKindOfClass:[NSNumber class]]
				? [info[@"wasOnline"] longLongValue]
				: 0;
			NSString *dated = TGProfileLastSeenText(wasOnline);
			if (dated)
				text = dated;
			if (text) {
				weakSelf.statusLabel.text = text;
				return;
			}
			[TGSettingsService statusForUser:weakSelf.userId completion:^(NSString *status) {
				weakSelf.statusLabel.text = TGProfileText(status) ?: @"";
			}];
		}];
		return;
	}
	if (!self.chatId)
		return;
	[TGContactsService groupOnlineSummaryForChat:self.chatId completion:^(NSString *text, NSInteger members, NSInteger online) {
		if (members > 0 && members != weakSelf.memberCount) {
			weakSelf.memberCount = members;
			[weakSelf rebuildManageRows];
		}
		NSString *summary = TGProfileText(text);
		if (summary) {
			weakSelf.statusLabel.text = summary;
			return;
		}
		[TGProfileService memberCountForChat:weakSelf.chatId completion:^(NSInteger count) {
			if (count > 0)
				weakSelf.statusLabel.text = TGLPlural(@"Conversation.StatusMembers", count, @"1 member", @"%@ members");
		}];
	}];
}

- (void)statusTapped {
	NSString *hint = [TGContactsService hiddenStatusHintForStatusInfo:self.statusInfo];
	if (!hint.length)
		return;
	[[[UIAlertView alloc] initWithTitle:nil message:hint delegate:nil
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
					  otherButtonTitles:nil] show];
}

- (NSArray *)actionItems {
	NSMutableArray *items = [NSMutableArray array];
	if (self.userId) {
		[items addObject:@{@"title" : TGL(@"UserInfo.SendMessage", @"Send Message"), @"action" : @"message"}];
		if (self.contact)
			[items addObject:@{@"title" : TGL(@"UserInfo.ShareContact", @"Share Contact"), @"action" : @"share"}];
		else
			[items addObject:@{@"title" : TGL(@"UserInfo.AddContact", @"Add Contact"), @"action" : @"add"}];
		if (!self.isBot && self.canCall) {
			[items addObject:@{@"title" : TGL(@"PeerInfo.ButtonCall", @"Call"), @"action" : @"call", @"disabled" : @(self.blocked)}];
			if (self.canVideoCall)
				[items addObject:@{@"title" : TGL(@"ContactList.Context.VideoCall", @"Video Call"), @"action" : @"video", @"disabled" : @(self.blocked)}];
		}
	} else if (self.chatId) {
		if (self.canListMembers)
			[items addObject:@{@"title" : TGL(@"GroupInfo.AddParticipant", @"Add Member"), @"action" : @"addmember"}];
		[items addObject:@{@"title" : TGL(@"Group.LeaveGroup", @"Leave Group"), @"action" : @"leave"}];
	}
	if (self.onSearchTapped && self.chatId)
		[items addObject:@{@"title" : TGL(@"Conversation.ContextMenuSearchMessages", @"Search Messages"), @"action" : @"search"}];
	[items addObject:@{@"title" : TGL(@"PeerInfo.ButtonMore", @"More"), @"action" : @"more"}];
	self.actionNames = items;
	return items;
}

- (NSInteger)actionRowCount {
	NSInteger count = (NSInteger)[self actionItems].count;
	return (count + 1) / 2;
}

- (UITableViewCell *)actionsCell:(UITableView *)tableView row:(NSInteger)row {
	TGProfileButtonsCell *cell = (TGProfileButtonsCell *)
		[tableView dequeueReusableCellWithIdentifier:@"buttons"];
	if (![cell isKindOfClass:[TGProfileButtonsCell class]])
		cell = [[TGProfileButtonsCell alloc] initWithStyle:UITableViewCellStyleDefault
										   reuseIdentifier:@"buttons"];
	NSArray *items = self.actionNames ?: [self actionItems];
	NSInteger first = row * 2;
	UIButton *buttons[2] = {cell.leftButton, cell.rightButton};
	for (NSInteger i = 0; i < 2; i++) {
		UIButton *button = buttons[i];
		NSInteger index = first + i;
		[button removeTarget:self action:NULL
			forControlEvents:UIControlEventTouchUpInside];
		if (index >= (NSInteger)items.count) {
			button.hidden = YES;
			continue;
		}
		NSDictionary *item = items[index];
		button.hidden = NO;
		BOOL disabled = TGProfileBool(item[@"disabled"]);
		button.alpha = disabled ? 0.7f : 1.0f;
		button.enabled = !disabled;
		[button setTitle:item[@"title"] forState:UIControlStateNormal];
		button.tag = index;
		[button addTarget:self action:@selector(actionTileTapped:)
			forControlEvents:UIControlEventTouchUpInside];
	}
	[cell setNeedsLayout];
	return cell;
}

- (void)actionTileTapped:(UIButton *)tile {
	if (tile.tag >= (NSInteger)self.actionNames.count)
		return;
	NSString *action = self.actionNames[tile.tag][@"action"];

	if ([action isEqualToString:@"message"]) {
		[self openConversation];
		return;
	}
	if ([action isEqualToString:@"add"]) {
		[self runMoreAction:@"Add to contacts"];
		return;
	}
	if ([action isEqualToString:@"share"]) {
		[self runMoreAction:@"Share contact"];
		return;
	}

	if ([action isEqualToString:@"addmember"]) {
		if (self.navigationController)
			[self pushGroupMembersInto:self.navigationController adminsFirst:NO];
		return;
	}
	if ([action isEqualToString:@"leave"]) {
		[self confirmLeaveGroup];
		return;
	}

	if ([action isEqualToString:@"call"] || [action isEqualToString:@"video"]) {
		if (!self.userId)
			return;
		if (self.blocked) {
			[self showToast:TGL(@"Toast.CannotCallBlockedUser", @"You can't call a blocked user.")];
			return;
		}
		[TGCallViewController presentForUserId:self.userId
										  name:self.name
									  outgoing:YES
										 video:[action isEqualToString:@"video"]];
	} else if ([action isEqualToString:@"search"]) {
		if (self.onSearchTapped)
			self.onSearchTapped();
	} else {
		[self showMoreMenuFrom:tile];
	}
}

- (void)updateMuteButton {
	[self.notificationsSwitch setOn:!self.muted animated:NO];
}

- (void)notificationsToggled:(UISwitch *)toggle {
	if (!self.chatId)
		return;
	self.muted = !toggle.on;
	[TGProfileService setChat:self.chatId muted:self.muted];
}

- (void)openConversation {
	UINavigationController *navigation = self.navigationController;
	if (!navigation)
		return;
	NSString *name = TGProfileText(self.name) ?: @"";
	if (self.chatId) {
		for (UIViewController *controller in navigation.viewControllers) {
			if ([controller isKindOfClass:[TGChatViewController class]] && ((TGChatViewController *)controller).chatId == self.chatId) {
				[navigation popToViewController:controller animated:YES];
				return;
			}
		}
		TGChatViewController *chat = [[TGChatViewController alloc] init];
		chat.chatId = self.chatId;
		chat.chatTitle = name;
		[navigation pushViewController:chat animated:YES];
		return;
	}
	if (!self.userId)
		return;
	int64_t userId = self.userId;
	__weak typeof(self) weakSelf = self;
	void (^openChat)(NSInteger) = ^(NSInteger paidStarCount) {
		[TGContactsService privateChatWithUser:userId completion:^(int64_t chatId) {
			if (!chatId)
				return;
			TGChatViewController *chat = [[TGChatViewController alloc] init];
			chat.chatId = chatId;
			chat.chatTitle = name;
			chat.paidMessageStarCount = paidStarCount;
			[navigation pushViewController:chat animated:YES];
		}];
	};
	[TGProfileService canSendMessageToUser:userId completion:^(BOOL canSend, BOOL isPaid, NSInteger starCount, NSString *blockReason) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!canSend && ![blockReason isEqualToString:@"deleted"]) {
			NSString *restrictedName = name.length ? name : TGL(@"Attachment.Contact", @"Contact");
			NSString *message = [NSString stringWithFormat:
					TGL(@"Chat.ToastMessagingRestrictedToPremium.Text", @"%@ only accepts messages from contacts and Premium users."),
				restrictedName];
			UIAlertView *refused = [[UIAlertView alloc]
					initWithTitle:nil
						  message:message
						 delegate:nil
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
				otherButtonTitles:nil];
			[refused show];
			return;
		}
		if (isPaid && starCount > 0) {
			NSString *contactName = strongSelf.name.length ? strongSelf.name : TGL(@"Attachment.Contact", @"Contact");
			NSString *starsText = TGLPlural(@"Chat.PaidMessage.Confirm.Text.Stars", starCount, @"%@ Star", @"%@ Stars");
			NSString *messagesText = TGLPlural(@"Chat.PaidMessage.Confirm.Text.Messages", 1, @"%@ message", @"%@ messages");
			NSString *message = [NSString stringWithFormat:
					TGL(@"Chat.PaidMessage.Confirm.Single.Text", @"%1$@ charges %2$@ per incoming message. Would you like to pay %3$@ to send %4$@?"),
				contactName, starsText, starsText, messagesText];
			NSString *payTitle = TGLPlural(@"Chat.PaidMessage.Confirm.PayForMessage", 1, @"Pay for %@ Message", @"Pay for %@ Messages");
			TGAlertView *confirm = [[TGAlertView alloc]
					initWithTitle:TGL(@"Chat.PaidMessage.Confirm.Title", @"Confirm Payment")
						  message:message
				cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
					okButtonTitle:payTitle
				  completionBlock:^(bool okButtonPressed) {
					  if (okButtonPressed)
						  openChat(starCount);
				  }];
			[confirm show];
			return;
		}
		openChat(0);
	}];
}

- (void)avatarTapped {
	if (self.photoOverlay)
		return;
	UIView *host = self.navigationController.view ?: self.view;
	UIImage *image = self.avatarView.image;
	if (!image)
		return;

	UIView *overlay = [[UIView alloc] initWithFrame:host.bounds];
	overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0];

	UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:overlay.bounds];
	scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	scroll.backgroundColor = [UIColor clearColor];
	scroll.pagingEnabled = YES;
	scroll.bounces = NO;
	scroll.showsHorizontalScrollIndicator = NO;
	scroll.showsVerticalScrollIndicator = NO;
	scroll.contentSize = overlay.bounds.size;
	scroll.delegate = self;
	UITapGestureRecognizer *closeTap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(closePhotoOverlay)];
	[scroll addGestureRecognizer:closeTap];
	if (self.userId || self.chatId) {
		UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self
					action:@selector(photoOverlayLongPressed:)];
		[scroll addGestureRecognizer:hold];
	}
	[overlay addSubview:scroll];

	UIImageView *big = [[UIImageView alloc] initWithImage:image];
	big.contentMode = UIViewContentModeScaleAspectFit;
	big.clipsToBounds = YES;
	big.frame = [self.avatarView convertRect:self.avatarView.bounds toView:host];
	[scroll addSubview:big];

	UIPageControl *pager = [UIPageControl alloc];
	pager = [pager initWithFrame:
			CGRectMake(0, overlay.bounds.size.height - kOverlayPagerBottom,
				overlay.bounds.size.width, kOverlayPagerHeight)];
	pager.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	pager.userInteractionEnabled = NO;
	pager.hidesForSinglePage = YES;
	pager.numberOfPages = 1;
	pager.currentPage = 0;
	[overlay addSubview:pager];

	[host addSubview:overlay];
	self.photoOverlay = overlay;
	self.photoScroll = scroll;
	self.photoPager = pager;
	self.overlayPhotos = @[];
	self.overlayPages = [NSMutableArray arrayWithObject:big];
	self.overlayDownloads = [NSMutableSet set];
	self.overlayRequested = [NSMutableSet set];
	self.overlayZooming = YES;

	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:0.3 animations:^{
		overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:1];
		big.frame = scroll.bounds;
	} completion:^(BOOL done) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || strongSelf.photoOverlay != overlay)
			return;
		strongSelf.overlayZooming = NO;
		[strongSelf layoutPhotoOverlay];
	}];

	if (!self.userId)
		return;
	[TGContactsService profilePhotosForUser:self.userId offset:0
									  limit:kOverlayPhotoLimit
								 completion:^(NSArray *photos, NSInteger total) {
									 typeof(self) strongSelf = weakSelf;
									 if (!strongSelf || strongSelf.photoOverlay != overlay)
										 return;
									 [strongSelf adoptOverlayPhotos:photos];
								 }];
}

- (void)adoptOverlayPhotos:(NSArray *)photos {
	if (![photos isKindOfClass:[NSArray class]])
		return;
	NSMutableArray *usable = [NSMutableArray array];
	for (id entry in photos) {
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		id fileId = ((NSDictionary *)entry)[@"fileId"];
		if ([fileId isKindOfClass:[NSNumber class]] && [fileId longLongValue] > 0)
			[usable addObject:entry];
	}
	if (!usable.count)
		return;
	self.overlayPhotos = usable;

	while (self.overlayPages.count < usable.count) {
		UIImageView *page = [[UIImageView alloc] initWithFrame:CGRectZero];
		page.contentMode = UIViewContentModeScaleAspectFit;
		page.clipsToBounds = YES;
		[self.photoScroll addSubview:page];
		[self.overlayPages addObject:page];
	}
	self.photoPager.numberOfPages = (NSInteger)usable.count;
	[self layoutPhotoOverlay];
	[self loadOverlayPagesAroundCurrent];
}

- (void)layoutPhotoOverlay {
	UIView *overlay = self.photoOverlay;
	if (!overlay)
		return;
	CGSize size = overlay.bounds.size;
	if (size.width < 1 || size.height < 1)
		return;
	self.photoScroll.frame = overlay.bounds;
	NSInteger count = self.overlayPages.count ?: 1;
	self.photoScroll.contentSize = CGSizeMake(size.width * count, size.height);
	for (NSInteger i = 0; i < self.overlayPages.count; i++) {
		if (i == 0 && self.overlayZooming)
			continue;
		UIImageView *page = self.overlayPages[i];
		page.frame = CGRectMake(size.width * i, 0, size.width, size.height);
	}
	NSInteger current = self.photoPager.currentPage;
	if (current < 0)
		current = 0;
	if (current >= (NSInteger)count)
		current = (NSInteger)count - 1;
	self.photoScroll.contentOffset = CGPointMake(size.width * current, 0);
	self.photoPager.frame = CGRectMake(0, size.height - kOverlayPagerBottom,
		size.width, kOverlayPagerHeight);
}

- (void)loadOverlayPagesAroundCurrent {
	NSInteger current = self.photoPager.currentPage;
	for (NSInteger index = 0; index < (NSInteger)self.overlayPages.count; index++) {
		if (index >= current - 1 && index <= current + 1)
			continue;
		UIImageView *page = self.overlayPages[index];
		if (!page.image)
			continue;
		page.image = nil;
		[self.overlayRequested removeObject:@(index)];
	}
	for (NSInteger index = current - 1; index <= current + 1; index++)
		[self loadOverlayPageAtIndex:index];
}

- (void)loadOverlayPageAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.overlayPhotos.count)
		return;
	if (index >= (NSInteger)self.overlayPages.count)
		return;
	NSNumber *key = @(index);
	if ([self.overlayRequested containsObject:key])
		return;
	NSDictionary *photo = self.overlayPhotos[index];
	long long fileId = [photo[@"fileId"] longLongValue];
	if (fileId <= 0)
		return;
	[self.overlayRequested addObject:key];
	[self.overlayDownloads addObject:@(fileId)];

	UIView *overlay = self.photoOverlay;
	UIImageView *page = self.overlayPages[index];
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || strongSelf.photoOverlay != overlay)
			return;
		[strongSelf.overlayDownloads removeObject:@(fileId)];
		if (!path.length) {
			[strongSelf.overlayRequested removeObject:key];
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *full = TGDecodeThumbnail(path, 640.0f);
			if (!full)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				typeof(self) innerSelf = weakSelf;
				if (!innerSelf || innerSelf.photoOverlay != overlay)
					return;
				CATransition *fade = [CATransition animation];
				fade.duration = 0.2;
				fade.type = kCATransitionFade;
				[page.layer addAnimation:fade forKey:@"photoFade"];
				page.image = full;
			});
		});
	}];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != self.photoScroll || !self.photoOverlay)
		return;
	CGFloat width = scrollView.bounds.size.width;
	if (width < 1)
		return;
	NSInteger page = (NSInteger)floorf((scrollView.contentOffset.x + width / 2) / width);
	if (page < 0)
		page = 0;
	if (page >= self.photoPager.numberOfPages)
		page = self.photoPager.numberOfPages - 1;
	if (page == self.photoPager.currentPage)
		return;
	self.photoPager.currentPage = page;
	[self loadOverlayPagesAroundCurrent];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
										 duration:(NSTimeInterval)duration {
	[super willAnimateRotationToInterfaceOrientation:orientation duration:duration];
	[self layoutPhotoOverlay];
}

- (void)closePhotoOverlay {
	UIView *overlay = self.photoOverlay;
	if (!overlay)
		return;
	self.photoOverlay = nil;
	self.photoScroll.delegate = nil;
	self.photoScroll = nil;
	self.photoPager = nil;
	self.overlayPages = nil;
	self.overlayPhotos = nil;
	self.overlayRequested = nil;
	self.overlayZooming = NO;
	[self cancelOverlayDownloads];
	[UIView animateWithDuration:0.2 animations:^{
		overlay.alpha = 0;
	} completion:^(BOOL done) {
		[overlay removeFromSuperview];
	}];
}

- (void)cancelOverlayDownloads {
	for (NSNumber *fileId in self.overlayDownloads) {
		if ([fileId longLongValue] > 0)
			[TGFileDownloadService cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:NO];
	}
	[self.overlayDownloads removeAllObjects];
}

- (void)photoOverlayLongPressed:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateBegan)
		return;
	NSInteger index = self.photoPager ? (NSInteger)self.photoPager.currentPage : 0;
	if (index < 0 || index >= (NSInteger)self.overlayPhotos.count)
		return;
	NSDictionary *photo = self.overlayPhotos[index];
	long long fileId = [photo[@"fileId"] longLongValue];
	if (fileId <= 0)
		return;
	self.reportPhotoFileId = fileId;

	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"PeerInfo.ReportProfilePhoto", @"Report Photo")
					  delegate:self
				   otherTitles:@[ TGL(@"ReportPeer.ReasonSpam", @"Spam"),
					   TGL(@"ReportPeer.ReasonViolence", @"Violence"),
					   TGL(@"ReportPeer.ReasonPornography", @"Pornography"),
					   TGL(@"ReportPeer.ReasonChildAbuse", @"Child Abuse"),
					   TGL(@"ReportPeer.ReasonCopyright", @"Copyright"),
					   TGL(@"ReportPeer.ReasonUnrelatedLocation", @"Unrelated Location"),
					   TGL(@"ReportPeer.ReasonFake", @"Fake Account"),
					   TGL(@"ReportPeer.ReasonIllegalDrugs", @"Illegal Drugs"),
					   TGL(@"Passport.Identity.TypePersonalDetails", @"Personal Details"),
					   TGL(@"ReportPeer.ReasonOther", @"Other") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 100;
	CGPoint longPressLocation = [recognizer locationInView:self.photoOverlay ?: self.view];
	[sheet tg_showFromRect:CGRectMake(longPressLocation.x, longPressLocation.y, 1, 1) inView:self.photoOverlay ?: self.view];
}

- (void)handleReportPhotoReasonSheetIndex:(NSInteger)index {
	NSArray *reasons = @[ @"spam", @"violence", @"pornography", @"childAbuse", @"copyright",
		@"unrelatedLocation", @"fake", @"illegalDrugs", @"personalDetails", @"custom" ];
	if (index < 0 || index >= (NSInteger)reasons.count) {
		self.reportPhotoFileId = 0;
		return;
	}
	self.reportPhotoReason = reasons[index];
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:nil
				  message:TGL(@"Report.AdditionalDetailsText", @"Add any details for the moderators, or send with just the reason.")
				 delegate:self
		cancelButtonTitle:nil
		otherButtonTitles:TGL(@"PhotoEditor.Skip", @"Skip"), TGL(@"MediaPicker.Send", @"Send"), nil];
	alert.tag = 97;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert show];
}

- (void)handleReportPhotoAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	long long fileId = self.reportPhotoFileId;
	NSString *reason = self.reportPhotoReason;
	self.reportPhotoFileId = 0;
	self.reportPhotoReason = nil;
	if (fileId <= 0)
		return;
	NSString *text = buttonIndex == 1 ? ([alertView textFieldAtIndex:0].text ?: @"") : @"";
	[self sendReportChatPhoto:fileId reason:reason text:text];
}

- (void)sendReportChatPhoto:(long long)fileId reason:(NSString *)reason text:(NSString *)text {
	__weak typeof(self) weakSelf = self;
	void (^send)(int64_t) = ^(int64_t targetChatId) {
		if (!targetChatId) {
			[weakSelf showToast:TGL(@"Toast.CouldNotSendReport", @"Could not send the report")];
			return;
		}
		[TGProfileService reportChatPhoto:targetChatId fileId:fileId reason:reason text:text
							   completion:^(BOOL ok) {
								   [weakSelf showToast:(ok
										   ? TGL(@"Report.Succeed", @"Telegram moderators will study your report. Thank you!")
										   : TGL(@"Toast.CouldNotSendReport", @"Could not send the report"))];
							   }];
	};
	if (self.chatId) {
		send(self.chatId);
		return;
	}
	if (!self.userId) {
		[self showToast:TGL(@"Toast.CouldNotSendReport", @"Could not send the report")];
		return;
	}
	[TGContactsService privateChatWithUser:self.userId completion:^(int64_t chatId) {
		send(chatId);
	}];
}

@end
