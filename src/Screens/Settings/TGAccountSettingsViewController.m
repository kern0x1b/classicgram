#import "TGSnackbar.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGActionSheet.h"
#import "TGSettingValueText.h"
#import "TGFriendlyError.h"
#import "TGAccountSettingsViewController.h"
#import "TGAccountUsernamesViewController.h"
#import "TGImageDecode.h"
#import "TGLocalization.h"
#import "TGNotificationManager.h"
#import "TGSettingsViewController.h"
#import "TGEmoji.h"
#import "RootViewController.h"
#import "TGTheme.h"
#import "TGDeviceViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGDevice.h"
#import "TGQRCodeViewController.h"
#import "TGFoldersViewController.h"
#import "TGProxyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGColourViewController.h"
#import "TGEmojiStatusPickerViewController.h"
#import "TGPremiumViewController.h"
#import "TGClient+Premium.h"
#import "TGProfileAudioViewController.h"
#import "TGPrivacyViewController.h"
#import "TGTabBar.h"
#import "TGClient+ChatList.h"
#import "TGClient+Account.h"
#import "TGClient+UserStatus.h"
#import "TGClient+Notifications.h"
#import "TGClient+Contacts.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+SafeTint.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGResendCountdown.h"

@implementation TGAccountSettingsViewController

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		self.title = TGL(@"Settings.MyAccount", @"Account");
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[self reload];

	__weak typeof(self) weakSelf = self;
	self.userProfileObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUserProfileDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGAccountSettingsViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					int64_t myUserId = [[TGClient shared].me[@"id"] longLongValue];
					if (!myUserId || [note.userInfo[@"userId"] longLongValue] != myUserId)
						return;
					[strongSelf reloadEmojiStatus];
				}];
}

- (void)dealloc {
	[_numberCodeResendCountdown stop];
	if (_userProfileObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_userProfileObserverToken];
}

- (void)reload {
	[self reloadAccountInfo];
	[self reloadProfileFields];
	[self reloadUsernames];
	[self reloadPublicLink];
	[self reloadPhotos];
	[self reloadColour];
	[self reloadEmojiStatus];
}

- (void)reloadColour {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] myAccentColorsWithCompletion:^(NSDictionary *colors) {
		typeof(self) strongSelf = weakSelf;
		if (![colors isKindOfClass:[NSDictionary class]] || !strongSelf)
			return;
		NSInteger colorId = [colors[@"colorId"] integerValue];
		NSInteger safeColorId = colorId < 0 ? 0 : colorId % 7;
		NSString *colourName = nil;
		switch (safeColorId) {
			case 0: colourName = TGL(@"Misc.ColourNameRed", @"Red"); break;
			case 1: colourName = TGL(@"Misc.ColourNameOrange", @"Orange"); break;
			case 2: colourName = TGL(@"Misc.ColourNameViolet", @"Violet"); break;
			case 3: colourName = TGL(@"Misc.ColourNameGreen", @"Green"); break;
			case 4: colourName = TGL(@"Misc.ColourNameCyan", @"Cyan"); break;
			case 5: colourName = TGL(@"Misc.ColourNameBlue", @"Blue"); break;
			default: colourName = TGL(@"Misc.ColourNamePink", @"Pink"); break;
		}
		strongSelf.colourDetail = colourName;
		[strongSelf.tableView reloadData];
	}];
}

- (void)reloadEmojiStatus {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] accountInfoWithCompletion:^(NSDictionary *account) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		int64_t myUserId = [account[@"id"] longLongValue];
		[[TGClient shared] emojiStatusForUser:myUserId completion:^(NSDictionary *status) {
			typeof(self) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			NSString *glyph = [status[@"emoji"] isKindOfClass:[NSString class]]
				? status[@"emoji"]
				: nil;
			innerSelf.emojiStatusDetail = glyph.length ? glyph : TGL(@"Stickers.SuggestNone", @"None");
			[innerSelf.tableView reloadData];
		}];
	}];
}

- (void)reloadAccountInfo {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] accountInfoWithCompletion:^(NSDictionary *info) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![info isKindOfClass:[NSDictionary class]])
			return;
		strongSelf.account = info;
		[strongSelf.tableView reloadData];
		NSString *phone = [info[@"phoneNumber"] isKindOfClass:[NSString class]]
			? info[@"phoneNumber"]
			: nil;
		if (!phone.length)
			return;
		[[TGClient shared] phoneNumberInfo:phone completion:^(NSDictionary *number) {
			__strong typeof(weakSelf) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (![number isKindOfClass:[NSDictionary class]])
				return;
			NSString *formatted = [number[@"formatted"] isKindOfClass:[NSString class]]
				? number[@"formatted"]
				: phone;
			NSString *country = [number[@"countryName"] isKindOfClass:[NSString class]]
				? number[@"countryName"]
				: nil;
			NSString *calling = [number[@"callingCode"] isKindOfClass:[NSString class]]
				? number[@"callingCode"]
				: nil;
			NSString *dialled = calling.length
				? [NSString stringWithFormat:@"+%@ %@", calling, formatted]
				: [NSString stringWithFormat:@"+%@", formatted];
			innerSelf.phoneDetail = country.length
				? [NSString stringWithFormat:@"%@ (%@)", dialled, country]
				: dialled;
			[innerSelf.tableView reloadData];
		}];
	}];
}

