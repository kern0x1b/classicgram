#import "TGImageDecode.h"
#import "TGStringTruncation.h"
#import "TGFileDownloadService.h"
#import "TGAccountUsernamesViewController.h"
#import "TGAccountSettingsViewController.h"
#import "TGLocalization.h"
#import "TGNotificationManager.h"
#import "TGSettingsViewController.h"
#import "TGEmoji.h"
#import "RootViewController.h"
#import "TGTheme.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGDevice.h"
#import "TGFoldersViewController.h"
#import "TGProxyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGTabBar.h"
#import "TGSettingsService.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"
#import "TGHexColour.h"

@implementation TGSettingsViewController (Header)

#pragma mark - header

- (void)buildHeader {
	CGFloat width = self.view.bounds.size.width ?: TGSettingsScreenWidth();
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, kHeaderHeight)];
	header.backgroundColor = [UIColor clearColor];
	header.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	NSDictionary *me = [TGSettingsService me];
	NSString *name = [self displayName];

	[self buildHeaderAvatarIn:header forName:name account:me];
	[self buildHeaderNameLabelIn:header width:width name:name];
	[self buildHeaderStatusLabelIn:header width:width];

	if (TGLocalizedIsRTL()) {
		CGAffineTransform mirror = CGAffineTransformMakeScale(-1, 1);
		self.avatarView.transform = mirror;
		self.headerNameLabel.transform = mirror;
		self.headerStatusLabel.transform = mirror;
	}

	self.tableView.tableHeaderView = header;
	[self refreshHeader];
}

- (void)buildHeaderAvatarIn:(UIView *)header
					forName:(NSString *)name
					account:(NSDictionary *)me {
	CGFloat inset = TGSettingsGroupedInset(header.bounds.size.width);
	self.avatarView = [[UIImageView alloc] initWithFrame:
			CGRectMake(9 + inset, 14, kHeaderAvatar, kHeaderAvatar)];
	self.avatarView.layer.cornerRadius = 10.0f;
	self.avatarView.clipsToBounds = YES;
	self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
	NSString *initials = [self initialsForName:name];
	long long colourId = [me[@"id"] longLongValue];
	self.avatarView.image = [TGIcons avatarWithInitials:initials size:kHeaderAvatar colourId:colourId];
	self.avatarView.userInteractionEnabled = YES;
	self.avatarView.exclusiveTouch = YES;
	UITapGestureRecognizer *tap = [UITapGestureRecognizer alloc];
	tap = [tap initWithTarget:self action:@selector(changePhotoButtonPressed)];
	[self.avatarView addGestureRecognizer:tap];
	[header addSubview:self.avatarView];
}

- (void)buildHeaderNameLabelIn:(UIView *)header
						 width:(CGFloat)width
						  name:(NSString *)name {
	CGFloat inset = TGSettingsGroupedInset(width);
	UILabel *nameLabel = [[TGEmojiLabel alloc] initWithFrame:
			CGRectMake(94 + inset, 24, MAX(20.0f, width - 94 - 9 - inset * 2), 24)];
	nameLabel.text = name;
	nameLabel.font = [UIFont boldSystemFontOfSize:19];
	nameLabel.textColor = TGColourFromHex(0x222932);
	nameLabel.backgroundColor = [UIColor clearColor];
	nameLabel.shadowColor = [UIColor colorWithRed:0xed / 255.0f green:0xf0 / 255.0f
											 blue:0xf5 / 255.0f
											alpha:0.28f];
	nameLabel.shadowOffset = CGSizeMake(0, 1);
	nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[header addSubview:nameLabel];
	self.headerNameLabel = nameLabel;
}

- (void)buildHeaderStatusLabelIn:(UIView *)header
						   width:(CGFloat)width {
	CGFloat inset = TGSettingsGroupedInset(width);
	UILabel *status = [[UILabel alloc] initWithFrame:
			CGRectMake(94 + inset, 52, MAX(20.0f, width - 94 - 9 - inset * 2), 24)];
	status.text = TGL(@"Presence.online", @"online");
	status.font = [UIFont systemFontOfSize:14];
	status.textColor = TGColourFromHex(0x6d7d90);
	status.backgroundColor = [UIColor clearColor];
	status.shadowColor = self.headerNameLabel.shadowColor;
	status.shadowOffset = CGSizeMake(0, 1);
	status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[header addSubview:status];
	self.headerStatusLabel = status;
}

- (NSString *)displayName {
	NSDictionary *me = [TGSettingsService me];
	NSMutableString *name = [NSMutableString string];
	if ([me[@"first_name"] isKindOfClass:[NSString class]])
		[name appendString:me[@"first_name"]];
	if ([me[@"last_name"] isKindOfClass:[NSString class]] && [me[@"last_name"] length]) {
		if (name.length)
			[name appendString:@" "];
		[name appendString:me[@"last_name"]];
	}
	if (name.length)
		return name;
	if ([me[@"username"] isKindOfClass:[NSString class]] && [me[@"username"] length])
		return me[@"username"];
	return TGL(@"Tour.Title1", @"Telegram");
}

