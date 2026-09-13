#import "TGTextFieldStyle.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGMemberRightsViewController.h"
#import "TGStringTruncation.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient+Groups.h"
#import "TGFlattenGroups.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGAlertView.h"
#import "TGImageDecode.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGGroupMembersViewControllerInternal.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGActionSheet.h"

@implementation TGMemberRightsViewController

- (id)initWithChatId:(int64_t)chatId userId:(int64_t)userId
				name:(NSString *)name
		 restricting:(BOOL)restricting {
	self = [super init];
	if (!self)
		return nil;
	_chatId = chatId;
	_userId = userId;
	_restricting = restricting;
	self.memberName = name.length ? name : TGL(@"GroupMembers.FallbackName", @"this user");
	self.values = [NSMutableDictionary dictionary];
	self.keys = [NSArray array];
	return self;
}

- (id)initWithDefaultPermissionsOfChat:(int64_t)chatId {
	self = [self initWithChatId:chatId userId:0 name:nil restricting:YES];
	if (!self)
		return nil;
	_defaults = YES;
	return self;
}

- (id)initForBanningWithChatId:(int64_t)chatId userId:(int64_t)userId name:(NSString *)name {
	self = [self initWithChatId:chatId userId:userId name:name restricting:NO];
	if (!self)
		return nil;
	_banning = YES;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	if (_defaults)
		self.title = TGL(@"GroupInfo.Permissions", @"Permissions");
	else if (_banning)
		self.title = TGL(@"Channel.BanUser.Title", @"Ban User");
	else
		self.title = _restricting ? TGL(@"Channel.BanUser.PermissionsHeader", @"Restrictions") : TGL(@"Bot.AddToChat.Add.AdminRights", @"Admin Rights");
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
	self.tableView.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.rowHeight = 44;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[self.view addSubview:self.tableView];

	self.statusLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 120, self.view.bounds.size.width, 22)];
	self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.statusLabel.backgroundColor = [UIColor clearColor];
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.font = [UIFont systemFontOfSize:15];
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.statusLabel.hidden = YES;
	[self.view addSubview:self.statusLabel];

	self.spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 90);
	self.spinner.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];
	[self.spinner startAnimating];
	self.tableView.hidden = YES;

	[self loadCurrentState];
}

- (NSArray *)defaultAdminKeys {
	return [NSArray arrayWithObjects:@"can_manage_chat", @"can_change_info",
		@"can_delete_messages", @"can_invite_users", @"can_restrict_members",
		@"can_pin_messages", @"can_manage_video_chats", nil];
}

- (void)loadCurrentState {
	__weak typeof(self) weakSelf = self;
	if (_banning) {
		self.keys = [NSArray array];
		self.untilDate = 0;
		self.editable = YES;
		[self finishLoading];
		return;
	}
	if (_defaults) {
		self.keys = [[TGClient shared] memberPermissionKeys] ?: [NSArray array];
		TGClient *client = [TGClient shared];
		[client defaultPermissionsInGroup:_chatId completion:^(NSDictionary *permissions) {
			TGMemberRightsViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (![permissions isKindOfClass:NSDictionary.class]) {
				[strongSelf showLoadFailure];
				return;
			}
			[strongSelf.values removeAllObjects];
			for (NSString *key in strongSelf.keys) {
				BOOL on = [[permissions objectForKey:key] boolValue];
				[strongSelf.values setObject:[NSNumber numberWithBool:on] forKey:key];
			}
			strongSelf.editable = YES;
			[strongSelf finishLoading];
		}];
		return;
	}
	if (_restricting) {
		self.keys = [[TGClient shared] memberPermissionKeys] ?: [NSArray array];
		TGClient *client = [TGClient shared];
		void (^apply)(NSDictionary *, BOOL, NSInteger) = ^(NSDictionary *permissions, BOOL isRestricted, NSInteger untilDate) {
			TGMemberRightsViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (![permissions isKindOfClass:NSDictionary.class]) {
				[strongSelf showLoadFailure];
				return;
			}
			strongSelf.untilDate = untilDate;
			[strongSelf.values removeAllObjects];
			for (NSString *key in strongSelf.keys) {
				BOOL on = [[permissions objectForKey:key] boolValue];
				[strongSelf.values setObject:[NSNumber numberWithBool:on] forKey:key];
			}
			strongSelf.editable = YES;
			[strongSelf finishLoading];
		};
		[client permissionsOfUser:_userId inGroup:_chatId completion:apply];
		return;
	}

	self.keys = self.basicGroupAdmin ? [NSArray array] : ([[TGClient shared] administratorRightKeys] ?: [NSArray array]);
	TGClient *client = [TGClient shared];
	void (^apply)(NSDictionary *, NSString *, BOOL, NSString *) =
		^(NSDictionary *rights, NSString *status, BOOL canBeEdited, NSString *customTitle) {
			TGMemberRightsViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (![rights isKindOfClass:NSDictionary.class]) {
				[strongSelf showLoadFailure];
				return;
			}
			BOOL alreadyAdmin = [status isEqualToString:@"administrator"] || [status isEqualToString:@"creator"];
			[strongSelf.values removeAllObjects];
			for (NSString *key in strongSelf.keys) {
				BOOL on = [[rights objectForKey:key] boolValue];
				if (!alreadyAdmin)
					on = [[strongSelf defaultAdminKeys] containsObject:key];
				[strongSelf.values setObject:[NSNumber numberWithBool:on] forKey:key];
			}
			strongSelf.customTitle = customTitle.length ? customTitle : nil;
			strongSelf.editable = canBeEdited || !alreadyAdmin;
			[strongSelf finishLoading];
		};
	[client administratorRightsOfUser:_userId inGroup:_chatId completion:apply];
}