- (void)reloadProfileFields {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] profileInfoWithCompletion:^(NSDictionary *info) {
		if (![info isKindOfClass:[NSDictionary class]])
			return;
		NSInteger day = [info[@"birthdayDay"] integerValue];
		NSInteger month = [info[@"birthdayMonth"] integerValue];
		NSInteger year = [info[@"birthdayYear"] integerValue];
		if (day > 0 && month > 0)
			weakSelf.birthdayText = year > 0
				? [NSString stringWithFormat:@"%02ld.%02ld.%04ld",
					  (long)day, (long)month, (long)year]
				: [NSString stringWithFormat:@"%02ld.%02ld", (long)day, (long)month];
		else
			weakSelf.birthdayText = nil;
		[weakSelf.tableView reloadData];

		int64_t personal = [info[@"personalChatId"] longLongValue];
		if (!personal) {
			weakSelf.personalChatTitle = nil;
			return;
		}
		[[TGClient shared] titleForChatId:personal completion:^(NSString *title) {
			weakSelf.personalChatTitle = [title isKindOfClass:[NSString class]]
				? title
				: nil;
			[weakSelf.tableView reloadData];
		}];
	}];
}

- (void)reloadUsernames {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] usernamesWithCompletion:^(NSDictionary *info) {
		weakSelf.usernames = [info isKindOfClass:[NSDictionary class]] ? info : nil;
		[weakSelf.tableView reloadData];
	}];
}

- (void)reloadPublicLink {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] publicLinkWithCompletion:^(NSString *url, NSInteger expiresIn) {
		weakSelf.publicLink = [url isKindOfClass:[NSString class]] ? url : nil;
		weakSelf.publicLinkExpiry = expiresIn;
		[weakSelf.tableView reloadData];
	}];
}

- (void)reloadPhotos {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] profilePhotosWithCompletion:^(NSArray *photos, BOOL failed) {
		if (!failed)
			weakSelf.photos = [photos isKindOfClass:[NSArray class]] ? photos : @[];
		weakSelf.photosLoaded = !failed;
		weakSelf.photosFailed = failed;
		[weakSelf.tableView reloadData];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 4;
	if (section == 1)
		return 6;
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 1)
		return TGL(@"Settings.ProfileHeader", @"Profile");
	if (section == 2)
		return TGL(@"CheckoutInfo.ReceiverInfoEmail", @"Email");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [theme groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"Settings.PublicLinkFooter",
				   @"The link is how people reach you without knowing your number. "
				   @"Tap it to put it on the clipboard.");
	if (section == 2)
		return TGL(@"Settings.LoginEmailFooter",
				   @"The login email is asked for when signing in on a new device. "
				   @"The second row only proves that an address is yours.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	CGFloat measured = [theme groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (NSString *)usernameDetail {
	if (![self.usernames isKindOfClass:[NSDictionary class]])
		return @"...";
	NSString *editable = [self.usernames[@"editable"] isKindOfClass:[NSString class]]
		? self.usernames[@"editable"]
		: @"";
	NSArray *active = [self.usernames[@"active"] isKindOfClass:[NSArray class]]
		? self.usernames[@"active"]
		: @[];
	if (!editable.length && !active.count)
		return TGL(@"Stickers.SuggestNone", @"None");
	NSString *head = editable.length ? [NSString stringWithFormat:@"@%@", editable]
									 : [NSString stringWithFormat:@"@%@", active[0]];
	if (active.count > 1)
		return [NSString stringWithFormat:@"%@ +%lu", head,
			(unsigned long)(active.count - 1)];
	return head;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGAccountCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.detailTextLabel.text = @"";
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];

	if (indexPath.section == 0) {
		[self fillIdentityCell:cell atRow:indexPath.row];
		return cell;
	}

	if (indexPath.section == 1) {
		[self fillProfileCell:cell atRow:indexPath.row];
		return cell;
	}

	cell.textLabel.text = indexPath.row == 0 ? TGL(@"PrivacySettings.LoginEmail", @"Login E-Mail")
											 : TGL(@"LoginEmail.Title", @"Add Email");
	return cell;
}

- (void)fillIdentityCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	if (row == 0) {
		cell.textLabel.text = TGL(@"Contacts.SortByName", @"Name");
		NSString *name = [self.account[@"name"] isKindOfClass:[NSString class]]
			? self.account[@"name"]
			: nil;
		cell.detailTextLabel.text = name.length ? name : @"...";
	} else if (row == 1) {
		cell.textLabel.text = TGL(@"Contacts.PhoneNumber", @"Phone Number");
		cell.detailTextLabel.text = self.phoneDetail.length ? self.phoneDetail : @"...";
	} else if (row == 2) {
		cell.textLabel.text = TGL(@"Username.Title", @"Username");
		cell.detailTextLabel.text = [self usernameDetail];
	} else {
		cell.textLabel.text = TGL(@"GroupInfo.PublicLink", @"Public Link");
		if (!self.publicLink.length)
			cell.detailTextLabel.text = @"...";
		else if (self.publicLinkExpiry > 0)
			cell.detailTextLabel.text = [NSString stringWithFormat:TGL(@"InviteLink.ExpiresIn", @"expires in %@"),
				[NSString stringWithFormat:@"%ld min", (long)(self.publicLinkExpiry / 60)]];
		else
			cell.detailTextLabel.text = self.publicLink;
	}
}

- (void)markDisclosure:(UITableViewCell *)cell {
	UIImage *art = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator.png"]);
	if (!art) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return;
	}
	UIImageView *view = [UIImageView alloc];
	view = [view initWithImage:art
			  highlightedImage:[UIImage imageNamed:
									   @"MenuDisclosureIndicator_Highlighted.png"]];
	view.frame = CGRectMake(0, 0, art.size.width, art.size.height);
	cell.accessoryView = view;
	cell.accessoryType = UITableViewCellAccessoryNone;
}