- (NSString *)initialsForName:(NSString *)name {
	NSString *source = name.length ? name : TGL(@"Tour.Title1", @"Telegram");
	return [TGSafeFirstCharacter(source) uppercaseString];
}

- (void)refreshHeader {
	if (!self.headerNameLabel)
		return;

	NSDictionary *me = [TGSettingsService me];
	int64_t userId = [me[@"id"] longLongValue];
	NSString *name = [self displayName];
	self.headerNameLabel.text = name;

	NSString *connection = [TGSettingsService connectionStateTitleForState:
			[TGSettingsService connectionState]];
	if (connection.length) {
		self.headerStatusLabel.text = [connection lowercaseString];
	} else if (!userId) {
		self.headerStatusLabel.text = TGL(@"State.connecting", @"connecting...");
	} else {
		self.headerStatusLabel.text = TGL(@"Presence.online", @"online");
	}

	NSNumber *fileId = [TGSettingsService photoFileIdForUserId:userId];
	if (!fileId) {
		NSString *initials = [self initialsForName:name];
		self.avatarView.image = [TGIcons avatarWithInitials:initials size:kHeaderAvatar colourId:userId];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId.longLongValue completion:^(NSString *path) {
		if (!path.length)
			return;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *photo = nil;
			@autoreleasepool {
				photo = TGDecodeSquareThumbnail(path, kHeaderAvatar);
			}
			if (!photo)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.avatarView.image = photo;
			});
		});
	}];
}

- (void)applyBottomBarInset {
	CGFloat bottom = 7;
	id tabs = self.tabBarController;
	if ([tabs isKindOfClass:[RootViewController class]]) {
		CGFloat tabBarInset = [(RootViewController *)tabs tabBarInsetForController:self];
		if (tabBarInset > 0)
			bottom = tabBarInset;
	}

	UIEdgeInsets insets = self.tableView.contentInset;
	if (insets.bottom == bottom &&
		self.tableView.scrollIndicatorInsets.bottom == bottom)
		return;
	insets.bottom = bottom;
	self.tableView.contentInset = insets;
	self.tableView.scrollIndicatorInsets = insets;
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	if (self.page == TGSettingsPageRoot)
		[self applyBottomBarInset];
	[self layoutHeaderForWidth:self.tableView.bounds.size.width];
}

- (void)layoutHeaderForWidth:(CGFloat)width {
	UIView *header = self.tableView.tableHeaderView;
	if (!header || !self.headerNameLabel || width <= 0)
		return;
	if (fabs(header.bounds.size.width - width) > 0.5f)
		header.frame = CGRectMake(0, 0, width, kHeaderHeight);
	CGFloat inset = TGSettingsGroupedInset(width);
	self.avatarView.frame = CGRectMake(9 + inset, 14, kHeaderAvatar, kHeaderAvatar);
	CGFloat labelWidth = MAX(20.0f, width - 94 - 9 - inset * 2);
	self.headerNameLabel.frame = CGRectMake(94 + inset, 24, labelWidth, 24);
	self.headerStatusLabel.frame = CGRectMake(94 + inset, 52, labelWidth, 24);
}

- (void)buildVersionFooter {
	NSDictionary *info = [NSBundle mainBundle].infoDictionary;
	UILabel *label = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width ?: TGSettingsScreenWidth(), 40)];
	label.text = [NSString stringWithFormat:TGL(@"Settings.TelegramArmv7", @"Telegram %@ (%@) armv7"),
		info[@"CFBundleShortVersionString"] ?: @"", info[@"CFBundleVersion"] ?: @""];
	label.font = [UIFont systemFontOfSize:14];
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = TGColourFromHex(0x697487);
	label.backgroundColor = [UIColor clearColor];
	label.shadowColor = TGColourFromHex(0xdae0e8);
	label.shadowOffset = CGSizeMake(0, 1);
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = label;
}

static inline CGFloat TGSettingsRetinaPixel(void) {
	return [[UIScreen mainScreen] scale] > 1.0f ? 0.5f : 1.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if (self.page == TGSettingsPageRoot)
		return [self rootKindForSection:section] == TGSettingsRootKindPhoto && self.tableView.isEditing ? (18 + 12) : 12;
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	if (!title.length)
		return 12;
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (self.page == TGSettingsPageRoot)
		return nil;
	TGTheme *theme = [TGTheme shared];
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	UIView *header = [theme groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
	TGApplyRTLHeaderMirroring(header);
	return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (caption.length)
		return [self commentHeightForCaption:caption];
	if (self.page == TGSettingsPageRoot)
		return 1 + TGSettingsRetinaPixel();
	return 1;
}

- (CGFloat)commentHeightForCaption:(NSString *)caption {
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.tableView.bounds.size.width ?: TGSettingsScreenWidth();
	return [theme groupedCommentHeightForText:caption width:width];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.tableView.bounds.size.width ?: TGSettingsScreenWidth();
	UIView *footer = [theme groupedCommentViewWithText:caption width:width];
	TGApplyRTLHeaderMirroring(footer);
	return footer;
}

@end