- (void)showLoadFailure {
	[self.spinner stopAnimating];
	self.tableView.hidden = YES;
	self.statusLabel.text = TGL(@"Login.UnknownError", @"An error occurred, please try again later.");
	self.statusLabel.hidden = NO;
}

- (void)finishLoading {
	[self.spinner stopAnimating];
	self.statusLabel.hidden = YES;
	self.loaded = YES;
	self.tableView.hidden = NO;
	[self.tableView reloadData];
	if (self.editable) {
		self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Done", @"Done") bold:YES
									   target:self
									   action:@selector(save)];
	}
}

- (BOOL)hasExtraSection {
	if (!self.loaded || !self.editable || _defaults)
		return NO;
	return _restricting || _banning || self.canTransferOwnership;
}

- (BOOL)hasTitleSection {
	return !_restricting && !_defaults && !_banning;
}

- (NSInteger)titleSectionIndex {
	return [self hasTitleSection] ? 0 : -1;
}

- (NSInteger)rightsSectionIndex {
	return [self hasTitleSection] ? 1 : 0;
}

- (NSInteger)extraSectionIndex {
	return [self hasExtraSection] ? [self rightsSectionIndex] + 1 : -1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	NSInteger count = 1;
	if ([self hasTitleSection])
		count++;
	if ([self hasExtraSection])
		count++;
	return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == [self titleSectionIndex])
		return 1;
	if (section == [self extraSectionIndex])
		return 1;
	return self.loaded ? (NSInteger)self.keys.count : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == [self titleSectionIndex])
		return TGL(@"Group.EditAdmin.RankTitle", @"CUSTOM TITLE");
	if (section == [self extraSectionIndex])
		return (_restricting || _banning) ? TGL(@"GroupPermission.Duration", @"Duration") : nil;
	if (_banning)
		return nil;
	if (_defaults)
		return TGL(@"GroupInfo.Permissions.SectionTitle", @"WHAT CAN MEMBERS OF THIS GROUP DO?");
	if (self.basicGroupAdmin)
		return nil;
	return _restricting ? TGL(@"GroupPermission.SectionTitle", @"WHAT CAN THIS MEMBER DO?")
						 : TGL(@"Channel.EditAdmin.PermissionsHeader", @"WHAT CAN THIS ADMIN DO?");
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == [self titleSectionIndex])
		return [NSString stringWithFormat:TGL(@"Group.EditAdmin.RankInfo", @"A title that will be shown instead of '%@'."),
			TGL(@"Group.EditAdmin.RankAdminPlaceholder", @"admin")];
	if (section == [self extraSectionIndex]) {
		if (_restricting || _banning)
			return self.untilDate > 0
				? TGL(@"MemberRights.RestrictionsLiftAutomatically", @"The restrictions are lifted automatically when the time is up.")
				: TGL(@"MemberRights.RestrictionsStayUntilLifted", @"The restrictions stay until you lift them.");
		return [NSString stringWithFormat:TGL(@"MemberRights.OwnerTransferFooter", @"%@ becomes the owner and you keep only admin rights."),
			self.memberName];
	}
	if (_banning)
		return [NSString stringWithFormat:TGL(@"MemberRights.BannedFooter", @"%@ is removed from the group and cannot rejoin until the ban is lifted."),
			self.memberName];
	if (_defaults)
		return TGL(@"MemberRights.DefaultsFooter", @"Anything turned off here is denied to every member who is not an administrator.");
	if (self.basicGroupAdmin)
		return TGL(@"MemberRights.BasicGroupAdminFooter", @"In basic groups, administrators have all applicable rights. Upgrade to a supergroup to choose them individually.");
	if (!self.editable)
		return _restricting
			? TGL(@"GroupPermission.EditingDisabled", @"You cannot edit restrictions of this user.")
			: TGL(@"Channel.EditAdmin.CannotEdit", @"You cannot edit the rights of this admin.");
	if (_restricting)
		return [NSString stringWithFormat:TGL(@"MemberRights.RestrictingFooter", @"Anything turned off here is denied to %@."),
			self.memberName];
	return [NSString stringWithFormat:TGL(@"MemberRights.AdminRightsFooter", @"%@ keeps only the rights left on here."),
		self.memberName];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == [self titleSectionIndex]) {
		static NSString *titleReuse = @"TGMemberTitleCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:titleReuse];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:titleReuse];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			UITextField *field = [[UITextField alloc] initWithFrame:
					CGRectMake(15, 11, cell.contentView.bounds.size.width - 30, 22)];
			field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			field.font = TGTextFieldFont();
			field.placeholder = TGL(@"Stickers.SuggestNone", @"None");
			field.delegate = self;
			field.returnKeyType = UIReturnKeyDone;
			field.clearButtonMode = UITextFieldViewModeWhileEditing;
			field.autocorrectionType = UITextAutocorrectionTypeNo;
			TGStyleTextField(field);
			[field addTarget:self action:@selector(customTitleChanged:)
				forControlEvents:UIControlEventEditingChanged];
			[cell.contentView addSubview:field];
			self.customTitleField = field;
		}
		self.customTitleField.text = self.customTitle ?: @"";
		self.customTitleField.textColor = [[TGTheme shared] primaryTextColour];
		self.customTitleField.enabled = self.editable;
		return cell;
	}

	if (indexPath.section == [self extraSectionIndex]) {
		static NSString *extraReuse = @"TGMemberExtraCell";
		UITableViewCell *extra = [tableView dequeueReusableCellWithIdentifier:extraReuse];
		if (!extra) {
			extra = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
										   reuseIdentifier:extraReuse];
			extra.textLabel.font = TGGroupedRowTitleFont();
		}
		if (_restricting || _banning) {
			[TGIcons removeActionButtonFromCell:extra];
			extra.textLabel.font = TGGroupedRowTitleFont();
			extra.textLabel.text = TGL(@"GroupPermission.Duration", @"Duration");
			extra.textLabel.textColor = [[TGTheme shared] primaryTextColour];
			extra.detailTextLabel.text = TGMembersDurationText(self.untilDate);
			extra.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		} else {
			[TGIcons actionButtonInCell:extra
								  title:TGL(@"Group.EditAdmin.TransferOwnership", @"Transfer Ownership")
								   kind:TGActionButtonKindDestructive
								 target:self
								 action:@selector(transferOwnershipPressed)];
		}
		return extra;
	}

	static NSString *reuse = @"TGMemberRightCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.font = TGGroupedRowTitleFont();
	}

	if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.keys.count)
		return cell;
	NSString *key = [self.keys objectAtIndex:(NSUInteger)indexPath.row];
	cell.textLabel.text = _restricting
		? TGTitleForMemberPermissionKey(key)
		: TGTitleForAdministratorRightKey(key);
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];

	UISwitch *toggle = [cell.accessoryView isKindOfClass:UISwitch.class]
		? (UISwitch *)cell.accessoryView
		: nil;
	if (!toggle) {
		toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
		[toggle addTarget:self action:@selector(toggleChanged:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
	}
	toggle.tag = indexPath.row;
	toggle.on = [[self.values objectForKey:key] boolValue];
	toggle.enabled = self.editable;
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == [self extraSectionIndex] && !(_restricting || _banning))
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section != [self extraSectionIndex])
		return;
	if (_restricting || _banning) {
		NSInteger cancelIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:TGL(@"Channel.BanUser.BlockFor", @"Restrict for")
						  delegate:self
					   otherTitles:@[ TGLPlural(@"MessageTimer.Days", 1, @"%d day", @"%d days"), TGLPlural(@"MessageTimer.Weeks", 1, @"%d week", @"%d weeks"),
						   TGLPlural(@"MessageTimer.Months", 1, @"%d month", @"%d months"), TGL(@"MessageTimer.Forever", @"Forever") ]
				  destructiveIndex:-1
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:NULL
				 cancelButtonIndex:&cancelIndex];
		UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
		[sheet tg_showFromRect:cell.frame inView:tableView];
		return;
	}
}