- (void)fillProfileCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	if (row == 0) {
		cell.textLabel.text = TGL(@"Settings.ProfilePhotos", @"Profile Photos");
		cell.detailTextLabel.text = TGSettingValueText(self.photosLoaded, self.photosFailed,
				[NSString stringWithFormat:@"%lu", (unsigned long)self.photos.count]);
	} else if (row == 1) {
		cell.textLabel.text = TGL(@"Settings.Birthday", @"Birthday");
		cell.detailTextLabel.text = self.birthdayText.length
			? self.birthdayText
			: TGL(@"AutoDownloadSettings.NotSet", @"Not set");
	} else if (row == 2) {
		cell.textLabel.text = TGL(@"Settings.PersonalChannelItem", @"Channel");
		cell.detailTextLabel.text = self.personalChatTitle.length
			? self.personalChatTitle
			: TGL(@"Stickers.SuggestNone", @"None");
	} else if (row == 3) {
		cell.textLabel.text = TGL(@"NameColor.Title.Account", @"Your Name Color");
		cell.detailTextLabel.text = self.colourDetail.length ? self.colourDetail : @"...";
		[self markDisclosure:cell];
	} else if (row == 4) {
		cell.textLabel.text = TGL(@"Premium.EmojiStatus", @"Emoji Status");
		cell.detailTextLabel.text = self.emojiStatusDetail.length ? self.emojiStatusDetail : @"...";
		[self markDisclosure:cell];
	} else {
		cell.textLabel.text = TGL(@"Attachment.ProfileMusic", @"Profile Music");
		[self markDisclosure:cell];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 0) {
		[self tapIdentityRow:indexPath.row];
		return;
	}

	if (indexPath.section == 1) {
		[self tapProfileRow:indexPath.row];
		return;
	}

	if (indexPath.section == 2) {
		UIAlertView *alert = [[TGAlertView alloc]
				initWithTitle:
					(indexPath.row == 0 ? TGL(@"PrivacySettings.LoginEmail", @"Login E-Mail") : TGL(@"LoginEmail.Title", @"Add Email"))
					  message:TGL(@"LoginEmail.Description", @"Please add your email address to keep access to your account.")
					 delegate:self
			cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			otherButtonTitles:TGL(@"Common.Next", @"Next"), nil];
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeEmailAddress;
		alert.tag = indexPath.row == 0 ? 4 : 6;
		[alert show];
	}
}

- (void)tapIdentityRow:(NSInteger)row {
	if (row == 0) {
		UIAlertView *alert = [[TGAlertView alloc]
				initWithTitle:TGL(@"EditProfile.Title", @"Edit Profile")
					  message:nil
					 delegate:self
			cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		NSString *name = [self.account[@"name"] isKindOfClass:[NSString class]]
			? self.account[@"name"]
			: @"";
		[alert textFieldAtIndex:0].text = name;
		alert.tag = 1;
		[alert show];
		return;
	}
	if (row == 1) {
		[self beginChangeNumber];
		return;
	}
	if (row == 2) {
		[self pushUsernamesScreen];
		return;
	}
	if (!self.publicLink.length)
		return;
	TGQRCodeViewController *code = [[TGQRCodeViewController alloc]
		initWithLink:self.publicLink
			 caption:nil];
	if (self.navigationController)
		[self.navigationController pushViewController:code animated:YES];
	else
		[UIPasteboard generalPasteboard].string = self.publicLink;
}

- (void)tapProfileRow:(NSInteger)row {
	if (row == 0) {
		NSInteger cancelIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:TGL(@"Privacy.ProfilePhoto", @"Profile Photo")
						  delegate:self
					   otherTitles:@[ TGL(@"Media.ChooseFromGallery", @"Choose from Library"),
						   TGL(@"Privacy.ProfilePhoto.SetPublicPhoto", @"Set Public Photo"),
						   TGL(@"Login.InfoDeletePhoto", @"Remove Photo") ]
				  destructiveIndex:2
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:NULL
				 cancelButtonIndex:&cancelIndex];
		sheet.tag = 11;
		[self showSheet:sheet];
		return;
	}
	if (row == 1) {
		NSInteger cancelIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:TGL(@"Settings.Birthday", @"Birthday")
						  delegate:self
					   otherTitles:@[ TGL(@"Settings.Birthday.Add", @"Set My Birthday"),
						   TGL(@"Settings.Birthday.Remove", @"Remove My Birthday") ]
				  destructiveIndex:1
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:NULL
				 cancelButtonIndex:&cancelIndex];
		sheet.tag = 12;
		[self showSheet:sheet];
		return;
	}
	if (row == 2) {
		[self showPersonalChatSheet];
		return;
	}
	if (row == 3) {
		if (self.navigationController)
			[self.navigationController pushViewController:[[TGColourViewController alloc] init]
												 animated:YES];
		return;
	}
	if (row == 4) {
		if (!self.navigationController)
			return;
		UIViewController *destination = [[TGClient shared] isPremiumAccount]
			? (UIViewController *)[[TGEmojiStatusPickerViewController alloc] init]
			: (UIViewController *)[[TGPremiumViewController alloc] init];
		[self.navigationController pushViewController:destination animated:YES];
		return;
	}
	if (self.navigationController)
		[self.navigationController pushViewController:
				[[TGProfileAudioViewController alloc] init]
											 animated:YES];
}

- (void)pushUsernamesScreen {
	NSArray *active = [self.usernames[@"active"] isKindOfClass:[NSArray class]]
		? self.usernames[@"active"]
		: @[];
	NSArray *disabled = [self.usernames[@"disabled"] isKindOfClass:[NSArray class]]
		? self.usernames[@"disabled"]
		: @[];
	NSString *editable = [self.usernames[@"editable"] isKindOfClass:[NSString class]]
		? self.usernames[@"editable"]
		: @"";
	TGAccountUsernamesViewController *screen = [[TGAccountUsernamesViewController alloc]
		initWithActiveUsernames:active
			  disabledUsernames:disabled
			   editableUsername:editable];
	__weak typeof(self) weakSelf = self;
	screen.onChanged = ^(NSArray *newActive, NSArray *newDisabled) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.usernames = @{@"editable" : editable,
			@"active" : newActive ?: @[],
			@"disabled" : newDisabled ?: @[]};
		[strongSelf.tableView reloadData];
	};
	if (self.navigationController)
		[self.navigationController pushViewController:screen animated:YES];
}

- (void)showPersonalChatSheet {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] suitablePersonalChatsWithCompletion:^(NSArray *chats, BOOL failed) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.isViewLoaded || !strongSelf.view.window)
			return;
		if (failed) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotLoadPersonalChats", @"The chats you could show on your profile could not be read")
						   seconds:2
						  onCommit:nil];
			return;
		}
		NSMutableArray *picks = [NSMutableArray array];
		for (id chat in ([chats isKindOfClass:[NSArray class]] ? chats : @[])) {
			if (![chat isKindOfClass:[NSDictionary class]])
				continue;
			[picks addObject:chat];
			if (picks.count >= 8)
				break;
		}
		[strongSelf showPersonalChatSheetWithPicks:picks];
	}];
}

- (void)showPersonalChatSheetWithPicks:(NSArray *)picks {
	self.chatPicks = picks;

	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *chat in picks) {
		NSString *title = [chat[@"title"] isKindOfClass:[NSString class]]
			? chat[@"title"]
			: TGL(@"ChatList.UnnamedChat", @"Chat");
		[titles addObject:title];
	}
	[titles addObject:TGL(@"Stickers.SuggestNone", @"None")];
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Settings.PersonalChannelItem", @"Channel")
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 13;
	[self showSheet:sheet];
}

- (void)beginChangeNumber {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] guessedCountryCodeWithCompletion:^(NSString *countryCode) {
		if (!countryCode.length) {
			[weakSelf askForNewNumberPrefilled:@"+"];
			return;
		}
		[[TGClient shared] countriesWithCompletion:^(NSArray *countries) {
			NSString *prefill = @"+";
			for (NSDictionary *country in countries) {
				if (![country isKindOfClass:[NSDictionary class]])
					continue;
				if (![country[@"code"] isKindOfClass:[NSString class]] || ![country[@"code"] isEqualToString:countryCode])
					continue;
				NSArray *calling = [country[@"callingCodes"] isKindOfClass:[NSArray class]]
					? country[@"callingCodes"]
					: nil;
				if (calling.count && [calling[0] isKindOfClass:[NSString class]])
					prefill = [NSString stringWithFormat:@"+%@", calling[0]];
				break;
			}
			[weakSelf askForNewNumberPrefilled:prefill];
		}];
	}];
}

- (void)askForNewNumberPrefilled:(NSString *)prefill {
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"ChangePhoneNumberNumber.Title", @"Change Number")
				  message:TGL(@"ChangePhoneNumberNumber.Help", @"We will send an SMS with a confirmation code to your new number.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Next", @"Next"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].keyboardType = UIKeyboardTypePhonePad;
	[alert textFieldAtIndex:0].text = prefill;
	alert.tag = 2;
	[alert show];
}

- (void)askForCodeWithTag:(NSInteger)tag description:(NSString *)description {
	[self askForCodeWithTag:tag description:description allowResend:YES];
}

- (NSString *)numberCodeResendButtonTitle {
	return self.numberCodeNextTitle.length ? self.numberCodeNextTitle : TGL(@"Conversation.MessageDialogRetry", @"Resend");
}

- (void)askForCodeWithTag:(NSInteger)tag description:(NSString *)description allowResend:(BOOL)allowResend {
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"Login.EnterCodeSMSTitle", @"Confirmation Code")
				  message:description.length ? description : TGL(@"ChangePhoneNumberCode.Help", @"We have sent you an SMS with the code")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumbersAndPunctuation;
	[alert addButtonWithTitle:TGL(@"SensitiveContent.Enable.Confirm", @"Confirm")];
	if (allowResend)
		[alert addButtonWithTitle:tag == 3 ? [self numberCodeResendButtonTitle] : TGL(@"Conversation.MessageDialogRetry", @"Resend")];
	if (tag == 3)
		[alert addButtonWithTitle:TGL(@"Login.HaveNotReceivedCodeInternal", @"Didn't get the code?")];
	alert.tag = tag;
	[alert show];
}

- (void)stopNumberCodeCountdown {
	[self.numberCodeResendCountdown stop];
	self.numberCodeResendCountdown = nil;
	self.numberCodeResendSeconds = 0;
}

- (void)beginNumberCodeCountdownWithSeconds:(NSInteger)seconds {
	[self.numberCodeResendCountdown stop];
	self.numberCodeResendCountdown = nil;
	self.numberCodeResendSeconds = seconds > 0 ? seconds : 0;
	if (seconds <= 0)
		return;
	__weak typeof(self) weakSelf = self;
	TGResendCountdown *countdown = [[TGResendCountdown alloc] init];
	countdown.onTick = ^(NSInteger secondsRemaining) {
		weakSelf.numberCodeResendSeconds = secondsRemaining;
	};
	countdown.onFinished = ^{
		weakSelf.numberCodeResendSeconds = 0;
	};
	self.numberCodeResendCountdown = countdown;
	[countdown startWithSeconds:seconds];
}