- (void)transferOwnershipPressed {
	if (self.onTransferOwnership)
		self.onTransferOwnership();
}

- (void)customTitleChanged:(UITextField *)field {
	NSString *text = [field.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (text.length > 16) {
		text = TGSafeSubstringToIndex(text, 16);
		field.text = text;
	}
	_customTitleEdited = YES;
	self.customTitle = text.length ? text : nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;
	NSInteger now = (NSInteger)[[NSDate date] timeIntervalSince1970];
	switch (buttonIndex) {
		case 0:
			self.untilDate = now + kMemberDurationDay;
			break;
		case 1:
			self.untilDate = now + kMemberDurationWeek;
			break;
		case 2:
			self.untilDate = now + kMemberDurationMonth;
			break;
		default:
			self.untilDate = 0;
			break;
	}
	[self.tableView reloadData];
}

- (void)toggleChanged:(UISwitch *)sender {
	if (sender.tag < 0 || sender.tag >= (NSInteger)self.keys.count)
		return;
	NSString *key = [self.keys objectAtIndex:(NSUInteger)sender.tag];
	[self.values setObject:[NSNumber numberWithBool:sender.on] forKey:key];
}

- (void)save {
	if (self.saving || !self.editable)
		return;
	self.saving = YES;
	self.navigationItem.rightBarButtonItem.enabled = NO;

	NSMutableDictionary *payload = [NSMutableDictionary dictionary];
	for (NSString *key in self.keys) {
		if ([[self.values objectForKey:key] boolValue])
			[payload setObject:[NSNumber numberWithBool:YES] forKey:key];
	}

	__weak typeof(self) weakSelf = self;
	void (^done)(BOOL) = ^(BOOL ok) {
		TGMemberRightsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.saving = NO;
		strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
		if (!ok) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"GroupMembers.CouldNotSaveChanges", @"Could not save the changes.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		if (strongSelf.onSaved)
			strongSelf.onSaved();
		[strongSelf.navigationController popViewControllerAnimated:YES];
	};

	if (_defaults) {
		[[TGClient shared] setDefaultPermissions:payload
										 inGroup:_chatId
									  completion:done];
		return;
	}
	if (_banning) {
		[[TGClient shared] banMember:_userId
							  inGroup:_chatId
							untilDate:self.untilDate
					   revokeMessages:NO
						   completion:done];
		return;
	}
	if (_restricting) {
		[[TGClient shared] restrictMember:_userId
								  inGroup:_chatId
							  permissions:payload
								untilDate:self.untilDate
							   completion:done];
		return;
	}
	[[TGClient shared] promoteMember:_userId
							 inGroup:_chatId
							  rights:payload
						 customTitle:_customTitleEdited ? (self.customTitle ?: @"") : nil
						  completion:^(BOOL statusOk, BOOL tagOk) {
							  TGMemberRightsViewController *strongSelf = weakSelf;
							  if (!strongSelf)
								  return;
							  strongSelf.saving = NO;
							  strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
							  if (!statusOk) {
								  [[[UIAlertView alloc] initWithTitle:nil
															  message:TGL(@"GroupMembers.CouldNotSaveChanges", @"Could not save the changes.")
															 delegate:nil
													cancelButtonTitle:TGL(@"Common.OK", @"OK")
													otherButtonTitles:nil] show];
								  return;
							  }
							  if (!tagOk) {
								  [[[UIAlertView alloc] initWithTitle:nil
															  message:TGL(@"GroupMembers.CouldNotSaveCustomTitle", @"The admin rights were saved, but the custom title could not be set.")
															 delegate:nil
													cancelButtonTitle:TGL(@"Common.OK", @"OK")
													otherButtonTitles:nil] show];
							  }
							  if (strongSelf.onSaved)
								  strongSelf.onSaved();
							  [strongSelf.navigationController popViewControllerAnimated:YES];
						  }];
}

@end