- (void)reportResult:(BOOL)ok title:(NSString *)title
			 success:(NSString *)success
			 failure:(NSString *)failure {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:title
						 message:(ok ? success : failure)delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex) {
		if (alertView.tag == 3)
			[self stopNumberCodeCountdown];
		return;
	}
	NSString *typed = alertView.alertViewStyle == UIAlertViewStylePlainTextInput
		? [alertView textFieldAtIndex:0].text
		: @"";
	typed = [typed stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceCharacterSet]];

	if (alertView.tag == 1) {
		[self submitTypedName:typed];
		return;
	}

	if (alertView.tag == 2) {
		[self submitTypedNumber:typed];
		return;
	}

	if (alertView.tag == 3) {
		[self submitTypedNumberCode:typed
						  fromAlert:alertView
							atIndex:buttonIndex];
		return;
	}

	if (alertView.tag == 4 || alertView.tag == 6) {
		[self submitTypedEmail:typed login:(alertView.tag == 4)];
		return;
	}

	if (alertView.tag == 5 || alertView.tag == 7) {
		[self submitTypedEmailCode:typed
							 login:(alertView.tag == 5)
						 fromAlert:alertView
						   atIndex:buttonIndex];
		return;
	}
}

- (void)submitTypedName:(NSString *)typed {
	if (!typed.length)
		return;
	__weak typeof(self) weakSelf = self;
	NSRange space = [typed rangeOfString:@" "];
	NSString *first = space.location == NSNotFound
		? typed
		: [typed substringToIndex:space.location];
	NSString *last = space.location == NSNotFound
		? @""
		: [typed substringFromIndex:space.location + 1];
	[[TGClient shared] setFirstName:first lastName:last completion:^(BOOL ok) {
		if (ok)
			[weakSelf reload];
		else
			[weakSelf reportResult:NO title:TGL(@"EditProfile.Title", @"Edit Profile") success:nil
						   failure:TGL(@"Settings.TelegramWouldNotTakeThatName", @"Telegram would not take that name.")];
	}];
}

- (void)submitTypedNumber:(NSString *)typed {
	if (!typed.length)
		return;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client sendChangePhoneNumberCode:typed completion:^(NSDictionary *info, NSString *errorMessage) {
		if (![info isKindOfClass:[NSDictionary class]]) {
			NSString *failure = TGFriendlyErrorText(errorMessage, TGL(@"Settings.ThatNumberWasRefused", @"That number was refused."));
			if ([errorMessage isEqualToString:@"PHONE_NUMBER_OCCUPIED"])
				failure = TGL(@"Settings.PhoneNumberOccupied", @"Sorry, this phone number is already being used for a different account.");
			else if ([errorMessage isEqualToString:@"PHONE_NUMBER_INVALID"])
				failure = TGL(@"Settings.PhoneNumberInvalid", @"Invalid phone number. Please check the number and try again.");
			[weakSelf reportResult:NO title:TGL(@"Settings.PhoneNumber", @"Change Number") success:nil
						   failure:failure];
			return;
		}
		NSString *text = [info[@"description"] isKindOfClass:[NSString class]]
			? info[@"description"]
			: nil;
		weakSelf.numberCodeDescription = text;
		weakSelf.numberCodeNextTitle = [info[@"nextDescription"] isKindOfClass:[NSString class]]
			? info[@"nextDescription"]
			: nil;
		[weakSelf beginNumberCodeCountdownWithSeconds:[info[@"timeout"] integerValue]];
		[weakSelf askForCodeWithTag:3 description:text allowResend:weakSelf.numberCodeResendSeconds <= 0];
	}];
}

- (void)submitTypedNumberCode:(NSString *)typed
					fromAlert:(UIAlertView *)alertView
					  atIndex:(NSInteger)buttonIndex {
	__weak typeof(self) weakSelf = self;
	NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
	if ([title isEqualToString:[self numberCodeResendButtonTitle]]) {
		if (self.numberCodeResendSeconds > 0) {
			[weakSelf askForCodeWithTag:3 description:weakSelf.numberCodeDescription allowResend:NO];
			return;
		}
		[[TGClient shared] resendChangePhoneNumberCodeWithCompletion:
				^(NSDictionary *info) {
					if (![info isKindOfClass:[NSDictionary class]]) {
						[weakSelf reportResult:NO title:TGL(@"Settings.PhoneNumber", @"Change Number") success:nil
									   failure:TGL(@"PrivacySettings.CodeCouldNotBeSentAgain", @"The code could not be sent again.")];
						return;
					}
					NSString *text = [info[@"description"] isKindOfClass:[NSString class]]
						? info[@"description"]
						: nil;
					weakSelf.numberCodeDescription = text;
					weakSelf.numberCodeNextTitle = [info[@"nextDescription"] isKindOfClass:[NSString class]]
						? info[@"nextDescription"]
						: nil;
					[weakSelf beginNumberCodeCountdownWithSeconds:[info[@"timeout"] integerValue]];
					[weakSelf askForCodeWithTag:3 description:text allowResend:weakSelf.numberCodeResendSeconds <= 0];
				}];
		return;
	}
	if ([title isEqualToString:TGL(@"Login.HaveNotReceivedCodeInternal", @"Didn't get the code?")]) {
		TGClient *client = [TGClient shared];
		[client reportChangePhoneNumberCodeMissing:nil completion:^(BOOL ok, NSString *errorMessage) {
			[weakSelf reportResult:ok title:TGL(@"Settings.PhoneNumber", @"Change Number")
						   success:TGL(@"Settings.TelegramWasToldTheCodeNeverArrived", @"Telegram was told the code never arrived.")
						   failure:TGFriendlyErrorText(errorMessage, TGL(@"Settings.TelegramWouldNotTakeThatReport", @"Telegram would not take that report."))];
		}];
		return;
	}
	if (!typed.length)
		return;
	[[TGClient shared] checkChangePhoneNumberCode:typed completion:^(BOOL ok, NSString *errorMessage) {
		if (ok) {
			[weakSelf stopNumberCodeCountdown];
			[weakSelf reload];
			[weakSelf reportResult:YES title:TGL(@"Settings.PhoneNumber", @"Change Number")
						   success:TGL(@"Settings.TheAccountIsOnTheNewNumber", @"The account is on the new number.")
						   failure:nil];
			return;
		}
		[weakSelf reportResult:NO title:TGL(@"Settings.PhoneNumber", @"Change Number") success:nil
					   failure:TGFriendlyErrorText(errorMessage, TGL(@"Settings.ThatCodeWasNotAccepted", @"That code was not accepted."))];
	}];
}

- (void)submitTypedEmail:(NSString *)typed login:(BOOL)login {
	if (!typed.length)
		return;
	__weak typeof(self) weakSelf = self;
	void (^sent)(NSString *, NSInteger) = ^(NSString *pattern, NSInteger length) {
		if (!pattern.length) {
			[weakSelf reportResult:NO title:TGL(@"CheckoutInfo.ReceiverInfoEmail", @"Email") success:nil
						   failure:TGL(@"Settings.ThatAddressWasRefused", @"That address was refused.")];
			return;
		}
		[weakSelf askForCodeWithTag:(login ? 5 : 7)
						description:[NSString stringWithFormat:
											TGL(@"Settings.CodeCharacterCountSentTo", @"A %ld-character code went to %@."),
										(long)length, pattern]];
	};
	if (login)
		[[TGClient shared] setLoginEmailAddress:typed completion:sent];
	else
		[[TGClient shared] sendEmailAddressVerificationCode:typed completion:sent];
}

- (void)submitTypedEmailCode:(NSString *)typed
					   login:(BOOL)login
				   fromAlert:(UIAlertView *)alertView
					 atIndex:(NSInteger)buttonIndex {
	__weak typeof(self) weakSelf = self;
	NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
	void (^sent)(NSString *, NSInteger) = ^(NSString *pattern, NSInteger length) {
		if (!pattern.length) {
			[weakSelf reportResult:NO title:TGL(@"CheckoutInfo.ReceiverInfoEmail", @"Email") success:nil
						   failure:TGL(@"PrivacySettings.CodeCouldNotBeSentAgain", @"The code could not be sent again.")];
			return;
		}
		[weakSelf askForCodeWithTag:(login ? 5 : 7)
						description:[NSString stringWithFormat:
											TGL(@"Settings.CodeCharacterCountSentTo", @"A %ld-character code went to %@."),
										(long)length, pattern]];
	};
	if ([title isEqualToString:TGL(@"Conversation.MessageDialogRetry", @"Resend")]) {
		if (login)
			[[TGClient shared] resendLoginEmailAddressCodeWithCompletion:sent];
		else
			[[TGClient shared] resendEmailAddressVerificationCodeWithCompletion:sent];
		return;
	}
	if (!typed.length)
		return;
	void (^checked)(BOOL) = ^(BOOL ok) {
		[weakSelf reportResult:ok title:TGL(@"CheckoutInfo.ReceiverInfoEmail", @"Email")
					   success:TGL(@"Settings.TheAddressIsConfirmed", @"The address is confirmed.")
					   failure:TGL(@"Settings.ThatCodeWasNotAccepted", @"That code was not accepted.")];
	};
	TGClient *client = [TGClient shared];
	if (login)
		[client checkLoginEmailAddressCode:typed completion:checked];
	else
		[client checkEmailAddressVerificationCode:typed completion:checked];
}

- (void)showBirthdayDatePickerSheet {
	NSInteger day = 0, month = 0, year = 0;
	NSArray *parts = [self.birthdayText componentsSeparatedByString:@"."];
	if (parts.count >= 2) {
		day = [parts[0] integerValue];
		month = [parts[1] integerValue];
	}
	if (parts.count >= 3)
		year = [parts[2] integerValue];

	UIActionSheet *sheet = [[UIActionSheet alloc]
				 initWithTitle:nil
					  delegate:self
			 cancelButtonTitle:nil
		destructiveButtonTitle:nil
			 otherButtonTitles:nil];
	sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	sheet.tag = 14;

	CGFloat sheetWidth = self.navigationController.view.bounds.size.width;
	if (sheetWidth < 1.0f)
		sheetWidth = self.view.bounds.size.width;

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, sheetWidth, 44)];
	bar.barStyle = UIBarStyleBlackTranslucent;
	UIBarButtonItem *cancel = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
							 target:self
							 action:@selector(dismissBirthdaySheet)];
	UIBarButtonItem *space = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
							 target:nil
							 action:nil];
	UIBarButtonItem *done = [[UIBarButtonItem alloc]
		initWithTitle:TGL(@"Conversation.LinkDialogSave", @"Save")
				style:UIBarButtonItemStyleDone
			   target:self
			   action:@selector(submitBirthdayFromPicker)];
	bar.items = @[ cancel, space, done ];
	[sheet addSubview:bar];

	UISwitch *hideYearSwitch = [[UISwitch alloc] init];
	hideYearSwitch.on = day > 0 && year == 0;
	hideYearSwitch.frame = CGRectMake(sheetWidth - hideYearSwitch.frame.size.width - 16,
		44 + (44 - hideYearSwitch.frame.size.height) / 2,
		hideYearSwitch.frame.size.width, hideYearSwitch.frame.size.height);
	[sheet addSubview:hideYearSwitch];
	self.birthdayHideYearSwitch = hideYearSwitch;

	UILabel *hideYearLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(16, 44, sheetWidth - hideYearSwitch.frame.size.width - 32, 44)];
	hideYearLabel.backgroundColor = [UIColor clearColor];
	hideYearLabel.textColor = [UIColor whiteColor];
	hideYearLabel.font = [UIFont systemFontOfSize:15];
	hideYearLabel.text = TGL(@"SuggestBirthdate.Accept.HideYear", @"Hide the Year");
	[sheet addSubview:hideYearLabel];

	NSDateComponents *comps = [[NSDateComponents alloc] init];
	comps.day = day > 0 ? day : 1;
	comps.month = month > 0 ? month : 1;
	comps.year = year > 0 ? year : 2000;
	NSDate *initialDate = [[NSCalendar currentCalendar] dateFromComponents:comps] ?: [NSDate date];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, 88, sheetWidth, 216)];
	picker.datePickerMode = UIDatePickerModeDate;
	picker.maximumDate = [NSDate date];
	picker.date = initialDate;
	[sheet addSubview:picker];
	self.birthdayPicker = picker;
	self.birthdaySheet = sheet;

	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.navigationController.view.bounds), CGRectGetMidY(self.navigationController.view.bounds), 1, 1)
					 inView:self.navigationController.view];
	[sheet setBounds:CGRectMake(0, 0, sheetWidth, 364)];
}

- (void)dismissBirthdaySheet {
	[self.birthdaySheet dismissWithClickedButtonIndex:-1 animated:YES];
	self.birthdaySheet = nil;
	self.birthdayPicker = nil;
	self.birthdayHideYearSwitch = nil;
}

- (void)submitBirthdayFromPicker {
	NSDate *date = self.birthdayPicker.date;
	BOOL hideYear = self.birthdayHideYearSwitch.on;
	[self.birthdaySheet dismissWithClickedButtonIndex:-1 animated:YES];
	self.birthdaySheet = nil;
	self.birthdayPicker = nil;
	self.birthdayHideYearSwitch = nil;
	if (!date)
		return;

	NSDateComponents *parts = [[NSCalendar currentCalendar]
		components:(NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit)
		  fromDate:date];
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setBirthdateDay:parts.day month:parts.month year:(hideYear ? 0 : parts.year)
				 completion:^(BOOL ok) {
					 if (ok)
						 [weakSelf reload];
					 else
						 [weakSelf reportResult:NO title:TGL(@"Settings.Birthday", @"Birthday") success:nil
										failure:TGL(@"Settings.TelegramWouldNotTakeThatDate", @"Telegram would not take that date.")];
				 }];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex)
		return;

	if (sheet.tag == 10) {
		[self reorderUsernamesToIndex:index];
		return;
	}

	if (sheet.tag == 11) {
		[self handleProfilePhotoSheetAtIndex:index];
		return;
	}

	if (sheet.tag == 12) {
		[self handleBirthdaySheetAtIndex:index];
		return;
	}

	if (sheet.tag == 13)
		[self setPersonalChatFromPickAtIndex:index];
}

- (void)reorderUsernamesToIndex:(NSInteger)index {
	if ((NSUInteger)index >= self.usernamePicks.count)
		return;
	__weak typeof(self) weakSelf = self;
	NSString *chosen = self.usernamePicks[index];
	NSMutableArray *order = [NSMutableArray arrayWithObject:chosen];
	for (NSString *username in self.usernamePicks) {
		if (![username isEqualToString:chosen])
			[order addObject:username];
	}
	[[TGClient shared] reorderActiveUsernames:order completion:^(BOOL ok, NSString *errorMessage) {
		if (ok) {
			[weakSelf reload];
			return;
		}
		NSString *failure = (errorMessage.length && [errorMessage rangeOfString:@"USERNAMES_ACTIVE_TOO_MUCH"].location != NSNotFound)
			? TGL(@"Username.TooManyActiveLinks", @"Sorry, you can't have that many active links. Turn off another link first.")
			: TGL(@"Settings.TheOrderCouldNotBeSaved", @"The order could not be saved.");
		[weakSelf reportResult:NO title:TGL(@"Settings.Usernames", @"Usernames") success:nil failure:failure];
	}];
}

- (void)handleProfilePhotoSheetAtIndex:(NSInteger)index {
	__weak typeof(self) weakSelf = self;
	if (index == 0 || index == 1) {
		if (![UIImagePickerController isSourceTypeAvailable:
					UIImagePickerControllerSourceTypePhotoLibrary]) {
			[self reportResult:NO title:TGL(@"Privacy.ProfilePhoto", @"Profile Photo") success:nil
					   failure:TGL(@"Chat.ThereIsNoPhotoLibraryOn", @"There is no photo library on this device.")];
			return;
		}
		self.pickingPublicPhoto = (index == 1);
		UIImagePickerController *picker = [[UIImagePickerController alloc] init];
		picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
		picker.delegate = self;
		picker.allowsEditing = YES;
		[self showPicker:picker];
		return;
	}
	if (!self.photos.count) {
		[self reportResult:NO title:TGL(@"Privacy.ProfilePhoto", @"Profile Photo") success:nil
				   failure:TGL(@"Settings.ThereIsNoProfilePhotoToRemove", @"There is no profile photo to remove.")];
		return;
	}
	long long currentPhotoId = [self.photos.firstObject[@"id"] longLongValue];
	[[TGClient shared] deleteProfilePhoto:currentPhotoId completion:^(BOOL ok) {
		if (ok)
			[weakSelf reload];
		else
			[weakSelf reportResult:NO title:TGL(@"Privacy.ProfilePhoto", @"Profile Photo") success:nil
						   failure:TGL(@"Settings.ThePhotoCouldNotBeRemoved", @"The photo could not be removed.")];
	}];
}

- (void)handleBirthdaySheetAtIndex:(NSInteger)index {
	__weak typeof(self) weakSelf = self;
	if (index == 0) {
		[self showBirthdayDatePickerSheet];
		return;
	}
	[[TGClient shared] clearBirthdateWithCompletion:^(BOOL ok) {
		if (ok)
			[weakSelf reload];
		else
			[weakSelf reportResult:NO title:TGL(@"Settings.Birthday", @"Birthday") success:nil
						   failure:TGL(@"Settings.TheBirthdayCouldNotBeCleared", @"The birthday could not be cleared.")];
	}];
}

- (void)setPersonalChatFromPickAtIndex:(NSInteger)index {
	__weak typeof(self) weakSelf = self;
	int64_t chatId = 0;
	if ((NSUInteger)index < self.chatPicks.count) {
		NSDictionary *chat = self.chatPicks[index];
		chatId = [chat[@"id"] longLongValue];
	}
	[[TGClient shared] setPersonalChat:chatId completion:^(BOOL ok) {
		if (ok)
			[weakSelf reload];
		else
			[weakSelf reportResult:NO title:TGL(@"Settings.PersonalChannelItem", @"Channel") success:nil
						   failure:TGL(@"Settings.TelegramWouldNotFeatureThatChat", @"Telegram would not feature that chat.")];
	}];
}

- (void)showPicker:(UIImagePickerController *)picker {
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad || picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
		[self presentViewController:picker animated:YES completion:nil];
		return;
	}
	[self dismissPickerPopover];
	UIPopoverController *popover =
		[[UIPopoverController alloc] initWithContentViewController:picker];
	self.pickerPopover = popover;
	[popover presentPopoverFromRect:[self anchorRect]
							 inView:self.view
		   permittedArrowDirections:UIPopoverArrowDirectionAny
						   animated:YES];
}

- (void)showSheet:(UIActionSheet *)sheet {
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
		[sheet tg_showFromRect:[self anchorRect] inView:self.view];
		return;
	}
	[sheet showFromRect:[self anchorRect] inView:self.view animated:YES];
}

- (CGRect)anchorRect {
	NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
	if (selected)
		return [self.view convertRect:[self.tableView rectForRowAtIndexPath:selected]
							 fromView:self.tableView];
	CGRect bounds = self.view.bounds;
	return CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1, 1);
}

- (BOOL)dismissPickerPopover {
	if (!self.pickerPopover)
		return NO;
	[self.pickerPopover dismissPopoverAnimated:YES];
	self.pickerPopover = nil;
	return YES;
}

- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info {
	if (![self dismissPickerPopover])
		[picker dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerEditedImage];
	if (!image)
		image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;

	CGSize size = image.size;
	CGFloat limit = 640.0f;
	CGFloat scale = MIN(1.0f, MIN(limit / MAX(size.width, 1.0f), limit / MAX(size.height, 1.0f)));
	UIImage *sized = image;
	if (scale < 1.0f || image.imageOrientation != UIImageOrientationUp) {
		CGSize target = CGSizeMake(floorf(size.width * scale),
			floorf(size.height * scale));
		UIGraphicsBeginImageContextWithOptions(target, YES, 1.0f);
		[image drawInRect:CGRectMake(0, 0, target.width, target.height)];
		sized = UIGraphicsGetImageFromCurrentImageContext() ?: image;
		UIGraphicsEndImageContext();
	}

	NSData *jpeg = UIImageJPEGRepresentation(sized, 0.8f);
	NSString *path = [NSTemporaryDirectory()
		stringByAppendingPathComponent:@"tg-profile-photo.jpg"];
	if (!jpeg || ![jpeg writeToFile:path atomically:YES]) {
		[self reportResult:NO title:TGL(@"Privacy.ProfilePhoto", @"Profile Photo") success:nil
				   failure:TGL(@"Settings.ThePictureCouldNotBePrepared", @"The picture could not be prepared.")];
		return;
	}

	BOOL asPublic = self.pickingPublicPhoto;
	self.pickingPublicPhoto = NO;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setProfilePhotoAtPath:path public:asPublic completion:^(BOOL ok) {
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		if (!ok) {
			[weakSelf reportResult:NO title:TGL(@"Privacy.ProfilePhoto", @"Profile Photo") success:nil
						   failure:TGL(@"Settings.TelegramWouldNotTakeThatPicture", @"Telegram would not take that picture.")];
			return;
		}
		[weakSelf reload];
		if (asPublic)
			[weakSelf reportResult:YES title:TGL(@"UserInfo.PublicPhoto", @"Public Photo")
						   success:TGL(@"Privacy.ProfilePhoto.PublicPhotoInfo", @"You can upload a public photo for those who are restricted from viewing your real profile photo.")
						   failure:nil];
	}];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.pickingPublicPhoto = NO;
	if (![self dismissPickerPopover])
		[picker dismissViewControllerAnimated:YES completion:nil];
}

@end
